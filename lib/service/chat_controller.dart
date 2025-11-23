import 'dart:async';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart' show debugPrint;
import '../constants.dart';
import '../helper/utils.dart';

class ChatController extends GetxController {
  static ChatController instance = Get.find();

  var userChats = <Map<String, dynamic>>[].obs;
  var messages = <ChatScreenData>[].obs;

  late String chatId;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _messagesSubscription;

  // Initialize chat and listen for messages
  Future<void> initializeChat(String friendId) async {
    if (friendId.isEmpty) {
      debugPrint("Cannot initialize chat: friendId is empty");
      return;
    }
    final currentUserId = userService.userId ?? '';
    if (currentUserId.isEmpty) {
      debugPrint("Cannot initialize chat: userId is empty");
      return;
    }
    chatId = await getOrCreateChatId(currentUserId, friendId);
    listenToMessages();
  }

  void listenToMessages() {
    _listenToMessages();
  }

  // Listen for new messages in the chat
  void _listenToMessages() {
    if (chatId.isEmpty) {
      debugPrint("Chat ID is empty");
      return;
    }

    // Cancel existing subscription if any
    _messagesSubscription?.cancel();

    try {
      _messagesSubscription = firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .orderBy('timestamp', descending: false)
          .snapshots()
          .listen(
        (querySnapshot) {
          messages.value = querySnapshot.docs
              .map((doc) {
                try {
                  return ChatScreenData.fromFirestore(doc.data(),
                      messageId: doc.id);
                } catch (e) {
                  debugPrint("Error parsing message data: $e");
                  return null;
                }
              })
              .whereType<ChatScreenData>()
              .toList();
        },
        onError: (e) {
          debugPrint("Error listening to messages: $e");
          messages.clear();
          // Show user-friendly error notification
          try {
            Get.snackbar(
              'Connection Error',
              'Unable to load messages. Please check your connection and try again.',
              snackPosition: SnackPosition.BOTTOM,
              duration: const Duration(seconds: 3),
            );
          } catch (_) {
            // Ignore if Get.context is not available
          }
        },
      );
    } catch (e) {
      debugPrint("Error setting up message listener: $e");
      messages.clear();
    }
  }

  // Load chats the user is part of
  Future<void> loadUserChats(String userId) async {
    try {
      final fetchedChats = await fetchUserChats(userId);

      // Filter to only active chats
      final activeChats =
          fetchedChats.where((chat) => chat['isActive'] != false).toList();

      for (var chat in activeChats) {
        final chatId = chat['chatId'];
        final participants = List<String>.from(chat['participants'] ?? []);
        final otherUserId =
            participants.firstWhere((id) => id != userId, orElse: () => '');

        final unreadMessagesQuery = await firestore
            .collection('chats')
            .doc(chatId)
            .collection('messages')
            .where('isRead', isEqualTo: false)
            .where('senderId', isEqualTo: otherUserId)
            .get();

        final unreadCount = unreadMessagesQuery.docs.length;
        chat['unreadCount'] = unreadCount;
      }

      userChats.value = activeChats;
    } catch (e) {
      debugPrint("Error loading user chats: $e");
      userChats.clear();
    }
  }

  Future<void> disableChats(String chatId, bool isActive) async {
    await firestore
        .collection('chats')
        .doc(chatId)
        .update({'isActive': isActive});
  }

  Future<void> markMessagesAsRead(String chatId, String otherUserId) async {
    final messagesQuery = await firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .where('isRead', isEqualTo: false)
        .where('senderId',
            isEqualTo: otherUserId) // Only mark others' messages as read
        .get();

    for (var doc in messagesQuery.docs) {
      await firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(doc.id)
          .update({'isRead': true});
    }
  }

  // Fetch user chat list
  Future<List<Map<String, dynamic>>> fetchUserChats(String userId) async {
    try {
      if (userId.isEmpty) {
        return [];
      }

      final userDoc = await firestore.collection('users').doc(userId).get();
      final userData = userDoc.data();
      if (!userDoc.exists ||
          userData == null ||
          !userData.containsKey('chats')) {
        return [];
      }

      final chatIds = List<String>.from(userData['chats'] ?? []);
      if (chatIds.isEmpty) {
        return [];
      }

      // Filter out empty chat IDs
      final validChatIds = chatIds.where((id) => id.isNotEmpty).toList();
      if (validChatIds.isEmpty) {
        return [];
      }

      // Fetch all chat documents in parallel for better performance
      // Use individual try-catch for each chat to handle permission errors gracefully
      final List<Map<String, dynamic>> chats = [];
      for (final chatId in validChatIds) {
        try {
          final chatDoc = await firestore.collection('chats').doc(chatId).get();
          if (chatDoc.exists) {
            final chatData = chatDoc.data();
            if (chatData != null) {
              chats.add({'chatId': chatId, ...chatData});
            }
          }
        } catch (e) {
          // Skip chats the user doesn't have permission to read
          // This can happen if chat permissions changed or chat was deleted
          debugPrint("Error fetching chat $chatId: $e");
          continue;
        }
      }
      return chats;
    } catch (e) {
      debugPrint("Error fetching user chats: $e");
      return [];
    }
  }

