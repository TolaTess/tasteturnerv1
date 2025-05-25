import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import '../constants.dart';
import '../helper/utils.dart';
import '../pages/safe_text_field.dart';
import '../service/chat_controller.dart';
import '../themes/theme_provider.dart';
import 'chat_screen.dart';
import '../widgets/icon_widget.dart';
import '../widgets/bottom_model.dart';
import '../screens/premium_screen.dart';

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
  bool get isPremium => userService.currentUser?.isPremium ?? false;

  bool isInFreeTrial = false;
  late ChatController chatController;

  // List of welcome messages
  final List<String> _welcomeMessages = [
    "👋 Hey there! Need some nutrition advice or meal planning help? I'm Tasty, your AI buddy!",
    "🌟 Welcome back! Looking for healthy meal ideas or want to discuss your fitness goals?",
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
    final freeTrialDate = userService.currentUser?.freeTrialDate;
    final isFreeTrial =
        freeTrialDate != null && DateTime.now().isBefore(freeTrialDate);
    setState(() {
      isInFreeTrial = isFreeTrial;
    });

    if (isPremium || isInFreeTrial) {
      _initializeChatWithBuddy();
    }
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
        !isPremium ||
        !isInFreeTrial ||
        chatController.messages.last.senderId == 'buddy') return;

    final messages = chatController.messages;
    final chatContent = messages.map((m) => m.messageContent).join('\n');
    final summaryPrompt = "Summarize this conversation: $chatContent";
    final summary = await geminiService.getResponse(summaryPrompt, 512);

    try {
      // Update chat summary as the last message
      await firestore.collection('chats').doc(chatId).update({
        'lastMessage': summary,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSender': messages.last.senderId,
      });

      print("Chat summary saved.");
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

  Widget _buildPremiumPrompt(ThemeProvider themeProvider) {
    return Stack(
      children: [
        if (widget.screen == 'message')
          Positioned(
            top: 20,
            left: 0,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: IconButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                icon: const IconCircleButton(),
              ),
            ),
          ),
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.workspace_premium,
                size: 80,
                color: kAccent,
              ),
              const SizedBox(height: 20),
              Text(
                'Premium Feature',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: themeProvider.isDarkMode ? kWhite : kBlack,
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  'Upgrade to premium to chat with your AI buddy Tasty 👋 and get personalized nutrition advice!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: themeProvider.isDarkMode ? kLightGrey : kDarkGrey,
                  ),
                ),
              ),
              const SizedBox(height: 32),
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
                child: const Text(
                  'Go Premium',
                  style: TextStyle(
                    fontSize: 18,
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
    if (isPremium || !isInFreeTrial) {
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
                const SizedBox(height: 45),
                Row(
                  children: [
                    if (isPremium || isInFreeTrial)
                      Expanded(
                        child: Container(
                          margin: const EdgeInsets.all(16),
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color:
                                themeProvider.isDarkMode ? kLightGrey : kWhite,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
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
                                CircleAvatar(
                                  backgroundColor:
                                      kAccentLight.withOpacity(0.5),
                                  backgroundImage: const AssetImage(
                                    tastyImage, // Adjust the path to your tasty image
                                  ),
                                  radius: 20,
                                ),
                                const SizedBox(width: 15),
                                Text(
                                  "Tasty Menu:",
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
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
                                      "💬 Chat about your fitness goals and progress",
                                      "Ask for advice, motivation, or meal planning",
                                      themeProvider.isDarkMode),
                                  _buildFeatureItem(
                                      context,
                                      "🎡 Type 'spin' to use the ingredient wheel",
                                      "Get random food suggestions based on your macros",
                                      themeProvider.isDarkMode),
                                  _buildFeatureItem(
                                      context,
                                      "📊 Discuss your nutrition and workout plans",
                                      "Get personalized recommendations for your goals",
                                      themeProvider.isDarkMode),
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
                      padding: const EdgeInsets.symmetric(vertical: 10),
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
                _buildInputSection(themeProvider.isDarkMode),
                SizedBox(
                  height: MediaQuery.of(context).viewInsets.bottom + 16,
                ),
              ],
            ),
          ),
        ),
      );
    } else {
      return Scaffold(
        body: _buildPremiumPrompt(themeProvider),
      );
    }
  }

  Widget _buildInputSection(bool isDarkMode) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        child: Row(
          children: [
            Expanded(
              child: SafeTextFormField(
                controller: textController,
                keyboardType: TextInputType.multiline,
                style: TextStyle(
                  fontSize: 16,
                  color: isDarkMode ? kWhite : kBlack,
                ),
                enabled: _canUserSendMessage(),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: isDarkMode ? kLightGrey : kWhite,
                  enabledBorder: outlineInputBorder(20),
                  focusedBorder: outlineInputBorder(20),
                  border: outlineInputBorder(20),
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  hintText: _getInputHintText(),
                  hintStyle: TextStyle(
                    color: isDarkMode
                        ? kWhite.withOpacity(0.5)
                        : kDarkGrey.withOpacity(0.5),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
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
                  h: 40,
                  w: 40,
                  colorL: canSend ? kAccent : kLightGrey,
                  colorD: canSend ? kAccent : kLightGrey,
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
      'displayName': userService.currentUser?.displayName ?? 'there',
      'fitnessGoal':
          userService.currentUser?.settings['fitnessGoal'] ?? 'Meal Planning',
      'chatSummary': userService.currentUser?.bio ?? '',
      'currentWeight':
          userService.currentUser?.settings['currentWeight'] ?? 0.0,
      'goalWeight': userService.currentUser?.settings['goalWeight'] ?? 0.0,
      'startingWeight':
          userService.currentUser?.settings['startingWeight'] ?? 0.0,
      'gender': userService.currentUser?.settings['gender'] ?? '',
      'foodGoal': userService.currentUser?.settings['foodGoal'] ?? 0.0,
      'dietPreference':
          userService.currentUser?.settings['dietPreference'] ?? 'Balanced',
      'bodyType': userService.currentUser?.settings['bodyType'] ?? '',
      'bodyTypeSymptoms':
          userService.currentUser?.settings['bodyTypeSymptoms'] ?? '',
    };
  }

  // Helper method to create initial prompt
  String _createInitialPrompt(Map<String, dynamic> userContext) {
    return """
Greet the user warmly and offer guidance based on:
- Username: ${userContext['displayName']} to address the user
- Fitness Goal: ${userContext['fitnessGoal']}
- Summary of previous chat: ${userContext['chatSummary']}
- Current Weight: ${userContext['currentWeight']}
- Goal Weight: ${userContext['goalWeight']}
- Starting Weight: ${userContext['startingWeight']}
- Gender: ${userContext['gender']}
- Food Goal: ${userContext['foodGoal']}
- Diet Preference: ${userContext['dietPreference']}
- Body Type: ${userContext['bodyType']}
- Body Type Symptoms: ${userContext['bodyTypeSymptoms']}
""";
  }

  // Helper method to send message to Gemini AI and save to Firestore
  Future<void> _sendMessageToGemini(String userInput,
      {bool isSystemMessage = false}) async {
    if (chatId == null || !(isPremium || isInFreeTrial)) return;

    final currentUserId = userService.userId!;
    final messages = chatController.messages;

    // Check for spin wheel command
    final userInputLower = userInput.toLowerCase();
    if (userInputLower.contains('spin') || userInputLower.contains('wheel')) {
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
        print("Error loading spin wheel: $e");
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
        print('Skipping AI response - last message was not from user');
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
          final username = userService.currentUser?.displayName;
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

  Future<void> _initializeChatWithBuddy() async {
    if (!(isPremium || isInFreeTrial)) return;

    if (chatId != null && chatId!.isNotEmpty) {
      // Existing chat - just listen to messages and mark as read
      chatController.chatId = chatId!;
      chatController.listenToMessages();
      chatController.markMessagesAsRead(chatId!, 'buddy');
      // Show a system message if the last message is not from the user
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final messages = chatController.messages;
        if (messages.isEmpty || messages.last.senderId != userService.userId) {
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
    }
  }

  void _showSystemMessage() {
    final randomMessage =
        _welcomeMessages[DateTime.now().microsecond % _welcomeMessages.length];
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
    // Save system message to Firestore
    _saveMessageToFirestore(randomMessage, 'systemMessage');
  }

  // Move this outside the build method
  Widget _buildFeatureItem(
      BuildContext context, String title, String subtitle, bool isDarkMode) {
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
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: isDarkMode ? kWhite : kBlack,
                      ),
                ),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: isDarkMode ? kWhite : kBlack,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
