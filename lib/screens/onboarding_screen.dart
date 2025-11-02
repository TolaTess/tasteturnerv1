import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';
import '../data_models/user_data_model.dart';
import '../helper/utils.dart';
import '../pages/safe_text_field.dart';
import '../screens/add_food_screen.dart';
import '../service/badge_service.dart';
import '../service/notification_service.dart';
import '../service/notification_handler_service.dart';
import '../service/hybrid_notification_service.dart';
import '../widgets/bottom_nav.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class OnboardingScreen extends StatefulWidget {
  final String userId;
  final String? displayName;
  const OnboardingScreen({super.key, required this.userId, this.displayName});

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
  bool _isEditingName = false; // Track if user is editing their name

  // List<Map<String, String>> familyMembers = [];

  @override
  void initState() {
    super.initState();
    if (widget.displayName != null && widget.displayName!.isNotEmpty) {
      nameController.text = widget.displayName!;
      debugPrint("Display Onboarding Name: ${widget.displayName}");
      _validateInputs(); // Validate to enable Next button
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
    nameController.dispose();
    super.dispose();
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
    return profaneWords.any(text.toLowerCase().contains);
  }

  /// ✅ Check if all required fields are filled before enabling "Next"
  void _validateInputs() {
    setState(() {
      switch (_currentPage) {
        case 0:
          final name = nameController.text.trim();
          // Only name is required
          _isNextEnabled = name.isNotEmpty && !isProfane(name);
          break;
        case 1:
        case 2:
        case 3:
        case 4:
          _isNextEnabled = true; // Visual slides - always enabled
          break;
        default:
          _isNextEnabled = false;
      }
    });
  }

  void _submitOnboarding() async {
    try {
      if (widget.userId.isEmpty) {
        debugPrint("Error: User ID is missing.");
        return;
      }

      Get.dialog(
        const Center(
            child: CircularProgressIndicator(
          color: kAccent,
        )),
        barrierDismissible: false,
      );

      final newUser = UserModel(
        userId: widget.userId,
        displayName: nameController.text.trim(),
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
          'gender': null, // Null - will trigger prompt
          'notificationsEnabled': _notificationsEnabled,
          'notificationPreferenceSet': true, // User has made a choice
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
            await chatController.getOrCreateChatId(widget.userId, 'buddy');

        await firestore.collection('users').doc(widget.userId).set(
          {'buddyChatId': buddyChatId},
          SetOptions(merge: true),
        );

        userService.setBuddyChatId(buddyChatId);

        final formattedDate = DateFormat('yyyy-MM-dd').format(DateTime.now());

        await helperController.saveMealPlan(
            widget.userId, formattedDate, 'welcome_day');

        if (widget.userId != tastyId3 || widget.userId != tastyId4) {
          await friendController.followFriend(
              widget.userId, tastyId, 'Tasty AI', context);
        }

        await prefs.setBool('is_first_time_user', true);

        // Initialize notifications if enabled
        if (_notificationsEnabled) {
          try {
            final notificationService = Get.find<NotificationService>();
            // Initialize without requesting permissions
            await notificationService.initNotification(
              onNotificationTapped: (String? payload) {
                if (payload != null) {
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
            try {
              await notificationService.requestIOSPermissions();
              debugPrint(
                  'iOS notification permissions requested during onboarding');
            } catch (e) {
              debugPrint('Error requesting iOS notification permissions: $e');
            }

            // Initialize hybrid notification service for Android/iOS
            try {
              final hybridNotificationService =
                  Get.find<HybridNotificationService>();
              await hybridNotificationService.initializeHybridNotifications();
              debugPrint('Hybrid notifications initialized during onboarding');
            } catch (e) {
              debugPrint('Error initializing hybrid notifications: $e');
            }

            debugPrint('Notifications enabled during onboarding');
          } catch (e) {
            debugPrint('Error initializing notifications: $e');
          }
        }

        // Close loading dialog
        Get.back();

        // Navigate to main app with bottom navigation
        Get.offAll(() => const BottomNavSec());

        try {
          await requestUMPConsent();
        } catch (e) {
          debugPrint("Error requesting UMP consent: $e");
        }
      } catch (e) {
        // Close loading dialog
        Get.back();

        debugPrint("Error saving user data: $e");
        Get.snackbar(
          'Error',
          'Failed to save user data. Please try again.',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      debugPrint("Error in _submitOnboarding: $e");
      Get.snackbar(
        'Error',
        'Something went wrong. Please try again.',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      Get.back();
    }
  }

  // List<Map<String, dynamic>> saveFamilyMembers() {
  //   return familyMembers.map((e) => Map<String, dynamic>.from(e)).toList();
  // }

  void _handleNotificationTap(String payload) async {
    try {
      debugPrint('Notification tapped: $payload');

      if (payload.contains('meal_plan_reminder') ||
          payload.contains('evening_review') ||
          payload.contains('water_reminder')) {
        if (payload.contains('meal_plan_reminder')) {
          Get.to(() => const BottomNavSec(selectedIndex: 4));
        } else if (payload.contains('water_reminder')) {
          Get.to(() => AddFoodScreen(date: DateTime.now()));
        } else if (payload.contains('evening_review')) {
          Get.to(() => AddFoodScreen(date: DateTime.now()));
        }
      } else {
        try {
          final handlerService = Get.find<NotificationHandlerService>();
          await handlerService.handleNotificationPayload(payload);
        } catch (e) {
          debugPrint('Error handling complex notification: $e');
          showTastySnackbar(
              'Something went wrong', 'Please try again later', Get.context!,
              backgroundColor: kRed);
        }
      }
    } catch (e) {
      debugPrint('Error handling notification tap: $e');
      showTastySnackbar(
          'Something went wrong', 'Please try again later', Get.context!,
          backgroundColor: kRed);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: GestureDetector(
        onTap: () {
          // Dismiss keyboard when tapping outside
          FocusScope.of(context).unfocus();
        },
        child: Container(
          // decoration: const BoxDecoration(
          //   color: kAccentLight,
          // ),
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
                        _validateInputs();
                      });
                    },
                    children: [
                      _buildNamePage(),
                      _buildMealPlanningSlide(),
                      _buildTrackingSlide(),
                      _buildCommunitySlide(),
                      _buildSettingsSlide(),
                    ],
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
  Widget _buildNamePage() {
    final bool hasExistingName =
        widget.displayName != null && widget.displayName!.isNotEmpty;
    final bool showTextField = !hasExistingName || _isEditingName;
    final textTheme = Theme.of(context).textTheme;
    final isDarkMode = getThemeProvider(context).isDarkMode;

    return _buildPage(
      textTheme: textTheme,
      title: "Welcome to $appName!",
      child1: showTextField
          ? Container(
              padding: EdgeInsets.all(getPercentageWidth(5, context)),
              decoration: BoxDecoration(
                color: kDarkGrey,
                borderRadius: BorderRadius.circular(10),
              ),
              child: SafeTextFormField(
                controller: nameController,
                autofocus: _isEditingName,
                style: TextStyle(
                    color: kDarkGrey, fontSize: getTextScale(3.5, context)),
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
            )
          : GestureDetector(
              onTap: () {
                setState(() {
                  _isEditingName = true;
                });
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    nameController.text,
                    style: textTheme.displaySmall?.copyWith(
                      color: isDarkMode ? kWhite : kDarkGrey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(width: getPercentageWidth(3, context)),
                  Icon(
                    Icons.edit,
                    color: kAccent,
                    size: getIconScale(7, context),
                  ),
                ],
              ),
            ),
      child2: const SizedBox.shrink(),
      child3: Image.asset(
        'assets/images/tasty/tasty.png',
        height: getPercentageHeight(40, context),
        width: getPercentageWidth(50, context),
        fit: BoxFit.contain,
      ),
      description: hasExistingName && !_isEditingName
          ? 'Great to see you!\n\nYour name looks good. Tap the edit icon if you\'d like to change it, or continue to explore what $appName can do for you.'
          : 'Let\'s get started!\n\nTell us your name and we\'ll show you what $appName can do for you.',
    );
  }

  /// Visual Feature Slide 1: Personalized Meal Plans & Custom Diets
  Widget _buildMealPlanningSlide() {
    final userName = nameController.text.trim().isNotEmpty
        ? nameController.text.trim()
        : "there";

    return _buildPage(
      textTheme: Theme.of(context).textTheme,
      title: "Hi $userName!\nWe can help you Plan Your Perfect Meals",
      description:
          "Get delicious, personalized meal plans designed to fit your unique dietary needs and health goals, including programs like No Sugar or Intermittent Fasting",
      child1: Container(
        padding: EdgeInsets.all(getPercentageWidth(5, context)),
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

            SizedBox(height: getPercentageHeight(3, context)),
            Text(
              "Personalized Meal Plans",
              style: TextStyle(
                color: Colors.white,
                fontSize: getTextScale(5, context),
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: getPercentageHeight(2, context)),
            // Feature boxes in 2x2 grid
            Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildFeatureBox(
                      context,
                      "Programs",
                      kPurple.withValues(alpha: 0.5), // Green
                      Icons.restaurant_menu,
                    ),
                    _buildFeatureBox(
                      context,
                      "Calender",
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
                      "Spin Wheel",
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
      title: "Meet Your AI Nutrition Coach",
      description:
          "Snap a photo of your meal and let our Tasty AI coach provide instant nutritional breakdowns, helping you make smarter food choices effortlessly",
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
              "Tasty AI Coach",
              style: TextStyle(
                color: Colors.white,
                fontSize: getTextScale(5, context),
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: getPercentageHeight(2, context)),
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
                      "Instant Insights",
                      kBlue.withValues(alpha: 0.5), // Cyan
                      Icons.lightbulb,
                    ),
                  ],
                ),
                SizedBox(height: getPercentageHeight(2, context)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildFeatureBox(
                      context,
                      "Chat",
                      kAccentLight.withValues(alpha: 0.5), // Deep Orange
                      Icons.chat,
                    ),
                    _buildFeatureBox(
                      context,
                      "Nutrition Summary",
                      kAccent.withValues(alpha: 0.5), // Deep Purple
                      Icons.recommend,
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
      title: "Track Your Journey!",
      description:
          "Easily track your macros and calories to stay on target. Plus, get auto-generated shopping lists to make healthy eating convenient and stress-free",
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
              "Effortless Tracking",
              style: TextStyle(
                color: Colors.white,
                fontSize: getTextScale(5, context),
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: getPercentageHeight(2, context)),
            // Feature boxes in 2x2 grid
            Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildFeatureBox(
                      context,
                      "Track Macros",
                      kPurple.withValues(alpha: 0.5), // Green
                      Icons.track_changes,
                    ),
                    _buildFeatureBox(
                      context,
                      "Weight Progress",
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
                      "Shopping Lists",
                      kPink.withValues(alpha: 0.5), // Orange
                      Icons.shopping_cart,
                    ),
                    _buildFeatureBox(
                      context,
                      "Visual Tracking",
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

  /// Settings Slide: Notifications & Dark Mode
  Widget _buildSettingsSlide() {
    final userName = nameController.text.trim().isNotEmpty
        ? nameController.text.trim()
        : "there";

    return _buildPage(
      textTheme: Theme.of(context).textTheme,
      title: "Almost There, $userName!",
      description:
          "Customize your experience with notifications and theme preferences",
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
                          "Enable Notifications",
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

  /// Build square feature box with icon and title
  Widget _buildFeatureBox(
      BuildContext context, String text, Color color, IconData icon) {
    return Container(
      width: getPercentageWidth(20, context), // Even smaller width
      height: getPercentageWidth(20, context), // Even smaller height
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
            maxLines: 2,
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

      if (_currentPage < 4) {
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
          _currentPage == 4 ? "Get Started" : "Next",
          textAlign: TextAlign.center,
          style: textTheme.displayMedium?.copyWith(
              fontWeight: FontWeight.w500,
              fontSize: getTextScale(5, context),
              color: _isNextEnabled ? kWhite : kDarkGrey),
        ),
      ),
    );
  }

  Future<void> requestUMPConsent() async {
    final params = ConsentRequestParameters();
    ConsentInformation.instance.requestConsentInfoUpdate(
      params,
      () {
        // Consent info updated successfully
        ConsentForm.loadAndShowConsentFormIfRequired((formError) {
          if (formError != null) {
            debugPrint('formError: $formError');
            // Consent gathering failed, but you can still check if ads can be requested
            _setFirebaseConsent();
          } else {
            debugPrint('formError: null');
            // Consent has been gathered
            _setFirebaseConsent();
          }
        });
      },
      (FormError error) {
        // Handle the error updating consent info
        // Optionally, you can still check if ads can be requested
        _setFirebaseConsent();
      },
    );
  }

  Future<void> _setFirebaseConsent() async {
    final canRequest = await ConsentInformation.instance.canRequestAds();
    await FirebaseAnalytics.instance.setConsent(
      adStorageConsentGranted: canRequest,
      analyticsStorageConsentGranted: canRequest,
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