  // Send a message
  Future<void> sendMessage({
    String? messageContent,
    List<String>? imageUrls,
    Map<String, dynamic>? shareRequest,
    bool isPrivate = false,
  }) async {
    try {
      final currentUserId = userService.userId ?? '';

      final chatRef = firestore.collection('chats').doc(chatId);
      final messageRef = chatRef.collection('messages').doc();

      final timestamp = FieldValue.serverTimestamp();

      final messageData = {
        'messageContent': messageContent ?? '',
        'imageUrls': imageUrls ?? [],
        'senderId': currentUserId,
        'timestamp': timestamp,
        'isRead': false,
      };

      if (shareRequest != null) {
        messageData['shareRequest'] = {
          ...shareRequest,
          'status': 'pending',
        };
      }

      await firestore.runTransaction((transaction) async {
        transaction.set(messageRef, messageData);

        transaction.update(chatRef, {
          'lastMessage': messageContent?.isNotEmpty == true
              ? messageContent
              : (imageUrls != null && imageUrls.isNotEmpty ? 'Photo' : ''),
          'lastMessageTime': timestamp,
        });
      });
    } catch (e) {
      debugPrint("Error sending message: $e");
    }
  }

  /// Save a message to Firestore for any chatId (for use in buddy_screen, program_screen, etc)
  static Future<void> saveMessageToFirestore({
    required String chatId,
    required String content,
    required String senderId,
    List<String>? imageUrls,
  }) async {
    final messageRef =
        firestore.collection('chats').doc(chatId).collection('messages').doc();
    final timestamp = FieldValue.serverTimestamp();
    await firestore.runTransaction((transaction) async {
      transaction.set(messageRef, {
        'messageContent': content,
        'senderId': senderId,
        'timestamp': timestamp,
        'imageUrls': imageUrls ?? [],
      });
      // Update chat summary (last message and time)
      transaction.update(
        firestore.collection('chats').doc(chatId),
        {
          'lastMessage': content,
          'lastMessageTime': timestamp,
          'lastMessageSender': senderId,
        },
      );
    });
  }

