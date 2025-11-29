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

  // Mode-based chat state
  final RxString currentMode = 'tasty'.obs; // 'tasty', 'planner', 'meal'
  final Map<String, List<ChatScreenData>> modeMessages = {};
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _modeMessagesSubscription;

  // Planning mode state
  final RxBool isPlanningMode = false.obs;
  final RxList<ChatScreenData> planningConversation = <ChatScreenData>[].obs;
  final RxBool isReadyToGenerate = false.obs;
  final Rx<Map<String, dynamic>?> planningFormData = Rx<Map<String, dynamic>?>(null);
  final RxBool isFormSubmitted = false.obs;
  final RxBool showForm = false.obs;

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
    
    // Set up mode subcollections and migrate if needed
    await _setupModeSubcollections();
    
    // Load current mode from chat document or default to 'tasty'
    await _loadCurrentMode();
    
    // Listen to messages for current mode
    listenToModeMessages(currentMode.value);
  }
  
  // Set up mode subcollections and migrate existing messages if needed
  Future<void> _setupModeSubcollections() async {
    if (chatId.isEmpty) return;
    
    try {
      // Check if old messages collection exists and has messages
      final oldMessagesQuery = await firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .limit(1)
          .get();
      
      // Check if mode subcollections already exist
      final tastyMessagesQuery = await firestore
          .collection('chats')
          .doc(chatId)
          .collection('tasty_messages')
          .limit(1)
          .get();
      
      // Migrate old messages to tasty_messages if needed
      if (oldMessagesQuery.docs.isNotEmpty && tastyMessagesQuery.docs.isEmpty) {
        debugPrint('Migrating old messages to tasty_messages subcollection');
        final allOldMessages = await firestore
            .collection('chats')
            .doc(chatId)
            .collection('messages')
            .get();
        
        final batch = firestore.batch();
        for (var doc in allOldMessages.docs) {
          final newRef = firestore
              .collection('chats')
              .doc(chatId)
              .collection('tasty_messages')
              .doc(doc.id);
          batch.set(newRef, doc.data());
        }
        await batch.commit();
        debugPrint('Migrated ${allOldMessages.docs.length} messages to tasty_messages');
      }
    } catch (e) {
      debugPrint('Error setting up mode subcollections: $e');
    }
  }
  
  // Load current mode from chat document
  Future<void> _loadCurrentMode() async {
    if (chatId.isEmpty) return;
    
    try {
      final chatDoc = await firestore.collection('chats').doc(chatId).get();
      if (chatDoc.exists) {
        final data = chatDoc.data();
        final mode = data?['currentMode'] as String?;
        if (mode != null && ['tasty', 'planner', 'meal'].contains(mode)) {
          currentMode.value = mode;
        }
      }
    } catch (e) {
      debugPrint('Error loading current mode: $e');
    }
  }
  
  // Switch to a different mode
  Future<void> switchMode(String mode) async {
    if (!['tasty', 'planner', 'meal'].contains(mode)) {
      debugPrint('Invalid mode: $mode');
      return;
    }
    
    if (currentMode.value == mode) return;
    
    // Cancel current subscription
    _modeMessagesSubscription?.cancel();
    
    // Update current mode
    currentMode.value = mode;
    
    // Update chat document with current mode
    if (chatId.isNotEmpty) {
      try {
        await firestore.collection('chats').doc(chatId).update({
          'currentMode': mode,
          'lastModeSwitch': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        debugPrint('Error updating current mode: $e');
      }
    }
    
    // Listen to messages for new mode
    listenToModeMessages(mode);
  }
  
  // Get mode subcollection name
  String _getModeSubcollection(String mode) {
    return '${mode}_messages';
  }
  
  // Listen to messages for a specific mode
  void listenToModeMessages(String mode) {
    if (chatId.isEmpty) {
      debugPrint("Chat ID is empty");
      return;
    }

    // Cancel existing subscription if any
    _modeMessagesSubscription?.cancel();

    try {
      final subcollectionName = _getModeSubcollection(mode);
      _modeMessagesSubscription = firestore
          .collection('chats')
          .doc(chatId)
          .collection(subcollectionName)
          .orderBy('timestamp', descending: false)
          .snapshots()
          .listen(
        (querySnapshot) {
          final modeMessagesList = querySnapshot.docs
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
          
          // Cache messages for this mode
          modeMessages[mode] = modeMessagesList;
          
          // Update observable messages if this is the current mode
          if (currentMode.value == mode) {
            // Merge with existing messages to avoid losing locally added messages
            // that haven't been picked up by Firestore yet
            final existingMessages = List<ChatScreenData>.from(messages);
            final mergedMessages = <ChatScreenData>[];
            
            // First add all Firestore messages
            for (final msg in modeMessagesList) {
              mergedMessages.add(msg);
            }
            
            // Then add any local messages that don't have IDs yet (pending save)
            // These are messages added locally but not yet in Firestore
            for (final msg in existingMessages) {
              if (msg.messageId.isEmpty && 
                  !mergedMessages.any((m) => 
                    m.messageContent == msg.messageContent &&
                    m.senderId == msg.senderId &&
                    (m.timestamp.toDate().difference(msg.timestamp.toDate()).inSeconds.abs() < 5)
                  )) {
                mergedMessages.add(msg);
              }
            }
            
            // Sort by timestamp
            mergedMessages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
            
            messages.value = mergedMessages;
          }
        },
        onError: (e) {
          debugPrint("Error listening to mode messages: $e");
          modeMessages[mode] = [];
          if (currentMode.value == mode) {
            messages.clear();
          }
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
      debugPrint("Error setting up mode message listener: $e");
      modeMessages[mode] = [];
      if (currentMode.value == mode) {
        messages.clear();
      }
    }
  }
  
  // Get cached messages for a specific mode
  List<ChatScreenData> getModeMessages(String mode) {
    return modeMessages[mode] ?? [];
  }
  
  // Save message to a specific mode subcollection
  Future<void> saveMessageToMode({
    required String mode,
    required String content,
    required String senderId,
    List<String>? imageUrls,
    Map<String, dynamic>? actionButtons,
  }) async {
    if (chatId.isEmpty) return;
    
    try {
      final subcollectionName = _getModeSubcollection(mode);
      final messageRef = firestore
          .collection('chats')
          .doc(chatId)
          .collection(subcollectionName)
          .doc();
      
      final timestamp = FieldValue.serverTimestamp();
      
      final messageData = {
        'messageContent': content,
        'senderId': senderId,
        'timestamp': timestamp,
        'imageUrls': imageUrls ?? [],
      };
      
      if (actionButtons != null) {
        // Ensure actionButtons only contains Firestore-serializable types
        messageData['actionButtons'] = _sanitizeForFirestore(actionButtons);
      }
      
      await firestore.runTransaction((transaction) async {
        transaction.set(messageRef, messageData);
        
        // Update chat summary with mode information
        transaction.update(
          firestore.collection('chats').doc(chatId),
          {
            'lastMessage': content,
            'lastMessageTime': timestamp,
            'lastMessageSender': senderId,
            'lastMessageMode': mode,
            'currentMode': mode,
          },
        );
      });
    } catch (e, stackTrace) {
      debugPrint("Error saving message to mode: $e");
      debugPrint("Stack trace: $stackTrace");
      debugPrint("Message content: $content");
      debugPrint("Action buttons: $actionButtons");
      // Re-throw to let caller handle it
      rethrow;
    }
  }

  void listenToMessages() {
    // Use mode-based listening
    listenToModeMessages(currentMode.value);
  }

  // Sanitize data for Firestore - ensure all values are serializable
  Map<String, dynamic> _sanitizeForFirestore(Map<String, dynamic> data) {
    final sanitized = <String, dynamic>{};
    for (final entry in data.entries) {
      final value = entry.value;
      if (value == null) {
        sanitized[entry.key] = null;
      } else if (value is String || value is int || value is double || value is bool) {
        sanitized[entry.key] = value;
      } else if (value is List) {
        sanitized[entry.key] = value.map((item) {
          if (item is String || item is int || item is double || item is bool) {
            return item;
          } else if (item is Map) {
            return _sanitizeForFirestore(item as Map<String, dynamic>);
          }
          return item.toString();
        }).toList();
      } else if (value is Map) {
        sanitized[entry.key] = _sanitizeForFirestore(value as Map<String, dynamic>);
      } else {
        // Convert any other type to string
        sanitized[entry.key] = value.toString();
      }
    }
    return sanitized;
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

  // Planning mode methods
  void enterPlanningMode() {
    isPlanningMode.value = true;
    planningConversation.clear();
    isReadyToGenerate.value = false;
  }

  void exitPlanningMode() {
    isPlanningMode.value = false;
    isReadyToGenerate.value = false;
    planningFormData.value = null;
    isFormSubmitted.value = false;
    showForm.value = false;
    planningConversation.clear();
  }

  void setPlanningFormData(Map<String, dynamic> data) {
    planningFormData.value = data;
    isFormSubmitted.value = true;
  }

  void addPlanningMessage(ChatScreenData message) {
    if (isPlanningMode.value) {
      planningConversation.add(message);
      // Check if ready to generate (simple heuristic: at least 4 exchanges)
      if (planningConversation.length >= 8) {
        // Check if AI has asked key questions
        final hasGoals = planningConversation.any((msg) =>
            msg.messageContent.toLowerCase().contains('goal') &&
            msg.senderId == 'buddy');
        final hasDuration = planningConversation.any((msg) =>
            msg.messageContent.toLowerCase().contains('duration') &&
            msg.senderId == 'buddy');
        if (hasGoals && hasDuration) {
          isReadyToGenerate.value = true;
        }
      }
    }
  }

  void checkReadyToGenerate() {
    // More sophisticated check: look for AI suggesting to generate
    final lastMessage = planningConversation.isNotEmpty
        ? planningConversation.last
        : null;
    if (lastMessage != null &&
        lastMessage.senderId == 'buddy' &&
        (lastMessage.messageContent.toLowerCase().contains('ready to generate') ||
            lastMessage.messageContent.toLowerCase().contains('create your plan') ||
            lastMessage.messageContent.toLowerCase().contains('generate the plan'))) {
      isReadyToGenerate.value = true;
    }
  }

  @override
  void onClose() {
    _messagesSubscription?.cancel();
    _messagesSubscription = null;
    _modeMessagesSubscription?.cancel();
    _modeMessagesSubscription = null;
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
  final Map<String, dynamic>? actionButtons;
  final String messageId;

  ChatScreenData({
    required this.messageContent,
    required this.imageUrls,
    required this.senderId,
    required this.timestamp,
    this.shareRequest,
    this.friendRequest,
    this.actionButtons,
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
      if (actionButtons != null) 'actionButtons': actionButtons,
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
      actionButtons: data['actionButtons'] as Map<String, dynamic>?,
      messageId: messageId ?? '',
    );
  }
}
