import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants.dart';
import '../helper/helper_functions.dart';

class ChatController extends GetxController {
  static ChatController instance = Get.find();

  var userChats = <Map<String, dynamic>>[].obs;
  var messages = <ChatScreenData>[].obs;

  late String chatId;

  // Initialize chat and listen for messages
  Future<void> initializeChat(String friendId) async {
    chatId = await getOrCreateChatId(userService.userId ?? '', friendId);
    listenToMessages();
  }

  void listenToMessages() {
    _listenToMessages();
  }

  // Listen for new messages in the chat
  void _listenToMessages() {
    if (chatId.isEmpty) {
      print("Chat ID is empty");
      return;
    }

    try {
      firestore
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
                  print("Error parsing message data: $e");
                  return null;
                }
              })
              .whereType<ChatScreenData>()
              .toList();
        },
        onError: (e) {
          print("Error listening to messages: $e");
          messages.clear();
        },
      );
    } catch (e) {
      print("Error setting up message listener: $e");
      messages.clear();
    }
  }

  // Load chats the user is part of
  Future<void> loadUserChats(String userId) async {
    try {
      final fetchedChats = await fetchUserChats(userId);

      for (var chat in fetchedChats) {
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

      userChats.value = fetchedChats;
    } catch (e) {
      print("Error loading user chats: $e");
      userChats.clear();
    }
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
      if (!userDoc.exists || !userDoc.data()!.containsKey('chats')) {
        return [];
      }

      final chatIds = List<String>.from(userDoc.data()?['chats'] ?? []);
      if (chatIds.isEmpty) {
        return [];
      }

      List<Map<String, dynamic>> chats = [];

      for (var chatId in chatIds) {
        if (chatId.isEmpty) continue;

        final chatDoc = await firestore.collection('chats').doc(chatId).get();
        if (chatDoc.exists && chatDoc.data() != null) {
          final chatData = chatDoc.data()!;
          chats.add({'chatId': chatId, ...chatData});
        }
      }
      return chats;
    } catch (e) {
      print("Error fetching user chats: $e");
      return [];
    }
  }

  // Send a message
  Future<void> sendMessage({
    String? messageContent,
    List<String>? imageUrls,
    Map<String, dynamic>? shareRequest,
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
      print("Error sending message: $e");
    }
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

      final messageData = messageDoc.data()!;
      final shareRequest = messageData['shareRequest'] as Map<String, dynamic>?;
      if (shareRequest == null) return;

      final senderId = messageData['senderId'] as String;
      final type = shareRequest['type'] as String;
      final date = shareRequest['date'] as String?;
      final header = shareRequest['header'] as String?;

      final calendarId = shareRequest['calendarId'] as String?; 
      if (calendarId == 'personal') {
        // Create shared calendar
        final calendarRef = firestore.collection('shared_calendars').doc();

      await calendarRef.set({
        'userIds': [senderId, userService.userId],
        'type': type,
        'date': date,
          'createdAt': FieldValue.serverTimestamp(),
          'header': header,
        });
      } else {
        // Update existing shared calendar
        final calendarRef = firestore
            .collection('shared_calendars')
            .doc(calendarId);

        // Get current calendar data
        final calendarDoc = await calendarRef.get();
        if (!calendarDoc.exists) return;

        final calendarData = calendarDoc.data() as Map<String, dynamic>;
        final currentUserIds = List<String>.from(calendarData['userIds'] ?? []);

        // Add new user if not already present
        if (!currentUserIds.contains(userService.userId)) {
          currentUserIds.add(userService.userId ?? '');
        }
        print('header: $header');

        // Update header and merge with existing userIds
        await calendarRef.update({
          'header': header,
          'userIds': FieldValue.arrayUnion([userService.userId ?? '']),
        });
       
      }

      // Update message to show accepted status
      await messageDoc.reference.update({
        'shareRequest.status': 'accepted',
      });

      // Send acceptance message
      await sendMessage(
        messageContent: 'I accepted your calendar share!',
      );
    } catch (e) {
      print("Error accepting calendar share 2: $e");
    }
  }

  // Get or create a chat document based on participants
  Future<String> getOrCreateChatId(String userId1, String userId2) async {
    final querySnapshot = await firestore
        .collection('chats')
        .where('participants', arrayContains: userId1)
        .get();

    for (var doc in querySnapshot.docs) {
      if (doc['participants'].contains(userId2)) {
        return doc.id;
      }
    }

    // Create a new chat if none exists
    final chatDoc = await firestore.collection('chats').add({
      'participants': [userId1, userId2],
      'createdAt': FieldValue.serverTimestamp(),
      'lastMessage': '',
      'lastMessageTime': null,
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
}

// Message data model
class ChatScreenData {
  final String messageContent;
  final List<String> imageUrls;
  final String senderId;
  final Timestamp timestamp;
  final Map<String, dynamic>? shareRequest;
  final String messageId;

  ChatScreenData({
    required this.messageContent,
    required this.imageUrls,
    required this.senderId,
    required this.timestamp,
    this.shareRequest,
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
      messageId: messageId ?? '',
    );
  }
}
