import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import '../constants.dart';
import '../helper/utils.dart';
import '../service/chat_utilities.dart';

class ChatController extends GetxController {
  static ChatController instance = Get.find();

  var userChats = <Map<String, dynamic>>[].obs;
  var messages = <ChatScreenData>[].obs;

  late String chatId;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _messagesSubscription;

  // Initialize friend chat (simple messages collection, no modes)
  Future<void> initializeFriendChat(String friendId) async {
    debugPrint('ChatController.initializeFriendChat called with friendId: $friendId');
    if (friendId.isEmpty) {
      debugPrint("Cannot initialize friend chat: friendId is empty");
      return;
    }
    final currentUserId = userService.userId ?? '';
    debugPrint('ChatController.initializeFriendChat - currentUserId: $currentUserId');
    if (currentUserId.isEmpty) {
      debugPrint("Cannot initialize friend chat: userId is empty");
      return;
    }

    // Cancel existing subscription if any
    _messagesSubscription?.cancel();

    debugPrint('ChatController.initializeFriendChat - Calling getOrCreateChatId($currentUserId, $friendId)');
    chatId = await ChatUtilities.getOrCreateChatId(currentUserId, friendId);
    debugPrint('ChatController.initializeFriendChat - Got chatId: $chatId');

    // Listen to simple messages collection (no modes)
    listenToFriendMessages();
    debugPrint('ChatController.initializeFriendChat - listenToFriendMessages called');
  }

  // Listen to simple messages collection for friend chats
  void listenToFriendMessages() {
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
          .collection('messages') // Simple messages collection
          .orderBy('timestamp', descending: false)
          .snapshots()
          .listen(
        (querySnapshot) {
          final messagesList = querySnapshot.docs
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

          messages.value = messagesList;
        },
        onError: (e) {
          debugPrint("Error listening to messages: $e");
          messages.value = [];
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
      messages.value = [];
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

      // Optimized query: fetch chats where user is a participant
      // This uses the existing composite index on participants + lastMessageTime
      final querySnapshot = await firestore
          .collection('chats')
          .where('participants', arrayContains: userId)
          .orderBy('lastMessageTime', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => {'chatId': doc.id, ...doc.data()})
          .toList();
    } catch (e) {
      debugPrint("Error fetching user chats: $e");
      return [];
    }
  }

  // Send a message (friend chat only)
  Future<void> sendMessage({
    String? messageContent,
    List<String>? imageUrls,
    Map<String, dynamic>? shareRequest,
    bool isPrivate = false,
  }) async {
// Validate chatId is set
    if (chatId.isEmpty) {
      throw Exception("Chat ID is not initialized");
    }

    try {
      final currentUserId = userService.userId ?? '';

      // Friend chat: use simple messages collection
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
    } catch (e, stackTrace) {
      debugPrint("Error sending message: $e");
      rethrow;
    }
  }

  /// Increment calendar share count for non-premium users
  Future<void> incrementCalendarShareCount() async {
    try {
      final currentUserId = userService.userId;
      if (currentUserId == null || currentUserId.isEmpty) {
        return;
      }

      final currentUser = userService.currentUser.value;
      if (currentUser?.isPremium == true) {
        // Premium users don't have share limits
        return;
      }

      await firestore.collection('users').doc(currentUserId).set(
        {
          'calendarShares': FieldValue.increment(1),
        },
        SetOptions(merge: true),
      );

      // Log analytics event
      FirebaseAnalytics.instance.logEvent(name: 'calendar_share_request');
    } catch (e) {
      debugPrint("Error incrementing calendar share count: $e");
    }
  }

  /// Save a message to Firestore for friend chats
  static Future<void> saveMessageToFirestore({
    required String chatId,
    required String content,
    required String senderId,
    List<String>? imageUrls,
  }) async {
    if (chatId.isEmpty) {
      throw Exception("Chat ID is not initialized");
    }

    // Friend chat: use simple messages collection
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

  Future<void> sendFriendRequestMessage({
    required String senderId,
    required String recipientId,
    String? friendName,
    String? date,
  }) async {
    final chatId = await ChatUtilities.getOrCreateChatId(senderId, recipientId);
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
