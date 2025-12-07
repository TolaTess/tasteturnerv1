import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import '../constants.dart';
import '../helper/utils.dart';
import '../helper/helper_functions.dart';
import '../data_models/meal_model.dart';
import '../service/meal_planning_service.dart';
import '../service/chat_utilities.dart';

class BuddyChatController extends GetxController {
  static BuddyChatController? instance;

  var messages = <ChatScreenData>[].obs;

  late String chatId;
  List<StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>?
      _modeSubscriptions = [];

  // Mode-based chat state
  final RxString currentMode = 'sous chef'.obs; // 'sous chef', 'meal'
  final Map<String, List<ChatScreenData>> modeMessages = {};

  // Planning mode state
  final RxBool isFormSubmitted = false.obs;
  final RxBool showForm = false.obs;

  // AI response loading state
  final RxBool isResponding = false.obs;

  // Family Member Context (for Meal Plan mode)
  final RxnString familyMemberName = RxnString();
  final RxnString familyMemberKcal = RxnString();
  final RxnString familyMemberGoal = RxnString();
  final RxnString familyMemberType = RxnString();

  // Pantry Ingredients (for Meal Plan mode)
  final RxList<String> pantryIngredients = <String>[].obs;

  // Welcome Messages
  final List<String> tastyWelcomeMessages = [
    "Morning, Chef. Sous Chef Turner here. What's on the pass today?",
    "Chef, the station is ready. How can I assist with your nutrition goals today?",
    "Welcome back, Chef. Mise en place is set. What are we working on?",
    "Chef, I'm here to help you manage the kitchen. What do you need?",
  ];

  // Initialize chat and listen for messages (for buddy chats with modes)
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

    chatId = await ChatUtilities.getOrCreateChatId(currentUserId, friendId);

    // Set up mode subcollections and migrate if needed
    await _setupModeSubcollections();

    // Load current mode from chat document or default to 'sous chef'
    await _loadCurrentMode();

