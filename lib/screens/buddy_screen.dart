import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../constants.dart';
import '../helper/helper_functions.dart';
import '../helper/utils.dart';
import '../pages/photo_manager.dart';
import '../pages/safe_text_field.dart';
import '../service/chat_controller.dart';
import '../service/program_service.dart';
import '../service/token_usage_service.dart';
import '../service/meal_planning_service.dart';
import '../data_models/program_model.dart';
import '../themes/theme_provider.dart';
import 'chat_screen.dart';
import '../widgets/icon_widget.dart';
import '../widgets/bottom_model.dart';
import '../widgets/planning_form.dart';
import '../screens/premium_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';

class TastyScreen extends StatefulWidget {
  final String screen;
  const TastyScreen({super.key, this.screen = 'buddy'});

  @override
  State<TastyScreen> createState() => _TastyScreenState();
}

class _TastyScreenState extends State<TastyScreen>
    with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController textController = TextEditingController();
  String? chatId;

  late ChatController chatController;
  late TabController _tabController;

  // Speech-to-text
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  String _recognizedText = '';

  // Food Health Journey mode
  bool _isHealthJourneyMode = false;

  // Tasty mode welcome messages
  final List<String> _tastyWelcomeMessages = [
    "👋 Hey there! Need some nutrition advice or meal planning help? I'm Tasty, your AI buddy!",
    "🌟 Welcome back! Looking for healthy meal ideas or want to discuss your nutrition goals?",
    "🥗 Hi! Want to explore new recipes or get personalized nutrition tips? Just ask!",
    "💪 Ready to make some healthy choices? Let me know what you'd like help with!",
    "🎯 Need help staying on track with your nutrition goals? I'm here to support you!"
  ];

  // Planner mode welcome messages
  final List<String> _plannerWelcomeMessages = [
    "👋 Ready to create your personalized nutrition program? Let's start by filling out your preferences!",
    "🌟 Let's design a custom nutrition plan tailored to your goals. First, tell me about your preferences!",
    "📋 I'm here to help you build a nutrition program. Let's begin with a few quick questions!"
  ];

  // Meal plan mode welcome messages
  final List<String> _mealPlanWelcomeMessages = [
    "🍽️ Welcome to Meal Plan! I can create 7-day meal plans, suggest quick meals, share detailed recipes, and even analyze meal images. What would you like today?",
    "👨‍🍳 Hi! I'm your meal planning assistant. Need a full week of meals, a single recipe, or quick meal ideas? Just ask or use the options below!",
    "🥘 Ready to plan some meals! I can help with weekly plans, individual recipes, quick 30-min meals, or analyze photos of your food. What sounds good?"
  ];

  // State for meal plan quick action buttons (shown when entering from buddy tab)
  bool _showMealPlanQuickActions = false;

  // Family member context for meal plan mode (passed from buddy_tab.dart)
  String? _familyMemberName;
  String? _familyMemberKcal;
  String? _familyMemberGoal;
  String? _familyMemberType;

  // Pending mode switches (deferred to post-frame callback to avoid chatId initialization issues)
  bool _pendingMealPlanMode = false;
  bool _pendingPlanningMode = false;

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

    // Initialize TabController for 3 modes
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabChange);

    // Check if planning mode or meal plan mode should be enabled from navigation
    // Note: Mode switch is deferred to post-frame callback to ensure chatId is initialized
    final args = Get.arguments;
    if (args != null && args is Map) {
      if (args['mealPlanMode'] == true) {
        // Store family member context for meal generation
        _familyMemberName = args['familyMemberName'] as String?;
        _familyMemberKcal = args['familyMemberKcal'] as String?;
        _familyMemberGoal = args['familyMemberGoal'] as String?;
        _familyMemberType = args['familyMemberType'] as String?;
        _pendingMealPlanMode = true;
      } else if (args['planningMode'] == true) {
        _pendingPlanningMode = true;
      }
    }

    if (canUseAI()) {
      _initializeChatWithBuddy();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      checkAndPromptAIPayment(context);

      // Handle pending mode switches (deferred from initState to avoid chatId initialization issues)
      if (_pendingMealPlanMode) {
        _pendingMealPlanMode = false;
        _tabController.index = 2;
        // Only switch mode if chatId is initialized
        if (chatId != null && chatId!.isNotEmpty) {
          chatController.switchMode('meal');
        } else {
          chatController.currentMode.value = 'meal';
        }
        _showMealPlanWelcomeWithOptions();
      } else if (_pendingPlanningMode) {
        _pendingPlanningMode = false;
        // Only enter planning mode if chatId is initialized
        if (chatId != null && chatId!.isNotEmpty) {
          chatController.enterPlanningMode();
        } else {
          chatController.currentMode.value = 'planner';
        }
        _tabController.index = 1;
      }

      // Initialize mode-specific content
      _initializeModeContent();
    });
  }

  void _handleTabChange() {
    if (!_tabController.indexIsChanging) {
      final modes = ['tasty', 'planner', 'meal'];
      final newMode = modes[_tabController.index];
      if (chatController.currentMode.value != newMode) {
        // Clear any welcome messages that might have been added for the wrong mode
        _clearWelcomeMessagesForWrongMode(newMode);

        // Only switch mode if chatId is initialized
        if (chatId != null && chatId!.isNotEmpty) {
          chatController.switchMode(newMode);
        } else {
          // Update mode without switching (which requires chatId)
          chatController.currentMode.value = newMode;
        }
        _initializeModeContent();
      }
    }
  }

  // Clear welcome messages that don't match the current mode
  void _clearWelcomeMessagesForWrongMode(String correctMode) {
    final messages = chatController.messages;
    final messagesToRemove = <ChatScreenData>[];

    for (final msg in messages) {
      // Check if this is a welcome message for a different mode
      if (msg.senderId == 'buddy' || msg.senderId == 'systemMessage') {
        final isTastyWelcome = _tastyWelcomeMessages.any(
            (welcome) => msg.messageContent.contains(welcome.substring(0, 20)));
        final isPlannerWelcome = _plannerWelcomeMessages.any(
            (welcome) => msg.messageContent.contains(welcome.substring(0, 20)));
        final isMealPlanWelcome = _mealPlanWelcomeMessages.any(
            (welcome) => msg.messageContent.contains(welcome.substring(0, 20)));

        // Remove welcome messages that don't match the current mode
        if (correctMode == 'planner' && (isTastyWelcome || isMealPlanWelcome)) {
          messagesToRemove.add(msg);
        } else if (correctMode == 'meal' &&
            (isTastyWelcome || isPlannerWelcome)) {
          messagesToRemove.add(msg);
        } else if (correctMode == 'tasty' &&
            (isPlannerWelcome || isMealPlanWelcome)) {
          messagesToRemove.add(msg);
        }
      }
    }

    if (messagesToRemove.isNotEmpty) {
      setState(() {
        for (final msg in messagesToRemove) {
          messages.remove(msg);
        }
      });
      debugPrint(
          'Cleared ${messagesToRemove.length} welcome message(s) for wrong mode');
    }
  }

  void _initializeModeContent() {
    final currentMode = chatController.currentMode.value;
    if (currentMode == 'planner') {
      _initializePlannerMode();
    } else if (currentMode == 'meal') {
      _initializeMealPlanMode();
    } else {
      _initializeTastyMode();
    }
  }

  // Removed - using planner mode initialization instead

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

  /// Save message to Firestore under chatId/{mode}_messages
  Future<void> _saveMessageToFirestore(String content, String senderId,
      {List<String>? imageUrls, Map<String, dynamic>? actionButtons}) async {
    if (chatId == null || chatId!.isEmpty) return;

    final currentMode = chatController.currentMode.value;
    await chatController.saveMessageToMode(
      mode: currentMode,
      content: content,
      senderId: senderId,
      imageUrls: imageUrls,
      actionButtons: actionButtons,
    );
  }

  /// Summarize chat when screen is closed and update chat summary in Firestore
  Future<void> _saveChatSummary() async {
    if (chatId == null ||
        !canUseAI() ||
        chatController.messages.last.senderId == 'buddy') return;

    final messages = chatController.messages;
    final chatContent = messages.map((m) => m.messageContent).join('\n');
    final summaryPrompt = "Summarize this conversation: $chatContent";
    final summary =
        await geminiService.getResponse(summaryPrompt, maxTokens: 512);

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
      debugPrint("Failed to save chat summary: $e");
    }
  }

  // Speech-to-text methods
  Future<void> _startListening() async {
    // Request microphone permission
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      if (mounted) {
        showTastySnackbar(
          'Permission Required',
          'Microphone permission is needed for voice notes.',
          context,
          backgroundColor: kRed,
        );
      }
      return;
    }

    // Check if speech recognition is available
    bool available = await _speech.initialize(
      onStatus: (status) {
        if (mounted) {
          setState(() {
            if (status == 'done' || status == 'notListening') {
              _isListening = false;
            }
          });
        }
      },
      onError: (error) {
        debugPrint('Speech recognition error: $error');
        if (mounted) {
          setState(() {
            _isListening = false;
          });
          showTastySnackbar(
            'Speech Error',
            'Failed to recognize speech. Please try again.',
            context,
            backgroundColor: kRed,
          );
        }
      },
    );

    if (!available) {
      if (mounted) {
        showTastySnackbar(
          'Not Available',
          'Speech recognition is not available on this device.',
          context,
          backgroundColor: kRed,
        );
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isListening = true;
        _recognizedText = '';
      });
    }

    // Start listening
    await _speech.listen(
      onResult: (result) {
        if (mounted) {
          setState(() {
            _recognizedText = result.recognizedWords;
            // Update text controller with recognized text
            textController.text = _recognizedText;
          });
        }
      },
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
      partialResults: true,
      localeId: 'en_US',
    );
  }

  Future<void> _stopListening() async {
    await _speech.stop();
    if (mounted) {
      setState(() {
        _isListening = false;
      });
    }
  }

  @override
  void dispose() {
    _speech.stop();
    _scrollController.dispose();
    textController.dispose();
    _tabController.dispose();
    // Don't await async operations in dispose - use deactivate instead
    super.dispose();
  }

  @override
  void deactivate() {
    // Save chat summary before widget is deactivated
    // This is called before dispose, so we can safely call async operations
    _saveChatSummary();
    super.deactivate();
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
                SizedBox(height: getPercentageHeight(1, context)),
                // Top bar with back button and tabs aligned
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: getPercentageWidth(2, context),
                    vertical: getPercentageHeight(1, context),
                  ),
                  child: Row(
                    children: [
                      // Back button for message screen and buddy screen - aligned with tabs
                      if (widget.screen == 'message' ||
                          widget.screen == 'buddy')
                        Container(
                          margin: EdgeInsets.only(
                              right: getPercentageWidth(2, context)),
                          decoration: BoxDecoration(
                            color: themeProvider.isDarkMode
                                ? kDarkGrey
                                : kLightGrey,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: InkWell(
                            onTap: () {
                              Get.back();
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: EdgeInsets.all(
                                  getPercentageWidth(2.5, context)),
                              child: Icon(
                                Icons.arrow_back_ios_new,
                                size: getPercentageWidth(4, context),
                                color: themeProvider.isDarkMode
                                    ? kWhite
                                    : kDarkGrey,
                              ),
                            ),
                          ),
                        ),
                      // Mode Tab Bar - aligned with back button
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: themeProvider.isDarkMode
                                ? kDarkGrey
                                : kLightGrey,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: TabBar(
                            controller: _tabController,
                            indicator: BoxDecoration(
                              color: kAccent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            indicatorSize: TabBarIndicatorSize.tab,
                            labelColor: kWhite,
                            unselectedLabelColor: themeProvider.isDarkMode
                                ? kWhite.withValues(alpha: 0.6)
                                : kDarkGrey.withValues(alpha: 0.6),
                            labelStyle: textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            tabs: const [
                              Tab(
                                icon: Icon(Icons.chat_bubble_outline),
                                text: 'Tasty',
                              ),
                              Tab(
                                icon: Icon(Icons.edit_note),
                                text: 'Planner',
                              ),
                              Tab(
                                icon: Icon(Icons.restaurant_menu),
                                text: 'Meal Plan',
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Mode Banner
                _buildModeBanner(themeProvider, textTheme),
                // Planning Form (show when in planner mode and showForm is true)
                Obx(() {
                  final currentMode = chatController.currentMode.value;
                  final showForm = chatController.showForm.value;

                  if (currentMode == 'planner' && showForm) {
                    // Scroll to form when it appears
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (_scrollController.hasClients) {
                        _scrollController.animateTo(
                          0,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut,
                        );
                      }
                    });
                    return Flexible(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: MediaQuery.of(context).size.height * 0.5,
                        ),
                        child: SingleChildScrollView(
                          child: PlanningForm(
                            onSubmit: (formData) {
                              _sendFormToAIForConfirmation(formData);
                            },
                            isDarkMode: themeProvider.isDarkMode,
                            initialData: chatController.planningFormData.value,
                          ),
                        ),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                }),

                // Food Health Journey mode banner
                if (_isHealthJourneyMode)
                  Container(
                    width: double.infinity,
                    margin: EdgeInsets.symmetric(
                      horizontal: getPercentageWidth(2, context),
                      vertical: getPercentageHeight(1, context),
                    ),
                    padding: EdgeInsets.symmetric(
                      horizontal: getPercentageWidth(3, context),
                      vertical: getPercentageHeight(1.5, context),
                    ),
                    decoration: BoxDecoration(
                      color: kAccent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: kAccent.withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.eco,
                          color: kAccent,
                          size: getIconScale(6, context),
                        ),
                        SizedBox(width: getPercentageWidth(2, context)),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Food Health Journey Mode Active",
                                style: textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: kAccent,
                                ),
                              ),
                              SizedBox(
                                  height: getPercentageHeight(0.3, context)),
                              Text(
                                "Tasty will provide personalized nutrition guidance and track your progress",
                                style: textTheme.bodySmall?.copyWith(
                                  color: themeProvider.isDarkMode
                                      ? kWhite.withValues(alpha: 0.8)
                                      : kDarkGrey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: Obx(() {
                    final messages = chatController.messages;
                    final currentMode = chatController.currentMode.value;

                    if (messages.isEmpty) {
                      // Show quick actions for meal plan mode when no messages
                      if (currentMode == 'meal' && _showMealPlanQuickActions) {
                        return SingleChildScrollView(
                          child: Column(
                            children: [
                              _buildMealPlanQuickActions(),
                            ],
                          ),
                        );
                      }
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

                    return Column(
                      children: [
                        // Show meal plan quick actions at the top when enabled
                        if (currentMode == 'meal' && _showMealPlanQuickActions)
                          _buildMealPlanQuickActions(),

                        // Chat messages list
                        Expanded(
                          child: ListView.builder(
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
                                onPlanSubmit: () {
                                  // Trigger plan generation when submit button is clicked
                                  _generatePlanFromConversation();
                                },
                              );
                            },
                          ),
                        ),
                      ],
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
            // Voice note button
            InkWell(
              onTap: !canUseAI()
                  ? null
                  : _isListening
                      ? () => _stopListening()
                      : () => _startListening(),
              child: Container(
                height: kIconSizeMedium * 1.8,
                width: kIconSizeMedium * 1.8,
                margin: const EdgeInsets.only(left: 5),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isListening
                      ? kRed.withValues(alpha: kMidOpacity)
                      : kAccent.withValues(alpha: kMidOpacity),
                ),
                child: Icon(
                  _isListening ? Icons.mic : Icons.mic_none,
                  size: kIconSizeMedium,
                  color: getThemeProvider(context).isDarkMode ? kWhite : kBlack,
                ),
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
              final isPlanning = chatController.isPlanningMode.value;
              final isReady = chatController.isReadyToGenerate.value;

              // Show Generate Plan button if ready, otherwise show send button
              if (isPlanning && isReady) {
                return ElevatedButton.icon(
                  onPressed: () => _generatePlanFromConversation(),
                  icon: const Icon(Icons.auto_awesome, color: kWhite),
                  label: const Text('Generate Plan',
                      style: TextStyle(color: kWhite)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kAccent,
                    padding: EdgeInsets.symmetric(
                      horizontal: getPercentageWidth(3, context),
                      vertical: getPercentageHeight(1, context),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                );
              }

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
      final response = await geminiService.getResponse(
        prompt,
        maxTokens: 512,
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
      debugPrint("Error getting remix suggestions: $e");
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

  // Helper method to send system message to Gemini AI (without saving the prompt to Firestore)
  Future<void> _sendSystemMessageToGemini(String systemPrompt) async {
    if (chatId == null || !canUseAI()) return;

    try {
      // Create a proper welcome message prompt instead of passing the system prompt directly
      final welcomePrompt = """
Based on the following user context, create a warm, personalized welcome message:

${systemPrompt}

Respond with only a friendly, encouraging welcome message that addresses the user by name and offers to help with their nutrition goals. Do not include any of the context information in your response.
""";

      final response = await geminiService.getResponse(
        welcomePrompt,
        maxTokens: 512,
        role: buddyAiRole,
      );

      if (response.contains("Error") || response.isEmpty) {
        throw Exception("Failed to generate response");
      }

      setState(() {
        chatController.messages.add(ChatScreenData(
          messageContent: response,
          senderId: 'buddy',
          timestamp: Timestamp.now(),
          imageUrls: [],
          messageId: '',
        ));
      });
      _onNewMessage();
      // Don't save welcome messages to Firestore - they're UI-only
      debugPrint('AI-generated welcome message shown (not saved to Firestore)');
    } catch (e) {
      debugPrint("Error getting AI response for system message: $e");
      // Add a fallback welcome message
      final fallbackMessage =
          "👋 Hey there! I'm Tasty, your AI nutrition buddy! How can I help you today?";
      setState(() {
        chatController.messages.add(ChatScreenData(
          messageContent: fallbackMessage,
          senderId: 'buddy',
          timestamp: Timestamp.now(),
          imageUrls: [],
          messageId: '',
        ));
      });
      _onNewMessage();
      // Don't save fallback welcome messages to Firestore - they're UI-only
      debugPrint('Fallback welcome message shown (not saved to Firestore)');
    }
  }

  // Helper method to send message to Gemini AI and save to Firestore
  Future<void> _sendMessageToGemini(String userInput,
      {bool isSystemMessage = false}) async {
    if (chatId == null || !canUseAI()) return;

    final currentMode = chatController.currentMode.value;
    final currentUserId = userService.userId!;
    final messages = chatController.messages;

    // Handle mode-specific message routing
    if (currentMode == 'planner') {
      await _handlePlannerModeMessage(userInput);
      return;
    } else if (currentMode == 'meal') {
      await _handleMealPlanModeMessage(userInput);
      return;
    }
    // Continue with tasty mode handling below

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
          maxTokens: 512,
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
      // Remove any system messages when user starts interacting
      _removeSystemMessages();

      // Add message to UI
      final userMessage = ChatScreenData(
        messageContent: userInput,
        senderId: currentUserId,
        timestamp: Timestamp.now(),
        imageUrls: [],
        messageId: '',
      );

      final messages = chatController.messages;
      setState(() {
        messages.add(userMessage);
      });

      // Track planning conversation
      if (chatController.isPlanningMode.value) {
        chatController.addPlanningMessage(userMessage);
      }

      _onNewMessage();

      // Save to Firestore
      await _saveMessageToFirestore(userInput, currentUserId);

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
          if (_isHealthJourneyMode) {
            prompt =
                """[Food Health Journey Mode - Track and guide the user's nutrition journey]

$prompt

IMPORTANT: You are now in Food Health Journey mode. Provide personalized nutrition guidance, track progress, offer encouragement, and help the user achieve their health goals. Be supportive and focus on long-term wellness.""";
          }

          // Add Planning Mode context if active
          if (chatController.isPlanningMode.value) {
            // Get minimal planning context (no chat summary)
            final userId = userService.userId ?? '';
            String? currentProgramName;
            if (userId.isNotEmpty) {
              try {
                final userProgramQuery = await firestore
                    .collection('userProgram')
                    .where('userIds', arrayContains: userId)
                    .limit(1)
                    .get();

                if (userProgramQuery.docs.isNotEmpty) {
                  final programId = userProgramQuery.docs.first.id;
                  final programDoc = await firestore
                      .collection('programs')
                      .doc(programId)
                      .get();
                  if (programDoc.exists) {
                    currentProgramName = programDoc.data()?['name'] as String?;
                  }
                }
              } catch (e) {
                debugPrint('Error fetching program in planning mode: $e');
              }
            }

            final fitnessGoal = userService
                .currentUser.value?.settings['fitnessGoal'] as String?;
            final username =
                userService.currentUser.value?.displayName ?? 'there';

            // Build focused planning prompt with only relevant context
            String planningContext = '';
            if (currentProgramName != null) {
              planningContext +=
                  'Current enrolled program: $currentProgramName. ';
            }
            if (fitnessGoal != null && fitnessGoal.isNotEmpty) {
              planningContext += 'Current goal: $fitnessGoal. ';
            }

            // Get form data if available
            final formData = chatController.planningFormData.value;
            String formDataContext = '';
            if (formData != null) {
              formDataContext = '''
Form Data (already provided by user):
- Duration: ${formData['duration']}
- Goal: ${formData['goal']}
- Diet Type: ${formData['dietType']}
- Activity Level: ${formData['activityLevel']}
${formData['additionalDetails']?.toString().isNotEmpty == true ? '- Additional Details: ${formData['additionalDetails']}' : ''}

''';
            }

            // Get full conversation history for planning context
            // Include all messages to maintain full context
            String conversationHistory = '';
            if (chatController.planningConversation.isNotEmpty) {
              conversationHistory = chatController.planningConversation
                  .map((msg) =>
                      '${msg.senderId == userService.userId ? "User" : "AI"}: ${msg.messageContent}')
                  .join('\n');
            }

            // Build focused planning prompt - override briefing instruction for planning mode
            prompt =
                """You are in Program Planning Mode. Your ONLY task is to help create a personalized nutrition program.

Context:
- User's name: $username
${planningContext.isNotEmpty ? '- $planningContext' : ''}

${formDataContext.isNotEmpty ? formDataContext : ''}${conversationHistory.isNotEmpty ? 'Conversation so far:\n$conversationHistory\n\n' : ''}User's current message: $userInput

CRITICAL INSTRUCTIONS:
1. Focus ONLY on gathering information needed to create a nutrition program
2. If form data is provided above, DO NOT ask for information that was already provided (duration, goal, diet type, activity level). Use that information and only ask for additional details if needed.
3. Ask ONE question at a time about any missing information:
   - Health goals (if not in form data)
   - Duration preference (if not in form data)
   - Dietary restrictions and preferences (if not in form data)
   - Meal preferences and cuisine types
   - Activity level (if not in form data)
   - Any specific requirements or constraints
4. Be conversational and friendly, but stay focused on planning
5. Reference the conversation history and form data to avoid repeating questions
6. Once you have enough information (goals, duration, dietary preferences, and activity level), say: "Great! I have enough information. Would you like me to generate your custom program now?"
7. Do NOT discuss anything unrelated to program planning
8. Do NOT reference previous chat conversations or unrelated topics
9. Respond naturally - you can use more than 2-4 sentences if needed for clarity

Respond with ONLY your next planning question or confirmation that you're ready to generate the plan.""";
          }

          // Use 8000 tokens for planning mode to support detailed conversations
          final maxTokens = chatController.isPlanningMode.value ? 8000 : 8000;
          // In planning mode, don't use buddyAiRole to avoid chat summary context
          // Also exclude diet context so AI can ask about dietary preferences
          final role = chatController.isPlanningMode.value ? null : buddyAiRole;
          final includeDietContext = !chatController.isPlanningMode.value;
          response = await geminiService.getResponse(
            prompt,
            maxTokens: maxTokens,
            role: role,
            includeDietContext: includeDietContext,
          );

          // Track token usage with planning mode metadata
          if (chatController.isPlanningMode.value) {
            try {
              final tokenService = TokenUsageService.instance;
              final userId = userService.userId;
              // Estimate tokens (actual tracking would need to come from gemini_service)
              // For now, we'll track with metadata
              await tokenService.trackUsage(
                operation: 'plan_creation',
                inputTokens: prompt.length ~/ 4, // Rough estimate
                outputTokens: response.length ~/ 4, // Rough estimate
                provider: 'gemini',
                userId: userId,
                metadata: {'mode': 'planning', 'operation': 'plan_creation'},
              );
            } catch (e) {
              debugPrint('Error tracking planning mode tokens: $e');
            }
          }

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

        setState(() {
          messages.add(aiResponseMessage);
        });

        // Track AI response in planning conversation
        if (chatController.isPlanningMode.value) {
          chatController.addPlanningMessage(aiResponseMessage);
        }

        _onNewMessage();
        await _saveMessageToFirestore(response, 'buddy');
      } catch (e) {
        debugPrint("Error getting AI response: $e");
        showTastySnackbar(
          'Please try again.',
          'Failed to get AI response. Please try again.',
          context,
        );
        // Add a fallback AI message so the user can type again
        setState(() {
          messages.add(ChatScreenData(
            messageContent:
                "Sorry, I snoozed for a moment. Please try sending your message again.",
            senderId: 'buddy',
            timestamp: Timestamp.now(),
            imageUrls: [],
            messageId: '',
          ));
        });
        _onNewMessage();
        await _saveMessageToFirestore(
            "Sorry, I snoozed for a moment. Please try sending your message again.",
            'buddy');
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
      // Existing chat - set chatId and initialize mode
      chatController.chatId = chatId!;
      await chatController.initializeChat('buddy');

      // Sync tab controller with current mode
      final modes = ['tasty', 'planner', 'meal'];
      final modeIndex = modes.indexOf(chatController.currentMode.value);
      if (modeIndex >= 0 && modeIndex < 3) {
        _tabController.index = modeIndex;
      }

      chatController.markMessagesAsRead(chatId!, 'buddy');
    } else {
      // New chat - create it and listen
      await chatController.initializeChat('buddy');
      setState(() {
        chatId = chatController.chatId;
      });
      if (chatId != null) {
        userService.setBuddyChatId(chatId!);
        chatController.markMessagesAsRead(chatId!, 'buddy');
      }
    }
  }

  void _initializeTastyMode() {
    // Initialize tasty mode - show welcome message if needed
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Wait for mode to stabilize
      await Future.delayed(const Duration(milliseconds: 300));

      if (!mounted) return;

      // Verify we're still in tasty mode before proceeding
      final currentMode = chatController.currentMode.value;
      if (currentMode != 'tasty') {
        debugPrint(
            'Mode changed from tasty to $currentMode, skipping welcome message');
        return;
      }

      if (chatController.messages.isEmpty) {
        // Double-check mode hasn't changed
        if (chatController.currentMode.value != 'tasty') {
          debugPrint(
              'Mode changed during initialization, aborting tasty welcome');
          return;
        }

        final now = DateTime.now();
        final lastWelcome = await _getLastGeminiWelcomeDate();
        final isToday = lastWelcome != null &&
            lastWelcome.year == now.year &&
            lastWelcome.month == now.month &&
            lastWelcome.day == now.day;

        // Final mode check before showing message
        if (chatController.currentMode.value != 'tasty') {
          debugPrint('Mode changed before showing welcome, aborting');
          return;
        }

        if (!isToday) {
          final userContext = _getUserContext();
          final initialPrompt = _createInitialPrompt(userContext);
          await _sendSystemMessageToGemini(initialPrompt);
          await _setLastGeminiWelcomeDate(now);
        } else {
          // Verify mode one more time before showing system message
          if (chatController.currentMode.value == 'tasty' && mounted) {
            _showSystemMessage();
          }
        }
      }
    });
  }

  void _initializePlannerMode() {
    // Initialize planner mode - show welcome message and form
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Wait for mode to stabilize and messages to load from Firestore
      await Future.delayed(const Duration(milliseconds: 500));

      if (!mounted) return;

      // Verify we're still in planner mode before proceeding
      final currentMode = chatController.currentMode.value;
      if (currentMode != 'planner') {
        debugPrint(
            'Mode changed from planner to $currentMode, skipping welcome message');
        return;
      }

      // Check if planner mode has no messages (first time entering)
      // Check both the cached mode messages and the current observable messages
      final plannerMessages = chatController.getModeMessages('planner');
      final currentMessages = chatController.messages;

      // Double-check mode hasn't changed
      if (chatController.currentMode.value != 'planner') {
        debugPrint(
            'Mode changed during initialization, aborting planner welcome');
        return;
      }

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

      // Final mode check before showing message
      if (chatController.currentMode.value != 'planner') {
        debugPrint('Mode changed before showing welcome, aborting');
        return;
      }

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

        // Final verification before adding message
        if (chatController.currentMode.value == 'planner' && mounted) {
          setState(() {
            chatController.messages.add(message);
          });
          _onNewMessage();
          // Don't save static welcome messages to Firestore - they're UI-only
          debugPrint('Planner welcome message shown (not saved to Firestore)');
        }
      }

      // Show form if not submitted yet (always show on first entry to planner mode)
      if (chatController.currentMode.value == 'planner' &&
          !chatController.isFormSubmitted.value) {
        chatController.showForm.value = true;
      }
    });
  }

  void _initializeMealPlanMode() {
    // Initialize meal plan mode - show welcome message
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Wait for mode to stabilize and messages to load from Firestore
      await Future.delayed(const Duration(milliseconds: 500));

      if (!mounted) return;

      // Verify we're still in meal plan mode before proceeding
      final currentMode = chatController.currentMode.value;
      if (currentMode != 'meal') {
        debugPrint(
            'Mode changed from meal to $currentMode, skipping welcome message');
        return;
      }

      // Check if meal plan mode has no messages (first time entering)
      final mealPlanMessages = chatController.getModeMessages('meal');
      final currentMessages = chatController.messages;

      // Double-check mode hasn't changed
      if (chatController.currentMode.value != 'meal') {
        debugPrint(
            'Mode changed during initialization, aborting meal plan welcome');
        return;
      }

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

      // Final mode check before showing message
      if (chatController.currentMode.value != 'meal') {
        debugPrint('Mode changed before showing welcome, aborting');
        return;
      }

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

        // Final verification before adding message
        if (chatController.currentMode.value == 'meal' && mounted) {
          setState(() {
            chatController.messages.add(message);
          });
          _onNewMessage();
          // Don't save static welcome messages to Firestore - they're UI-only
          debugPrint(
              'Meal plan welcome message shown (not saved to Firestore)');
        }
      }
    });
  }

  String _getWelcomeMessageForMealPlan() {
    return _mealPlanWelcomeMessages[
        DateTime.now().microsecond % _mealPlanWelcomeMessages.length];
  }

  String _getWelcomeMessageForPlanner() {
    return _plannerWelcomeMessages[
        DateTime.now().microsecond % _plannerWelcomeMessages.length];
  }

  // Show meal plan welcome with quick action buttons (when entering from buddy tab)
  void _showMealPlanWelcomeWithOptions() {
    setState(() {
      _showMealPlanQuickActions = true;
    });
  }

  // Handle meal plan quick action selection
  void _handleMealPlanQuickAction(String action) {
    if (!mounted) return;

    setState(() {
      _showMealPlanQuickActions = false;
    });

    String prompt;
    int? mealCount;
    switch (action) {
      case '7days':
        prompt = _familyMemberName != null
            ? 'Create a 7-day meal plan for $_familyMemberName with breakfast, lunch, and dinner'
            : 'Create a 7-day meal plan with breakfast, lunch, and dinner';
        mealCount = 21; // 7 days × 3 meals
        break;
      case 'single':
        prompt = _familyMemberName != null
            ? 'Suggest a single healthy meal for $_familyMemberName'
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
    _handleMealPlanModeMessage(prompt, mealCount: mealCount);
  }

  // Build meal plan quick actions widget
  Widget _buildMealPlanQuickActions() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  Theme.of(context).colorScheme.secondary.withOpacity(0.1),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.restaurant_menu,
                      color: Theme.of(context).colorScheme.primary,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _familyMemberName != null
                            ? '🎯 Planning for $_familyMemberName'
                            : '🍽️ What would you like to plan?',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Choose a quick option below or type your own request:',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.7),
                      ),
                ),
                const SizedBox(height: 16),

                // Main action buttons - 7 days and single meal
                Row(
                  children: [
                    Expanded(
                      child: _buildQuickActionButton(
                        icon: Icons.calendar_view_week,
                        label: '7-Day Plan',
                        sublabel: 'Full week meals',
                        onTap: () => _handleMealPlanQuickAction('7days'),
                        isPrimary: true,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildQuickActionButton(
                        icon: Icons.restaurant,
                        label: 'Single Meal',
                        sublabel: 'Quick suggestion',
                        onTap: () => _handleMealPlanQuickAction('single'),
                        isPrimary: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Secondary action buttons
                Row(
                  children: [
                    Expanded(
                      child: _buildQuickActionButton(
                        icon: Icons.menu_book,
                        label: 'Recipe',
                        sublabel: 'Detailed instructions',
                        onTap: () => _handleMealPlanQuickAction('recipe'),
                        isPrimary: false,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildQuickActionButton(
                        icon: Icons.timer,
                        label: 'Quick Meals',
                        sublabel: 'Under 30 min',
                        onTap: () => _handleMealPlanQuickAction('quick'),
                        isPrimary: false,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Custom option
                OutlinedButton.icon(
                  onPressed: () => _handleMealPlanQuickAction('custom'),
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text('Type my own request'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
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

  // Build individual quick action button
  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required String sublabel,
    required VoidCallback onTap,
    required bool isPrimary,
  }) {
    return Material(
      color: isPrimary
          ? Theme.of(context).colorScheme.primary
          : Theme.of(context).colorScheme.surfaceVariant,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                color: isPrimary
                    ? Colors.white
                    : Theme.of(context).colorScheme.onSurfaceVariant,
                size: 22,
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: isPrimary
                          ? Colors.white
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                sublabel,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: isPrimary
                          ? Colors.white70
                          : Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant
                              .withOpacity(0.7),
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Handle planner mode messages
  Future<void> _handlePlannerModeMessage(String userInput) async {
    if (chatId == null || !canUseAI()) return;

    final currentUserId = userService.userId!;
    final messages = chatController.messages;

    // Add user message to UI
    final userMessage = ChatScreenData(
      messageContent: userInput,
      senderId: currentUserId,
      timestamp: Timestamp.now(),
      imageUrls: [],
      messageId: '',
    );

    setState(() {
      messages.add(userMessage);
    });
    _onNewMessage();
    await _saveMessageToFirestore(userInput, currentUserId);

    // Check if form is submitted and user is confirming
    final formData = chatController.planningFormData.value;
    final isFormSubmitted = chatController.isFormSubmitted.value;

    if (isFormSubmitted && formData != null) {
      // Check if user is confirming or wants to amend
      final userInputLower = userInput.toLowerCase();
      if (userInputLower.contains('yes') ||
          userInputLower.contains('confirm') ||
          userInputLower.contains('proceed') ||
          userInputLower.contains('create') ||
          userInputLower.contains('generate')) {
        // User confirmed - generate plan
        await _generatePlanFromConversation();
        return;
      } else if (userInputLower.contains('amend') ||
          userInputLower.contains('change') ||
          userInputLower.contains('edit')) {
        // User wants to amend - show form again
        chatController.isFormSubmitted.value = false;
        chatController.planningFormData.value = null;
        chatController.showForm.value = true;

        final responseMessage = ChatScreenData(
          messageContent:
              "No problem! Let's update your preferences. Please fill out the form again.",
          senderId: 'buddy',
          timestamp: Timestamp.now(),
          imageUrls: [],
          messageId: '',
        );
        setState(() {
          messages.add(responseMessage);
        });
        _onNewMessage();
        await _saveMessageToFirestore(responseMessage.messageContent, 'buddy');
        return;
      }
    }

    // If form not submitted yet, just acknowledge
    if (!isFormSubmitted) {
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
      setState(() {
        messages.add(responseMessage);
      });
      _onNewMessage();
      await _saveMessageToFirestore(
        responseMessage.messageContent,
        'buddy',
        actionButtons: responseMessage.actionButtons,
      );
    }
  }

  // Handle meal plan mode messages
  Future<void> _handleMealPlanModeMessage(String userInput,
      {int? mealCount}) async {
    if (chatId == null || !canUseAI()) return;

    final currentUserId = userService.userId!;
    final messages = chatController.messages;

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

    debugPrint(
        'Detected meal count: $detectedMealCount (from prompt: "$userInput")');

    // Add user message to UI
    final userMessage = ChatScreenData(
      messageContent: userInput,
      senderId: currentUserId,
      timestamp: Timestamp.now(),
      imageUrls: [],
      messageId: '',
    );

    if (mounted) {
      setState(() {
        messages.add(userMessage);
      });
      _onNewMessage();
    }
    await _saveMessageToFirestore(userInput, currentUserId);

    try {
      // Use meal planning service to generate meal plan with family member context
      final mealPlanningService = MealPlanningService.instance;
      final result = await mealPlanningService.generateMealPlanFromPrompt(
        userInput,
        mealCount: detectedMealCount,
        familyMemberName: _familyMemberName,
        familyMemberKcal: _familyMemberKcal,
        familyMemberGoal: _familyMemberGoal,
        familyMemberType: _familyMemberType,
      );

      if (result['success'] == true) {
        final meals = result['meals'] as List<dynamic>? ?? [];
        final mealIds = result['mealIds'] as List<dynamic>? ?? [];
        final familyMemberName = result['familyMemberName'] as String?;

        if (meals.isNotEmpty) {
          // Format meal list for display
          final mealList = meals.take(10).map((meal) {
            final title = meal['title'] ?? 'Untitled Meal';
            final mealType = meal['mealType'] ?? 'meal';
            return "• $title ($mealType)";
          }).join('\n');

          // Customize response message based on family member
          final responseContent = familyMemberName != null
              ? """Here are some meal suggestions for $familyMemberName:

$mealList

Click "View Meals" to browse and add them to your calendar!"""
              : """Here are some meal suggestions for you:

$mealList

Click "View Meals" to browse and add them to your calendar!""";

          final actionButtonsMap = <String, dynamic>{
            'viewMeals': true,
            if (mealIds.isNotEmpty) 'mealIds': mealIds,
            if (familyMemberName != null) 'familyMemberName': familyMemberName,
          };

          debugPrint('Setting actionButtons: $actionButtonsMap');
          debugPrint('mealIds count: ${mealIds.length}');

          final responseMessage = ChatScreenData(
            messageContent: responseContent,
            senderId: 'buddy',
            timestamp: Timestamp.now(),
            imageUrls: [],
            messageId: '',
            actionButtons: actionButtonsMap,
          );

          if (mounted) {
            setState(() {
              messages.add(responseMessage);
            });
            _onNewMessage();
          }
          await _saveMessageToFirestore(
            responseContent,
            'buddy',
            actionButtons: responseMessage.actionButtons,
          );

          // Save meals to buddy collection for display in buddy tab
          try {
            await _saveMealsToBuddyCollection(
              mealIds.map((id) => id.toString()).toList(),
              familyMemberName: familyMemberName,
            );
          } catch (buddyError) {
            debugPrint('Error saving to buddy collection: $buddyError');
          }
        } else {
          throw Exception('No meals generated');
        }
      } else {
        throw Exception(result['error'] ?? 'Failed to generate meals');
      }
    } catch (e) {
      debugPrint("Error generating meal plan: $e");
      final errorMessage = ChatScreenData(
        messageContent:
            "I'm having trouble generating meals right now. Could you try rephrasing your request? For example, you could say 'I want healthy breakfast ideas' or 'Show me vegetarian dinner recipes'.",
        senderId: 'buddy',
        timestamp: Timestamp.now(),
        imageUrls: [],
        messageId: '',
      );
      if (mounted) {
        setState(() {
          messages.add(errorMessage);
        });
        _onNewMessage();
      }
      await _saveMessageToFirestore(errorMessage.messageContent, 'buddy');
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
      final mealPlanRef = firestore
          .collection('mealPlans')
          .doc(userId)
          .collection('buddy')
          .doc(dateStr);

      // Format meal IDs with meal type suffixes based on the meal data
      final formattedMealIds = <String>[];
      for (final mealId in mealIds) {
        // Try to get meal type from the meal document
        try {
          final mealDoc = await firestore.collection('meals').doc(mealId).get();
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

  void _showSystemMessage() {
    final messages = chatController.messages;
    final currentMode = chatController.currentMode.value;

    // Get appropriate welcome message based on current mode
    String randomMessage;
    switch (currentMode) {
      case 'planner':
        randomMessage = _plannerWelcomeMessages[
            DateTime.now().microsecond % _plannerWelcomeMessages.length];
        break;
      case 'meal':
        randomMessage = _mealPlanWelcomeMessages[
            DateTime.now().microsecond % _mealPlanWelcomeMessages.length];
        break;
      default: // tasty
        randomMessage = _tastyWelcomeMessages[
            DateTime.now().microsecond % _tastyWelcomeMessages.length];
        break;
    }

    // Don't add system message if there's already one at the end
    if (messages.isNotEmpty && messages.last.senderId == 'systemMessage') {
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
    // Note: System messages are NOT saved to Firestore - they're UI-only
  }

  // Remove system messages from UI when user starts interacting
  void _removeSystemMessages() {
    setState(() {
      chatController.messages
          .removeWhere((message) => message.senderId == 'systemMessage');
    });
  }

  // Build mode banner widget
  Widget _buildModeBanner(ThemeProvider themeProvider, TextTheme textTheme) {
    return Obx(() {
      final currentMode = chatController.currentMode.value;
      String title;
      String description;
      IconData icon;
      Color color;

      switch (currentMode) {
        case 'planner':
          title = 'Planner Mode';
          description = 'Create a personalized nutrition program';
          icon = Icons.edit_note;
          color = kAccent;
          break;
        case 'meal':
          title = 'Meal Plan Mode';
          description = 'Plan meals, get recipes, and add to calendar';
          icon = Icons.restaurant_menu;
          color = kAccentLight;
          break;
        default: // tasty
          title = 'Tasty Mode';
          description = 'General conversation about health and nutrition';
          icon = Icons.chat_bubble_outline;
          color = kAccent;
          break;
      }

      return Container(
        width: double.infinity,
        margin: EdgeInsets.symmetric(
          horizontal: getPercentageWidth(2, context),
          vertical: getPercentageHeight(0.5, context),
        ),
        padding: EdgeInsets.all(getPercentageWidth(3, context)),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: color,
              size: getIconScale(5, context),
            ),
            SizedBox(width: getPercentageWidth(2, context)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: textTheme.titleSmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: getPercentageHeight(0.3, context)),
                  Text(
                    description,
                    style: textTheme.bodySmall?.copyWith(
                      color: themeProvider.isDarkMode
                          ? kWhite.withValues(alpha: 0.7)
                          : kDarkGrey.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            if (currentMode == 'planner' &&
                chatController.isFormSubmitted.value)
              IconButton(
                icon: Icon(
                  Icons.edit,
                  color: color,
                  size: getIconScale(5, context),
                ),
                onPressed: () {
                  chatController.isFormSubmitted.value = false;
                  chatController.planningFormData.value = null;
                },
                tooltip: 'Edit Form',
              ),
          ],
        ),
      );
    });
  }

  // Removed - no longer using feature items with new tab design
  // Removed - planner mode is now a tab, no need to exit dialog

  Future<void> _sendFormToAIForConfirmation(
      Map<String, dynamic> formData) async {
    if (!mounted) return;

    debugPrint('Form submitted with data: $formData');

    // Store form data in controller
    chatController.setPlanningFormData(formData);

    // Static confirmation message (no AI until user confirms)
    // Always show the "Based on these preferences..." line
    final additionalDetailsText =
        formData['additionalDetails']?.toString().trim();
    final hasAdditionalDetails =
        additionalDetailsText != null && additionalDetailsText.isNotEmpty;

    final confirmationMessage = """Perfect! I've received your program details:

📅 Duration: ${formData['duration']}
🎯 Goal: ${formData['goal']}
🥗 Diet Type: ${formData['dietType']}
💪 Activity Level: ${formData['activityLevel']}
${hasAdditionalDetails ? '📝 Additional Details: $additionalDetailsText\n' : ''}Based on these preferences, I'll create a personalized nutrition program that focuses on ${formData['goal']} while respecting your ${formData['dietType']} dietary preferences.

If you're happy with these details, click "Submit" below to generate your custom program. If you'd like to make any changes, click "Amend Form".""";

    final confirmationChatMessage = ChatScreenData(
      messageContent: confirmationMessage,
      senderId: 'buddy',
      timestamp: Timestamp.now(),
      imageUrls: [],
      messageId: '',
      actionButtons: {
        'amendForm': 'Amend Form',
        'submitPlan': 'Submit',
      },
    );

    debugPrint('Adding confirmation message to chat');
    debugPrint('Confirmation message content: $confirmationMessage');
    debugPrint('Full message length: ${confirmationMessage.length}');

    // Mark form as submitted
    chatController.isFormSubmitted.value = true;

    // Add message locally first for immediate UI feedback
    chatController.messages.add(confirmationChatMessage);
    final messageCount = chatController.messages.length;
    debugPrint('Message added locally, count: $messageCount');
    debugPrint(
        'Last message content: ${chatController.messages.last.messageContent.substring(0, 50)}...');

    // Force UI update
    if (mounted) {
      setState(() {});
    }
    _onNewMessage();

    // Don't save to Firestore yet - only save when user clicks Submit
    // Message will persist locally until user leaves the screen or clicks Submit
    debugPrint(
        'Confirmation message added locally (not saved to Firestore yet)');
    debugPrint('Final message count: ${chatController.messages.length}');

    // Hide form after submission
    chatController.showForm.value = false;
  }

  Future<void> _generatePlanFromConversation() async {
    if (!mounted || !canUseAI()) return;

    // Save the confirmation message to Firestore now that user has clicked Submit
    final confirmationMessage = chatController.messages.firstWhere(
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
        await _saveMessageToFirestore(
          confirmationMessage.messageContent,
          'buddy',
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
      final formData = chatController.planningFormData.value;
      final conversationText = chatController.planningConversation
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

      // Explicitly include diet type in prompt to override any user settings
      final generationPrompt = """Diet Type: $formDietType

Based on the user's form responses and our conversation, create a structured nutrition program.

$formDataSection${conversationText.isNotEmpty ? 'Refinement Conversation:\n$conversationText\n' : ''}

Please create a JSON object with the following structure:
{
  "name": "Program name (be creative and personalized)",
  "description": "Detailed description of the program",
  "duration": "e.g., '7 days', '30 days', '90 days'",
  "type": "custom",
  "goals": ["goal1", "goal2", "goal3"],
  "requirements": ["requirement1", "requirement2"],
  "benefits": ["benefit1", "benefit2", "benefit3"],
  "recommendations": ["recommendation1", "recommendation2"],
  "programDetails": ["detail1", "detail2"],
  "notAllowed": ["item1", "item2"],
  "routine": [
    {
      "title": "Routine item name (e.g., 'Morning Hydration', 'Meal Planning', 'Exercise')",
      "duration": "e.g., '15 minutes', '30 minutes', '1 hour'",
      "description": "Detailed description of what this routine item involves and how to complete it"
    }
  ],
  "weeklyPlans": [
    {
      "week": 1,
      "goals": ["week goal"],
      "mealPlan": {
        "Monday": ["meal1", "meal2", "meal3"],
        "Tuesday": ["meal1", "meal2", "meal3"],
        "Wednesday": ["meal1", "meal2", "meal3"],
        "Thursday": ["meal1", "meal2", "meal3"],
        "Friday": ["meal1", "meal2", "meal3"],
        "Saturday": ["meal1", "meal2", "meal3"],
        "Sunday": ["meal1", "meal2", "meal3"]
      },
      "nutritionGuidelines": {
        "calories": "guideline",
        "protein": "guideline",
        "carbs": "guideline"
      },
      "tips": ["tip1", "tip2"]
    }
  ],
  "portionDetails": {}
}

IMPORTANT: 
- Include at least 3-5 routine items that are relevant to the program (e.g., meal planning, hydration, exercise, meal prep, etc.)
- All fields are required - do not omit any fields
- Ensure benefits, requirements, recommendations, programDetails, and notAllowed arrays have at least 2-3 items each
- The routine array should contain actionable daily/weekly tasks for the user

Return ONLY valid JSON, no additional text.""";

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

      if (!mounted) return;

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

      // Create meals from meal plan with minimal data
      final updatedProgramData = await _createMealsFromPlan(
          programData, programData['description'] ?? '');

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

      // Create private program
      final programService = Get.find<ProgramService>();
      Program program;
      try {
        program = await programService.createPrivateProgram(
          updatedProgramData,
          planningConversationId: chatId,
        );
        debugPrint('Program created successfully: ${program.programId}');
      } catch (e, stackTrace) {
        debugPrint('ERROR creating program: $e');
        debugPrint('Stack trace: $stackTrace');
        debugPrint('Program data that failed: $updatedProgramData');
        rethrow;
      }

      if (!mounted) return;

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

      setState(() {
        chatController.messages.add(successMessage);
      });
      chatController.addPlanningMessage(successMessage);
      _onNewMessage();
      await _saveMessageToFirestore(
        successMessage.messageContent,
        'buddy',
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
      chatController.exitPlanningMode();
    } catch (e) {
      debugPrint('Error generating plan: $e');
      if (!mounted) return;

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
    final batch = firestore.batch();
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
            final mealRef = firestore.collection('meals').doc();
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
              'userId': tastyId,
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

  /// Sanitize data for Firestore by removing null values and ensuring serializable types
  dynamic _sanitizeForFirestore(dynamic data) {
    if (data == null) {
      return null;
    } else if (data is String ||
        data is int ||
        data is double ||
        data is bool) {
      return data;
    } else if (data is List) {
      final sanitized = <dynamic>[];
      for (final item in data) {
        final sanitizedItem = _sanitizeForFirestore(item);
        if (sanitizedItem != null) {
          sanitized.add(sanitizedItem);
        }
      }
      return sanitized;
    } else if (data is Map) {
      final sanitized = <String, dynamic>{};
      for (final entry in data.entries) {
        final sanitizedValue = _sanitizeForFirestore(entry.value);
        // Only include non-null values
        if (sanitizedValue != null) {
          sanitized[entry.key.toString()] = sanitizedValue;
        }
      }
      return sanitized;
    } else {
      // Convert any other type to string
      return data.toString();
    }
  }

  /// Save program meal plans to buddy collection for display in buddy tab
  Future<void> _saveProgramMealPlansToBuddy(Program program) async {
    final userId = userService.userId ?? '';
    if (userId.isEmpty) return;

    // Get diet preference from form data instead of user settings
    final formData = chatController.planningFormData.value;
    final diet = formData?['dietType']?.toString() ?? 'general';

    debugPrint('=== _saveProgramMealPlansToBuddy: Starting ===');
    debugPrint('Form data: $formData');
    debugPrint('Using diet: $diet');
    debugPrint('Number of weekly plans: ${program.weeklyPlans.length}');

    // Process each week's meal plan
    try {
      for (var weeklyPlan in program.weeklyPlans) {
        debugPrint('Processing week ${weeklyPlan.week}');
        final mealPlan = weeklyPlan.mealPlan;
        debugPrint('Meal plan structure: ${mealPlan.keys.toList()}');
        debugPrint('Meal plan entries count: ${mealPlan.length}');

        // Convert day-based meal plan to date-based
        // Use current date + week offset
        final baseDate =
            DateTime.now().add(Duration(days: (weeklyPlan.week - 1) * 7));

        // Process each day
        for (var entry in mealPlan.entries) {
          final dayName = entry.key; // e.g., "Monday", "Tuesday"
          final mealIds = List<String>.from(entry.value);

          debugPrint('Day: $dayName, Meal IDs count: ${mealIds.length}');
          debugPrint('Meal IDs: $mealIds');

          // Validate mealIds
          if (mealIds.isEmpty) {
            debugPrint(
                'Warning: No meal IDs for $dayName in week ${weeklyPlan.week}');
            continue;
          }

          // Convert day name to date
          final dayOffset = _getDayOffset(dayName);
          final planDate = baseDate.add(Duration(days: dayOffset));
          final dateStr = DateFormat('yyyy-MM-dd').format(planDate);

          debugPrint('Date string: $dateStr');

          // Format mealIds with meal type suffixes using the same method as meal plan chat
          // Try to get meal type from meal document, otherwise use default order
          final defaultMealTypes = ['breakfast', 'lunch', 'dinner', 'snack'];
          final formattedMealIds = <String>[];
          for (int i = 0; i < mealIds.length; i++) {
            final mealId = mealIds[i];
            if (mealId.isEmpty) {
              debugPrint('Warning: Empty meal ID at index $i for $dayName');
              continue;
            }

            // Try to get meal type from the meal document
            String mealType = 'general';
            try {
              final mealDoc =
                  await firestore.collection('meals').doc(mealId).get();
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
            formattedMealIds.add('$mealId/$suffix');
          }

          debugPrint('Formatted meal IDs: $formattedMealIds');

          // Save to buddy collection
          final mealPlanRef = firestore
              .collection('mealPlans')
              .doc(userId)
              .collection('buddy')
              .doc(dateStr);

          // Get existing document to preserve generations
          final existingDoc = await mealPlanRef.get();
          List<Map<String, dynamic>> existingGenerations = [];

          if (existingDoc.exists) {
            final existingData = existingDoc.data();
            final generations = existingData?['generations'] as List<dynamic>?;
            if (generations != null) {
              existingGenerations = generations
                  .map((gen) => gen as Map<String, dynamic>)
                  .toList();
            }
          }

          debugPrint(
              'Existing generations count: ${existingGenerations.length}');

          // Create new generation - programs are main user only
          // Use Timestamp.now() for consistency with meal plan chat
          final newGeneration = <String, dynamic>{
            'mealIds': formattedMealIds,
            'timestamp': Timestamp.now(),
            'diet': diet,
            'source': 'program',
            'familyMemberName':
                null, // Programs are main user only - explicitly set to null for filtering
          };

          // Only add tips if not empty
          if (weeklyPlan.tips.isNotEmpty) {
            final tipsText = weeklyPlan.tips.join('\n');
            if (tipsText.trim().isNotEmpty) {
              newGeneration['tips'] = tipsText;
            }
          }

          debugPrint(
              'New generation structure: ${newGeneration.keys.toList()}');
          debugPrint(
              'New generation mealIds count: ${formattedMealIds.length}');

          existingGenerations.add(newGeneration);

          debugPrint(
              'Total generations after adding: ${existingGenerations.length}');

          // Sanitize existingGenerations before saving
          final sanitizedGenerations =
              _sanitizeForFirestore(existingGenerations) as List<dynamic>?;

          if (sanitizedGenerations == null) {
            debugPrint('Error: Sanitized generations is null');
            continue;
          }

          debugPrint(
              'Sanitized generations count: ${sanitizedGenerations.length}');

          // Prepare data to save
          final dataToSave = <String, dynamic>{
            'date': dateStr,
            'generations': sanitizedGenerations,
          };

          debugPrint('Data to save keys: ${dataToSave.keys.toList()}');
          debugPrint('Attempting to save to Firestore...');

          // Save to Firestore with error handling
          try {
            await mealPlanRef.set(dataToSave, SetOptions(merge: true));
            debugPrint('Successfully saved to Firestore for date: $dateStr');
          } catch (e, stackTrace) {
            debugPrint('ERROR saving to Firestore for date $dateStr: $e');
            debugPrint('Stack trace: $stackTrace');
            debugPrint('Data that failed to save: $dataToSave');
            // Continue processing other days even if one fails
          }
        }
      }
      debugPrint('=== _saveProgramMealPlansToBuddy: Completed ===');
    } catch (e, stackTrace) {
      debugPrint('CRITICAL ERROR in _saveProgramMealPlansToBuddy: $e');
      debugPrint('Stack trace: $stackTrace');
      // Don't rethrow - allow program creation to complete even if meal plan save fails
    }
  }

  /// Convert day name to day offset (0 = Monday, 6 = Sunday)
  int _getDayOffset(String dayName) {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    final index = days.indexOf(dayName);
    return index >= 0 ? index : 0;
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
