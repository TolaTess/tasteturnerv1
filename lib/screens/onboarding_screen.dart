import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';
import '../data_models/user_data_model.dart';
import '../helper/utils.dart';
import '../service/chat_utilities.dart';
import '../pages/safe_text_field.dart';
import '../screens/add_food_screen.dart';
import '../service/badge_service.dart';
import '../service/notification_service.dart';
import '../service/notification_handler_service.dart';
import '../service/hybrid_notification_service.dart';
import '../widgets/bottom_nav.dart';
import 'onboarding_cycle_sync_screen.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class OnboardingScreen extends StatefulWidget {
  final String userId;
  final String? displayName;
  final String?
      authProvider; // Track which auth provider was used (apple.com, google.com, password)
  const OnboardingScreen(
      {super.key, required this.userId, this.displayName, this.authProvider});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _controller = PageController();
  int _currentPage = 0;
  late final AnimationController _bounceController;

  // User inputs
  final TextEditingController nameController = TextEditingController();
  bool _isNextEnabled = false;
  bool _notificationsEnabled = false;
  bool _darkModeEnabled = false;
  bool _isSubmitting = false; // Prevent multiple submissions

  // Gender selection (optional during onboarding)
  String? _selectedGender;

  // Cycle syncing (optional during onboarding)
  bool _cycleSyncEnabled = false;
  DateTime? _cycleLastPeriodStart;
  final TextEditingController _cycleLengthController =
      TextEditingController(text: '28');

  // Track if UMP consent has been requested (to avoid multiple calls)
  bool _umpConsentRequested = false;
  // Track if UMP consent has been obtained (required to proceed)
  bool _umpConsentObtained = false;
  // Track if there was an error showing the consent form (to show fallback button)
  bool _umpConsentFormError = false;
  // Track if a form is currently being shown/loaded to prevent concurrent calls
  bool _isFormLoading = false;

  // Scroll controller for lingo walkthrough slide
  final ScrollController _lingoScrollController = ScrollController();

  // List<Map<String, String>> familyMembers = [];

  @override
  void initState() {
    super.initState();
    // Pre-fill name if provided from Apple/Google, even though we skip the name page
    if (widget.displayName != null && widget.displayName!.isNotEmpty) {
      nameController.text = widget.displayName!;
      debugPrint("Display Onboarding Name: ${widget.displayName}");
    }
    // If skipping name page, start validation for the first visible page (step 2)
    if (_shouldSkipNamePage()) {
      _validateInputs(); // Validate to enable Next button for step 2
    } else {
      _validateInputs(); // Validate for name page
    }
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);

    // Get current theme preference
    _darkModeEnabled = getThemeProvider(context).isDarkMode;
  }

  @override
  void dispose() {
    _bounceController.dispose();
    _controller.dispose();
    nameController.dispose();
    _lingoScrollController.dispose();
    super.dispose();
  }

  /// Check if name page should be skipped (skip step 1 for Apple/Google sign-in)
  bool _shouldSkipNamePage() {
    // Skip step 1 (name page) when coming from Apple or Google sign-in
    final isAppleOrGoogle = widget.authProvider == 'apple.com' ||
        widget.authProvider == 'google.com';
    return isAppleOrGoogle;
  }

  /// Get the total number of pages (excluding name page if skipped)
  int get _totalPages => _shouldSkipNamePage() ? 9 : 10;

  /// Build the list of pages for PageView, conditionally excluding name page
  List<Widget> _buildPageViewChildren() {
    final children = <Widget>[];

    // Only include name page if name is not provided from Apple/Google
    if (!_shouldSkipNamePage()) {
      children.add(_buildNamePage());
    }

    // Add all other pages
    children.addAll([
      _buildMealPlanningSlide(),
      _buildTrackingSlide(),
      _buildCommunitySlide(),
      _buildGenderSlide(),
      _buildCycleSyncSlide(),
      _buildUMPConsentSlide(),
      _buildFreeTrialSlide(),
      _buildSettingsSlide(),
      _buildLingualWalkthroughSlide(),
    ]);

    return children;
  }

  bool isProfane(String text) {
    final profaneWords = [
      'fuck',
      'shit',
      'asshole',
      'bitch',
      'cunt',
      'dick',
      'faggot',
      'nigga',
      'nigger',
    ];
    final lowerText = text.toLowerCase();
    return profaneWords.any((word) => lowerText.contains(word));
  }

  // Validate and sanitize name
  String? _validateName(String name) {
    final trimmed = name.trim();

    if (trimmed.isEmpty) {
      return 'Name cannot be empty';
    }

    if (trimmed.length < 2) {
      return 'Name must be at least 2 characters';
    }

    if (trimmed.length > 50) {
      return 'Name must be less than 50 characters';
    }

    if (isProfane(trimmed)) {
      return 'Please use appropriate language';
    }

    // Remove any potentially harmful characters
    final sanitized = trimmed.replaceAll(RegExp(r'[<>{}[\]\\]'), '');
    if (sanitized != trimmed) {
      return 'Name contains invalid characters';
    }

    return null; // Valid
  }

  /// ✅ Check if all required fields are filled before enabling "Next"
  void _validateInputs() {
    setState(() {
      final skipNamePage = _shouldSkipNamePage();

      switch (_currentPage) {
        case 0:
          if (skipNamePage) {
            // Page 0 is now Meal Planning (visual slide)
            _isNextEnabled = true;
          } else {
            // Page 0 is Name Page - only shown when no name is provided
            final name = nameController.text.trim();
            final validationError = _validateName(name);
            _isNextEnabled = validationError == null;
          }
          break;
        case 1:
          if (skipNamePage) {
            // Page 1 is now Tracking (visual slide)
            _isNextEnabled = true;
          } else {
            // Page 1 is Meal Planning (visual slide)
            _isNextEnabled = true;
          }
          break;
        case 2:
          if (skipNamePage) {
            // Page 2 is now Community (visual slide)
            _isNextEnabled = true;
          } else {
            // Page 2 is Tracking (visual slide)
            _isNextEnabled = true;
          }
          break;
        case 3:
          if (skipNamePage) {
            // Page 3 is now Gender slide
            _isNextEnabled = true; // Gender slide - always enabled (optional)
          } else {
            // Page 3 is Community (visual slide)
            _isNextEnabled = true;
          }
          break;
        case 4:
          if (skipNamePage) {
            // Page 4 is now Cycle Sync slide
            final isMale = _selectedGender?.toLowerCase() == 'male';
            final shouldShowInfoOnly = _selectedGender == null || isMale;
            if (shouldShowInfoOnly || !_cycleSyncEnabled) {
              _isNextEnabled = true;
            } else {
              final length = int.tryParse(_cycleLengthController.text.trim());
              final validLength =
                  length != null && length >= 21 && length <= 40;
              final now = DateTime.now();
              final lastStart = _cycleLastPeriodStart;
              final validDate = lastStart != null &&
                  !lastStart.isAfter(
                    DateTime(now.year, now.month, now.day + 1),
                  );
              _isNextEnabled = validLength && validDate;
            }
          } else {
            // Page 4 is Gender slide
            _isNextEnabled = true; // Gender slide - always enabled (optional)
          }
          break;
        case 5:
          if (skipNamePage) {
            // Page 5 is now UMP Consent slide
            // Next button is only enabled after consent is obtained
            _isNextEnabled = _umpConsentObtained;
          } else {
            // Page 5 is Cycle Sync slide
            final isMale = _selectedGender?.toLowerCase() == 'male';
            final shouldShowInfoOnly = _selectedGender == null || isMale;
            if (shouldShowInfoOnly || !_cycleSyncEnabled) {
              _isNextEnabled = true;
            } else {
              final length = int.tryParse(_cycleLengthController.text.trim());
              final validLength =
                  length != null && length >= 21 && length <= 40;
              final now = DateTime.now();
              final lastStart = _cycleLastPeriodStart;
              final validDate = lastStart != null &&
                  !lastStart.isAfter(
                    DateTime(now.year, now.month, now.day + 1),
                  );
              _isNextEnabled = validLength && validDate;
            }
          }
          break;
        case 6:
          if (skipNamePage) {
            // Page 6 is now Free Trial slide
            _isNextEnabled = true; // Free Trial slide - always enabled
          } else {
            // Page 6 is UMP Consent slide
            // Next button is only enabled after consent is obtained
            _isNextEnabled = _umpConsentObtained;
          }
          break;
        case 7:
          if (skipNamePage) {
            // Page 7 is now Settings slide
            _isNextEnabled = true; // Settings slide
          } else {
            // Page 7 is Free Trial slide
            _isNextEnabled = true; // Free Trial slide - always enabled
          }
          break;
        case 8:
          if (skipNamePage) {
            // Page 8 is now Lingual Walkthrough (New last page)
            _isNextEnabled = true;
          } else {
            // Page 8 is Settings
            _isNextEnabled = true;
          }
          break;
        case 9:
          // Page 9 is Lingual Walkthrough (New last page)
          _isNextEnabled = true;
          break;
        default:
          _isNextEnabled = false;
      }
    });
  }

  void _submitOnboarding() async {
    if (_isSubmitting) return; // Prevent multiple submissions

    try {
      if (widget.userId.isEmpty) {
        debugPrint("Error: User ID is missing.");
        if (mounted) {
          Get.snackbar(
            'Error',
            'User ID is missing. Please try again.',
            backgroundColor: Colors.red,
            colorText: Colors.white,
          );
        }
        return;
      }

      // Validate name before submission
      // If name page was skipped, use displayName from widget; otherwise use controller
      final name = _shouldSkipNamePage() &&
              (widget.displayName != null && widget.displayName!.isNotEmpty)
          ? widget.displayName!.trim()
          : nameController.text.trim();
      final nameValidation = _validateName(name);
      if (nameValidation != null) {
        if (mounted) {
          Get.snackbar(
            'Invalid Name',
            nameValidation,
            backgroundColor: Colors.red,
            colorText: Colors.white,
          );
        }
        return;
      }

      setState(() {
        _isSubmitting = true;
      });

      if (!mounted) return;

      Get.dialog(
        const Center(
            child: CircularProgressIndicator(
          color: kAccent,
        )),
        barrierDismissible: false,
      );

      // Sanitize name before saving
      // Use displayName from widget if name page was skipped, otherwise use controller
      final nameToSave = _shouldSkipNamePage() &&
              (widget.displayName != null && widget.displayName!.isNotEmpty)
          ? widget.displayName!
          : nameController.text.trim();
      final sanitizedName = nameToSave.replaceAll(RegExp(r'[<>{}[\]\\]'), '');

      final newUser = UserModel(
        userId: widget.userId,
        displayName: sanitizedName,
        bio: getRandomBio(bios),
        dob: '', // Empty - will trigger prompt
        profileImage: '',
        userType: 'user',
        isPremium: false, // Default to false, can be enabled later
        created_At: DateTime.now(),
        freeTrialDate: DateTime.now().add(const Duration(days: 30)),
        settings: <String, dynamic>{
          'waterIntake': '2000',
          'foodGoal': '2000', // Default - will trigger prompt
          'proteinGoal': 150,
          'carbsGoal': 200,
          'fatGoal': 65,
          'goalWeight': '', // Empty - will trigger prompt
          'startingWeight': '', // Empty
          'currentWeight': '', // Empty - will trigger prompt
          'fitnessGoal': 'Healthy Eating', // Default - will trigger prompt
          'targetSteps': '10000',
          'dietPreference': 'Balanced',
          'gender': _selectedGender, // Gender from onboarding or null
          'notificationsEnabled': _notificationsEnabled,
          'notificationPreferenceSet': true, // User has made a choice
          'cycleTracking': {
            'isEnabled': _cycleSyncEnabled,
            'lastPeriodStart': _cycleLastPeriodStart?.toIso8601String(),
            'cycleLength':
                int.tryParse(_cycleLengthController.text.trim()) ?? 28,
          },
        },
        preferences: {
          'diet': 'None', // Default - will trigger prompt
          'allergies': [], // Empty - will trigger prompt
          'cuisineType': 'Balanced',
          'proteinDishes': 2,
          'grainDishes': 2,
          'vegDishes': 3,
          'lastUpdated': FieldValue.serverTimestamp(),
        },
        // UMP consent handles terms acceptance
        ageVerification: {
          'dateFormatValid': true, // UMP consent covers this
          'dateOfBirth': null,
          'verifiedAt': FieldValue.serverTimestamp(),
        },
        termsAcceptance: {
          'hasAccepted': true, // UMP consent covers this
          'acceptedAt': FieldValue.serverTimestamp(),
          'version': '1.0',
        },
      );

      try {
        // Save user data to Firestore
        await firestore.collection('users').doc(widget.userId).set(
              newUser.toMap(),
              SetOptions(merge: true),
            );

        // Assign user number and check for first 100 users badge
        await BadgeService.instance
            .assignUserNumberAndCheckBadge(widget.userId);

        // Set current user
        userService.setUser(newUser);

        // Save to local storage using toJson()
        final prefs = await SharedPreferences.getInstance();

        // Create buddy chat
        final String buddyChatId =
            await ChatUtilities.getOrCreateChatId(widget.userId, 'buddy');

        await firestore.collection('users').doc(widget.userId).set(
          {'buddyChatId': buddyChatId},
          SetOptions(merge: true),
        );

        userService.setBuddyChatId(buddyChatId);

        final formattedDate = DateFormat('yyyy-MM-dd').format(DateTime.now());

        await helperController.saveMealPlan(
            widget.userId, formattedDate, 'welcome_day');

        if (widget.userId != tastyId3 && widget.userId != tastyId4) {
          await friendController.followFriend(
              widget.userId, tastyId, 'Sous Chef', context);
        }

        await prefs.setBool('is_first_time_user', true);

        // UMP consent is now handled in the UMP consent slide before Settings
        // No need to request it here during submission

        // Initialize notifications if enabled
        if (_notificationsEnabled && mounted) {
          try {
            NotificationService? notificationService;
            try {
              notificationService = Get.find<NotificationService>();
            } catch (e) {
              debugPrint('NotificationService not found: $e');
              if (mounted) {
                Get.snackbar(
                  'Notification Setup',
                  'Notifications could not be initialized. You can enable them later in settings.',
                  backgroundColor: kAccentLight,
                  colorText: kWhite,
                  duration: const Duration(seconds: 3),
                );
              }
            }

            if (notificationService != null && mounted) {
              // Initialize without requesting permissions
              await notificationService.initNotification(
                onNotificationTapped: (String? payload) {
                  if (payload != null && mounted) {
                    _handleNotificationTap(payload);
                  }
                },
              ).timeout(
                const Duration(seconds: 10),
                onTimeout: () {
                  debugPrint('Notification initialization timed out');
                },
              );

              // Request iOS permissions explicitly now that user has enabled notifications
              if (mounted) {
                try {
                  await notificationService.requestIOSPermissions();
                  debugPrint(
                      'iOS notification permissions requested during onboarding');
                } catch (e) {
                  debugPrint(
                      'Error requesting iOS notification permissions: $e');
                }
              }

              // Initialize hybrid notification service for Android only
              // iOS uses local notifications which are already handled by NotificationService
              if (mounted && Platform.isAndroid) {
                try {
                  HybridNotificationService? hybridNotificationService;
                  try {
                    hybridNotificationService =
                        Get.find<HybridNotificationService>();
                  } catch (e) {
                    debugPrint('HybridNotificationService not found: $e');
                  }

                  if (hybridNotificationService != null) {
                    await hybridNotificationService
                        .initializeHybridNotifications();
                    debugPrint(
                        'Hybrid notifications initialized during onboarding (Android)');
                  }
                } catch (e) {
                  debugPrint('Error initializing hybrid notifications: $e');
                }
              } else if (mounted && Platform.isIOS) {
                // For iOS, notification preferences can be set up later when needed
                // The local notification service is already initialized above
                debugPrint(
                    'iOS notifications: Using local notifications (hybrid service skipped)');
              }

              debugPrint('Notifications enabled during onboarding');
            }
          } catch (e) {
            debugPrint('Error initializing notifications: $e');
            if (mounted) {
              // Show non-blocking error - notifications are optional
              Get.snackbar(
                'Notification Setup',
                'Notifications could not be initialized. You can enable them later in settings.',
                backgroundColor: kAccentLight,
                colorText: kWhite,
                duration: const Duration(seconds: 3),
              );
            }
          }
        }

        if (!mounted) return;

        // Close loading dialog
        if (Get.isDialogOpen ?? false) {
          Get.back();
        }

        // Navigate to main app with bottom navigation
        Get.offAll(() => const BottomNavSec());
      } catch (e) {
        if (!mounted) return;

        // Close loading dialog if open
        if (Get.isDialogOpen ?? false) {
          Get.back();
        }

        debugPrint("Error saving user data: $e");
        Get.snackbar(
          'Error',
          'Failed to save user data. Please try again.',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      } finally {
        if (mounted) {
          setState(() {
            _isSubmitting = false;
          });
        }
      }
    } catch (e) {
      debugPrint("Error in _submitOnboarding: $e");
      if (mounted) {
        // Close loading dialog if open
        if (Get.isDialogOpen ?? false) {
          Get.back();
        }

        Get.snackbar(
          'Error',
          'Something went wrong. Please try again.',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );

        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  // List<Map<String, dynamic>> saveFamilyMembers() {
  //   return familyMembers.map((e) => Map<String, dynamic>.from(e)).toList();
  // }

  void _handleNotificationTap(String payload) async {
    if (!mounted) return;

    try {
      debugPrint('Notification tapped: $payload');

      if (payload.contains('meal_plan_reminder') ||
          payload.contains('evening_review') ||
          payload.contains('water_reminder')) {
        if (!mounted) return;

        if (payload.contains('meal_plan_reminder')) {
          Get.to(() => const BottomNavSec(selectedIndex: 4));
        } else if (payload.contains('water_reminder')) {
          Get.to(() => AddFoodScreen(date: DateTime.now()));
        } else if (payload.contains('evening_review')) {
          Get.to(() => AddFoodScreen(date: DateTime.now()));
        }
      } else {
        if (!mounted) return;

        try {
          NotificationHandlerService? handlerService;
          try {
            handlerService = Get.find<NotificationHandlerService>();
          } catch (e) {
            debugPrint('NotificationHandlerService not found: $e');
          }

          if (handlerService != null) {
            await handlerService.handleNotificationPayload(payload);
          } else if (mounted && context.mounted) {
            showTastySnackbar(
                'Something went wrong', 'Please try again later', context,
                backgroundColor: kRed);
          }
        } catch (e) {
          debugPrint('Error handling complex notification: $e');
          if (mounted && context.mounted) {
            showTastySnackbar(
                'Something went wrong', 'Please try again later', context,
                backgroundColor: kRed);
          }
        }
      }
    } catch (e) {
      debugPrint('Error handling notification tap: $e');
      if (mounted && context.mounted) {
        showTastySnackbar(
            'Something went wrong', 'Please try again later', context,
            backgroundColor: kRed);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    return Scaffold(
      resizeToAvoidBottomInset: true,
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
        child: GestureDetector(
          onTap: () {
            // Dismiss keyboard when tapping outside
            FocusScope.of(context).unfocus();
          },
          child: SafeArea(
            child: Column(
              children: [
                if (_currentPage > 0)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      icon: Icon(
                        Icons.arrow_back_ios,
                        color: getThemeProvider(context).isDarkMode
                            ? kWhite
                            : kDarkGrey,
                      ),
                      onPressed: () {
                        // Dismiss keyboard when navigating
                        FocusScope.of(context).unfocus();
                        _controller.previousPage(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeIn,
                        );
                      },
                    ),
                  ),
                Expanded(
                  child: PageView(
                    controller: _controller,
                    physics: _isNextEnabled
                        ? const BouncingScrollPhysics()
                        : const NeverScrollableScrollPhysics(),
                    onPageChanged: (value) {
                      // Dismiss keyboard when changing pages
                      FocusScope.of(context).unfocus();
                      setState(() {
                        _currentPage = value;
                      });
                      // Reset consent obtained flag when navigating to UMP page
                      // User must interact with the form to enable next button
                      final skipNamePage = _shouldSkipNamePage();
                      final isUMPPage = (skipNamePage && value == 5) ||
                          (!skipNamePage && value == 6);
                      if (isUMPPage) {
                        _umpConsentObtained = false;
                        _umpConsentFormError = false; // Reset error state
                        // Auto-trigger consent form when slide appears
                        // Use a small delay to ensure slide is fully rendered
                        Future.delayed(const Duration(milliseconds: 500), () {
                          if (mounted && _currentPage == value) {
                            _requestUMPConsentFromSlide();
                          }
                        });
                      }
                      _validateInputs();
                    },
                    children: _buildPageViewChildren(),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(getPercentageWidth(5, context)),
                  child: _buildNavigationButtons(
                      textTheme: Theme.of(context).textTheme),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Welcome & Name Input Page
  /// Only shown when no name is provided from auth provider
  Widget _buildNamePage() {
    final textTheme = Theme.of(context).textTheme;

    return _buildPage(
      textTheme: textTheme,
      title: "Welcome to $appName!",
      description:
          "The stations are clean and the prep is ready. Who is running the pass today? Enter your name, Chef.",
      child1: Container(
        padding: EdgeInsets.all(getPercentageWidth(5, context)),
        decoration: BoxDecoration(
          color: kDarkGrey,
          borderRadius: BorderRadius.circular(10),
        ),
        child: SafeTextFormField(
          controller: nameController,
          style:
              TextStyle(color: kDarkGrey, fontSize: getTextScale(3.5, context)),
          onChanged: (_) => _validateInputs(),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFF3F3F3),
            enabledBorder: outlineInputBorder(10),
            focusedBorder: outlineInputBorder(10),
            border: outlineInputBorder(10),
            labelStyle: const TextStyle(color: Color(0xffefefef)),
            hintStyle: TextStyle(
                color: kLightGrey, fontSize: getTextScale(3.5, context)),
            hintText: "Enter your name",
            floatingLabelBehavior: FloatingLabelBehavior.always,
            contentPadding: EdgeInsets.only(
              top: getPercentageHeight(1.5, context),
              bottom: getPercentageHeight(1.5, context),
              right: getPercentageWidth(2, context),
              left: getPercentageWidth(2, context),
            ),
          ),
        ),
      ),
      child2: const SizedBox.shrink(),
      child3: Image.asset(
        'assets/images/tasty/tasty.png',
        height: getPercentageHeight(40, context),
        width: getPercentageWidth(50, context),
        fit: BoxFit.contain,
      ),
    );
  }

  /// Visual Feature Slide 1: Personalized Meal Plans & Custom Diets
  Widget _buildMealPlanningSlide() {
    final userName = nameController.text.trim().isNotEmpty
        ? nameController.text.trim()
        : (widget.displayName != null && widget.displayName!.isNotEmpty
            ? widget.displayName!
            : "there");
    debugPrint("Meal Planning Slide User Name: $userName");

    // Initialize ads in background when this slide is displayed
    // This ensures ads are ready without delaying home screen loading
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.microtask(() async {
        if (!mounted) return;

        // Skip ad initialization for premium users (though unlikely during onboarding)
        try {
          final currentUser = userService.currentUser.value;
          final isPremium = currentUser?.isPremium ?? false;

          if (!isPremium) {
            try {
              await MobileAds.instance.initialize();
              debugPrint('Ads initialized successfully during onboarding');
            } catch (e) {
              debugPrint('Error initializing ads during onboarding: $e');
              // Don't show error to user - ads are not critical for onboarding
            }
          } else {
            debugPrint('Skipping ad initialization - user is premium');
          }
        } catch (e) {
          debugPrint('Error checking premium status during onboarding: $e');
          // Try to initialize anyway if we can't check premium status
          try {
            await MobileAds.instance.initialize();
            debugPrint(
                'Ads initialized successfully during onboarding (premium check failed)');
          } catch (initError) {
            debugPrint('Error initializing ads during onboarding: $initError');
          }
        }
      });
    });

    return _buildPage(
      textTheme: Theme.of(context).textTheme,
      title: "Welcome to the Kitchen, \nChef $userName!",
      description:
          "Let's get your station organized. Whether you need a No Sugar plan or Intermittent Fasting logic, I’m here to design the perfect menu for your specific goals.",
      child1: Container(
        padding: EdgeInsets.symmetric(
          horizontal: getPercentageWidth(2, context),
          vertical: getPercentageHeight(3, context),
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              kAccent,
              kAccentLight.withValues(alpha: 0.5)
            ], // Teal gradient
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Color(0xFF4A90E2).withOpacity(0.3),
              blurRadius: 10,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          children: [
            // Calendar + Plate Icon (referencing the image)
            Text(
              "Organizer",
              style: TextStyle(
                color: Colors.white,
                fontSize: getTextScale(5, context),
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: getPercentageHeight(0.5, context)),
            Text(
              "These are some things we can do together.",
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: getTextScale(3, context),
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: getPercentageHeight(1, context)),
            // Feature boxes in 2x2 grid
            Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildFeatureBox(
                      context,
                      "Join a Programs",
                      kPurple.withValues(alpha: 0.5), // Green
                      Icons.restaurant_menu,
                    ),
                    _buildFeatureBox(
                      context,
                      "Share your Calender with Family",
                      kBlue.withValues(alpha: 0.5), // Blue
                      Icons.calendar_month,
                    ),
                  ],
                ),
                SizedBox(height: getPercentageHeight(2, context)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildFeatureBox(
                      context,
                      "No Waste Dine In",
                      kAccentLight.withValues(alpha: 0.5), // Orange
                      Icons.dining,
                    ),
                    _buildFeatureBox(
                      context,
                      "Spin the Wheel",
                      kAccent.withValues(alpha: 0.5), // Purple
                      Icons.casino,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
      child2: const SizedBox.shrink(),
      child3: const SizedBox.shrink(),
    );
  }

  /// Visual Feature Slide 2: AI-Powered Nutrition & Instant Insights
  Widget _buildTrackingSlide() {
    return _buildPage(
      textTheme: Theme.of(context).textTheme,
      title: "Reporting for Duty.",
      description:
          'My name is Turner, your digital Sous Chef. My job is simple: You run the pass, I handle the prep.',
      child1: Container(
        padding: EdgeInsets.all(getPercentageWidth(5, context)),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              kPurple,
              kPurple.withValues(alpha: 0.5)
            ], // Orange gradient
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Color(0xFFFF6B35).withOpacity(0.3),
              blurRadius: 10,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          children: [
            SizedBox(height: getPercentageHeight(3, context)),
            Text(
              "I'm at your Service!", // My expertise at your service.
              style: TextStyle(
                color: Colors.white,
                fontSize: getTextScale(5, context),
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),

            SizedBox(height: getPercentageHeight(0.5, context)),
            Text(
              "These are some things I can do for you.",
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: getTextScale(3, context),
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: getPercentageHeight(1, context)),
            // Feature boxes in 2x2 grid
            Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildFeatureBox(
                      context,
                      "Snap & Analyze",
                      kPink.withValues(alpha: 0.5), // Pink
                      Icons.camera_alt,
                    ),
                    _buildFeatureBox(
                      context,
                      "Get daily insights on your meals",
                      kBlue.withValues(alpha: 0.5), // Cyan
                      Icons.insights,
                    ),
                  ],
                ),
                SizedBox(height: getPercentageHeight(2, context)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildFeatureBox(
                      context,
                      "Chat with me, your Sous Chef",
                      kAccentLight.withValues(alpha: 0.5), // Deep Orange
                      Icons.chat,
                    ),
                    _buildFeatureBox(
                      context,
                      "Get your Symptoms Tracked",
                      kAccent.withValues(alpha: 0.5), // Deep Purple
                      Icons.health_and_safety,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
      child2: const SizedBox.shrink(),
      child3: const SizedBox.shrink(),
    );
  }

  /// Visual Feature Slide 3: Effortless Macro Tracking & Shopping Lists
  Widget _buildCommunitySlide() {
    return _buildPage(
      textTheme: Theme.of(context).textTheme,
      title: "Master Your Inventory.",
      description:
          "I’ll track the macros and calories so you don't have to. Plus, I'll generate your shopping lists to make sure your kitchen is always stocked.",
      child1: Container(
        padding: EdgeInsets.all(getPercentageWidth(5, context)),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              kAccentLight,
              kAccentLight.withValues(alpha: 0.5)
            ], // Teal gradient
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Color(0xFF4A90E2).withOpacity(0.3),
              blurRadius: 10,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          children: [
            SizedBox(height: getPercentageHeight(3, context)),
            Text(
              "Your Kitchen, Your Rules.",
              style: TextStyle(
                color: Colors.white,
                fontSize: getTextScale(5, context),
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: getPercentageHeight(0.5, context)),
            Text(
              "More things we can do together",
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: getTextScale(3.5, context),
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: getPercentageHeight(1, context)),
            // Feature boxes in 2x2 grid
            Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildFeatureBox(
                      context,
                      "Track your Macros and Calories",
                      kPurple.withValues(alpha: 0.5), // Green
                      Icons.track_changes,
                    ),
                    _buildFeatureBox(
                      context,
                      "Track your Weight Progress",
                      kBlue.withValues(alpha: 0.5), // Blue
                      Icons.monitor_weight,
                    ),
                  ],
                ),
                SizedBox(height: getPercentageHeight(2, context)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildFeatureBox(
                      context,
                      "Generate Shopping Lists",
                      kPink.withValues(alpha: 0.5), // Orange
                      Icons.shopping_cart,
                    ),
                    _buildFeatureBox(
                      context,
                      "Check your Health and Food Intake",
                      kAccent.withValues(alpha: 0.5), // Purple
                      Icons.bar_chart,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
      child2: const SizedBox.shrink(),
      child3: const SizedBox.shrink(),
    );
  }

  /// UMP Consent Slide: Privacy & Ads Consent
  Widget _buildUMPConsentSlide() {
    final userName = nameController.text.trim().isNotEmpty
        ? nameController.text.trim()
        : (widget.displayName != null && widget.displayName!.isNotEmpty
            ? widget.displayName!
            : "there");

    return _buildPage(
      textTheme: Theme.of(context).textTheme,
      title: "Privacy & Consent,\nChef $userName!",
      description:
          "We respect your privacy. Please review and accept our privacy policy and terms. This helps us provide you with personalized content and ads.",
      child1: Container(
        padding: EdgeInsets.all(getPercentageWidth(5, context)),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [kAccentLight, kAccentLight.withValues(alpha: 0.7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: kAccentLight.withOpacity(0.3),
              blurRadius: 10,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          children: [
            SizedBox(height: getPercentageHeight(2, context)),
            Icon(
              Icons.privacy_tip,
              color: Colors.white,
              size: getIconScale(12, context),
            ),
            SizedBox(height: getPercentageHeight(3, context)),
            Text(
              "Privacy & Terms",
              style: TextStyle(
                color: Colors.white,
                fontSize: getTextScale(5, context),
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: getPercentageHeight(2, context)),
            Text(
              _umpConsentObtained && !_umpConsentFormError
                  ? "Thank you for reviewing and accepting our privacy policy and terms! You can now continue with the onboarding."
                  : "We need your consent to:\n• Provide personalized content and recommendations\n• Show relevant ads to support the app\n• Improve your experience with analytics\n\nThe consent form will open automatically. Please review and accept to continue.",
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: getTextScale(3.5, context),
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: getPercentageHeight(3, context)),
            // Only show button if there was an error or form hasn't been shown yet
            if (_umpConsentFormError ||
                (!_umpConsentObtained && _umpConsentRequested))
              ElevatedButton(
                onPressed: () => _requestUMPConsentFromSlide(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: kAccentLight,
                  padding: EdgeInsets.symmetric(
                    horizontal: getPercentageWidth(8, context),
                    vertical: getPercentageHeight(1.5, context),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                  elevation: 5,
                ),
                child: Text(
                  'Open Consent Form',
                  style: TextStyle(
                    fontSize: getTextScale(4, context),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            SizedBox(height: getPercentageHeight(2, context)),
          ],
        ),
      ),
      child2: const SizedBox.shrink(),
      child3: const SizedBox.shrink(),
    );
  }

  /// Free Trial Slide: 30-Day Free Access
  Widget _buildFreeTrialSlide() {
    final userName = nameController.text.trim().isNotEmpty
        ? nameController.text.trim()
        : (widget.displayName != null && widget.displayName!.isNotEmpty
            ? widget.displayName!
            : "there");

    // Calculate free trial end date (30 days from now)
    final freeTrialEndDate = DateTime.now().add(const Duration(days: 30));
    final formattedDate = DateFormat('MMM d, yyyy').format(freeTrialEndDate);

    return _buildPage(
      textTheme: Theme.of(context).textTheme,
      title: "Your 30-Day Free Trial,\nChef $userName!",
      description:
          "You get full access to all features for 30 days. Explore everything TasteTurner has to offer!",
      child1: Container(
        padding: EdgeInsets.all(getPercentageWidth(5, context)),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [kAccentLight, kAccentLight.withValues(alpha: 0.5)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: kAccentLight.withOpacity(0.3),
              blurRadius: 10,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          children: [
            SizedBox(height: getPercentageHeight(2, context)),
            Icon(
              Icons.celebration,
              color: Colors.white,
              size: getIconScale(12, context),
            ),
            SizedBox(height: getPercentageHeight(3, context)),
            Text(
              "Full Access for 30 Days",
              style: TextStyle(
                color: Colors.white,
                fontSize: getTextScale(5, context),
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: getPercentageHeight(0.5, context)),
            Text(
              "You will see ads during your free trial.",
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: getTextScale(3, context),
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: getPercentageHeight(1, context)),

            Container(
              padding: EdgeInsets.all(getPercentageWidth(4, context)),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Column(
                children: [
                  Text(
                    "Your free trial ends on",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: getTextScale(3.5, context),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: getPercentageHeight(1, context)),
                  Text(
                    formattedDate,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: getTextScale(5, context),
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            SizedBox(height: getPercentageHeight(3, context)),
            Container(
              padding: EdgeInsets.all(getPercentageWidth(4, context)),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.white,
                    size: getIconScale(6, context),
                  ),
                  SizedBox(width: getPercentageWidth(3, context)),
                  Expanded(
                    child: Text(
                      "After your free trial ends, upgrade to Executive Chef to continue enjoying all premium features.",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: getTextScale(3.2, context),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: getPercentageHeight(2, context)),
          ],
        ),
      ),
      child2: const SizedBox.shrink(),
      child3: const SizedBox.shrink(),
    );
  }

  /// Settings Slide: Notifications & Dark Mode
  Widget _buildSettingsSlide() {
    final userName = nameController.text.trim().isNotEmpty
        ? nameController.text.trim()
        : (widget.displayName != null && widget.displayName!.isNotEmpty
            ? widget.displayName!
            : "there");

    return _buildPage(
      textTheme: Theme.of(context).textTheme,
      title: "Final Polish,\nChef $userName!",
      description:
          "Set your kitchen vibe and notification style. Once this is done, we’re ready for our first service.",
      child1: Container(
        padding: EdgeInsets.all(getPercentageWidth(5, context)),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [kAccent, kAccent.withValues(alpha: 0.7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: kAccent.withOpacity(0.3),
              blurRadius: 10,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          children: [
            SizedBox(height: getPercentageHeight(2, context)),

            // Notifications Toggle
            Container(
              padding: EdgeInsets.all(getPercentageWidth(4, context)),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.notifications_active,
                    color: Colors.white,
                    size: getIconScale(8, context),
                  ),
                  SizedBox(width: getPercentageWidth(4, context)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Notifications",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: getTextScale(4, context),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: getPercentageHeight(0.5, context)),
                        Text(
                          "Get reminders for meals and hydration",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: getTextScale(3, context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _notificationsEnabled,
                    onChanged: (value) {
                      setState(() {
                        _notificationsEnabled = value;
                      });
                    },
                    activeColor: kAccentLight,
                    activeTrackColor: kAccentLight.withOpacity(0.5),
                  ),
                ],
              ),
            ),

            SizedBox(height: getPercentageHeight(3, context)),

            // Dark Mode Toggle
            Container(
              padding: EdgeInsets.all(getPercentageWidth(4, context)),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Row(
                children: [
                  Icon(
                    _darkModeEnabled ? Icons.dark_mode : Icons.light_mode,
                    color: Colors.white,
                    size: getIconScale(8, context),
                  ),
                  SizedBox(width: getPercentageWidth(4, context)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Dark Mode",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: getTextScale(4, context),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: getPercentageHeight(0.5, context)),
                        Text(
                          "Choose your preferred theme",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: getTextScale(3, context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _darkModeEnabled,
                    onChanged: (value) {
                      setState(() {
                        _darkModeEnabled = value;
                        getThemeProvider(context).toggleTheme();
                      });
                    },
                    activeColor: kAccentLight,
                    activeTrackColor: kAccentLight.withOpacity(0.5),
                  ),
                ],
              ),
            ),

            SizedBox(height: getPercentageHeight(2, context)),
          ],
        ),
      ),
      child2: const SizedBox.shrink(),
      child3: const SizedBox.shrink(),
    );
  }

  /// New Slide: Lingual Walkthrough / Chef Terminology
  Widget _buildLingualWalkthroughSlide() {
    return _buildPage(
      textTheme: Theme.of(context).textTheme,
      title: "Speaking the Lingo",
      description:
          "Before we start service, let's learn the language of the kitchen. Here is how we run things.",
      child1: Container(
        padding: EdgeInsets.all(getPercentageWidth(5, context)),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              kAccent,
              kPurple.withValues(alpha: 0.7)
            ], // Teal to Blue gradient
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: kAccent.withOpacity(0.3),
              blurRadius: 10,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Stack(
          children: [
            SingleChildScrollView(
              controller: _lingoScrollController,
              child: Column(
                children: [
                  SizedBox(height: getPercentageHeight(2, context)),
                  _buildTermRow(
                    context,
                    "Head Chef",
                    "That's You! You're in charge of your kitchen and nutrition goals.",
                    Icons.person,
                  ),
                  _buildDivider(context),
                  _buildTermRow(
                    context,
                    "Sous Chef",
                    "That's Me (Turner). I'm your AI assistant here to help with meal planning and tracking.",
                    Icons.smart_toy,
                  ),
                  _buildDivider(context),
                  _buildTermRow(
                    context,
                    "The Pass",
                    "Your Food Diary. Log meals, track macros, and review your daily nutrition here.",
                    Icons.assignment,
                  ),
                  _buildDivider(context),
                  _buildTermRow(
                    context,
                    "Dine In",
                    "Cook with what you have. Get recipe suggestions based on ingredients in your fridge.",
                    Icons.kitchen,
                  ),
                  _buildDivider(context),
                  _buildTermRow(
                    context,
                    "Kitchen",
                    "Your main dashboard. Track daily nutrition, view goals, and access quick actions.",
                    Icons.home,
                  ),
                  _buildDivider(context),
                  _buildTermRow(
                    context,
                    "Menus",
                    "Meal programs and plans tailored to your dietary needs.",
                    Icons.restaurant_menu,
                  ),
                  _buildDivider(context),
                  _buildTermRow(
                    context,
                    "Inspiration",
                    "Community feed where chefs share recipes and tips.",
                    Icons.explore,
                  ),
                  _buildDivider(context),
                  _buildTermRow(
                    context,
                    "Spin",
                    "Spin the wheel for spontaneous recipe discovery when you can't decide.",
                    Icons.casino,
                  ),
                  _buildDivider(context),
                  _buildTermRow(
                    context,
                    "Schedule",
                    "Your meal planning calendar. Plan ahead and organize your week.",
                    Icons.calendar_month,
                  ),
                  _buildDivider(context),
                  _buildTermRow(
                    context,
                    "Inventory",
                    "Your shopping list. Auto-generated from planned meals.",
                    Icons.shopping_cart,
                  ),
                  _buildDivider(context),
                  _buildTermRow(
                    context,
                    "Cookbook",
                    "Your recipe collection. Save and browse favorite dishes.",
                    Icons.menu_book,
                  ),
                  _buildDivider(context),
                  _buildTermRow(
                    context,
                    "Brigade",
                    "Your friends and community. Connect with other chefs.",
                    Icons.people,
                  ),
                  _buildDivider(context),
                  _buildTermRow(
                    context,
                    "Station",
                    "Your profile and kitchen settings. Customize your experience.",
                    Icons.settings,
                  ),
                  _buildDivider(context),
                  _buildTermRow(
                    context,
                    "Order Fire",
                    "Log meals and track what you've eaten.",
                    Icons.restaurant,
                  ),
                  SizedBox(height: getPercentageHeight(2, context)),
                ],
              ),
            ),
          ],
        ),
      ),
      child2: const SizedBox.shrink(),
      child3: const SizedBox.shrink(),
    );
  }

  Widget _buildTermRow(
      BuildContext context, String term, String definition, IconData icon) {
    return Padding(
      padding:
          EdgeInsets.symmetric(vertical: getPercentageHeight(1.5, context)),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start, // Align to top for longer text
        children: [
          Container(
            padding: EdgeInsets.all(getPercentageWidth(2, context)),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: getIconScale(5, context),
            ),
          ),
          SizedBox(width: getPercentageWidth(4, context)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  term,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: getTextScale(4, context),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: getPercentageHeight(0.5, context)),
                Text(
                  definition,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: getTextScale(3.2, context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider(BuildContext context) {
    return Divider(
      color: Colors.white.withOpacity(0.2),
      thickness: 1,
      height: 1,
    );
  }

  /// Build square feature box with icon and title
  Widget _buildFeatureBox(
      BuildContext context, String text, Color color, IconData icon) {
    return Container(
      width: getPercentageWidth(22, context), // Even smaller width
      height: getPercentageWidth(25, context), // Even smaller height
      padding:
          EdgeInsets.all(getPercentageWidth(2.5, context)), // Reduced padding
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: Colors.white,
            size: getPercentageWidth(7, context), // Even smaller icon
          ),
          SizedBox(
              height: getPercentageHeight(0.8, context)), // Minimal spacing
          Text(
            text,
            style: TextStyle(
              color: Colors.white,
              fontSize: getTextScale(2.5, context), // Even smaller font
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  /// Reusable Page Wrapper
  Widget _buildPage({
    required String title,
    required String description,
    required Widget child1,
    required Widget child2,
    required Widget child3,
    required TextTheme textTheme,
  }) {
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.all(getPercentageWidth(5, context)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            title.contains("Welcome to $appName!")
                ? SizedBox(height: getPercentageHeight(7, context))
                : SizedBox(height: getPercentageHeight(3, context)),
            title.isNotEmpty
                ? Text(
                    title,
                    textAlign: TextAlign.center,
                    style: textTheme.displaySmall
                        ?.copyWith(fontWeight: FontWeight.w800, color: kAccent),
                  )
                : const SizedBox.shrink(),
            SizedBox(height: getPercentageHeight(2, context)),
            Text(
              description,
              textAlign: TextAlign.center,
              style: textTheme.bodyLarge?.copyWith(
                color:
                    getThemeProvider(context).isDarkMode ? kWhite : kDarkGrey,
              ),
            ),
            SizedBox(height: getPercentageHeight(5, context)),
            child1,
            SizedBox(height: getPercentageHeight(2, context)),
            child2,
            SizedBox(height: getPercentageHeight(2, context)),
            child3,
          ],
        ),
      ),
    );
  }

  void _nextPage() {
    if (_isNextEnabled) {
      // Dismiss keyboard when navigating
      FocusScope.of(context).unfocus();

      if (_currentPage < _totalPages - 1) {
        _controller.nextPage(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeIn,
        );
      } else {
        _submitOnboarding();
      }
    }
  }

  /// Navigation Buttons
  Widget _buildNavigationButtons({required TextTheme textTheme}) {
    return Padding(
      padding: EdgeInsets.symmetric(
          horizontal: getPercentageWidth(5, context),
          vertical: getPercentageHeight(1, context)),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          minimumSize: Size.fromHeight(getPercentageHeight(7, context)),
          backgroundColor: _isNextEnabled ? kAccent : kLightGrey,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(50),
          ),
        ),
        onPressed: _isNextEnabled ? _nextPage : null,
        child: Text(
          _currentPage == _totalPages - 1 ? "Get Started" : "Next",
          textAlign: TextAlign.center,
          style: textTheme.displayMedium?.copyWith(
              fontWeight: FontWeight.w500,
              fontSize: getTextScale(5, context),
              color: _isNextEnabled ? kWhite : kDarkGrey),
        ),
      ),
    );
  }

  /// Request UMP consent from the onboarding slide (button click)
  Future<void> _requestUMPConsentFromSlide() async {
    try {
      final params = ConsentRequestParameters();
      ConsentInformation.instance.requestConsentInfoUpdate(
        params,
        () async {
          // Consent info updated successfully
          final canRequest = await ConsentInformation.instance.canRequestAds();
          final privacyOptionsStatus = await ConsentInformation.instance
              .getPrivacyOptionsRequirementStatus();

          debugPrint(
              'UMP Status - canRequestAds: $canRequest, privacyOptionsStatus: $privacyOptionsStatus');

          // If consent hasn't been obtained, show the initial consent form
          if (!canRequest) {
            if (_isFormLoading) {
              debugPrint('Form already loading, waiting for it to show...');
              // Wait a bit and retry if form is loading
              Future.delayed(const Duration(milliseconds: 1000), () {
                if (mounted && !_umpConsentObtained) {
                  debugPrint('Retrying consent form after delay...');
                  _requestUMPConsentFromSlide();
                }
              });
              return;
            }
            debugPrint('Consent not obtained, showing initial consent form...');
            _isFormLoading = true;
            ConsentForm.loadAndShowConsentFormIfRequired((formError) {
              _isFormLoading = false;
              if (formError != null) {
                debugPrint('=== UMP Consent form error ===');
                debugPrint('Error code: ${formError.errorCode}');
                debugPrint('Error message: ${formError.message}');
                debugPrint('Full error: $formError');
                debugPrint('================================');

                // Error code 7 means form is already being loaded
                // Retry after a delay to let the form show
                if (formError.errorCode == 7) {
                  debugPrint(
                      'Form already loading (error 7), retrying after delay...');
                  Future.delayed(const Duration(milliseconds: 1500), () {
                    if (mounted && !_umpConsentObtained) {
                      _requestUMPConsentFromSlide();
                    }
                  });
                } else {
                  // Form error occurred, show fallback button
                  _setFirebaseConsent();
                  if (mounted) {
                    setState(() {
                      _umpConsentRequested = true;
                      _umpConsentFormError = true;
                    });
                    _validateInputs();
                  }
                }
              } else {
                debugPrint('UMP Consent form processed successfully');
                _setFirebaseConsent();
                // Update state to reflect consent was obtained
                if (mounted) {
                  setState(() {
                    _umpConsentRequested = true;
                    _umpConsentObtained = true;
                    _umpConsentFormError =
                        false; // Clear error state on success
                  });
                  // Re-validate to enable next button
                  _validateInputs();
                }
              }
            });
          } else if (privacyOptionsStatus ==
              PrivacyOptionsRequirementStatus.required) {
            // If consent was already obtained but privacy options are required,
            // show the privacy options form
            if (_isFormLoading) {
              debugPrint(
                  'Privacy options form already loading, waiting for it to show...');
              // Wait a bit and retry if form is loading
              Future.delayed(const Duration(milliseconds: 1000), () {
                if (mounted && !_umpConsentObtained) {
                  debugPrint('Retrying privacy options form after delay...');
                  _requestUMPConsentFromSlide();
                }
              });
              return;
            }
            debugPrint('Showing privacy options form...');
            _isFormLoading = true;
            ConsentForm.showPrivacyOptionsForm((formError) {
              _isFormLoading = false;
              if (formError != null) {
                debugPrint('=== Privacy options form error ===');
                debugPrint('Error code: ${formError.errorCode}');
                debugPrint('Error message: ${formError.message}');
                debugPrint('Full error: $formError');
                debugPrint('===================================');

                // Error code 7 means form is already being loaded
                // Retry after a delay to let the form show
                if (formError.errorCode == 7) {
                  debugPrint(
                      'Form already loading (error 7), retrying after delay...');
                  Future.delayed(const Duration(milliseconds: 1500), () {
                    if (mounted && !_umpConsentObtained) {
                      _requestUMPConsentFromSlide();
                    }
                  });
                } else {
                  // Form error occurred, show fallback button
                  _setFirebaseConsent();
                  if (mounted) {
                    setState(() {
                      _umpConsentRequested = true;
                      _umpConsentFormError = true;
                    });
                    _validateInputs();
                  }
                }
              } else {
                debugPrint('Privacy options form processed successfully');
                _setFirebaseConsent();
                // Update state to reflect consent was obtained
                if (mounted) {
                  setState(() {
                    _umpConsentRequested = true;
                    _umpConsentObtained = true;
                    _umpConsentFormError =
                        false; // Clear error state on success
                  });
                  // Re-validate to enable next button
                  _validateInputs();
                }
              }
            });
          } else {
            // Consent already obtained and privacy options not required
            debugPrint('Consent already obtained, no form needed');
            _setFirebaseConsent();
            if (mounted) {
              setState(() {
                _umpConsentRequested = true;
                _umpConsentObtained = true;
                _umpConsentFormError = false; // No error, consent already there
              });
              // Re-validate to enable next button
              _validateInputs();
            }
          }
        },
        (FormError error) {
          // Handle the error updating consent info
          debugPrint('=== UMP Consent info update error ===');
          debugPrint('Error code: ${error.errorCode}');
          debugPrint('Error message: ${error.message}');
          debugPrint('Full error: $error');
          debugPrint('=====================================');
          _setFirebaseConsent();
        },
      );
    } catch (e) {
      debugPrint('Error requesting UMP consent: $e');
      // Still set Firebase consent even if UMP fails
      _setFirebaseConsent();
    }
  }

  /// Legacy method - kept for compatibility but not used
  @Deprecated('Use _requestUMPConsentFromSlide instead')
  Future<void> requestUMPConsent() async {
    await _requestUMPConsentFromSlide();
  }

  Future<void> _setFirebaseConsent() async {
    final canRequest = await ConsentInformation.instance.canRequestAds();
    await FirebaseAnalytics.instance.setConsent(
      adStorageConsentGranted: canRequest,
      analyticsStorageConsentGranted: canRequest,
    );
  }

  /// Gender Selection Slide
  Widget _buildGenderSlide() {
    final userName = nameController.text.trim().isNotEmpty
        ? nameController.text.trim()
        : (widget.displayName != null && widget.displayName!.isNotEmpty
            ? widget.displayName!
            : "there");

    debugPrint("Gender Slide User Name: $userName");
    final textTheme = Theme.of(context).textTheme;

    return _buildPage(
      textTheme: textTheme,
      title: "Calibrating Your Station, \nChef $userName!",
      description:
          "To design the right menu, I need to know who I'm cooking for. These details help me calculate your precise nutritional targets. (Optional, Chef - we can adjust later)",
      child1: Container(
        padding: EdgeInsets.all(getPercentageWidth(5, context)),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [kAccent, kAccent.withValues(alpha: 0.7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: kAccent.withOpacity(0.3),
              blurRadius: 10,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Gender (Optional)",
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            SizedBox(height: getPercentageHeight(2, context)),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedGender = 'male';
                        _validateInputs();
                      });
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        vertical: getPercentageHeight(2, context),
                        horizontal: getPercentageWidth(2, context),
                      ),
                      decoration: BoxDecoration(
                        color: _selectedGender == 'male'
                            ? Colors.white
                            : Colors.transparent,
                        border: Border.all(
                          color: Colors.white,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Male',
                        textAlign: TextAlign.center,
                        style: textTheme.bodyLarge?.copyWith(
                          color: _selectedGender == 'male'
                              ? kAccent
                              : Colors.white,
                          fontWeight: _selectedGender == 'male'
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: getPercentageWidth(3, context)),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedGender = 'female';
                        _validateInputs();
                      });
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        vertical: getPercentageHeight(2, context),
                        horizontal: getPercentageWidth(2, context),
                      ),
                      decoration: BoxDecoration(
                        color: _selectedGender == 'female'
                            ? Colors.white
                            : Colors.transparent,
                        border: Border.all(
                          color: Colors.white,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Female',
                        textAlign: TextAlign.center,
                        style: textTheme.bodyLarge?.copyWith(
                          color: _selectedGender == 'female'
                              ? kAccent
                              : Colors.white,
                          fontWeight: _selectedGender == 'female'
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (_selectedGender != null)
              Padding(
                padding:
                    EdgeInsets.only(top: getPercentageHeight(1.5, context)),
                child: Text(
                  'Gender helps calculate more accurate calorie and macro recommendations',
                  style: textTheme.bodySmall?.copyWith(
                    color: Colors.white.withOpacity(0.9),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
          ],
        ),
      ),
      child2: const SizedBox.shrink(),
      child3: const SizedBox.shrink(),
    );
  }

  /// Cycle Syncing Slide
  Widget _buildCycleSyncSlide() {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    final textTheme = Theme.of(context).textTheme;
    final isMale = _selectedGender?.toLowerCase() == 'male';
    final shouldShowInfoOnly = _selectedGender == null || isMale;

    return _buildPage(
      textTheme: textTheme,
      title: "Sync the Menu to Your Body.",
      description: shouldShowInfoOnly
          ? "Cycle syncing is available for Chefs with menstrual cycles. If you need this later, just let me know in Settings."
          : "Different weeks require different fuel. If you have a cycle, I can gently adapt your nutritional targets to match your hormonal phases.",
      child1: shouldShowInfoOnly
          ? Container(
              padding: EdgeInsets.all(getPercentageWidth(5, context)),
              decoration: BoxDecoration(
                color: isDarkMode
                    ? kDarkGrey.withValues(alpha: 0.3)
                    : kLightGrey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: kAccent,
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: kAccent,
                    size: getIconScale(8, context),
                  ),
                  SizedBox(width: getPercentageWidth(3, context)),
                  Expanded(
                    child: Text(
                      "Let me adjust your nutritional targets based on your cycle phase. This is exclusively available for Chefs with menstrual cycles",
                      style: textTheme.bodyMedium?.copyWith(
                        color: isDarkMode ? kWhite : kDarkGrey,
                      ),
                    ),
                  ),
                ],
              ),
            )
          : OnboardingCycleSyncScreen(
              isDarkMode: isDarkMode,
              isEnabled: _cycleSyncEnabled,
              lastPeriodStart: _cycleLastPeriodStart,
              cycleLengthController: _cycleLengthController,
              onToggle: () {
                setState(() {
                  _cycleSyncEnabled = !_cycleSyncEnabled;
                  // Set a sensible default date when turning on if none selected yet
                  if (_cycleSyncEnabled && _cycleLastPeriodStart == null) {
                    _cycleLastPeriodStart =
                        DateTime.now().subtract(const Duration(days: 3));
                  }
                  _validateInputs();
                });
              },
              onPickDate: () async {
                final now = DateTime.now();
                final initialDate = _cycleLastPeriodStart ?? now;
                final picked = await showDatePicker(
                  context: context,
                  initialDate: initialDate,
                  firstDate: now.subtract(const Duration(days: 90)),
                  lastDate: now,
                  builder: (context, child) {
                    return Theme(
                      data: getDatePickerTheme(context, isDarkMode).copyWith(
                        colorScheme: isDarkMode
                            ? ColorScheme.dark(
                                surface: kDarkGrey,
                                primary: kAccent,
                                onPrimary: kWhite.withValues(
                                    alpha: 0.5), // Selected date text color
                                onSurface: kAccent,
                              )
                            : ColorScheme.light(
                                primary: kAccent,
                                onPrimary: kDarkGrey.withValues(
                                    alpha: 0.5), // Selected date text color
                                onSurface: kDarkGrey,
                              ),
                      ),
                      child: child!,
                    );
                  },
                );
                if (picked != null && mounted) {
                  setState(() {
                    _cycleLastPeriodStart = picked;
                    _validateInputs();
                  });
                }
              },
            ),
      child2: const SizedBox.shrink(),
      child3: const SizedBox.shrink(),
    );
  }
}

/// Custom input formatter for date input (dd-mm-yyyy)
class DateInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;

    // Remove all non-digits
    final digitsOnly = text.replaceAll(RegExp(r'[^\d]'), '');

    // Limit to 8 digits (ddmmyyyy)
    final limitedDigits =
        digitsOnly.length > 8 ? digitsOnly.substring(0, 8) : digitsOnly;

    // Format with dashes
    String formatted = '';
    for (int i = 0; i < limitedDigits.length; i++) {
      if (i == 2 || i == 4) {
        formatted += '-';
      }
      formatted += limitedDigits[i];
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
