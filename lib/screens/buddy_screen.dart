import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import '../constants.dart';
import '../helper/helper_functions.dart';
import '../helper/utils.dart';
import '../pages/photo_manager.dart';
import '../pages/safe_text_field.dart';
import '../service/chat_controller.dart';
import '../themes/theme_provider.dart';
import 'chat_screen.dart';
import '../widgets/icon_widget.dart';
import '../widgets/bottom_model.dart';
import '../screens/premium_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TastyScreen extends StatefulWidget {
  final String screen;
  const TastyScreen({super.key, this.screen = 'buddy'});

  @override
  State<TastyScreen> createState() => _TastyScreenState();
}

class _TastyScreenState extends State<TastyScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController textController = TextEditingController();
  String? chatId;

  late ChatController chatController;

  // List of welcome messages
  final List<String> _welcomeMessages = [
    "👋 Hey there! Need some nutrition advice or meal planning help? I'm Tasty, your AI buddy!",
    "🌟 Welcome back! Looking for healthy meal ideas or want to discuss your nutrition goals?",
    "🥗 Hi! Want to explore new recipes or get personalized nutrition tips? Just ask!",
    "💪 Ready to make some healthy choices? Let me know what you'd like help with!",
    "🎯 Need help staying on track with your nutrition goals? I'm here to support you!"
  ];

  @override
  void initState() {
    super.initState();
    try {
      chatController = Get.find<ChatController>();
    } catch (e) {
      // If controller is not found, initialize it
      chatController = Get.put(ChatController());
    }
    chatId = userService.buddyId;

    if (canUseAI()) {
      _initializeChatWithBuddy();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      checkAndPromptAIPayment(context);
    });
  }

  void _onNewMessage() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  OutlineInputBorder outlineInputBorder(double radius) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(radius),
      borderSide: const BorderSide(color: Colors.transparent),
    );
  }

  /// Save message to Firestore under chatId/messages
  Future<void> _saveMessageToFirestore(String content, String senderId,
      {List<String>? imageUrls}) async {
    // Always save all messages, including system messages
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

  /// Summarize chat when screen is closed and update chat summary in Firestore
  Future<void> _saveChatSummary() async {
    if (chatId == null ||
        !canUseAI() ||
        chatController.messages.last.senderId == 'buddy') return;

    final messages = chatController.messages;
    final chatContent = messages.map((m) => m.messageContent).join('\n');
    final summaryPrompt = "Summarize this conversation: $chatContent";
    final summary = await geminiService.getResponse(summaryPrompt, 512);

    try {
      // Prepare update data
      final updateData = {
        'lastMessage': summary,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSender': messages.last.senderId,
      };

      // Include food analysis ID if available
      final analysisId = getLastFoodAnalysisId();
      if (analysisId != null) {
        updateData['lastFoodAnalysisId'] = analysisId;
      }

      // Update chat summary as the last message
      await firestore.collection('chats').doc(chatId).update(updateData);
    } catch (e) {
      print("Failed to save chat summary: $e");
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _saveChatSummary();
    super.dispose();
  }

  Widget _buildPremiumPrompt(ThemeProvider themeProvider, TextTheme textTheme) {
    return Stack(
      children: [
        if (widget.screen == 'message')
          Positioned(
            top: getPercentageHeight(5, context),
            left: getPercentageWidth(2, context),
            child: Padding(
              padding: EdgeInsets.all(getPercentageWidth(2, context)),
              child: IconButton(
                onPressed: () {
                  Get.back();
                },
                icon: IconCircleButton(
                  isRemoveContainer: true,
                  size: getIconScale(6.5, context),
                ),
              ),
            ),
          ),
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.workspace_premium,
                size: getIconScale(15, context),
                color: kAccent,
              ),
              SizedBox(height: getPercentageHeight(1, context)),
              Text(
                'Premium Feature',
                style: textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: getPercentageHeight(1, context)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  'Upgrade to premium to chat with your AI buddy Tasty 👋 and get personalized nutrition advice!',
                  textAlign: TextAlign.center,
                  style: textTheme.bodyMedium?.copyWith(
                    color: themeProvider.isDarkMode ? kLightGrey : kDarkGrey,
                  ),
                ),
              ),
              SizedBox(height: getPercentageHeight(3, context)),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: kAccent,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const PremiumScreen(),
                    ),
                  );
                },
                child: Text(
                  'Go Premium',
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: kWhite,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final textTheme = Theme.of(context).textTheme;
    if (canUseAI()) {
      if (chatId == null) {
        // Chat is still initializing
        return const Scaffold(
          body: Center(child: CircularProgressIndicator(color: kAccent)),
        );
      }
      return Scaffold(
        body: SafeArea(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              FocusScope.of(context).unfocus();
            },
            child: Column(
              children: [
                SizedBox(height: getPercentageHeight(2.5, context)),
                Row(
                  children: [
                    if (canUseAI())
                      Expanded(
                        child: Container(
                          margin:
                              EdgeInsets.all(getPercentageWidth(1.5, context)),
                          padding:
                              EdgeInsets.all(getPercentageWidth(1, context)),
                          decoration: BoxDecoration(
                            color:
                                themeProvider.isDarkMode ? kLightGrey : kWhite,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ExpansionTile(
                            collapsedIconColor:
                                themeProvider.isDarkMode ? kWhite : kDarkGrey,
                            iconColor:
                                themeProvider.isDarkMode ? kWhite : kDarkGrey,
                            title: Row(
                              children: [
                                if (widget.screen == 'message')
                                  InkWell(
                                    onTap: () {
                                      Get.back();
                                    },
                                    child: const IconCircleButton(),
                                  ),
                                SizedBox(width: getPercentageWidth(2, context)),
                                Text(
                                  "Tasty Menu:",
                                  style: textTheme.displaySmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    fontSize: getTextScale(7, context),
                                    color: themeProvider.isDarkMode
                                        ? kWhite
                                        : kDarkGrey,
                                  ),
                                ),
                              ],
                            ),
                            initiallyExpanded: false,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildFeatureItem(
                                      context,
                                      "💬 Chat about your nutrition goals and progress",
                                      "Ask for advice, motivation, or meal planning",
                                      themeProvider.isDarkMode,
                                      textTheme),
                                  _buildFeatureItem(
                                      context,
                                      "🎡 Type 'spin' to use the ingredient wheel",
                                      "Get random food suggestions based on your macros",
                                      themeProvider.isDarkMode,
                                      textTheme),
                                  _buildFeatureItem(
                                      context,
                                      "📊 Discuss your nutrition and workout plans",
                                      "Get personalized recommendations for your goals",
                                      themeProvider.isDarkMode,
                                      textTheme),
                                  _buildFeatureItem(
                                      context,
                                      "🍽️ Analyze your food images",
                                      "Get personalized recommendations for your meal",
                                      themeProvider.isDarkMode,
                                      textTheme),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                Expanded(
                  child: Obx(() {
                    final messages = chatController.messages;

                    if (messages.isEmpty) {
                      return noItemTastyWidget(
                        "No messages yet.",
                        "Start a conversation with Tasty!.",
                        context,
                        false,
                        'buddy',
                      );
                    }

                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (_scrollController.hasClients) {
                        _scrollController
                            .jumpTo(_scrollController.position.maxScrollExtent);
                      }
                    });

                    return ListView.builder(
                      controller: _scrollController,
                      itemCount: messages.length,
                      padding: EdgeInsets.symmetric(
                          vertical: getPercentageHeight(1, context)),
                      itemBuilder: (context, index) {
                        final message = messages[index];
                        return ChatItem(
                          dataSrc: message,
                          isMe: message.senderId == userService.userId,
                          chatController: chatController,
                          chatId: chatId!,
                        );
                      },
                    );
                  }),
                ),
                _buildInputSection(themeProvider.isDarkMode, textTheme),
                SizedBox(height: getPercentageHeight(3, context)),
              ],
            ),
          ),
        ),
      );
    } else {
      return Scaffold(
        body: _buildPremiumPrompt(themeProvider, textTheme),
      );
    }
  }

  Widget _buildInputSection(bool isDarkMode, TextTheme textTheme) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            getPercentageWidth(2, context),
            getPercentageHeight(0.8, context),
            getPercentageWidth(2, context),
            getPercentageHeight(2.8, context)),
        child: Row(
          children: [
            InkWell(
              onTap: !canUseAI()
                  ? null
                  : () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        builder: (_) {
                          return CustomImagePickerModal(
                            onSend: (images, caption) => handleImageSend(
                                images,
                                caption,
                                chatId!,
                                _scrollController,
                                chatController),
                          );
                        },
                      );
                    },
              child: const IconCircleButton(
                icon: Icons.camera_alt,
                size: kIconSizeMedium,
              ),
            ),
            SizedBox(width: getPercentageWidth(1, context)),
            Expanded(
              child: SafeTextFormField(
                controller: textController,
                keyboardType: TextInputType.multiline,
                style: textTheme.bodyMedium?.copyWith(
                  color: isDarkMode ? kWhite : kBlack,
                ),
                enabled: _canUserSendMessage(),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: isDarkMode ? kLightGrey : kWhite,
                  enabledBorder: outlineInputBorder(20),
                  focusedBorder: outlineInputBorder(20),
                  border: outlineInputBorder(20),
                  contentPadding: EdgeInsets.symmetric(
                      vertical: getPercentageHeight(1.2, context),
                      horizontal: getPercentageWidth(1.6, context)),
                  hintText: _getInputHintText(),
                  hintStyle: textTheme.bodyMedium?.copyWith(
                    color: isDarkMode
                        ? kWhite.withValues(alpha: 0.5)
                        : kDarkGrey.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ),
            SizedBox(width: getPercentageWidth(1, context)),
            Obx(() {
              final canSend = _canUserSendMessage();
              return InkWell(
                onTap: canSend
                    ? () async {
                        final messageText = textController.text.trim();
                        if (messageText.isNotEmpty) {
                          await _sendMessageToGemini(messageText);
                          textController.clear();
                        }
                      }
                    : null,
                child: IconCircleButton(
                  icon: Icons.send,
                  size: kIconSizeMedium,
                  colorL: canSend ? kDarkGrey : kLightGrey,
                  colorD: canSend ? kWhite : kLightGrey,
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  // Helper method to check if user can send a message
  bool _canUserSendMessage() {
    final messages = chatController.messages;
    return messages.isEmpty ||
        messages.last.senderId == 'buddy' ||
        messages.last.senderId == 'systemMessage';
  }

  // Helper method to get appropriate hint text
  String _getInputHintText() {
    final messages = chatController.messages;
    if (messages.isNotEmpty &&
        messages.last.senderId != 'buddy' &&
        messages.last.senderId != 'systemMessage') {
      return 'Waiting for AI response...';
    }
    return 'Type your message...';
  }

  // Helper method to get user context
  Map<String, dynamic> _getUserContext() {
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

  // Helper method to send remix response
  Future<void> _sendRemixResponse(
      String prompt,
      Map<String, dynamic> userContext,
      String currentUserId,
      String chatId,
      List<ChatScreenData> messages) async {
    try {
      print('🔍 DEBUG: Sending remix prompt: $prompt');
      final response = await geminiService.getResponse(
        prompt,
        512,
        role: buddyAiRole,
      );
      print('🔍 DEBUG: Remix response received: "$response"');

      setState(() {
        messages.add(ChatScreenData(
          messageContent: response,
          senderId: 'buddy',
          timestamp: Timestamp.now(),
          imageUrls: [],
          messageId: '',
        ));
      });
      _onNewMessage();
      await _saveMessageToFirestore(response, 'buddy');
    } catch (e) {
      print("Error getting remix suggestions: $e");
      setState(() {
        messages.add(ChatScreenData(
          messageContent:
              "I'd love to help you remix those ingredients! Here are some ideas based on your ${userContext['dietPreference']} goals: try adding more protein with some lean meat or legumes, swap refined grains for whole grains, and add colorful vegetables for extra nutrients. What specific ingredient would you like to focus on? 😊",
          senderId: 'buddy',
          timestamp: Timestamp.now(),
          imageUrls: [],
          messageId: '',
        ));
      });
      _onNewMessage();
      await _saveMessageToFirestore(
          "I'd love to help you remix those ingredients! Here are some ideas based on your ${userContext['dietPreference']} goals: try adding more protein with some lean meat or legumes, swap refined grains for whole grains, and add colorful vegetables for extra nutrients. What specific ingredient would you like to focus on? 😊",
          'buddy');
    }
  }

  // Helper method to create initial prompt
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

  // Helper method to send message to Gemini AI and save to Firestore
  Future<void> _sendMessageToGemini(String userInput,
      {bool isSystemMessage = false}) async {
    if (chatId == null || !canUseAI()) return;

    final currentUserId = userService.userId!;
    final messages = chatController.messages;

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
      // Add user message to chat
      setState(() {
        messages.add(ChatScreenData(
          messageContent: userInput,
          senderId: currentUserId,
          timestamp: Timestamp.now(),
          imageUrls: [],
          messageId: '',
        ));
      });
      _onNewMessage();
      await _saveMessageToFirestore(userInput, currentUserId);

      // Trigger detailed food analysis
      await handleDetailedFoodAnalysis(context, chatId!);
      return;
    }

    // Check for Option 1 - Remix ingredients
    if (userInputLower.contains('option 1') ||
        userInputLower.contains('1') ||
        userInputLower.contains('remix')) {
      FirebaseAnalytics.instance.logEvent(name: 'buddy_remix_ingredients');
      // Add user message to chat
      setState(() {
        messages.add(ChatScreenData(
          messageContent: userInput,
          senderId: currentUserId,
          timestamp: Timestamp.now(),
          imageUrls: [],
          messageId: '',
        ));
      });
      _onNewMessage();
      await _saveMessageToFirestore(userInput, currentUserId);

      // Get user context and food analysis data
      final userContext = _getUserContext();
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
            remixPrompt, userContext, currentUserId, chatId!, messages);
        return;
      }

      // Fallback if no analysis data
      final remixPrompt = """
User wants to remix their meal for ${userContext['dietPreference']} diet and ${userContext['fitnessGoal']} goals.

Give 3-4 specific ingredient or cooking suggestions. Be encouraging and practical!
""";

      await _sendRemixResponse(
          remixPrompt, userContext, currentUserId, chatId!, messages);
      return;
    }

    // Check for Option 2 - Optimize nutrition
    if (userInputLower.contains('option 2') ||
        userInputLower.contains('2') ||
        userInputLower.contains('protein') ||
        userInputLower.contains('optimize')) {
      FirebaseAnalytics.instance.logEvent(name: 'buddy_optimize_nutrition');
      // Add user message to chat
      setState(() {
        messages.add(ChatScreenData(
          messageContent: userInput,
          senderId: currentUserId,
          timestamp: Timestamp.now(),
          imageUrls: [],
          messageId: '',
        ));
      });
      _onNewMessage();
      await _saveMessageToFirestore(userInput, currentUserId);

      // Get user context and food analysis data
      final userContext = _getUserContext();
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
          512,
          role: buddyAiRole,
        );

        setState(() {
          messages.add(ChatScreenData(
            messageContent: response,
            senderId: 'buddy',
            timestamp: Timestamp.now(),
            imageUrls: [],
            messageId: '',
          ));
        });
        _onNewMessage();
        await _saveMessageToFirestore(response, 'buddy');
      } catch (e) {
        final fallbackMessage = isWeightLoss
            ? "Great choice! To reduce calories while keeping protein high, try: using lean proteins like chicken breast or fish, adding more vegetables to increase volume, using cooking sprays instead of oils, and choosing Greek yogurt over regular yogurt. These swaps will help you feel full while staying on track! 💪"
            : isMuscleBuild
                ? "Perfect for muscle building! Try adding: a protein-rich side like cottage cheese or Greek yogurt, some nuts or seeds for healthy fats and extra protein, quinoa instead of rice for complete protein, or a protein smoothie as a post-meal boost. Your muscles will thank you! 🏋️‍♂️"
                : "For optimal nutrition balance, consider: adding colorful vegetables for vitamins and minerals, including healthy fats like avocado or nuts, ensuring you have a good protein source, and staying hydrated. Balance is key to feeling your best! 🌟";

        setState(() {
          messages.add(ChatScreenData(
            messageContent: fallbackMessage,
            senderId: 'buddy',
            timestamp: Timestamp.now(),
            imageUrls: [],
            messageId: '',
          ));
        });
        _onNewMessage();
        await _saveMessageToFirestore(fallbackMessage, 'buddy');
      }
      return;
    }

    // Check for spin wheel command
    if (userInputLower.contains('spin') || userInputLower.contains('wheel')) {
      FirebaseAnalytics.instance.logEvent(name: 'buddy_spin_wheel');
      try {
        // Get ingredients from Firestore first
        final ingredients = await macroManager.getIngredientsByCategory('all');
        final uniqueTypes = await macroManager.getUniqueTypes(ingredients);
        final mealList = await mealManager.fetchMealsByCategory('all');
        // Add user message to chat
        setState(() {
          messages.add(ChatScreenData(
            messageContent: userInput,
            senderId: currentUserId,
            timestamp: Timestamp.now(),
            imageUrls: [],
            messageId: '',
          ));
        });
        _onNewMessage();
        await _saveMessageToFirestore(userInput, currentUserId);

        // Add AI response with countdown
        const aiResponse =
            "🎡 Preparing your Spin Wheel!\n\nIn just 5 seconds, you'll be able to:\n"
            "• Select from different macro categories\n"
            "• Add your own custom ingredients\n"
            "• Spin for random meal suggestions\n\n"
            "Loading the wheel... ⏳";

        setState(() {
          messages.add(ChatScreenData(
            messageContent: aiResponse,
            senderId: 'buddy',
            timestamp: Timestamp.now(),
            imageUrls: [],
            messageId: '',
          ));
        });
        _onNewMessage();
        await _saveMessageToFirestore(aiResponse, 'buddy');

        // Wait before showing the spin wheel
        if (mounted) {
          await Future.delayed(const Duration(seconds: 5));
          showSpinWheel(
            context,
            'Carbs',
            ingredients,
            mealList,
            uniqueTypes,
            'All',
            true,
          );
        }
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
      // Add message to UI
      setState(() {
        messages.add(ChatScreenData(
          messageContent: userInput,
          senderId: currentUserId,
          timestamp: Timestamp.now(),
          imageUrls: [],
          messageId: '',
        ));
      });
      _onNewMessage();

      // Save to Firestore
      await _saveMessageToFirestore(userInput, currentUserId);

      // Only trigger Gemini if the last message is from the user
      if (messages.isNotEmpty && messages.last.senderId != currentUserId) {
        return;
      }
    }

    // Only trigger Gemini if the last message is from the user
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
          final prompt = "${userInput}, user name is ${username ?? ''}".trim();
          response = await geminiService.getResponse(
            prompt,
            512,
            role: buddyAiRole,
          );

          if (response.contains("Error") || response.isEmpty) {
            throw Exception("Failed to generate response");
          }
        }

        setState(() {
          messages.add(ChatScreenData(
            messageContent: response,
            senderId: 'buddy',
            timestamp: Timestamp.now(),
            imageUrls: [],
            messageId: '',
          ));
        });
        _onNewMessage();
        await _saveMessageToFirestore(response, 'buddy');
      } catch (e) {
        print("Error getting AI response: $e");
        showTastySnackbar(
          'Please try again.',
          'Failed to get AI response. Please try again.',
          context,
        );
        // Add a fallback AI message so the user can type again
        setState(() {
          messages.add(ChatScreenData(
            messageContent: "Sorry, I couldn't respond. Please try again.",
            senderId: 'buddy',
            timestamp: Timestamp.now(),
            imageUrls: [],
            messageId: '',
          ));
        });
        _onNewMessage();
        await _saveMessageToFirestore(
            "Sorry, I couldn't respond. Please try again.", 'buddy');
      }
    }
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

  Future<void> _initializeChatWithBuddy() async {
    if (!canUseAI()) return;

    if (chatId != null && chatId!.isNotEmpty) {
      // Existing chat - just listen to messages and mark as read
      chatController.chatId = chatId!;
      chatController.listenToMessages();
      chatController.markMessagesAsRead(chatId!, 'buddy');
      // Show a Gemini welcome message once per day, or system message if not needed
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final messages = chatController.messages;
        final now = DateTime.now();
        final lastWelcome = await _getLastGeminiWelcomeDate();
        final isToday = lastWelcome != null &&
            lastWelcome.year == now.year &&
            lastWelcome.month == now.month &&
            lastWelcome.day == now.day;
        if (!isToday) {
          final userContext = _getUserContext();
          final initialPrompt = _createInitialPrompt(userContext);
          await _sendMessageToGemini(initialPrompt, isSystemMessage: true);
          await _setLastGeminiWelcomeDate(now);
        } else if (messages.isEmpty ||
            messages.last.senderId != userService.userId) {
          _showSystemMessage();
        }
      });
    } else {
      // New chat - create it and listen
      await chatController.initializeChat('buddy').then((_) {
        setState(() {
          chatId = chatController.chatId;
        });
        userService.setBuddyChatId(chatId!);
        chatController.markMessagesAsRead(chatId!, 'buddy');
      });

      // ONLY send welcome message for completely new chats
      _showSystemMessage();
      final userContext = _getUserContext();
      final initialPrompt = _createInitialPrompt(userContext);
      await _sendMessageToGemini(initialPrompt, isSystemMessage: true);
      await _setLastGeminiWelcomeDate(DateTime.now());
    }
  }

  void _showSystemMessage() {
    final messages = chatController.messages;
    final randomMessage =
        _welcomeMessages[DateTime.now().microsecond % _welcomeMessages.length];

    // Only send if last message is not a system message or is different
    if (messages.isNotEmpty &&
        messages.last.senderId == 'systemMessage' &&
        messages.last.messageContent == randomMessage) {
      return;
    }

    setState(() {
      chatController.messages.add(ChatScreenData(
        messageContent: randomMessage,
        senderId: 'systemMessage',
        timestamp: Timestamp.now(),
        imageUrls: [],
        messageId: '',
      ));
    });
    _onNewMessage();
    _saveMessageToFirestore(randomMessage, 'systemMessage');
  }

  // Move this outside the build method
  Widget _buildFeatureItem(BuildContext context, String title, String subtitle,
      bool isDarkMode, TextTheme textTheme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: kAccent,
                  ),
                ),
                Center(
                  child: Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: textTheme.bodySmall?.copyWith(
                      color: isDarkMode ? kWhite : kBlack,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> checkAndPromptAIPayment(BuildContext context) async {
    final preference = await SharedPreferences.getInstance();
    final startDateStr = preference.getString('ai_trial_start_date');

    if (startDateStr != null) {
      final startDate = DateTime.parse(startDateStr);
      final now = DateTime.now();
      if (now.difference(startDate).inDays >= 14) {
        // Get theme values before showing dialog
        final isDarkMode = getThemeProvider(context).isDarkMode;
        final textTheme = Theme.of(context).textTheme;

        // Show payment dialog
        showDialog(
          context: context,
          builder: (dialogContext) => AlertDialog(
            backgroundColor: isDarkMode ? kDarkGrey : kWhite,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            title: Text('AI Assistant Trial Ended',
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                )),
            content: Text(
              'Your free trial has ended. Go Premium to continue using the AI Assistant.',
              style: textTheme.bodySmall?.copyWith(),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const PremiumScreen(),
                    ),
                  );
                },
                child: Text('Premium', style: textTheme.bodySmall?.copyWith()),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child:
                    Text('Maybe Later', style: textTheme.bodySmall?.copyWith()),
              ),
            ],
          ),
        );
      }
    }
  }
}