  // Accept calendar share request
  Future<void> acceptCalendarShare(String messageId) async {
    try {
      final messageDoc = await firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId)
          .get();

      if (!messageDoc.exists) return;

      final messageData = messageDoc.data();
      if (messageData == null) return;
      final shareRequest = messageData['shareRequest'] as Map<String, dynamic>?;
      if (shareRequest == null) return;

      final header = shareRequest['header'] as String?;

      final calendarId = shareRequest['calendarId'] as String?;

      final calendarRef =
          firestore.collection('shared_calendars').doc(calendarId);

      // Get current calendar data
      final calendarDoc = await calendarRef.get();
      if (!calendarDoc.exists) return;

      final calendarData = calendarDoc.data() as Map<String, dynamic>;
      final currentUserIds = List<String>.from(calendarData['userIds'] ?? []);

      // Add new user if not already present
      if (!currentUserIds.contains(userService.userId)) {
        currentUserIds.add(userService.userId ?? '');
      }

      // Update header and merge with existing userIds
      await calendarRef.update({
        'header': header,
        'userIds': FieldValue.arrayUnion([userService.userId ?? '']),
      });

      // Update message to show accepted status
      await messageDoc.reference.update({
        'shareRequest.status': 'accepted',
      });
      // Send acceptance message
      await sendMessage(
        messageContent: 'I accepted your calendar share!',
      );
    } catch (e) {
      debugPrint("Error accepting calendar share 2: $e");
    }
  }

  // Get or create a chat document based on participants
  Future<String> getOrCreateChatId(String userId1, String userId2) async {
    try {
      final userDoc = await firestore.collection('users').doc(userId1).get();
      final existingChatIds = List<String>.from(userDoc.data()?['chats'] ?? []);

      for (final chatId in existingChatIds) {
        try {
          final chatDoc = await firestore.collection('chats').doc(chatId).get();
          if (!chatDoc.exists) {
            continue;
          }
          final participants =
              List<String>.from(chatDoc.data()?['participants'] ?? []);
          if (participants.contains(userId2)) {
            return chatId;
          }
        } catch (e) {
          debugPrint('Error checking chat $chatId: $e');
          continue;
        }
      }
    } catch (e) {
      debugPrint('Error loading user chats: $e');
    }

    // Create a new chat if none exists
    // Ensure current user is in participants array for security rules
    final currentUserId = userService.userId ?? userId1;
    final participants = [userId1, userId2];
    if (!participants.contains(currentUserId)) {
      participants.add(currentUserId);
    }

    final chatDoc = await firestore.collection('chats').add({
      'participants': participants,
      'createdAt': FieldValue.serverTimestamp(),
      'lastMessage': '',
      'lastMessageTime': null,
      'isActive': true,
    });

    await _updateUserChats(userId1, chatDoc.id);
    await _updateUserChats(userId2, chatDoc.id);

    return chatDoc.id;
  }

  // Add chat reference to user's chat list
  Future<void> _updateUserChats(String userId, String chatId) async {
    await firestore.collection('users').doc(userId).set({
      'chats': FieldValue.arrayUnion([chatId]),
    }, SetOptions(merge: true));
  }

  Future<void> sendFriendRequestMessage({
    required String senderId,
    required String recipientId,
    String? friendName,
    String? date,
  }) async {
    final chatId = await getOrCreateChatId(senderId, recipientId);
    final chatRef = firestore.collection('chats').doc(chatId);
    final messageRef = chatRef.collection('messages').doc();

    final messageData = {
      'messageContent': '$friendName wants to be your friend!',
      'senderId': senderId,
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': false,
      'friendRequest': {
        'status': 'pending',
        'senderId': senderId,
        'recipientId': recipientId,
        'friendName': friendName,
        'date': date,
      }
    };

    await messageRef.set(messageData);
  }

  Future<void> acceptFriendRequest(String chatId, String messageId) async {
    final messageRef = firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId);
    final messageDoc = await messageRef.get();
    if (!messageDoc.exists) return;

    final data = messageDoc.data();
    if (data == null) return;
    final friendRequest = data['friendRequest'] as Map<String, dynamic>?;
    if (friendRequest == null) return;

    final senderId = friendRequest['senderId'];
    final recipientId = friendRequest['recipientId'];

    if (senderId == userService.userId) {
      showTastySnackbar(
        'Cannot Accept Friend Request',
        'You cannot accept your own friend request.',
        Get.context!,
      );
      return;
    }
    // Update message status
    await messageRef.update({'friendRequest.status': 'accepted'});

    // Add each user to the other's friends collection
    await firestore.collection('friends').doc(senderId).set({
      'following': FieldValue.arrayUnion([recipientId])
    }, SetOptions(merge: true));
    await firestore.collection('friends').doc(recipientId).set({
      'following': FieldValue.arrayUnion([senderId])
    }, SetOptions(merge: true));

    await friendController.fetchFollowing(senderId);
    await friendController.fetchFollowing(recipientId);
  }

  @override
  void onClose() {
    _messagesSubscription?.cancel();
    _messagesSubscription = null;
    super.onClose();
  }
}

// Message data model
class ChatScreenData {
  final String messageContent;
  final List<String> imageUrls;
  final String senderId;
  final Timestamp timestamp;
  final Map<String, dynamic>? shareRequest;
  final Map<String, dynamic>? friendRequest;
  final String messageId;

  ChatScreenData({
    required this.messageContent,
    required this.imageUrls,
    required this.senderId,
    required this.timestamp,
    this.shareRequest,
    this.friendRequest,
    required this.messageId,
  });

  Map<String, dynamic> toMap() {
    return {
      'title': messageContent,
      'mediaPaths': imageUrls,
      'senderId': senderId,
      'timestamp': timestamp,
      'messageId': messageId,
      if (shareRequest != null) 'shareRequest': shareRequest,
      if (friendRequest != null) 'friendRequest': friendRequest,
    };
  }

  factory ChatScreenData.fromFirestore(Map<String, dynamic> data,
      {String? messageId}) {
    return ChatScreenData(
      messageContent: data['messageContent'] ?? '',
      imageUrls: List<String>.from(data['imageUrls'] ?? []),
      senderId: data['senderId'] ?? '',
      timestamp: data['timestamp'] ?? Timestamp.now(),
      shareRequest: data['shareRequest'] as Map<String, dynamic>?,
      friendRequest: data['friendRequest'] as Map<String, dynamic>?,
      messageId: messageId ?? '',
    );
  }
}
