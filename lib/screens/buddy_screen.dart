import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:tasteturner/widgets/chat_input_bar.dart';
import 'package:tasteturner/widgets/chat_mode_switcher.dart';
import '../constants.dart';
import '../helper/helper_functions.dart';
import '../helper/utils.dart';
import '../pages/photo_manager.dart';
import '../service/chat_controller.dart';
import '../themes/theme_provider.dart';
import 'chat_screen.dart';
import '../widgets/icon_widget.dart';
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

  // State for meal plan quick action buttons (shown when entering from buddy tab)
  bool _showMealPlanQuickActions = false;

  // Pending mode switches (deferred to post-frame callback to avoid chatId initialization issues)
  bool _pendingMealPlanMode = false;
  bool _pendingPlanningMode = false;
  bool _fromProgramScreen = false; // Track if coming from program screen

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
        chatController.familyMemberName.value =
            args['familyMemberName'] as String?;
        chatController.familyMemberKcal.value =
            args['familyMemberKcal'] as String?;
        chatController.familyMemberGoal.value =
            args['familyMemberGoal'] as String?;
        chatController.familyMemberType.value =
            args['familyMemberType'] as String?;
        
        // Store pantry ingredients if provided
        if (args['pantryIngredients'] != null) {
          final pantryList = args['pantryIngredients'] as List<dynamic>?;
          if (pantryList != null) {
            chatController.pantryIngredients.value = 
                pantryList.map((e) => e.toString()).toList();
          }
        }
        
        _pendingMealPlanMode = true;
      } else if (args['planningMode'] == true) {
        _pendingPlanningMode = true;
        _fromProgramScreen = true; // Mark that we're coming from program screen
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
          // Switch mode first to load correct messages, then enter planning mode
          chatController.switchMode('planner').then((_) {
            chatController.enterPlanningMode();
          });
        } else {
          chatController.currentMode.value = 'planner';
        }
        _tabController.index = 1;

        // If coming from program screen, open the form automatically
        if (_fromProgramScreen) {
          chatController.showForm.value = true;
          chatController.isFormSubmitted.value = false;
          chatController.planningFormData.value = null;
        }
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

        // If manually switching to planner mode (not from program screen), open form immediately
        if (newMode == 'planner' && !_fromProgramScreen) {
          chatController.showForm.value = true;
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
        final isTastyWelcome = chatController.tastyWelcomeMessages.any(
            (welcome) => msg.messageContent.contains(welcome.substring(0, 20)));
        final isPlannerWelcome = chatController.plannerWelcomeMessages.any(
            (welcome) => msg.messageContent.contains(welcome.substring(0, 20)));
        final isMealPlanWelcome = chatController.mealPlanWelcomeMessages.any(
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
      chatController.initializePlannerMode(_fromProgramScreen);
    } else if (currentMode == 'meal') {
      chatController.initializeMealPlanMode();
    } else {
      chatController.initializeTastyMode(context);
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
      {List<String>? imageUrls,
      Map<String, dynamic>? actionButtons,
      String? messageId}) async {
    if (chatId == null || chatId!.isEmpty) return;

    final currentMode = chatController.currentMode.value;
    await chatController.saveMessageToMode(
      mode: currentMode,
      content: content,
      senderId: senderId,
      imageUrls: imageUrls,
      actionButtons: actionButtons,
      messageId: messageId,
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
                                : kAccentLight.withValues(alpha: 0.2),
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
                      // Mode Switcher
                      Expanded(
                        child: ChatModeSwitcher(
                          controller: _tabController,
                          tabs: [
                            ChatModeTab(
                              icon: Icons.chat_bubble_outline,
                              label: 'Tasty',
                            ),
                            ChatModeTab(
                              icon: Icons.edit_note,
                              label: 'Planner',
                            ),
                            ChatModeTab(
                              icon: Icons.restaurant_menu,
                              label: 'Meal Plan',
                            ),
                          ],
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
                  final isPlannerMode = currentMode == 'planner';

                  // Scroll to form when it appears
                  if (isPlannerMode && showForm) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (_scrollController.hasClients) {
                        _scrollController.animateTo(
                          0,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut,
                        );
                      }
                    });
                  }

                  return AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    child: (isPlannerMode && showForm)
                        ? Flexible(
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxHeight:
                                    MediaQuery.of(context).size.height * 0.5,
                              ),
                              child: SingleChildScrollView(
                                child: PlanningForm(
                                  onSubmit: (formData) {
                                    _sendFormToAIForConfirmation(formData);
                                  },
                                  onClose: () {
                                    chatController.showForm.value = false;
                                  },
                                  isDarkMode: themeProvider.isDarkMode,
                                  initialData:
                                      chatController.planningFormData.value,
                                ),
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                  );
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
                      return _buildEmptyState(
                          currentMode, themeProvider.isDarkMode);
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
                          child: GestureDetector(
                            onTap: () {
                              // Close form when tapping on chat area (only in planner mode)
                              if (chatController.currentMode.value ==
                                      'planner' &&
                                  chatController.showForm.value) {
                                chatController.showForm.value = false;
                              }
                            },
                            behavior: HitTestBehavior.translucent,
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
                                    chatController
                                        .generatePlanFromConversation(context);
                                  },
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    );
                  }),
                ),
                // Input Section
                Obx(() {
                  final isPlanning = chatController.isPlanningMode.value;
                  final isReady = chatController.isReadyToGenerate.value;

                  return ChatInputBar(
                    controller: textController,
                    isListening: _isListening,
                    canUseAI: canUseAI(),
                    onSend: () async {
                      final messageText = textController.text.trim();
                      if (messageText.isNotEmpty) {
                        await chatController.sendMessageToAI(
                            messageText, context);
                        textController.clear();
                      }
                    },
                    onImagePick: () {
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
                    onVoiceToggle:
                        _isListening ? _stopListening : _startListening,
                    isPlanning: isPlanning,
                    isReadyToGenerate: isReady,
                    onGeneratePlan: () =>
                        chatController.generatePlanFromConversation(context),
                  );
                }),
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

    chatController.handleMealPlanQuickAction(action);
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
                        chatController.familyMemberName.value != null
                            ? '🎯 Planning for ${chatController.familyMemberName.value}'
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

  Widget _buildEmptyState(String mode, bool isDarkMode) {
    IconData icon;
    String title;
    String subtitle;
    List<String> quickStarters;

    switch (mode) {
      case 'planner':
        icon = Icons.edit_note;
        title = 'Design Your Program';
        subtitle =
            'Create a personalized nutrition plan tailored to your goals.';
        quickStarters = [
          'Create a 7-day plan',
          'I want to lose weight',
          'Build muscle plan',
        ];
        break;
      case 'meal':
        icon = Icons.restaurant_menu;
        title = 'Plan Your Meals';
        subtitle = 'Get delicious recipes and organize your weekly eating.';
        quickStarters = [
          'Plan my week',
          'Healthy dinner ideas',
          'Quick breakfast',
        ];
        break;
      default: // tasty
        icon = Icons.chat_bubble_outline;
        title = 'Chat with Tasty';
        subtitle = 'Ask me anything about nutrition, health, or food!';
        quickStarters = [
          'Analyze my food',
          'Healthy snack ideas',
          'Nutrition tips',
        ];
        break;
    }

    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: getPercentageWidth(8, context),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: kAccent.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 48,
                  color: kAccent,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : kBlack,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: isDarkMode
                          ? Colors.white.withOpacity(0.7)
                          : kDarkGrey.withOpacity(0.7),
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: quickStarters.map((starter) {
                  return ActionChip(
                    label: Text(starter),
                    onPressed: () {
                      textController.text = starter;
                      chatController.sendMessageToAI(starter, context);
                      textController.clear();
                    },
                    backgroundColor: isDarkMode
                        ? kLightGrey.withOpacity(0.1)
                        : kLightGrey.withOpacity(0.3),
                    labelStyle: TextStyle(
                      color: isDarkMode ? Colors.white : kBlack,
                      fontSize: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: isDarkMode
                            ? Colors.white.withOpacity(0.1)
                            : kBlack.withOpacity(0.05),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
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