    // Listen to messages from all modes simultaneously
    listenToAllModeMessages();
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
        if (mode != null && ['sous chef', 'meal'].contains(mode)) {
          currentMode.value = mode;
        }
      }
    } catch (e) {
      debugPrint('Error loading current mode: $e');
    }
  }

  // Switch to a different mode
  Future<void> switchMode(String mode) async {
    if (!['sous chef', 'meal'].contains(mode)) {
      debugPrint('Invalid mode: $mode');
      return;
    }

    if (currentMode.value == mode) return;

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
  }

  // Get mode subcollection name
  String _getModeSubcollection(String mode) {
    return '${mode}_messages';
  }

  // Listen to messages from all modes simultaneously and merge them
  void listenToAllModeMessages() {
    if (chatId.isEmpty) {
      debugPrint("Chat ID is empty");
      return;
    }

    // Cancel existing subscriptions if any
    _cancelAllModeSubscriptions();

    try {
      final modes = ['sous chef', 'meal'];
      _modeSubscriptions = [];

      for (final mode in modes) {
        final subcollectionName = _getModeSubcollection(mode);
        final subscription = firestore
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

            // Merge all modes and update observable
            _mergeAndUpdateMessages();
          },
          onError: (e) {
            debugPrint("Error listening to $mode messages: $e");
            modeMessages[mode] = [];
            _mergeAndUpdateMessages();
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

        _modeSubscriptions!.add(subscription);
      }
    } catch (e) {
      debugPrint("Error setting up mode message listeners: $e");
      modeMessages['sous chef'] = [];
      modeMessages['meal'] = [];
      messages.clear();
    }
  }

  // Merge messages from all modes and update the observable
  void _mergeAndUpdateMessages() {
    final existingMessages = List<ChatScreenData>.from(messages);
    final mergedMessages = <ChatScreenData>[];

    // Add all messages from both modes
    for (final mode in ['sous chef', 'meal']) {
      final modeMessagesList = modeMessages[mode] ?? [];
      for (final msg in modeMessagesList) {
        mergedMessages.add(msg);
      }
    }

    // Add any local messages that don't have IDs yet (pending save)
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

  // Cancel all mode subscriptions
  void _cancelAllModeSubscriptions() {
    if (_modeSubscriptions != null) {
      for (final subscription in _modeSubscriptions!) {
        subscription.cancel();
      }
      _modeSubscriptions = [];
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
        messageData['actionButtons'] =
            ChatUtilities.sanitizeForFirestore(actionButtons);
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

  // Send a message
  Future<void> sendMessage({
    String? messageContent,
    List<String>? imageUrls,
    Map<String, dynamic>? shareRequest,
    bool isPrivate = false,
  }) async {
    // Validate chatId is set
    if (chatId.isEmpty) {
      debugPrint("Error: Cannot send message - chatId is empty");
      throw Exception("Chat ID is not initialized");
    }

    try {
      final currentUserId = userService.userId ?? '';

      // Buddy chat: use mode subcollections
      final actionButtons = shareRequest != null
          ? {
              'shareRequest': {...shareRequest, 'status': 'pending'}
            }
          : null;

      await saveMessageToMode(
        mode: currentMode.value,
        content: messageContent ?? '',
        senderId: currentUserId,
        imageUrls: imageUrls,
        actionButtons: actionButtons,
      );

      // Update chat summary
      final chatRef = firestore.collection('chats').doc(chatId);
      final timestamp = FieldValue.serverTimestamp();
      await chatRef.update({
        'lastMessage': messageContent?.isNotEmpty == true
            ? messageContent
            : (imageUrls != null && imageUrls.isNotEmpty ? 'Photo' : ''),
        'lastMessageTime': timestamp,
        'lastMessageSender': currentUserId,
        'lastMessageMode': currentMode.value,
      });
    } catch (e) {
      debugPrint("Error sending message: $e");
      rethrow;
    }
  }

  /// Save a message to Firestore for any chatId (for use in program_screen, etc)
  /// This method is primarily for buddy chats and will route to mode subcollections
  static Future<void> saveMessageToFirestore({
    required String chatId,
    required String content,
    required String senderId,
    List<String>? imageUrls,
    String? mode, // Optional mode for buddy chats (defaults to 'sous chef')
  }) async {
    if (chatId.isEmpty) {
      debugPrint("Error: Cannot save message - chatId is empty");
      throw Exception("Chat ID is not initialized");
    }

    // Check if this is a buddy chat by comparing with userService.buddyId
    final isBuddyChat = chatId == userService.buddyId;

    if (isBuddyChat) {
      // Buddy chat: use mode subcollections
      final targetMode = mode ?? 'sous chef';
      final subcollectionName = '${targetMode}_messages';
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

      await firestore.runTransaction((transaction) async {
        transaction.set(messageRef, messageData);

        // Update chat summary with mode information
        transaction.update(
          firestore.collection('chats').doc(chatId),
          {
            'lastMessage': content,
            'lastMessageTime': timestamp,
            'lastMessageSender': senderId,
            'lastMessageMode': targetMode,
            'currentMode': targetMode,
          },
        );
      });
    } else {
      // Friend chat: use simple messages collection (shouldn't happen in BuddyChatController, but handle gracefully)
      final messageRef = firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc();
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
  }

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

  // Main method to send message to AI
  Future<void> sendMessageToAI(String userInput, BuildContext context,
      {bool isHealthJourneyMode = false}) async {
    if (chatId.isEmpty || !canUseAI()) return;

    final currentUserId = userService.userId!;

    // Handle mode-specific message routing
    if (currentMode.value == 'meal') {
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

      // Set loading state
      isResponding.value = true;
      try {
        final response = await geminiService.getResponse(
          optimizePrompt,
          maxTokens: 4096,
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
      } finally {
        // Always clear loading state
        isResponding.value = false;
      }
      return;
    }

    // Add user messages to UI and Firestore first
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

    // Save to Firestore
    await saveMessageToMode(
      mode: currentMode.value,
      content: userInput,
      senderId: currentUserId,
      messageId: messageId,
    );

    // Only trigger Gemini if the last message is from the user
    if (messages.isNotEmpty && messages.last.senderId == currentUserId) {
      // Set loading state
      isResponding.value = true;
      try {
        final username = userService.currentUser.value?.displayName;
        String prompt = "${userInput}, user name is ${username ?? ''}".trim();

        // Add Food Health Journey context if mode is active
        if (isHealthJourneyMode) {
          prompt =
              """[Food Health Journey Mode - Track and guide the user's nutrition journey]

$prompt

IMPORTANT: You are now in Food Health Journey mode. Provide personalized nutrition guidance, track progress, offer encouragement, and help the user achieve their health goals. Be supportive and focus on long-term wellness.""";
        }

        // Build conversation history from recent messages (last 10 messages for context)
        // This allows the AI to understand follow-up questions
        List<Map<String, String>> conversationHistory = [];
        final recentMessages = messages.length > 6
            ? messages.sublist(messages.length - 6)
            : messages;

        // Skip the last message (current user input) as it will be added separately
        for (int i = 0; i < recentMessages.length - 1; i++) {
          final msg = recentMessages[i];
          // Only include text messages (skip images, action buttons, etc.)
          if (msg.messageContent.isNotEmpty &&
              msg.imageUrls.isEmpty &&
              msg.actionButtons == null) {
            final role = msg.senderId == currentUserId ? 'user' : 'model';
            conversationHistory.add({
              'role': role,
              'text': msg.messageContent,
            });
          }
        }

        // Use higher token limit to accommodate model "thoughts" and prevent empty responses
        // The model uses ~511 tokens for thoughts, so we need significantly more for actual response
        // Set to 4096 to ensure we get complete responses even with thoughts
        final tokenLimit = 4096;

        final response = await geminiService.getResponse(
          prompt,
          maxTokens: tokenLimit,
          role: buddyAiRole,
          conversationHistory:
              conversationHistory.isNotEmpty ? conversationHistory : null,
        );

        // Handle empty or error responses
        if (response.contains("Error") || response.isEmpty) {
          // Throw exception to show error handling
          throw Exception("Failed to generate response");
        }

        // Filter out system instructions from the response
        final cleanedResponse = _filterSystemInstructions(response);

        final aiResponseMessage = ChatScreenData(
          messageContent: cleanedResponse,
          senderId: 'buddy',
          timestamp: Timestamp.now(),
          imageUrls: [],
          messageId: '',
        );

        messages.add(aiResponseMessage);

        await saveMessageToMode(
          mode: currentMode.value,
          content: cleanedResponse,
          senderId: 'buddy',
        );
      } catch (e) {
        debugPrint("Error getting AI response: $e");
        // Show error snackbar
        showTastySnackbar(
          'Please try again.',
          'The station had a hiccup. Please try again.',
          context,
        );
        // Add a fallback AI message so the user can type again
        final fallbackContent =
            "Chef, I had a moment there. Please send that again.";

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
      } finally {
        // Always clear loading state
        isResponding.value = false;
      }
    }
  }

  // Handle meal plan quick action selection
  void handleMealPlanQuickAction(String action) {
    String prompt;
    int? mealCount;
    Map<String, int>? distribution;
    switch (action) {
      case '7days':
        prompt = familyMemberName.value != null
            ? 'Create a 7-day meal plan for ${familyMemberName.value} with exactly 3 breakfasts, 3 lunches, 3 dinners, and 2 snacks. Distribute these meals across the 7 days.'
            : 'Create a 7-day meal plan with exactly 3 breakfasts, 3 lunches, 3 dinners, and 2 snacks. Distribute these meals across the 7 days.';
        mealCount = 11; // 3 breakfasts + 3 lunches + 3 dinners + 2 snacks
        distribution = {
          'breakfast': 3,
          'lunch': 3,
          'dinner': 3,
          'snack': 2,
        };
        break;
      case 'single':
        prompt = familyMemberName.value != null
            ? 'Suggest a single healthy meal for ${familyMemberName.value}'
            : 'Suggest a single healthy meal';
        mealCount = 1;
        break;
      case 'remix':
        // Remix is handled in buddy_screen.dart via dialog
        // This case should not be reached, but kept for safety
        return;
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

    // Send the prompt through the chat with mealCount and distribution
    handleMealPlanModeMessage(prompt,
        mealCount: mealCount, distribution: distribution);
  }

  // Handle meal plan mode messages
  Future<void> handleMealPlanModeMessage(String userInput,
      {int? mealCount,
      Map<String, int>? distribution,
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
        detectedMealCount =
            11; // 3 breakfasts + 3 lunches + 3 dinners + 2 snacks
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

    // Set loading state
    isResponding.value = true;
    try {
      // Use meal planning service to generate meal plan with family member context
      final mealPlanningService = MealPlanningService.instance;
      final result = await mealPlanningService.generateMealPlanFromPrompt(
        userInput,
        mealCount: detectedMealCount,
        distribution: distribution,
        familyMemberName: familyMemberName,
        familyMemberKcal: familyMemberKcal,
        familyMemberGoal: familyMemberGoal,
        familyMemberType: familyMemberType,
        pantryIngredients:
            pantryIngredients.isNotEmpty ? pantryIngredients.toList() : null,
      );

      if (result['success'] == true) {
        final meals = result['meals'] as List<dynamic>? ?? [];
        var mealIds = result['mealIds'] as List<dynamic>? ?? [];
        final resultFamilyMemberName = result['familyMemberName'] as String?;

        // If mealIds is empty but meals exist, extract IDs from meals array
        if (mealIds.isEmpty && meals.isNotEmpty) {
          mealIds = meals
              .map((meal) {
                if (meal is Map<String, dynamic>) {
                  // Try different possible ID fields
                  return meal['id'] ?? meal['mealId'];
                }
                return null;
              })
              .whereType<String>()
              .where((id) => id.isNotEmpty)
              .toList();
        }

        // Also check existingMealIds if available
        if (mealIds.isEmpty) {
          final existingMealIds =
              result['existingMealIds'] as List<dynamic>? ?? [];
          if (existingMealIds.isNotEmpty) {
            mealIds = existingMealIds.map((id) => id.toString()).toList();
          }
        }

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
    } finally {
      // Always clear loading state
      isResponding.value = false;
    }
  }

  // Initialize Tasty Mode
  Future<void> initializeTastyMode(BuildContext context) async {
    // Wait for mode to stabilize
    await Future.delayed(const Duration(milliseconds: 300));

    // Verify we're still in sous chef mode before proceeding
    if (currentMode.value != 'sous chef') {
      return;
    }

    // Only show local greeting if messages are empty (first time entering)
    // No AI call - just use local welcome message
    // AI will only be called when user writes or clicks on meal items
    // IMPORTANT: Welcome message is only shown in UI, NOT saved to Firestore
    if (messages.isEmpty) {
      final welcomeContent = tastyWelcomeMessages[
          DateTime.now().microsecond % tastyWelcomeMessages.length];
      final message = ChatScreenData(
        messageContent: welcomeContent,
        senderId: 'buddy',
        timestamp: Timestamp.now(),
        imageUrls: [],
        messageId: '',
      );
      messages.add(message);
      // Do NOT save welcome message to Firestore - it's only for UI display
      debugPrint(
          "Sous chef local greeting shown (no AI call, not saved to Firestore)");
    }
  }

  // Initialize Meal Plan Mode
  Future<void> initializeMealPlanMode() async {
    // Wait for mode to stabilize and messages to load from Firestore
    await Future.delayed(const Duration(milliseconds: 500));

    // Verify we're still in meal plan mode before proceeding
    if (currentMode.value != 'meal') {
      debugPrint(
          'Mode changed from meal to ${currentMode.value}, skipping meal plan initialization');
      return;
    }

    // Meal Plan mode does not show a welcome message
    // Users can start interacting immediately
    debugPrint('Meal Plan mode initialized (no welcome message)');
  }

  // Process remix for selected meal
  Future<void> processRemixForMeal(
      Meal selectedMeal, BuildContext context) async {
    if (chatId.isEmpty) return;

    final currentUserId = userService.userId!;

    try {
      // Add user message indicating remix request
      final userMessage = ChatScreenData(
        messageContent: 'Remix: ${selectedMeal.title}',
        senderId: currentUserId,
        timestamp: Timestamp.now(),
        imageUrls: [],
        messageId: const Uuid().v4(),
      );
      messages.add(userMessage);
      await saveMessageToMode(
        mode: currentMode.value,
        content: userMessage.messageContent,
        senderId: currentUserId,
        messageId: userMessage.messageId,
      );

      // Get user context and family member info
      final userContext = getUserContext();
      final ingredients = selectedMeal.ingredients.isNotEmpty
          ? selectedMeal.ingredients.entries
              .map((e) => '${e.key}: ${e.value}')
              .join(', ')
          : 'ingredients not specified';

      // Create comprehensive remix meal generation prompt
      final remixMealPrompt = """
Create a remixed version of the following meal with ingredient substitutions and cooking method improvements:

Original Meal: ${selectedMeal.title}
Original Ingredients: $ingredients
Original Cooking Method: ${selectedMeal.cookingMethod ?? 'not specified'}

User Context:
- Diet Preference: ${userContext['dietPreference']}
- Fitness Goal: ${userContext['fitnessGoal']}

Instructions:
- Make 3-4 specific ingredient substitutions or cooking method improvements
- Create a complete meal with full instructions, ingredients with quantities, cooking steps, and nutritional information
- The remixed meal should align with the user's diet and fitness goals
- Ensure the meal is practical, encouraging, and maintains the essence of the original while improving it
""";

      // Generate meal directly using single meal method
      final mealPlanningService = MealPlanningService.instance;
      final result = await mealPlanningService.generateMealPlanFromPrompt(
        remixMealPrompt,
        mealCount: 1, // Single meal
        familyMemberName: familyMemberName.value,
        familyMemberKcal: familyMemberKcal.value,
        familyMemberGoal: familyMemberGoal.value,
        familyMemberType: familyMemberType.value,
        pantryIngredients:
            pantryIngredients.isNotEmpty ? pantryIngredients.toList() : null,
      );

      if (result['success'] == true) {
        final meals = result['meals'] as List<dynamic>? ?? [];
        var mealIds = result['mealIds'] as List<dynamic>? ?? [];
        final resultFamilyMemberName = result['familyMemberName'] as String?;

        // If mealIds is empty but meals exist, extract IDs from meals array
        if (mealIds.isEmpty && meals.isNotEmpty) {
          mealIds = meals
              .map((meal) {
                if (meal is Map<String, dynamic>) {
                  // Try different possible ID fields
                  return meal['id'] ?? meal['mealId'];
                }
                return null;
              })
              .whereType<String>()
              .where((id) => id.isNotEmpty)
              .toList();
        }

        // Also check existingMealIds if available
        if (mealIds.isEmpty) {
          final existingMealIds =
              result['existingMealIds'] as List<dynamic>? ?? [];
          if (existingMealIds.isNotEmpty) {
            mealIds = existingMealIds.map((id) => id.toString()).toList();
          }
        }

        if (meals.isNotEmpty && mealIds.isNotEmpty) {
          // Create message about the remix with View Recipe button
          final messageId = const Uuid().v4();
          final remixMessageContent =
              'I\'ve remixed ${selectedMeal.title} for you, Chef! Click "View Recipe" to see the full instructions. Enjoy Cooking!';
          final actionButtons = <String, dynamic>{
            'viewMeals': true,
            'mealIds': mealIds,
            if (resultFamilyMemberName != null)
              'familyMemberName': resultFamilyMemberName,
          };

          final remixMessage = ChatScreenData(
            messageContent: remixMessageContent,
            senderId: 'buddy',
            timestamp: Timestamp.now(),
            imageUrls: [],
            messageId: messageId,
            actionButtons: actionButtons,
          );
          messages.add(remixMessage);

          // Save remix message to Firestore so it persists when user returns
          await saveMessageToMode(
            mode: currentMode.value,
            content: remixMessageContent,
            senderId: 'buddy',
            messageId: messageId,
            actionButtons: actionButtons,
          );
          debugPrint(
              'Remix meal generated successfully and saved to Firestore');
        } else {
          // No meals generated or no mealIds
          final errorMessage = ChatScreenData(
            messageContent:
                'Chef, I had trouble generating the remixed meal. Please try again.',
            senderId: 'buddy',
            timestamp: Timestamp.now(),
            imageUrls: [],
            messageId: '',
          );
          messages.add(errorMessage);
          await saveMessageToMode(
            mode: currentMode.value,
            content: errorMessage.messageContent,
            senderId: 'buddy',
          );
        }
      } else {
        // Generation failed
        final errorMessage = ChatScreenData(
          messageContent:
              'Chef, I had trouble generating the remixed meal. Please try again.',
          senderId: 'buddy',
          timestamp: Timestamp.now(),
          imageUrls: [],
          messageId: '',
        );
        messages.add(errorMessage);
        await saveMessageToMode(
          mode: currentMode.value,
          content: errorMessage.messageContent,
          senderId: 'buddy',
        );
      }
    } catch (e) {
      debugPrint('Error processing remix request: $e');
      final errorMessage = ChatScreenData(
        messageContent:
            'Chef, I had trouble processing your remix request. Please try again.',
        senderId: 'buddy',
        timestamp: Timestamp.now(),
        imageUrls: [],
        messageId: '',
      );
      messages.add(errorMessage);
      await saveMessageToMode(
        mode: currentMode.value,
        content: errorMessage.messageContent,
        senderId: 'buddy',
      );
      if (context.mounted) {
        showTastySnackbar(
          'Error',
          'Chef, I had trouble processing your remix request. Please try again.',
          context,
        );
      }
    }
  }

  // Filter out system instructions from AI responses
  String _filterSystemInstructions(String response) {
    String cleaned = response;

    // Remove common system instruction patterns using simple string replacement first
    final instructionPhrases = [
      'Greet the user as "Chef" and offer guidance',
      "Greet the user as 'Chef' and offer guidance",
      'Greet the user as Chef and offer guidance',
      'Remember: You are Sous Chef Turner',
      'Be professional, solution-oriented',
      'Address the user as "Chef" throughout',
      'offer guidance based on',
    ];

    // Remove instruction phrases (case-insensitive)
    for (final phrase in instructionPhrases) {
      final escaped = phrase.replaceAllMapped(
          RegExp(r'[.*+?^${}()|[\]\\]'), (m) => '\\${m[0]}');
      final regex = RegExp(escaped, caseSensitive: false);
      cleaned = cleaned.replaceAll(regex, '');
    }

    // Remove patterns that might appear in multi-line instruction blocks
    final patterns = [
      // Pattern for instruction-like text at the start with context info
      RegExp(r'^.*?(?:address them as|based on:|Username:|Goal:).*?\n',
          caseSensitive: false, dotAll: true),
      // Pattern for "Greet the user" followed by context
      RegExp(r'Greet\s+the\s+user.*?Address\s+the\s+user.*?throughout',
          caseSensitive: false, dotAll: true),
    ];

    for (final pattern in patterns) {
      cleaned = cleaned.replaceAll(pattern, '');
    }

    // Clean up multiple consecutive newlines
    cleaned = cleaned.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    // Trim whitespace
    cleaned = cleaned.trim();

    return cleaned.isEmpty ? response : cleaned;
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
    _cancelAllModeSubscriptions();
    super.onClose();
  }
}
