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
import '../service/buddy_chat_controller.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../themes/theme_provider.dart';
import '../widgets/chat_item.dart';
import '../widgets/icon_widget.dart';
import '../screens/premium_screen.dart';
import '../data_models/meal_model.dart';
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
  final FocusNode _textFieldFocusNode = FocusNode();
  String? chatId;

  late BuddyChatController chatController;
  late TabController _tabController;

  // Speech-to-text
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  String _recognizedText = '';

  // Quick actions visibility state (use RxBool for reactive updates)
  final RxBool _showQuickActions = true.obs;

  // Input enabled state (disabled in meal plan mode until user clicks "Type my own request")
  final RxBool _isInputEnabled = true.obs;

  // Pending mode switches (deferred to post-frame callback to avoid chatId initialization issues)
  bool _pendingMealPlanMode = false;
  bool _pendingSousChefMode = false;

  @override
  void initState() {
    super.initState();
    try {
      chatController = Get.find<BuddyChatController>();
    } catch (e) {
      // If controller is not found, initialize it
      chatController = Get.put(BuddyChatController());
    }
    chatId = userService.buddyId;

    // Initialize TabController for 2 modes (Sous Chef and Meal Plan)
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabChange);

    // Check if meal plan mode should be enabled from navigation
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
      } else if (args['mealPlanMode'] == false) {
        // Explicitly set to sous chef mode when mealPlanMode is false
        _pendingSousChefMode = true;
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
        _tabController.index = 1; // Meal Plan is now index 1 (was index 2)
        // Only switch mode if chatId is initialized
        if (chatId != null && chatId!.isNotEmpty) {
          chatController.switchMode('meal');
        } else {
          chatController.currentMode.value = 'meal';
        }
        // Disable input in meal plan mode
        _isInputEnabled.value = false;
      } else if (_pendingSousChefMode) {
        _pendingSousChefMode = false;
        _tabController.index = 0; // Sous Chef is index 0
        // Only switch mode if chatId is initialized
        if (chatId != null && chatId!.isNotEmpty) {
          chatController.switchMode('sous chef');
        } else {
          chatController.currentMode.value = 'sous chef';
        }
        // Enable input in sous chef mode
        _isInputEnabled.value = true;
      }

      // Initialize mode-specific content
      _initializeModeContent();
    });
  }

  void _handleTabChange() {
    if (!_tabController.indexIsChanging) {
      final modes = ['sous chef', 'meal'];
      final newMode = modes[_tabController.index];
      if (chatController.currentMode.value != newMode) {
        // Only switch mode if chatId is initialized
        // Mode switching now only controls where new messages are routed,
        // not which messages are displayed
        if (chatId != null && chatId!.isNotEmpty) {
          chatController.switchMode(newMode);
        } else {
          // Update mode without switching (which requires chatId)
          chatController.currentMode.value = newMode;
        }

        // Show quick actions when switching to meal mode
        if (newMode == 'meal') {
          _showQuickActions.value = true;
          _isInputEnabled.value = false; // Disable input in meal plan mode
        } else {
          // Enable input when switching to sous chef mode
          _isInputEnabled.value = true;
        }

        _initializeModeContent();
      }
    }
  }

  void _initializeModeContent() {
    final currentMode = chatController.currentMode.value;
    if (currentMode == 'meal') {
      chatController.initializeMealPlanMode();
    } else {
      chatController.initializeTastyMode(context);
    }
  }

  /// Handle errors with consistent snackbar display
  void _handleError(String message, {String? details}) {
    if (!mounted || !context.mounted) return;
    debugPrint('Error: $message${details != null ? ' - $details' : ''}');
    showTastySnackbar(
      'Error',
      message,
      context,
      backgroundColor: Colors.red,
    );
  }

  /// Summarize chat when screen is closed and update chat summary in Firestore
  Future<void> _saveChatSummary() async {
    if (chatId == null ||
        !canUseAI() ||
        chatController.messages.isEmpty ||
        chatController.messages.last.senderId == 'buddy') return;

    try {
      final messages = chatController.messages;
      // Use the last message content as summary instead of calling AI
      // This prevents unnecessary AI calls when leaving the screen
      final summary = messages.last.messageContent;

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
      // Don't show error to user as this happens in background
    }
  }

  // Speech-to-text methods
  Future<void> _startListening() async {
    // Check microphone permission status
    final status = await Permission.microphone.status;

    if (status.isDenied) {
      // Request permission
      final requestResult = await Permission.microphone.request();
      if (!requestResult.isGranted) {
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
    } else if (status.isPermanentlyDenied || status.isRestricted) {
      // Permission permanently denied or restricted - open settings
      if (mounted) {
        final shouldOpenSettings = await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            final isDarkMode = getThemeProvider(context).isDarkMode;
            final textTheme = Theme.of(context).textTheme;
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              backgroundColor: isDarkMode ? kDarkGrey : kWhite,
              title: Text(
                'Microphone Permission Required',
                style: textTheme.titleMedium?.copyWith(
                  color: isDarkMode ? kWhite : kBlack,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Text(
                'Microphone access was denied. To use voice notes, please enable microphone permission in Settings → TasteTurner → Microphone.',
                style: textTheme.bodyMedium?.copyWith(
                  color: isDarkMode ? kWhite.withOpacity(0.9) : kDarkGrey,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(
                    'Cancel',
                    style: textTheme.bodyMedium?.copyWith(
                      color: isDarkMode ? kWhite.withOpacity(0.7) : kLightGrey,
                    ),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(
                    'Open Settings',
                    style: textTheme.bodyMedium?.copyWith(
                      color: kWhite,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            );
          },
        );

        if (shouldOpenSettings == true) {
          await openAppSettings();
        }
      }
      return;
    } else if (!status.isGranted) {
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
    _textFieldFocusNode.dispose();
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
                  'Upgrade to premium to chat with your digital Sous Chef Turner 👋 and get personalized nutrition advice!',
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
    final isDarkMode = themeProvider.isDarkMode;
    final textTheme = Theme.of(context).textTheme;
    if (canUseAI()) {
      if (chatId == null) {
        // Chat is still initializing
        return const Scaffold(
          body: Center(child: CircularProgressIndicator(color: kAccent)),
        );
      }
      return Scaffold(
        body: Container(
          decoration: BoxDecoration(
            image: DecorationImage(
              image: AssetImage(
                isDarkMode
                    ? 'assets/images/background/imagedark.jpeg'
                    : 'assets/images/background/imagelight.jpeg',
              ),
              fit: BoxFit.cover,
              colorFilter: ColorFilter.mode(
                isDarkMode
                    ? Colors.black.withOpacity(0.5)
                    : Colors.white.withOpacity(0.5),
                isDarkMode ? BlendMode.darken : BlendMode.lighten,
              ),
            ),
          ),
          child: SafeArea(
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
                            isDarkMode: themeProvider.isDarkMode,
                            tabs: [
                              ChatModeTab(
                                icon: Icons.chat_bubble_outline,
                                label: 'Sous Chef',
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

                  Expanded(
                    child: Obx(() {
                      final messages = chatController.messages;
                      final currentMode = chatController.currentMode.value;
                      final showQuickActions = _showQuickActions.value;

                      if (messages.isEmpty) {
                        // Show quick actions for meal plan mode when no messages and visible
                        if (currentMode == 'meal' && showQuickActions) {
                          return SingleChildScrollView(
                            child: Column(
                              children: [
                                _buildMealPlanQuickActions(
                                    themeProvider.isDarkMode, context),
                              ],
                            ),
                          );
                        }
                        return _buildEmptyState(
                            currentMode, themeProvider.isDarkMode);
                      }

                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (_scrollController.hasClients) {
                          _scrollController.jumpTo(
                              _scrollController.position.maxScrollExtent);
                        }
                      });

                      return Column(
                        children: [
                          // Show meal plan quick actions at the top when in meal mode and visible
                          if (currentMode == 'meal' && showQuickActions)
                            Flexible(
                              child: _buildMealPlanQuickActions(
                                  themeProvider.isDarkMode, context),
                            ),

                          // Chat messages list
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                // Dismiss keyboard when tapping chat area
                                FocusScope.of(context).unfocus();
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
                                    isMe:
                                        message.senderId == userService.userId,
                                    chatController: chatController,
                                    chatId: chatId!,
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                      );
                    }),
                  ),
                  // Input Section - Only show if enabled or not in meal plan mode
                  Obx(() {
                    final currentMode = chatController.currentMode.value;
                    final isInputEnabled = _isInputEnabled.value;
                    // Hide input in meal plan mode unless user clicked "Type my own request"
                    if (currentMode == 'meal' && !isInputEnabled) {
                      return const SizedBox.shrink();
                    }
                    return ChatInputBar(
                      controller: textController,
                      focusNode: _textFieldFocusNode,
                      isListening: _isListening,
                      canUseAI: canUseAI(),
                      enabled: isInputEnabled,
                      onSend: () async {
                        final messageText = textController.text.trim();
                        if (messageText.isNotEmpty) {
                          chatController.sendMessageToAI(messageText, context);
                          textController.clear();
                        }
                      },
                      onImagePick: () async {
                        try {
                          final ImagePicker picker = ImagePicker();
                          // Pick at full quality, we'll compress properly in handleImageSend
                          List<XFile> pickedImages = await picker.pickMultiImage(
                            imageQuality: 100, // Full quality to avoid color shifts
                          );

                          if (pickedImages.isNotEmpty) {
                            // Convert XFile to File and call handleImageSend
                            List<File> imageFiles = pickedImages
                                .map((xfile) => File(xfile.path))
                                .toList();
                            await handleImageSend(
                              imageFiles,
                              null, // No caption for buddy chat images
                              chatId!,
                              _scrollController,
                              chatController,
                            );
                          }
                        } catch (e) {
                          debugPrint('Error picking images: $e');
                          if (mounted) {
                            showTastySnackbar(
                              'Error',
                              'Failed to pick images. Please try again.',
                              context,
                              backgroundColor: kRed,
                            );
                          }
                        }
                      },
                      onVoiceToggle:
                          _isListening ? _stopListening : _startListening,
                    );
                  }),
                  SizedBox(height: getPercentageHeight(3, context)),
                ],
              ),
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

  Future<void> _initializeChatWithBuddy() async {
    if (!canUseAI() || !mounted) return;

    try {
      // Check navigation arguments to determine initial mode
      final args = Get.arguments;
      final shouldBeMealMode =
          args != null && args is Map && args['mealPlanMode'] == true;
      final shouldBeSousChefMode =
          args != null && args is Map && args['mealPlanMode'] == false;

      if (chatId != null && chatId!.isNotEmpty) {
        // Existing chat - set chatId and initialize mode
        chatController.chatId = chatId!;
        await chatController.initializeChat('buddy');

        if (!mounted) return;

        // Override loaded mode if navigation arguments specify a mode
        if (shouldBeSousChefMode) {
          chatController.currentMode.value = 'sous chef';
          if (chatId != null && chatId!.isNotEmpty) {
            await chatController.switchMode('sous chef');
          }
        } else if (shouldBeMealMode) {
          chatController.currentMode.value = 'meal';
          if (chatId != null && chatId!.isNotEmpty) {
            await chatController.switchMode('meal');
          }
        }

        // Sync tab controller with current mode
        final modes = ['sous chef', 'meal'];
        final modeIndex = modes.indexOf(chatController.currentMode.value);
        if (modeIndex >= 0 && modeIndex < 2) {
          _tabController.index = modeIndex;
        }

      } else {
        // New chat - create it and listen
        await chatController.initializeChat('buddy');

        if (!mounted) return;

        // Override default mode if navigation arguments specify a mode
        if (shouldBeSousChefMode) {
          chatController.currentMode.value = 'sous chef';
        } else if (shouldBeMealMode) {
          chatController.currentMode.value = 'meal';
        }

        setState(() {
          chatId = chatController.chatId;
        });
        if (chatId != null && chatId!.isNotEmpty) {
          try {
            userService.setBuddyChatId(chatId!);
            // Update mode in Firestore if we have a chatId
            if (shouldBeSousChefMode) {
              await chatController.switchMode('sous chef');
            } else if (shouldBeMealMode) {
              await chatController.switchMode('meal');
            }
          } catch (e) {
            debugPrint('Error setting buddy chat ID: $e');
            _handleError('Failed to initialize chat. Please try again.',
                details: e.toString());
          }
        }
      }
    } catch (e) {
      debugPrint('Error initializing chat with buddy: $e');
      if (mounted) {
        _handleError('Failed to initialize chat. Please try again.',
            details: e.toString());
      }
    }
  }


  // Show favorite meals dialog for remix selection
  Future<void> _showFavoriteMealsDialog(BuildContext context) async {
    if (!mounted) return;

    final isDarkMode = getThemeProvider(context).isDarkMode;
    final textTheme = Theme.of(context).textTheme;

    try {
      // Fetch favorite meals
      final favoriteMeals = await mealManager.fetchFavoriteMeals();

      if (favoriteMeals.isEmpty) {
        // No favorite meals - show message
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (dialogContext) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            backgroundColor: isDarkMode ? kDarkGrey : kWhite,
            title: Text(
              'No Favorite Meals',
              style: textTheme.titleMedium?.copyWith(
                color: isDarkMode ? kWhite : kBlack,
              ),
            ),
            content: Text(
              'Chef, you don\'t have any favorite meals yet. Please favorite some meals first, then I can help you remix them!',
              style: textTheme.bodyMedium?.copyWith(
                color: isDarkMode ? kLightGrey : kDarkGrey,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(
                  'OK',
                  style: textTheme.bodyMedium?.copyWith(
                    color: isDarkMode ? kWhite : kAccent,
                  ),
                ),
              ),
            ],
          ),
        );
        return;
      }

      // Show dialog with favorite meals list
      if (!mounted) return;
      final selectedMeal = await showDialog<Meal>(
        context: context,
        barrierDismissible: true,
        builder: (dialogContext) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          backgroundColor: isDarkMode ? kDarkGrey : kWhite,
          title: Text(
            'Select Meal to Remix',
            style: textTheme.titleMedium?.copyWith(
              color: isDarkMode ? kWhite : kBlack,
            ),
          ),
          content: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.6,
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: favoriteMeals.length,
              itemBuilder: (context, index) {
                final meal = favoriteMeals[index];
                return ListTile(
                  title: Text(
                    capitalizeFirstLetter(meal.title),
                    style: TextStyle(
                      fontSize: getTextScale(3, context),
                      color: isDarkMode ? kWhite : kBlack,
                    ),
                  ),
                  subtitle: meal.calories > 0
                      ? Text(
                          '${meal.calories} kcal',
                          style: TextStyle(
                            fontSize: getTextScale(2.5, context),
                            color: isDarkMode ? kLightGrey : kDarkGrey,
                          ),
                        )
                      : null,
                  trailing: Icon(
                    Icons.auto_fix_high,
                    color: kAccent,
                  ),
                  onTap: () {
                    Navigator.pop(dialogContext, meal);
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                'Cancel',
                style: textTheme.bodyMedium?.copyWith(
                  color: isDarkMode ? kLightGrey : kDarkGrey,
                ),
              ),
            ),
          ],
        ),
      );

      // If meal was selected, process remix
      if (selectedMeal != null && mounted) {
        await chatController.processRemixForMeal(selectedMeal, context);
      }
    } catch (e) {
      debugPrint('Error showing favorite meals dialog: $e');
      if (mounted) {
        showTastySnackbar(
          'Error',
          'Failed to load favorite meals. Please try again.',
          context,
        );
      }
    }
  }

  // Handle meal plan quick action selection
  void _handleMealPlanQuickAction(String action, bool isDarkMode) {
    if (!mounted) return;

    // If custom action, enable input and focus the text input field (no confirmation needed)
    if (action == 'custom') {
      // Hide quick actions first (reactive update)
      _showQuickActions.value = false;
      
      // Enable input (reactive update)
      _isInputEnabled.value = true;
      
      // Wait for the widget tree to rebuild before focusing
      // Use addPostFrameCallback to ensure UI is fully updated
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Add a delay to ensure the input bar is fully rendered and visible
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted && _textFieldFocusNode.canRequestFocus) {
            // Unfocus any existing focus first, then focus the text field
            FocusScope.of(context).unfocus();
            Future.delayed(const Duration(milliseconds: 100), () {
              if (mounted && _textFieldFocusNode.canRequestFocus) {
                _textFieldFocusNode.requestFocus();
              }
            });
          }
        });
      });
      return;
    }

    // Dismiss keyboard first for other actions
    FocusScope.of(context).unfocus();

    // For remix, show favorite meals dialog directly (no confirmation)
    if (action == 'remix') {
      _showQuickActions.value = false;
      _showFavoriteMealsDialog(context);
      return;
    }

    // Show confirmation dialog for other actions
    _showMealPlanActionConfirmation(action, isDarkMode);
  }

  // Show confirmation dialog before executing meal plan action
  void _showMealPlanActionConfirmation(String action, bool isDarkMode) {
    if (!mounted) return;

    final textTheme = Theme.of(context).textTheme;

    // Get action details
    String title;
    String message;
    switch (action) {
      case '7days':
        title = 'Create 7-Day Meal Plan';
        message =
            'This will generate a complete 7-day meal plan with breakfast, lunch, and dinner. Continue?';
        break;
      case 'single':
        title = 'Get Single Meal Suggestion';
        message = 'This will suggest a single healthy meal for you. Continue?';
        break;
      case 'quick':
        title = 'Get Quick Meal Ideas';
        message =
            'This will suggest 3 quick and easy meal ideas you can make in under 30 minutes. Continue?';
        break;
      default:
        title = 'Confirm Action';
        message = 'Do you want to continue?';
    }

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: isDarkMode ? kDarkGrey : kWhite,
          title: Text(
            title,
            style: textTheme.titleLarge?.copyWith(
              color: isDarkMode ? kWhite : kBlack,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            message,
            style: textTheme.bodyMedium?.copyWith(
              color: isDarkMode ? kLightGrey : kDarkGrey,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                // Ensure keyboard stays dismissed
                FocusScope.of(context).unfocus();
              },
              child: Text(
                'Cancel',
                style: textTheme.bodyMedium?.copyWith(
                  color: isDarkMode ? kLightGrey : kDarkGrey,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                // Ensure keyboard stays dismissed before executing action
                FocusScope.of(context).unfocus();
                // Hide quick actions after action is executed
                _showQuickActions.value = false;
                // Execute action
                chatController.handleMealPlanQuickAction(action);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: kAccent,
                foregroundColor: kWhite,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );
  }

  // Build meal plan quick actions widget
  Widget _buildMealPlanQuickActions(bool isDarkMode, BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      constraints: BoxConstraints(maxHeight: getPercentageHeight(50, context)),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
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
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      // Icon(
                      //   Icons.restaurant_menu,
                      //   color: Theme.of(context).colorScheme.primary,
                      //   size: 24,
                      // ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          chatController.familyMemberName.value != null
                              ? '🎯 Planning for ${chatController.familyMemberName.value}'
                              : '🍽️ Chef, What would you like to plan?',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.close,
                          color: isDarkMode
                              ? kWhite.withOpacity(0.7)
                              : kBlack.withOpacity(0.7),
                          size: 20,
                        ),
                        onPressed: () {
                          _showQuickActions.value = false;
                        },
                        tooltip: 'Close',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  SizedBox(height: getPercentageHeight(1, context)),
                  Text(
                    'Choose a quick option below or type your own request:',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: isDarkMode
                              ? kWhite.withValues(alpha: 0.7)
                              : kBlack.withValues(alpha: 0.7),
                        ),
                  ),
                  SizedBox(height: getPercentageHeight(1, context)),

                  // Main action buttons - 7 days and single meal
                  Row(
                    children: [
                      Expanded(
                        child: _buildQuickActionButton(
                          isDarkMode: isDarkMode,
                          icon: Icons.calendar_view_week,
                          label: '7-Day Plan',
                          sublabel: 'Full week meals',
                          onTap: () =>
                              _handleMealPlanQuickAction('7days', isDarkMode),
                          isPrimary: true,
                        ),
                      ),
                      SizedBox(width: getPercentageWidth(2, context)),
                      Expanded(
                        child: _buildQuickActionButton(
                          isDarkMode: isDarkMode,
                          icon: Icons.restaurant,
                          label: 'Single Meal',
                          sublabel: 'Quick suggestion',
                          onTap: () =>
                              _handleMealPlanQuickAction('single', isDarkMode),
                          isPrimary: true,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: getPercentageHeight(1, context)),

                  // Secondary action buttons
                  Row(
                    children: [
                      Expanded(
                        child: _buildQuickActionButton(
                          isDarkMode: isDarkMode,
                          icon: Icons.auto_fix_high,
                          label: 'Remix',
                          sublabel: 'Remix favorite meal',
                          onTap: () =>
                              _handleMealPlanQuickAction('remix', isDarkMode),
                          isPrimary: false,
                        ),
                      ),
                      SizedBox(width: getPercentageWidth(2, context)),
                      Expanded(
                        child: _buildQuickActionButton(
                          isDarkMode: isDarkMode,
                          icon: Icons.timer,
                          label: 'Quick Meals',
                          sublabel: 'Under 30 min',
                          onTap: () =>
                              _handleMealPlanQuickAction('quick', isDarkMode),
                          isPrimary: false,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: getPercentageHeight(1, context)),

                  // Custom option
                  OutlinedButton.icon(
                    onPressed: () =>
                        _handleMealPlanQuickAction('custom', isDarkMode),
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
    required bool isDarkMode,
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
        case 'meal':
          title = 'Meal Plan Mode';
          description = 'Plan meals, get recipes, and add to calendar';
          icon = Icons.restaurant_menu;
          color = kAccentLight;
          break;
        default: // sous chef
          title = 'Sous Chef Mode';
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
          ],
        ),
      );
    });
  }

  // Removed - no longer using feature items with new tab design
  // Removed - planner mode is now a tab, no need to exit dialog

  Widget _buildEmptyState(String mode, bool isDarkMode) {
    IconData icon;
    String title;
    String subtitle;
    List<String> quickStarters;

    switch (mode) {
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
      default: // sous chef
        icon = Icons.chat_bubble_outline;
        title = 'Chat with Sous Chef';
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
