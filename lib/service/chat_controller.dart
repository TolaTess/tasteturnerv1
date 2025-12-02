import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';

import 'package:intl/intl.dart';
import 'package:tasteturner/service/program_service.dart';
import 'package:tasteturner/data_models/program_model.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';
import '../helper/utils.dart';
import '../helper/helper_functions.dart';

import '../service/meal_planning_service.dart';
import '../widgets/bottom_model.dart';

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
  final Rx<Map<String, dynamic>?> planningFormData =
      Rx<Map<String, dynamic>?>(null);
  final RxBool isFormSubmitted = false.obs;
  final RxBool showForm = false.obs;

  // Family Member Context (for Meal Plan mode)
  final RxnString familyMemberName = RxnString();
  final RxnString familyMemberKcal = RxnString();
  final RxnString familyMemberGoal = RxnString();
  final RxnString familyMemberType = RxnString();

  // Pantry Ingredients (for Meal Plan mode)
  final RxList<String> pantryIngredients = <String>[].obs;

  // Welcome Messages
  final List<String> tastyWelcomeMessages = [
    "Hey there! I'm Tasty, your personal food buddy. 🍎 What's on your mind?",
    "Hi! Ready to talk food? I can help with recipes, nutrition info, or just chatting about your favorite meals! 🥦",
    "Welcome back! Hungry for some knowledge? Ask me anything about food! 🍕",
    "Hello! I'm here to help you eat better and feel great. What are we discussing today? 🥗"
  ];

  final List<String> plannerWelcomeMessages = [
    "Let's plan your perfect meal program! 📅 Tell me about your goals.",
    "Ready to design a nutrition plan that fits your lifestyle? Let's get started! 📝",
    "I can help you create a personalized meal program. What are you aiming for? 🎯",
    "Planning mode activated! Let's structure your nutrition for success. 🚀"
  ];

  final List<String> mealPlanWelcomeMessages = [
    "Time to plan some delicious meals! 🍳 What kind of food are you in the mood for?",
    "Let's organize your weekly eats. Any specific cravings or dietary needs? 🥑",
    "Meal planning made easy! Tell me what you like, and I'll suggest some recipes. 🥘",
    "Ready to fill your calendar with tasty dishes? Let's get planning! 🗓️"
  ];

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
        debugPrint(
            'Migrated ${allOldMessages.docs.length} messages to tasty_messages');
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
              // Deduplicate based on messageId if available, otherwise fall back to timestamp/content check
              final isDuplicate = mergedMessages.any((m) =>
                  (msg.messageId.isNotEmpty && m.messageId == msg.messageId) ||
                  (msg.messageId.isEmpty &&
                      m.messageContent == msg.messageContent &&
                      m.senderId == msg.senderId &&
                      (m.timestamp
                              .toDate()
                              .difference(msg.timestamp.toDate())
                              .inSeconds
                              .abs() <
                          5)));

              if (!isDuplicate) {
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
    String? messageId,
  }) async {
    if (chatId.isEmpty) return;

    try {
      final subcollectionName = _getModeSubcollection(mode);
      final messageRef = firestore
          .collection('chats')
          .doc(chatId)
          .collection(subcollectionName)
          .doc(messageId);

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
      } else if (value is String ||
          value is int ||
          value is double ||
          value is bool) {
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
        sanitized[entry.key] =
            _sanitizeForFirestore(value as Map<String, dynamic>);
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

  /// Increment calendar share count for non-premium users
  Future<void> incrementCalendarShareCount() async {
    try {
      final currentUserId = userService.userId;
      if (currentUserId == null || currentUserId.isEmpty) {
        debugPrint("Cannot increment calendar share: userId is empty");
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
    final lastMessage =
        planningConversation.isNotEmpty ? planningConversation.last : null;
    if (lastMessage != null &&
        lastMessage.senderId == 'buddy' &&
        (lastMessage.messageContent
                .toLowerCase()
                .contains('ready to generate') ||
            lastMessage.messageContent
                .toLowerCase()
                .contains('create your plan') ||
            lastMessage.messageContent
                .toLowerCase()
                .contains('generate the plan'))) {
      isReadyToGenerate.value = true;
    }
  }

  // --- AI Chat Logic ---

  // Helper method to get user context
  Map<String, dynamic> getUserContext() {
    return {
      'displayName': userService.currentUser.value?.displayName ?? 'there',
      'fitnessGoal': userService.currentUser.value?.settings['fitnessGoal'] ??
          'Healthy Eating',
      'chatSummary': userService.currentUser.value?.bio ?? '',
      'currentWeight':
          userService.currentUser.value?.settings['currentWeight'] ?? 0.0,
      'goalWeight':
          userService.currentUser.value?.settings['goalWeight'] ?? 0.0,
      'startingWeight':
          userService.currentUser.value?.settings['startingWeight'] ?? 0.0,
      'foodGoal': userService.currentUser.value?.settings['foodGoal'] ?? 0.0,
      'dietPreference':
          userService.currentUser.value?.settings['dietPreference'] ??
              'Balanced',
    };
  }

  // Helper method to validate and handle food analysis data
  Map<String, dynamic> _validateFoodAnalysisData(
      Map<String, dynamic>? analysisData) {
    if (analysisData == null) {
      return {
        'foodItems': [
          {
            'name': 'Unknown Food',
            'estimatedWeight': '100g',
            'confidence': 'low',
            'nutritionalInfo': {
              'calories': 200,
              'protein': 10,
              'carbs': 20,
              'fat': 8,
              'fiber': 2,
              'sugar': 5,
              'sodium': 200
            }
          }
        ],
        'totalNutrition': {
          'calories': 200,
          'protein': 10,
          'carbs': 20,
          'fat': 8,
          'fiber': 2,
          'sugar': 5,
          'sodium': 200
        },
        'confidence': 'low',
        'notes': 'Analysis data was invalid or missing'
      };
    }

    // Ensure required fields exist
    if (!analysisData.containsKey('foodItems') ||
        !analysisData.containsKey('totalNutrition')) {
      return _validateFoodAnalysisData(null); // Return fallback
    }

    // Validate food items structure
    final foodItems = analysisData['foodItems'] as List?;
    if (foodItems == null || foodItems.isEmpty) {
      return _validateFoodAnalysisData(null); // Return fallback
    }

    // Validate each food item
    final validatedFoodItems = <Map<String, dynamic>>[];
    for (final item in foodItems) {
      if (item is Map<String, dynamic>) {
        final validatedItem = {
          'name': item['name'] ?? 'Unknown Food',
          'estimatedWeight': item['estimatedWeight'] ?? '100g',
          'confidence': item['confidence'] ?? 'low',
          'nutritionalInfo': {
            'calories': item['nutritionalInfo']?['calories'] ?? 200,
            'protein': item['nutritionalInfo']?['protein'] ?? 10,
            'carbs': item['nutritionalInfo']?['carbs'] ?? 20,
            'fat': item['nutritionalInfo']?['fat'] ?? 8,
            'fiber': item['nutritionalInfo']?['fiber'] ?? 2,
            'sugar': item['nutritionalInfo']?['sugar'] ?? 5,
            'sodium': item['nutritionalInfo']?['sodium'] ?? 200,
          }
        };
        validatedFoodItems.add(validatedItem);
      }
    }

    // Validate total nutrition
    final totalNutrition =
        analysisData['totalNutrition'] as Map<String, dynamic>? ?? {};
    final validatedTotalNutrition = {
      'calories': totalNutrition['calories'] ?? 200,
      'protein': totalNutrition['protein'] ?? 10,
      'carbs': totalNutrition['carbs'] ?? 20,
      'fat': totalNutrition['fat'] ?? 8,
      'fiber': totalNutrition['fiber'] ?? 2,
      'sugar': totalNutrition['sugar'] ?? 5,
      'sodium': totalNutrition['sodium'] ?? 200,
    };

    return {
      'foodItems': validatedFoodItems,
      'totalNutrition': validatedTotalNutrition,
      'mealType': analysisData['mealType'] ?? 'unknown',
      'estimatedPortionSize': analysisData['estimatedPortionSize'] ?? 'medium',
      'ingredients':
          analysisData['ingredients'] ?? {'unknown ingredient': '1 portion'},
      'cookingMethod': analysisData['cookingMethod'] ?? 'unknown',
      'confidence': analysisData['confidence'] ?? 'low',
      'healthScore': analysisData['healthScore'] ?? 5,
      'notes': analysisData['notes'] ?? 'Analysis completed successfully'
    };
  }

  // Helper method to extract ingredients from analysis data
  String _extractIngredientsFromAnalysis(Map<String, dynamic> analysisData) {
    if (analysisData.containsKey('foodItems') &&
        analysisData['foodItems'] is List) {
      final foods = analysisData['foodItems'] as List;
      return foods
          .take(5)
          .map((food) => food['name'] ?? food.toString())
          .join(', ');
    }
    return 'the meal items';
  }

  // Helper method to send remix response
  Future<void> _sendRemixResponse(
      String prompt,
      Map<String, dynamic> userContext,
      String currentUserId,
      String chatId) async {
    try {
      final response = await geminiService.getResponse(
        prompt,
        maxTokens: 512,
        role: buddyAiRole,
      );

      final message = ChatScreenData(
        messageContent: response,
        senderId: 'buddy',
        timestamp: Timestamp.now(),
        imageUrls: [],
        messageId: '',
      );
      messages.add(message);

      await saveMessageToMode(
        mode: currentMode.value,
        content: response,
        senderId: 'buddy',
      );
    } catch (e) {
      debugPrint("Error getting remix suggestions: $e");
      final fallbackContent =
          "I'd love to help you remix those ingredients! Here are some ideas based on your ${userContext['dietPreference']} goals: try adding more protein with some lean meat or legumes, swap refined grains for whole grains, and add colorful vegetables for extra nutrients. What specific ingredient would you like to focus on? 😊";

      final message = ChatScreenData(
        messageContent: fallbackContent,
        senderId: 'buddy',
        timestamp: Timestamp.now(),
        imageUrls: [],
        messageId: '',
      );
      messages.add(message);

      await saveMessageToMode(
        mode: currentMode.value,
        content: fallbackContent,
        senderId: 'buddy',
      );
    }
  }

  // Main method to send message to AI
  Future<void> sendMessageToAI(String userInput, BuildContext context,
      {bool isSystemMessage = false, bool isHealthJourneyMode = false}) async {
    if (chatId.isEmpty || !canUseAI()) return;

    final currentUserId = userService.userId!;

    // Handle mode-specific message routing
    if (currentMode.value == 'planner') {
      await _handlePlannerModeMessage(userInput);
      return;
    } else if (currentMode.value == 'meal') {
      await handleMealPlanModeMessage(userInput);
      return;
    }

    // Check for various commands
    final userInputLower = userInput.toLowerCase();

    // Check for food analysis options
    if (userInputLower.contains('option 3') ||
        userInputLower.contains('3') ||
        userInputLower.contains('analyze') ||
        userInputLower.contains('analyse') ||
        userInputLower.contains('detailed food analysis') ||
        userInputLower.contains('food analysis')) {
      FirebaseAnalytics.instance.logEvent(name: 'buddy_food_analysis');

      final messageId = const Uuid().v4();
      final userMessage = ChatScreenData(
        messageContent: userInput,
        senderId: currentUserId,
        timestamp: Timestamp.now(),
        imageUrls: [],
        messageId: messageId,
      );
      messages.add(userMessage);

      await saveMessageToMode(
        mode: currentMode.value,
        content: userInput,
        senderId: currentUserId,
        messageId: messageId,
      );

      // Trigger detailed food analysis
      await handleDetailedFoodAnalysis(context, chatId);
      return;
    }

    // Check for Option 1 - Remix ingredients
    if (userInputLower.contains('option 1') ||
        userInputLower.contains('1') ||
        userInputLower.contains('remix')) {
      FirebaseAnalytics.instance.logEvent(name: 'buddy_remix_ingredients');

      final messageId = const Uuid().v4();
      final userMessage = ChatScreenData(
        messageContent: userInput,
        senderId: currentUserId,
        timestamp: Timestamp.now(),
        imageUrls: [],
        messageId: messageId,
      );
      messages.add(userMessage);

      await saveMessageToMode(
        mode: currentMode.value,
        content: userInput,
        senderId: currentUserId,
        messageId: messageId,
      );

      // Get user context and food analysis data
      final userContext = getUserContext();
      final analysisId = getLastFoodAnalysisId();

      if (analysisId != null) {
        final analysisData = await getFoodAnalysisData(analysisId);
        final validatedData = _validateFoodAnalysisData(analysisData);
        // Create remix suggestions based on actual analyzed ingredients
        final ingredients = _extractIngredientsFromAnalysis(validatedData);
        final remixPrompt = """
User wants to remix their meal containing: $ingredients

For their ${userContext['dietPreference']} diet and ${userContext['fitnessGoal']} goals.

Give 3-4 specific ingredient substitutions or cooking method improvements. Be encouraging and practical!
""";
        await _sendRemixResponse(
            remixPrompt, userContext, currentUserId, chatId);
        return;
      }

      // Fallback if no analysis data
      final remixPrompt = """
User wants to remix their meal for ${userContext['dietPreference']} diet and ${userContext['fitnessGoal']} goals.

Give 3-4 specific ingredient or cooking suggestions. Be encouraging and practical!
""";

      await _sendRemixResponse(remixPrompt, userContext, currentUserId, chatId);
      return;
    }

    // Check for Option 2 - Optimize nutrition
    if (userInputLower.contains('option 2') ||
        userInputLower.contains('2') ||
        userInputLower.contains('protein') ||
        userInputLower.contains('optimize')) {
      FirebaseAnalytics.instance.logEvent(name: 'buddy_optimize_nutrition');

      final messageId = const Uuid().v4();
      final userMessage = ChatScreenData(
        messageContent: userInput,
        senderId: currentUserId,
        timestamp: Timestamp.now(),
        imageUrls: [],
        messageId: messageId,
      );
      messages.add(userMessage);

      await saveMessageToMode(
        mode: currentMode.value,
        content: userInput,
        senderId: currentUserId,
        messageId: messageId,
      );

      // Get user context and food analysis data
      final userContext = getUserContext();
      final goal = userContext['fitnessGoal'] as String;
      final isWeightLoss = goal.toLowerCase().contains('weight loss') ||
          goal.toLowerCase().contains('lose');
      final isMuscleBuild = goal.toLowerCase().contains('muscle') ||
          goal.toLowerCase().contains('gain');

      final analysisId = getLastFoodAnalysisId();

      String optimizePrompt;
      if (analysisId != null) {
        final analysisData = await getFoodAnalysisData(analysisId);
        final validatedData = _validateFoodAnalysisData(analysisData);
        final totalNutrition =
            validatedData['totalNutrition'] as Map<String, dynamic>? ?? {};
        final calories = totalNutrition['calories'] ?? 'unknown';
        final protein = totalNutrition['protein'] ?? 'unknown';
        final carbs = totalNutrition['carbs'] ?? 'unknown';
        final fat = totalNutrition['fat'] ?? 'unknown';
        final ingredients = _extractIngredientsFromAnalysis(validatedData);

        optimizePrompt = """
User wants to optimize their meal containing: $ingredients
Current nutrition: ${calories}cal, ${protein}g protein, ${carbs}g carbs, ${fat}g fat

For their ${userContext['fitnessGoal']} goals.

Focus on ${isWeightLoss ? 'reducing calories while keeping protein high' : isMuscleBuild ? 'adding more protein for muscle building' : 'optimizing nutritional balance'}.

Give 3-4 specific improvements based on the actual nutrition data. Be encouraging!
""";
      } else {
        optimizePrompt = """
User wants to optimize their meal for ${userContext['fitnessGoal']} goals.

Focus on ${isWeightLoss ? 'reducing calories while keeping protein high' : isMuscleBuild ? 'adding more protein for muscle building' : 'optimizing nutritional balance'}.

Give 3-4 practical tips. Be encouraging!
""";
      }

      try {
        final response = await geminiService.getResponse(
          optimizePrompt,
          maxTokens: 512,
          role: buddyAiRole,
        );

        final message = ChatScreenData(
          messageContent: response,
          senderId: 'buddy',
          timestamp: Timestamp.now(),
          imageUrls: [],
          messageId: '',
        );
        messages.add(message);

        await saveMessageToMode(
          mode: currentMode.value,
          content: response,
          senderId: 'buddy',
        );
      } catch (e) {
        final fallbackMessage = isWeightLoss
            ? "Great choice! To reduce calories while keeping protein high, try: using lean proteins like chicken breast or fish, adding more vegetables to increase volume, using cooking sprays instead of oils, and choosing Greek yogurt over regular yogurt. These swaps will help you feel full while staying on track! 💪"
            : isMuscleBuild
                ? "Perfect for muscle building! Try adding: a protein-rich side like cottage cheese or Greek yogurt, some nuts or seeds for healthy fats and extra protein, quinoa instead of rice for complete protein, or a protein smoothie as a post-meal boost. Your muscles will thank you! 🏋️‍♂️"
                : "For optimal nutrition balance, consider: adding colorful vegetables for vitamins and minerals, including healthy fats like avocado or nuts, ensuring you have a good protein source, and staying hydrated. Balance is key to feeling your best! 🌟";

        final message = ChatScreenData(
          messageContent: fallbackMessage,
          senderId: 'buddy',
          timestamp: Timestamp.now(),
          imageUrls: [],
          messageId: '',
        );
        messages.add(message);

        await saveMessageToMode(
          mode: currentMode.value,
          content: fallbackMessage,
          senderId: 'buddy',
        );
      }
      return;
    }

    // Check for spin wheel command
    if (userInputLower.contains('spin') || userInputLower.contains('wheel')) {
      FirebaseAnalytics.instance.logEvent(name: 'buddy_spin_wheel');
      try {
        // Get ingredients from Firestore first
        final ingredients = await macroManager.getIngredientsByCategory('all');
        final mealList = await mealManager.fetchMealsByCategory('all');

        final messageId = const Uuid().v4();
        final userMessage = ChatScreenData(
          messageContent: userInput,
          senderId: currentUserId,
          timestamp: Timestamp.now(),
          imageUrls: [],
          messageId: messageId,
        );
        messages.add(userMessage);

        await saveMessageToMode(
          mode: currentMode.value,
          content: userInput,
          senderId: currentUserId,
          messageId: messageId,
        );

        // Add AI response with countdown
        const aiResponse =
            "🎡 Preparing your Spin Wheel!\n\nIn just 5 seconds, you'll be able to:\n"
            "• Select from different macro categories\n"
            "• Add your own custom ingredients\n"
            "• Spin for random meal suggestions\n\n"
            "Loading the wheel... ⏳";

        final aiMessage = ChatScreenData(
          messageContent: aiResponse,
          senderId: 'buddy',
          timestamp: Timestamp.now(),
          imageUrls: [],
          messageId: '',
        );
        messages.add(aiMessage);

        await saveMessageToMode(
          mode: currentMode.value,
          content: aiResponse,
          senderId: 'buddy',
        );

        // Wait before showing the spin wheel
        await Future.delayed(const Duration(seconds: 5));
        // Note: context is required here
        showSpinWheel(
          context,
          'Carbs',
          ingredients,
          mealList,
          'All',
          true,
        );
      } catch (e) {
        showTastySnackbar(
          'Please try again.',
          'Failed to load ingredients. Please try again.',
          context,
        );
      }
      return;
    }

    // Add user messages to UI and Firestore first
    if (!isSystemMessage) {
      // Remove any system messages when user starts interacting
      // _removeSystemMessages(); // TODO: Implement if needed

      // Add message to UI
      final messageId = const Uuid().v4();
      final userMessage = ChatScreenData(
        messageContent: userInput,
        senderId: currentUserId,
        timestamp: Timestamp.now(),
        imageUrls: [],
        messageId: messageId,
      );

      messages.add(userMessage);

      // Track planning conversation
      if (isPlanningMode.value) {
        addPlanningMessage(userMessage);
      }

      // Save to Firestore
      await saveMessageToMode(
        mode: currentMode.value,
        content: userInput,
        senderId: currentUserId,
        messageId: messageId,
      );

      // Only trigger Gemini if the last message is from the user
      if (messages.isNotEmpty && messages.last.senderId != currentUserId) {
        return;
      }
    }

    // Only trigger Gemini if the last message is from the user OR if it's a system message
    if (isSystemMessage ||
        (messages.isNotEmpty && messages.last.senderId == currentUserId)) {
      try {
        String response;
        if (!isSystemMessage &&
            messages.isNotEmpty &&
            messages.last.senderId == 'systemMessage') {
          // If this is a follow-up question from the user
          response =
              "Is there anything else you'd like to know about what we just discussed? I'm here to help!";
        } else {
          final username = userService.currentUser.value?.displayName;
          String prompt = "${userInput}, user name is ${username ?? ''}".trim();

          // Add Food Health Journey context if mode is active
          if (isHealthJourneyMode) {
            prompt =
                """[Food Health Journey Mode - Track and guide the user's nutrition journey]

$prompt

IMPORTANT: You are now in Food Health Journey mode. Provide personalized nutrition guidance, track progress, offer encouragement, and help the user achieve their health goals. Be supportive and focus on long-term wellness.""";
          }

          // Note: Planning mode is handled in _handlePlannerModeMessage

          response = await geminiService.getResponse(
            prompt,
            maxTokens: 512,
            role: buddyAiRole,
          );

          if (response.contains("Error") || response.isEmpty) {
            throw Exception("Failed to generate response");
          }
        }

        final aiResponseMessage = ChatScreenData(
          messageContent: response,
          senderId: 'buddy',
          timestamp: Timestamp.now(),
          imageUrls: [],
          messageId: '',
        );

        messages.add(aiResponseMessage);

        await saveMessageToMode(
          mode: currentMode.value,
          content: response,
          senderId: 'buddy',
        );
      } catch (e) {
        debugPrint("Error getting AI response: $e");
        showTastySnackbar(
          'Please try again.',
          'Failed to get AI response. Please try again.',
          context,
        );
        // Add a fallback AI message so the user can type again
        final fallbackContent =
            "Sorry, I snoozed for a moment. Please try sending your message again.";

        final message = ChatScreenData(
          messageContent: fallbackContent,
          senderId: 'buddy',
          timestamp: Timestamp.now(),
          imageUrls: [],
          messageId: '',
        );
        messages.add(message);

        await saveMessageToMode(
          mode: currentMode.value,
          content: fallbackContent,
          senderId: 'buddy',
        );
      }
    }
  }

  // Handle planner mode messages
  Future<void> _handlePlannerModeMessage(String userInput) async {
    if (chatId.isEmpty || !canUseAI()) return;

    final currentUserId = userService.userId!;

    // Add user message to UI
    final userMessage = ChatScreenData(
      messageContent: userInput,
      senderId: currentUserId,
      timestamp: Timestamp.now(),
      imageUrls: [],
      messageId: '',
    );

    messages.add(userMessage);

    await saveMessageToMode(
      mode: currentMode.value,
      content: userInput,
      senderId: currentUserId,
    );

    // Check if form is submitted and user is confirming
    final formData = planningFormData.value;
    final isSubmitted = isFormSubmitted.value;

    if (isSubmitted && formData != null) {
      // Check if user is confirming or wants to amend
      final userInputLower = userInput.toLowerCase();
      if (userInputLower.contains('yes') ||
          userInputLower.contains('confirm') ||
          userInputLower.contains('proceed') ||
          userInputLower.contains('create') ||
          userInputLower.contains('generate')) {
        // User confirmed - generate plan
        isReadyToGenerate.value = true; // Trigger UI to show generate button

        final responseMessage = ChatScreenData(
          messageContent:
              "Great! I'm ready to generate your plan. Click the 'Generate Plan' button above to proceed!",
          senderId: 'buddy',
          timestamp: Timestamp.now(),
          imageUrls: [],
          messageId: '',
        );
        messages.add(responseMessage);
        await saveMessageToMode(
          mode: currentMode.value,
          content: responseMessage.messageContent,
          senderId: 'buddy',
        );
        return;
      } else if (userInputLower.contains('amend') ||
          userInputLower.contains('change') ||
          userInputLower.contains('edit')) {
        // User wants to amend - show form again
        isFormSubmitted.value = false;
        planningFormData.value = null;
        showForm.value = true;

        final responseMessage = ChatScreenData(
          messageContent:
              "No problem! Let's update your preferences. Please fill out the form again.",
          senderId: 'buddy',
          timestamp: Timestamp.now(),
          imageUrls: [],
          messageId: '',
        );
        messages.add(responseMessage);

        await saveMessageToMode(
          mode: currentMode.value,
          content: responseMessage.messageContent,
          senderId: 'buddy',
        );
        return;
      }
    }

    // If form not submitted yet, just acknowledge
    if (!isSubmitted) {
      final responseMessage = ChatScreenData(
        messageContent:
            "Please fill out the form above to get started with creating your nutrition program.",
        senderId: 'buddy',
        timestamp: Timestamp.now(),
        imageUrls: [],
        messageId: '',
        actionButtons: {
          'openForm': 'Fill Program Details Form',
        },
      );
      messages.add(responseMessage);

      await saveMessageToMode(
        mode: currentMode.value,
        content: responseMessage.messageContent,
        senderId: 'buddy',
        actionButtons: responseMessage.actionButtons,
      );
    }
  }

  // Handle meal plan quick action selection
  void handleMealPlanQuickAction(String action) {
    String prompt;
    int? mealCount;
    switch (action) {
      case '7days':
        prompt = familyMemberName.value != null
            ? 'Create a 7-day meal plan for ${familyMemberName.value} with breakfast, lunch, and dinner'
            : 'Create a 7-day meal plan with breakfast, lunch, and dinner';
        mealCount = 21; // 7 days × 3 meals
        break;
      case 'single':
        prompt = familyMemberName.value != null
            ? 'Suggest a single healthy meal for ${familyMemberName.value}'
            : 'Suggest a single healthy meal';
        mealCount = 1;
        break;
      case 'recipe':
        prompt =
            'Give me a detailed recipe with ingredients and step-by-step instructions';
        mealCount = 1;
        break;
      case 'quick':
        prompt =
            'Suggest 3 quick and easy meal ideas I can make in under 30 minutes';
        mealCount = 3;
        break;
      case 'custom':
        // Just hide buttons and let user type their own request
        return;
      default:
        return;
    }

    // Send the prompt through the chat with mealCount
    handleMealPlanModeMessage(prompt, mealCount: mealCount);
  }

  // Handle meal plan mode messages
  Future<void> handleMealPlanModeMessage(String userInput,
      {int? mealCount,
      String? familyMemberName,
      String? familyMemberKcal,
      String? familyMemberGoal,
      String? familyMemberType}) async {
    if (chatId.isEmpty || !canUseAI()) return;

    final currentUserId = userService.userId!;

    // Detect meal count from prompt if not provided
    int? detectedMealCount = mealCount;
    if (detectedMealCount == null) {
      final userInputLower = userInput.toLowerCase();
      // Check for single meal patterns (more comprehensive)
      if (userInputLower.contains('single meal') ||
          userInputLower.contains('one meal') ||
          userInputLower.contains('a single') ||
          userInputLower.contains('just one') ||
          userInputLower.contains('only one') ||
          (userInputLower.contains('a meal') &&
              (userInputLower.contains('suggest') ||
                  userInputLower.contains('give') ||
                  userInputLower.contains('show') ||
                  userInputLower.contains('recommend')))) {
        detectedMealCount = 1;
      } else if (userInputLower.contains('7 day') ||
          userInputLower.contains('7-day') ||
          userInputLower.contains('seven day')) {
        detectedMealCount = 21; // 7 days × 3 meals
      } else if (userInputLower.contains('3 meal') ||
          userInputLower.contains('three meal')) {
        detectedMealCount = 3;
      }
      // Default to 10 if not specified
    }

    // Add user message to UI
    final userMessage = ChatScreenData(
      messageContent: userInput,
      senderId: currentUserId,
      timestamp: Timestamp.now(),
      imageUrls: [],
      messageId: '',
    );

    messages.add(userMessage);

    await saveMessageToMode(
      mode: currentMode.value,
      content: userInput,
      senderId: currentUserId,
    );

    try {
      // Use meal planning service to generate meal plan with family member context
      final mealPlanningService = MealPlanningService.instance;
      final result = await mealPlanningService.generateMealPlanFromPrompt(
        userInput,
        mealCount: detectedMealCount,
        familyMemberName: familyMemberName,
        familyMemberKcal: familyMemberKcal,
        familyMemberGoal: familyMemberGoal,
        familyMemberType: familyMemberType,
        pantryIngredients:
            pantryIngredients.isNotEmpty ? pantryIngredients.toList() : null,
      );

      if (result['success'] == true) {
        final meals = result['meals'] as List<dynamic>? ?? [];
        final mealIds = result['mealIds'] as List<dynamic>? ?? [];
        final resultFamilyMemberName = result['familyMemberName'] as String?;

        if (meals.isNotEmpty) {
          // Format meal list for display
          final mealList = meals.take(10).map((meal) {
            final title = meal['title'] ?? 'Untitled Meal';
            final mealType = meal['mealType'] ?? 'meal';
            return "• $title ($mealType)";
          }).join('\n');

          // Customize response message based on family member
          final responseContent = resultFamilyMemberName != null
              ? """Here are some meal suggestions for $resultFamilyMemberName:

$mealList

Click "View Meals" to browse and add them to your calendar!"""
              : """Here are some meal suggestions for you:

$mealList

Click "View Meals" to browse and add them to your calendar!""";

          final actionButtonsMap = <String, dynamic>{
            'viewMeals': true,
            if (mealIds.isNotEmpty) 'mealIds': mealIds,
            if (resultFamilyMemberName != null)
              'familyMemberName': resultFamilyMemberName,
          };

          final responseMessage = ChatScreenData(
            messageContent: responseContent,
            senderId: 'buddy',
            timestamp: Timestamp.now(),
            imageUrls: [],
            messageId: '',
            actionButtons: actionButtonsMap,
          );

          messages.add(responseMessage);

          await saveMessageToMode(
            mode: currentMode.value,
            content: responseContent,
            senderId: 'buddy',
            actionButtons: actionButtonsMap,
          );

          // Save meals to buddy collection for display in buddy tab
          try {
            await _saveMealsToBuddyCollection(
              mealIds.map((id) => id.toString()).toList(),
              familyMemberName: resultFamilyMemberName,
            );
          } catch (buddyError) {
            debugPrint('Error saving to buddy collection: $buddyError');
          }
        } else {
          throw Exception("No meals generated");
        }
      } else {
        throw Exception(result['error'] ?? "Unknown error");
      }
    } catch (e) {
      debugPrint("Error generating meal plan: $e");
      final errorMessage =
          "I couldn't generate a meal plan at the moment. Please try again later.";

      final message = ChatScreenData(
        messageContent: errorMessage,
        senderId: 'buddy',
        timestamp: Timestamp.now(),
        imageUrls: [],
        messageId: '',
      );
      messages.add(message);

      await saveMessageToMode(
        mode: currentMode.value,
        content: errorMessage,
        senderId: 'buddy',
      );
    }
  }

  // Initialize Tasty Mode
  Future<void> initializeTastyMode(BuildContext context) async {
    // Wait for mode to stabilize
    await Future.delayed(const Duration(milliseconds: 300));

    // Verify we're still in tasty mode before proceeding
    if (currentMode.value != 'tasty') {
      debugPrint(
          'Mode changed from tasty to ${currentMode.value}, skipping welcome message');
      return;
    }

    if (messages.isEmpty) {
      final now = DateTime.now();
      final lastWelcome = await _getLastGeminiWelcomeDate();
      final isToday = lastWelcome != null &&
          lastWelcome.year == now.year &&
          lastWelcome.month == now.month &&
          lastWelcome.day == now.day;

      if (!isToday) {
        final userContext = getUserContext();
        final initialPrompt = _createInitialPrompt(userContext);
        await sendMessageToAI(initialPrompt, context, isSystemMessage: true);
        await _setLastGeminiWelcomeDate(now);
      } else {
        // Show system message if it's today but no messages in current session
        _showSystemMessage();
      }
    }
  }

  // Initialize Planner Mode
  Future<void> initializePlannerMode(bool fromProgramScreen) async {
    // Wait for mode to stabilize and messages to load from Firestore
    await Future.delayed(const Duration(milliseconds: 500));

    // Verify we're still in planner mode before proceeding
    if (currentMode.value != 'planner') {
      debugPrint(
          'Mode changed from planner to ${currentMode.value}, skipping welcome message');
      return;
    }

    // Check if planner mode has no messages (first time entering)
    final plannerMessages = getModeMessages('planner');
    final currentMessages = messages;

    // Check if there's already a welcome message from buddy
    final hasWelcomeMessage = plannerMessages.any((msg) =>
            msg.senderId == 'buddy' &&
            (msg.messageContent.contains('Ready to create') ||
                msg.messageContent.contains('design a custom') ||
                msg.messageContent.contains('help you build'))) ||
        currentMessages.any((msg) =>
            msg.senderId == 'buddy' &&
            (msg.messageContent.contains('Ready to create') ||
                msg.messageContent.contains('design a custom') ||
                msg.messageContent.contains('help you build')));

    // If no planner messages exist and no welcome message, show welcome message
    if (plannerMessages.isEmpty &&
        currentMessages.isEmpty &&
        !hasWelcomeMessage) {
      final welcomeMessage = _getWelcomeMessageForPlanner();
      final message = ChatScreenData(
        messageContent: welcomeMessage,
        senderId: 'buddy',
        timestamp: Timestamp.now(),
        imageUrls: [],
        messageId: '',
        actionButtons: {
          'openForm': 'Fill Program Details Form',
        },
      );

      messages.add(message);
      // Don't save static welcome messages to Firestore - they're UI-only
      debugPrint('Planner welcome message shown (not saved to Firestore)');
    }

    // Show form when entering planner mode
    if (fromProgramScreen) {
      // Coming from program screen - open form automatically immediately
      showForm.value = true;
      isFormSubmitted.value = false;
      planningFormData.value = null;
    }
  }

  // Initialize Meal Plan Mode
  Future<void> initializeMealPlanMode() async {
    // Wait for mode to stabilize and messages to load from Firestore
    await Future.delayed(const Duration(milliseconds: 500));

    // Verify we're still in meal plan mode before proceeding
    if (currentMode.value != 'meal') {
      debugPrint(
          'Mode changed from meal to ${currentMode.value}, skipping welcome message');
      return;
    }

    // Check if meal plan mode has no messages (first time entering)
    final mealPlanMessages = getModeMessages('meal');
    final currentMessages = messages;

    // Check if there's already a welcome message
    final hasWelcomeMessage = mealPlanMessages.any((msg) =>
            msg.senderId == 'buddy' &&
            (msg.messageContent.contains('plan meals') ||
                msg.messageContent.contains('get cooking') ||
                msg.messageContent.contains('delicious meals'))) ||
        currentMessages.any((msg) =>
            msg.senderId == 'buddy' &&
            (msg.messageContent.contains('plan meals') ||
                msg.messageContent.contains('get cooking') ||
                msg.messageContent.contains('delicious meals')));

    // If no meal plan messages exist and no welcome message, show welcome message
    if (mealPlanMessages.isEmpty &&
        currentMessages.isEmpty &&
        !hasWelcomeMessage) {
      final welcomeMessage = _getWelcomeMessageForMealPlan();
      final message = ChatScreenData(
        messageContent: welcomeMessage,
        senderId: 'buddy',
        timestamp: Timestamp.now(),
        imageUrls: [],
        messageId: '',
      );

      messages.add(message);
      // Don't save static welcome messages to Firestore - they're UI-only
      debugPrint('Meal plan welcome message shown (not saved to Firestore)');
    }
  }

  String _getWelcomeMessageForMealPlan() {
    return mealPlanWelcomeMessages[
        DateTime.now().microsecond % mealPlanWelcomeMessages.length];
  }

  String _getWelcomeMessageForPlanner() {
    return plannerWelcomeMessages[
        DateTime.now().microsecond % plannerWelcomeMessages.length];
  }

  // Helper: Get last Gemini welcome date
  Future<DateTime?> _getLastGeminiWelcomeDate() async {
    final preference = await SharedPreferences.getInstance();
    final key = 'last_gemini_welcome_date_${userService.userId}';
    final dateString = preference.getString(key);
    if (dateString == null) return null;
    return DateTime.tryParse(dateString);
  }

  // Helper: Set last Gemini welcome date
  Future<void> _setLastGeminiWelcomeDate(DateTime date) async {
    final preference = await SharedPreferences.getInstance();
    final key = 'last_gemini_welcome_date_${userService.userId}';
    await preference.setString(key, date.toIso8601String());
  }

  String _createInitialPrompt(Map<String, dynamic> userContext) {
    return """
Greet the user warmly and offer guidance based on:
- Username: ${userContext['displayName']} to address the user
- Goal: ${userContext['fitnessGoal']}
- Summary of previous chat: ${userContext['chatSummary']}
- Current Weight: ${userContext['currentWeight']}
- Goal Weight: ${userContext['goalWeight']}
- Starting Weight: ${userContext['startingWeight']}
- Food Goal: ${userContext['foodGoal']}
- Diet Preference: ${userContext['dietPreference']}
""";
  }

  void _showSystemMessage() {
    // Get appropriate welcome message based on current mode
    String randomMessage;
    switch (currentMode.value) {
      case 'planner':
        randomMessage = plannerWelcomeMessages[
            DateTime.now().microsecond % plannerWelcomeMessages.length];
        break;
      case 'meal':
        randomMessage = mealPlanWelcomeMessages[
            DateTime.now().microsecond % mealPlanWelcomeMessages.length];
        break;
      default: // tasty
        randomMessage = tastyWelcomeMessages[
            DateTime.now().microsecond % tastyWelcomeMessages.length];
        break;
    }

    // Don't add system message if there's already one at the end
    if (messages.isNotEmpty && messages.last.senderId == 'systemMessage') {
      return;
    }

    messages.add(ChatScreenData(
      messageContent: randomMessage,
      senderId: 'systemMessage',
      timestamp: Timestamp.now(),
      imageUrls: [],
      messageId: '',
    ));
    // Note: System messages are NOT saved to Firestore - they're UI-only
  }

  Future<void> generatePlanFromConversation(BuildContext context) async {
    if (!canUseAI()) return;

    // Save the confirmation message to Firestore now that user has clicked Submit
    final confirmationMessage = messages.firstWhere(
      (msg) => msg.messageContent
          .contains('Perfect! I\'ve received your program details'),
      orElse: () => ChatScreenData(
        messageContent: '',
        senderId: '',
        timestamp: Timestamp.now(),
        imageUrls: [],
        messageId: '',
      ),
    );

    if (confirmationMessage.messageContent.isNotEmpty &&
        confirmationMessage.messageId.isEmpty) {
      // Only save if it hasn't been saved yet (messageId is empty)
      debugPrint(
          'Saving confirmation message to Firestore before generating plan');

      // Ensure actionButtons are properly formatted (only string values)
      Map<String, dynamic>? sanitizedActionButtons;
      if (confirmationMessage.actionButtons != null) {
        sanitizedActionButtons = {};
        confirmationMessage.actionButtons!.forEach((key, value) {
          // Only allow string values in actionButtons for Firestore
          if (value is String) {
            sanitizedActionButtons![key] = value;
          } else {
            sanitizedActionButtons![key] = value.toString();
          }
        });
      }

      try {
        await saveMessageToMode(
          mode: 'buddy', // Always save to buddy collection for confirmation
          content: confirmationMessage.messageContent,
          senderId: 'buddy',
          actionButtons: sanitizedActionButtons,
        );
      } catch (e, stackTrace) {
        debugPrint('Error saving confirmation message: $e');
        debugPrint('Stack trace: $stackTrace');
        // Continue with plan generation even if message save fails
      }
    }

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: kAccent),
      ),
    );

    try {
      // Get form data and conversation context
      final formData = planningFormData.value;
      final conversationText = planningConversation
          .map((msg) =>
              '${msg.senderId == userService.userId ? "User" : "AI"}: ${msg.messageContent}')
          .join('\n');

      // Build generation prompt with form data as primary source
      String formDataSection = '';
      final formDietType = formData?['dietType']?.toString() ?? 'general';
      if (formData != null) {
        formDataSection = """
Form Data:
- Duration: ${formData['duration']}
- Goal: ${formData['goal']}
- Diet Type: ${formData['dietType']}
- Activity Level: ${formData['activityLevel']}
${formData['additionalDetails']?.toString().isNotEmpty == true ? '- Additional Details: ${formData['additionalDetails']}' : ''}

""";
      }

      // Generate meals using meal mode method (10-15 meals)
      debugPrint(
          'Generating meals for custom program using meal mode method...');
      final mealPlanningService = MealPlanningService.instance;

      // Build prompt for meal generation
      final mealPrompt =
          """Create a meal plan based on the following requirements:
      
Diet Type: $formDietType
$formDataSection${conversationText.isNotEmpty ? 'Refinement Conversation:\n$conversationText\n' : ''}

Generate 10-15 diverse meals that align with these requirements.""";

      // Get user context
      final userContext = getUserContext();
      final contextInfo = """
Target: ${userContext['displayName']}
Fitness Goal: ${userContext['fitnessGoal']}
Diet Preference: $formDietType
Daily Calorie Target: ${userContext['foodGoal']} kcal
""";

      // Generate meals using meal mode method
      final mealResult = await mealPlanningService.generateMealPlan(
        mealPrompt,
        contextInfo,
        cuisine: formDietType.toLowerCase(),
        mealCount: 12, // Generate 12 meals (between 10-15)
      );

      if (!mealResult['success'] || (mealResult['meals'] as List).isEmpty) {
        throw Exception('Failed to generate meals for program');
      }

      final generatedMeals = mealResult['meals'] as List<dynamic>;
      final mealIds = mealResult['mealIds'] as List<String>? ?? [];
      debugPrint('Generated ${generatedMeals.length} meals for custom program');

      // Create empty meal plan structure - user will distribute meals themselves
      final daysOfWeek = [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday'
      ];
      final mealPlanMap = <String, List<String>>{};

      // Initialize all days with empty arrays - user will distribute meals themselves
      for (final day in daysOfWeek) {
        mealPlanMap[day] = [];
      }

      debugPrint(
          'Created ${mealIds.length} meals - user will distribute them across days');

      // Simplified prompt for basic program structure only
      // Server-side will enrich with routine, benefits, requirements, etc.
      final generationPrompt = """Diet Type: $formDietType

Based on the user's form responses and our conversation, create a basic nutrition program structure.

$formDataSection${conversationText.isNotEmpty ? 'Refinement Conversation:\n$conversationText\n' : ''}

Please create a JSON object with ONLY the following basic structure (server will add details later):
{
  "name": "Program name (be creative and personalized)",
  "description": "Detailed description of the program",
  "duration": "e.g., '7 days', '30 days', '90 days'",
  "type": "custom",
  "weeklyPlans": [
    {
      "week": 1,
      "goals": ["week goal"],
      "mealPlan": {
        "Monday": [],
        "Tuesday": [],
        "Wednesday": [],
        "Thursday": [],
        "Friday": [],
        "Saturday": [],
        "Sunday": []
      },
      "nutritionGuidelines": {
        "calories": "guideline",
        "protein": "guideline",
        "carbs": "guideline"
      },
      "tips": ["tip1", "tip2"]
    }
  ]
}

IMPORTANT: 
- Return ONLY the fields above (name, description, duration, type, weeklyPlans)
- Do NOT include: goals, requirements, benefits, recommendations, programDetails, notAllowed, routine, portionDetails
- These will be added by the server automatically
- weeklyPlans must have at least 1 week
- mealPlan will be populated with generated meal IDs - just return empty arrays
- Return ONLY valid JSON, no additional text.""";

      // Use form dietType instead of user settings dietPreference
      // Set includeDietContext and includeProgramContext to false to prevent using user settings/current program
      final response = await geminiService.getResponse(
        generationPrompt,
        maxTokens: 4096,
        role: buddyAiRole,
        includeDietContext: false, // Don't use user settings dietPreference
        includeProgramContext:
            false, // Don't include current program context when creating new program
      );

      if (!context.mounted) return;

      // Parse JSON response
      String jsonStr = response.trim();
      debugPrint('=== JSON Parsing: Starting ===');
      debugPrint('Raw response length: ${response.length}');
      debugPrint(
          'Raw response preview (first 500 chars): ${response.substring(0, response.length > 500 ? 500 : response.length)}');

      // Remove markdown code blocks if present
      if (jsonStr.startsWith('```json')) {
        jsonStr = jsonStr.substring(7);
      }
      if (jsonStr.startsWith('```')) {
        jsonStr = jsonStr.substring(3);
      }
      if (jsonStr.endsWith('```')) {
        jsonStr = jsonStr.substring(0, jsonStr.length - 3);
      }
      jsonStr = jsonStr.trim();

      debugPrint('Cleaned JSON string length: ${jsonStr.length}');

      final programData = json.decode(jsonStr) as Map<String, dynamic>;
      debugPrint('Parsed programData keys: ${programData.keys.toList()}');
      debugPrint('Program name: ${programData['name']}');

      final weeklyPlansRaw = programData['weeklyPlans'] as List<dynamic>? ?? [];
      debugPrint('Number of weekly plans in JSON: ${weeklyPlansRaw.length}');

      // Store generated meal IDs in program data for user to distribute later
      // Meals are already created via MealPlanningService, just need to store IDs
      if (weeklyPlansRaw.isNotEmpty) {
        final firstWeek = weeklyPlansRaw[0] as Map<String, dynamic>;
        // Set empty meal plan structure - user will distribute meals themselves
        firstWeek['mealPlan'] = mealPlanMap;
        // Store available meal IDs separately so user can assign them
        firstWeek['availableMealIds'] = mealIds;
        debugPrint(
            'Created ${mealIds.length} meals - user will distribute them across days');
      }

      // Meals are already created, just use the program data
      final updatedProgramData = programData;

      // Validate program data structure before creating program
      debugPrint('=== Validating program data before creation ===');
      debugPrint('Program data keys: ${updatedProgramData.keys.toList()}');
      final weeklyPlans =
          updatedProgramData['weeklyPlans'] as List<dynamic>? ?? [];
      debugPrint('Number of weekly plans: ${weeklyPlans.length}');

      for (int i = 0; i < weeklyPlans.length; i++) {
        final weekPlan = weeklyPlans[i];
        debugPrint('Week ${i + 1} type: ${weekPlan.runtimeType}');
        if (weekPlan is! Map) {
          debugPrint(
              'ERROR: Week ${i + 1} is not a Map, it is ${weekPlan.runtimeType}');
          throw Exception(
              'Invalid weekly plan structure: week ${i + 1} is not a Map');
        }
        final weekPlanMap = weekPlan as Map<String, dynamic>;
        debugPrint('Week ${i + 1} keys: ${weekPlanMap.keys.toList()}');

        final mealPlan = weekPlanMap['mealPlan'];
        debugPrint('Week ${i + 1} mealPlan type: ${mealPlan.runtimeType}');
        if (mealPlan is! Map) {
          debugPrint(
              'ERROR: Week ${i + 1} mealPlan is not a Map, it is ${mealPlan.runtimeType}');
          throw Exception(
              'Invalid meal plan structure: week ${i + 1} mealPlan is not a Map');
        }

        final mealPlanMap = mealPlan as Map<String, dynamic>;
        for (var entry in mealPlanMap.entries) {
          final dayName = entry.key;
          final meals = entry.value;
          debugPrint('  $dayName meals type: ${meals.runtimeType}');
          if (meals is! List) {
            debugPrint(
                'ERROR: $dayName meals is not a List, it is ${meals.runtimeType}');
            throw Exception(
                'Invalid meal structure: $dayName meals is not a List');
          }
          final mealsList = meals;
          debugPrint('  $dayName meals count: ${mealsList.length}');
          for (int j = 0; j < mealsList.length; j++) {
            final meal = mealsList[j];
            if (meal is! String) {
              debugPrint(
                  'ERROR: $dayName meal $j is not a String, it is ${meal.runtimeType}');
              throw Exception(
                  'Invalid meal ID: $dayName meal $j is not a String');
            }
          }
        }
      }
      debugPrint('=== Program data validation passed ===');

      // Create private program with basic structure
      final programService = Get.find<ProgramService>();
      Program program;
      try {
        program = await programService.createPrivateProgram(
          updatedProgramData,
          planningConversationId: chatId,
        );
        debugPrint('Basic program created successfully: ${program.programId}');
      } catch (e, stackTrace) {
        debugPrint('ERROR creating program: $e');
        debugPrint('Stack trace: $stackTrace');
        debugPrint('Program data that failed: $updatedProgramData');
        rethrow;
      }

      if (!context.mounted) return;

      // Enrich program with AI-generated details (routine, benefits, requirements, etc.)
      try {
        debugPrint('Starting program enrichment via cloud function...');
        await geminiService.enrichProgramWithAI(
          programId: program.programId,
          basicProgram: {
            'name': program.name,
            'description': program.description,
            'duration': program.duration,
            'type': program.type,
            'weeklyPlans': updatedProgramData['weeklyPlans'],
          },
          formData: formData,
          conversationContext:
              conversationText.isNotEmpty ? conversationText : null,
        );
        debugPrint('Program enriched successfully');
      } catch (e) {
        debugPrint('Error enriching program (non-critical): $e');
        // Continue even if enrichment fails - program is still usable
      }

      // Save meal plans to buddy collection
      try {
        await _saveProgramMealPlansToBuddy(program);
      } catch (e) {
        debugPrint('Error saving meal plans to buddy: $e');
        // Continue even if this fails
      }

      Navigator.pop(context); // Close loading dialog

      // Create success message with action buttons
      final successMessage = ChatScreenData(
        messageContent:
            'Your personalized program "${program.name}" has been created successfully! You can view it in your program progress or check out the meal plans in the buddy tab.',
        senderId: 'buddy',
        timestamp: Timestamp.now(),
        imageUrls: [],
        messageId: '',
        actionButtons: {
          'viewPlan': program.programId,
          'viewMealPlan': true,
        },
      );

      messages.add(successMessage);
      addPlanningMessage(successMessage);

      await saveMessageToMode(
        mode: 'buddy',
        content: successMessage.messageContent,
        senderId: 'buddy',
        actionButtons: successMessage.actionButtons,
      );

      // Show success snackbar
      Get.snackbar(
        'Success!',
        'Your custom program "${program.name}" has been created!',
        backgroundColor: kAccentLight,
        colorText: kWhite,
        duration: const Duration(seconds: 3),
      );

      // Exit planning mode
      exitPlanningMode();
    } catch (e) {
      debugPrint('Error generating plan: $e');
      if (!context.mounted) return;

      Navigator.pop(context); // Close loading dialog

      Get.snackbar(
        'Error',
        'Failed to generate program. Please try again.',
        backgroundColor: Colors.red,
        colorText: kWhite,
      );
    }
  }

  /// Create meals from meal plan with minimal data (title, calories) for cloud functions to process
  Future<Map<String, dynamic>> _createMealsFromPlan(
      Map<String, dynamic> programData, String programDescription) async {
    debugPrint('=== _createMealsFromPlan: Starting ===');
    final updatedData = Map<String, dynamic>.from(programData);
    final weeklyPlans = updatedData['weeklyPlans'] as List<dynamic>? ?? [];
    debugPrint('Number of weekly plans: ${weeklyPlans.length}');

    if (weeklyPlans.isEmpty) {
      debugPrint('WARNING: No weekly plans found in program data!');
      return updatedData;
    }

    final mealNameToId = <String, String>{};
    final batch = FirebaseFirestore.instance.batch();
    int totalMealsFound = 0;

    // Collect all unique meal names from all weekly plans
    for (int weekIndex = 0; weekIndex < weeklyPlans.length; weekIndex++) {
      final weekPlan = weeklyPlans[weekIndex];
      debugPrint('Processing week ${weekIndex + 1}');
      if (weekPlan is Map<String, dynamic>) {
        debugPrint('Week plan keys: ${weekPlan.keys.toList()}');
      } else {
        debugPrint('Week plan is not a map, type: ${weekPlan.runtimeType}');
      }

      final mealPlan = weekPlan['mealPlan'] as Map<String, dynamic>? ?? {};
      debugPrint('Meal plan keys: ${mealPlan.keys.toList()}');
      debugPrint('Meal plan entries: ${mealPlan.length}');

      if (mealPlan.isEmpty) {
        debugPrint('WARNING: Empty meal plan for week ${weekIndex + 1}');
        continue;
      }

      for (var entry in mealPlan.entries) {
        final dayName = entry.key;
        final dayMeals = entry.value;
        debugPrint('Day: $dayName');
        debugPrint('Day meals type: ${dayMeals.runtimeType}');
        debugPrint('Day meals value: $dayMeals');

        if (dayMeals is! List) {
          debugPrint(
              'WARNING: Day meals for $dayName is not a List, it is ${dayMeals.runtimeType}');
          continue;
        }

        final meals = dayMeals as List<dynamic>? ?? [];
        debugPrint('Number of meals for $dayName: ${meals.length}');
        totalMealsFound += meals.length;

        for (int mealIndex = 0; mealIndex < meals.length; mealIndex++) {
          final mealName = meals[mealIndex];
          final mealNameStr = mealName.toString().trim();
          debugPrint('  Meal $mealIndex: "$mealNameStr"');

          if (mealNameStr.isEmpty) {
            debugPrint(
                '  WARNING: Empty meal name at index $mealIndex for $dayName');
            continue;
          }

          if (!mealNameToId.containsKey(mealNameStr)) {
            // Create meal document with minimal data
            final mealRef =
                FirebaseFirestore.instance.collection('meals').doc();
            final mealId = mealRef.id;
            debugPrint('  Creating meal document with ID: $mealId');

            final basicMealData = {
              'title': mealNameStr,
              'mealType': 'main',
              'calories': 0, // Will be filled by cloud functions
              'categories': [programData['type'] ?? 'custom'],
              'nutritionalInfo': {},
              'ingredients': {},
              'instructions': [],
              'status': 'pending',
              'createdAt': FieldValue.serverTimestamp(),
              'type': 'main',
              'userId': 'tasty_ai', // Use a placeholder ID or similar
              'source': 'ai_generated',
              'version': 'basic',
              'processingAttempts': 0,
              'lastProcessingAttempt': null,
              'processingPriority': DateTime.now().millisecondsSinceEpoch,
              'needsProcessing': true,
              'partOfWeeklyMeal': true,
              'weeklyPlanContext': programDescription,
            };

            batch.set(mealRef, basicMealData);
            mealNameToId[mealNameStr] = mealId;
            debugPrint('  Added to mealNameToId: "$mealNameStr" -> $mealId');
          } else {
            debugPrint('  Skipping duplicate meal: "$mealNameStr"');
          }
        }
      }
    }

    debugPrint('Total meals found across all days: $totalMealsFound');
    debugPrint('Unique meals to create: ${mealNameToId.length}');
    debugPrint('Meal name to ID mapping: $mealNameToId');

    // Commit all meals
    if (mealNameToId.isNotEmpty) {
      debugPrint('Committing batch with ${mealNameToId.length} meals...');
      await batch.commit();
      debugPrint(
          'Successfully created ${mealNameToId.length} meals with minimal data');
    } else {
      debugPrint('WARNING: No meals to create! mealNameToId is empty.');
    }

    // Replace meal names with meal IDs in program data
    debugPrint('Replacing meal names with IDs in program data...');
    for (int weekIndex = 0; weekIndex < weeklyPlans.length; weekIndex++) {
      final weekPlan = weeklyPlans[weekIndex];
      final mealPlan = weekPlan['mealPlan'] as Map<String, dynamic>? ?? {};
      final updatedMealPlan = <String, List<String>>{};

      debugPrint('Week ${weekIndex + 1}: Processing ${mealPlan.length} days');

      for (var entry in mealPlan.entries) {
        final dayName = entry.key;
        final meals = entry.value as List<dynamic>? ?? [];
        final mealIds = <String>[
          for (final mealName in meals)
            mealNameToId[mealName.toString().trim()] ??
                mealName.toString().trim()
        ];
        updatedMealPlan[dayName] = mealIds;
        debugPrint(
            '  $dayName: ${meals.length} meals -> ${mealIds.length} meal IDs');
      }
      weekPlan['mealPlan'] = updatedMealPlan;
    }

    updatedData['weeklyPlans'] = weeklyPlans;
    debugPrint('=== _createMealsFromPlan: Completed ===');
    return updatedData;
  }

  /// Save program meal plans to buddy collection for display in buddy tab
  /// All meals from all weeks are saved as a single generation under today's date
  Future<void> _saveProgramMealPlansToBuddy(Program program) async {
    final userId = userService.userId ?? '';
    if (userId.isEmpty) return;

    // Get diet preference from form data instead of user settings
    final formData = planningFormData.value;
    final diet = formData?['dietType']?.toString() ?? 'general';

    debugPrint('=== _saveProgramMealPlansToBuddy: Starting ===');
    debugPrint('Form data: $formData');
    debugPrint('Using diet: $diet');
    debugPrint('Number of weekly plans: ${program.weeklyPlans.length}');

    try {
      // Collect all meals from all weeks into a single list
      final allFormattedMealIds = <String>[];
      final allTips = <String>[];

      // Process each week's meal plan
      for (var weeklyPlan in program.weeklyPlans) {
        debugPrint('Processing week ${weeklyPlan.week}');
        final mealPlan = weeklyPlan.mealPlan;
        debugPrint('Meal plan structure: ${mealPlan.keys.toList()}');
        debugPrint('Meal plan entries count: ${mealPlan.length}');

        // Collect tips from this week
        if (weeklyPlan.tips.isNotEmpty) {
          allTips.addAll(weeklyPlan.tips);
        }

        // Process each day in this week
        for (var entry in mealPlan.entries) {
          final dayName = entry.key; // e.g., "Monday", "Tuesday"
          final mealIds = List<String>.from(entry.value);

          debugPrint('Day: $dayName, Meal IDs count: ${mealIds.length}');

          // Validate mealIds
          if (mealIds.isEmpty) {
            debugPrint(
                'Warning: No meal IDs for $dayName in week ${weeklyPlan.week}');
            continue;
          }

          // Format mealIds with meal type suffixes using the same method as meal plan chat
          // Try to get meal type from meal document, otherwise use default order
          final defaultMealTypes = ['breakfast', 'lunch', 'dinner', 'snack'];
          for (int i = 0; i < mealIds.length; i++) {
            final mealId = mealIds[i];
            if (mealId.isEmpty) {
              debugPrint('Warning: Empty meal ID at index $i for $dayName');
              continue;
            }

            // Try to get meal type from the meal document
            String mealType = 'general';
            try {
              final mealDoc = await FirebaseFirestore.instance
                  .collection('meals')
                  .doc(mealId)
                  .get();
              if (mealDoc.exists) {
                final mealData = mealDoc.data();
                mealType = (mealData?['mealType'] as String?)?.toLowerCase() ??
                    'general';
              } else {
                // Fallback to default order if meal doesn't exist yet
                final defaultIndex = i < defaultMealTypes.length
                    ? i
                    : i % defaultMealTypes.length;
                mealType = defaultMealTypes[defaultIndex];
              }
            } catch (e) {
              // Fallback to default order on error
              final defaultIndex =
                  i < defaultMealTypes.length ? i : i % defaultMealTypes.length;
              mealType = defaultMealTypes[defaultIndex];
            }

            final suffix = _getMealTypeSuffix(mealType);
            // Programs are main user only - no family member name in format
            allFormattedMealIds.add('$mealId/$suffix');
          }
        }
      }

      debugPrint(
          'Total formatted meal IDs collected: ${allFormattedMealIds.length}');
      debugPrint('Total tips collected: ${allTips.length}');

      if (allFormattedMealIds.isEmpty) {
        debugPrint('Warning: No meals to save');
        return;
      }

      // Save all meals as a single generation under today's date (like meal plan chat)
      final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final mealPlanRef = FirebaseFirestore.instance
          .collection('mealPlans')
          .doc(userId)
          .collection('buddy')
          .doc(dateStr);

      // Create new generation - programs are main user only
      // Use Timestamp.now() for consistency with meal plan chat
      final newGeneration = <String, dynamic>{
        'mealIds': allFormattedMealIds,
        'timestamp': Timestamp.now(),
        'diet': diet,
        'source': 'program',
        'familyMemberName':
            null, // Programs are main user only - explicitly set to null for filtering
      };

      // Only add tips if not empty
      if (allTips.isNotEmpty) {
        final tipsText = allTips.join('\n');
        if (tipsText.trim().isNotEmpty) {
          newGeneration['tips'] = tipsText;
        }
      }

      debugPrint('New generation structure: ${newGeneration.keys.toList()}');
      debugPrint('New generation mealIds count: ${allFormattedMealIds.length}');
      debugPrint('Saving to date: $dateStr');

      // Use update with arrayUnion to append the new generation (same as meal plan chat)
      // This avoids mixing FieldValue sentinels with already-parsed Timestamp objects
      await mealPlanRef.set({
        'date': dateStr,
      }, SetOptions(merge: true));

      await mealPlanRef.update({
        'generations': FieldValue.arrayUnion([newGeneration]),
      });

      debugPrint(
          'Successfully saved ${allFormattedMealIds.length} meals to buddy collection under date: $dateStr');
      debugPrint('=== _saveProgramMealPlansToBuddy: Completed ===');
    } catch (e, stackTrace) {
      debugPrint('CRITICAL ERROR in _saveProgramMealPlansToBuddy: $e');
      debugPrint('Stack trace: $stackTrace');
      // Don't rethrow - allow program creation to complete even if meal plan save fails
    }
  }

  /// Save meals to buddy collection for display in buddy tab
  /// This allows meals generated in meal plan chat to appear in the buddy tab
  Future<void> _saveMealsToBuddyCollection(
    List<String> mealIds, {
    String? familyMemberName,
  }) async {
    final userId = userService.userId ?? '';
    if (userId.isEmpty || mealIds.isEmpty) return;

    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final mealPlanRef = FirebaseFirestore.instance
          .collection('mealPlans')
          .doc(userId)
          .collection('buddy')
          .doc(dateStr);

      // Format meal IDs with meal type suffixes based on the meal data
      final formattedMealIds = <String>[];
      for (final mealId in mealIds) {
        // Try to get meal type from the meal document
        try {
          final mealDoc = await FirebaseFirestore.instance
              .collection('meals')
              .doc(mealId)
              .get();
          if (mealDoc.exists) {
            final mealData = mealDoc.data();
            final mealType =
                (mealData?['mealType'] as String?)?.toLowerCase() ?? 'general';
            final suffix = _getMealTypeSuffix(mealType);
            if (familyMemberName != null && familyMemberName.isNotEmpty) {
              formattedMealIds.add('$mealId/$suffix/$familyMemberName');
            } else {
              formattedMealIds.add('$mealId/$suffix');
            }
          } else {
            formattedMealIds.add(mealId);
          }
        } catch (e) {
          formattedMealIds.add(mealId);
        }
      }

      // Create new generation with regular timestamp (not FieldValue)
      // We'll use arrayUnion to append, which avoids mixing FieldValue with parsed data
      final newGeneration = <String, dynamic>{
        'mealIds': formattedMealIds,
        'timestamp': Timestamp.now(),
        'diet': userService.currentUser.value?.settings['dietPreference'] ??
            'general',
        'source': 'meal_plan_chat',
      };

      // Add family member name if provided
      // Note: Don't set familyMemberName field at all if null, so buddy_tab filtering works correctly
      if (familyMemberName != null && familyMemberName.isNotEmpty) {
        newGeneration['familyMemberName'] = familyMemberName;
      }
      // If familyMemberName is null/empty, don't include the field - buddy_tab checks for null or empty

      debugPrint('Saving generation to buddy collection:');
      debugPrint('  - mealIds count: ${formattedMealIds.length}');
      debugPrint('  - familyMemberName: ${newGeneration['familyMemberName']}');
      debugPrint('  - date: $dateStr');
      debugPrint('  - sample mealIds: ${formattedMealIds.take(3).toList()}');

      // Use update with arrayUnion to append the new generation
      // This avoids mixing FieldValue sentinels with already-parsed Timestamp objects
      await mealPlanRef.set({
        'date': dateStr,
      }, SetOptions(merge: true));

      await mealPlanRef.update({
        'generations': FieldValue.arrayUnion([newGeneration]),
      });

      debugPrint(
          'Successfully saved ${formattedMealIds.length} meals to buddy collection');
    } catch (e) {
      debugPrint('Error saving meals to buddy collection: $e');
    }
  }

  /// Get meal type suffix for buddy collection
  String _getMealTypeSuffix(String mealType) {
    switch (mealType.toLowerCase()) {
      case 'breakfast':
        return 'bf';
      case 'lunch':
        return 'lh';
      case 'dinner':
        return 'dn';
      case 'snack':
      case 'snacks':
        return 'sk';
      default:
        return 'bf'; // Default to breakfast
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
