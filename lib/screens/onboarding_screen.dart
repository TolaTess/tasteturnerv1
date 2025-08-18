import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tasteturner/helper/helper_files.dart';
import '../constants.dart';
import '../data_models/user_data_model.dart';
import '../helper/utils.dart';
import '../pages/dietary_choose_screen.dart';
import '../pages/safe_text_field.dart';
import '../service/badge_service.dart';
import '../themes/theme_provider.dart';
import 'post_onboarding_walkthrough.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class OnboardingScreen extends StatefulWidget {
  final String userId;
  const OnboardingScreen({super.key, required this.userId});

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
  final TextEditingController ageController = TextEditingController();
  final TextEditingController locationController = TextEditingController();
  final TextEditingController weightController = TextEditingController();
  final TextEditingController targetWeightController = TextEditingController();
  final TextEditingController dobController = TextEditingController();
  String selectedSex = '';
  String selectedGender = ''; // Add gender selection
  String selectedActivityLevel = '';
  String selectedHeightUnit = 'cm';
  String selectedWeightUnit = 'kg';
  List<String> selectedGoals = [];
  bool enableAITrial = false;
  bool _isNextEnabled = false;

  // Add dietary preferences
  String selectedDiet = '';
  Set<String> selectedAllergies = {};
  String selectedCuisineType = '';

  // List<Map<String, String>> familyMembers = [];

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _bounceController.dispose();
    dobController.dispose();
    nameController.dispose();
    ageController.dispose();
    locationController.dispose();
    weightController.dispose();
    targetWeightController.dispose();
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
          _isNextEnabled = name.isNotEmpty && !isProfane(name);
          break;
        case 1:
          _isNextEnabled = true; // Feature tour page - always enabled
          break;
        case 2:
          _isNextEnabled = selectedGoals.isNotEmpty;
          break;
        case 3:
          _isNextEnabled = true;
          break;
        case 4:
          _isNextEnabled = true; // Settings page - always enabled
          break;
        case 5:
          _isNextEnabled = true; // Feature tour page - always enabled
          break;
        default:
          _isNextEnabled = false;
      }
    });
  }

  void _submitOnboarding() async {
    try {
      if (widget.userId.isEmpty) {
        print("Error: User ID is missing.");
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
        dob: dobController.text,
        profileImage: '',
        userType: 'user',
        isPremium: enableAITrial,
        created_At: DateTime.now(),
        freeTrialDate: DateTime.now().add(const Duration(days: 30)),
        settings: <String, dynamic>{
          'waterIntake': '2000',
          'foodGoal': calculateRecommendedCaloriesFromGoal(
              selectedGoals.first, selectedGender),
          'proteinGoal': calculateRecommendedMacrosGoals(
              selectedGoals.first, selectedGender)['protein'],
          'carbsGoal': calculateRecommendedMacrosGoals(
              selectedGoals.first, selectedGender)['carbs'],
          'fatGoal': calculateRecommendedMacrosGoals(
              selectedGoals.first, selectedGender)['fat'],
          'goalWeight': "${targetWeightController.text} $selectedWeightUnit",
          'startingWeight': "${weightController.text} $selectedWeightUnit",
          "currentWeight": "${weightController.text} $selectedWeightUnit",
          'fitnessGoal':
              selectedGoals.isNotEmpty ? selectedGoals.first : 'Healthy Eating',
          'targetSteps': '10000',
          'dietPreference': selectedDiet.isNotEmpty ? selectedDiet : 'Balanced',
          'gender': selectedGender.isNotEmpty ? selectedGender : null,
        },
        preferences: {
          'diet': selectedDiet,
          'allergies': selectedAllergies.toList(),
          'cuisineType':
              selectedCuisineType.isNotEmpty ? selectedCuisineType : 'Balanced',
          'proteinDishes': 2,
          'grainDishes': 2,
          'vegDishes': 3,
          'lastUpdated': FieldValue.serverTimestamp(),
        },
        // familyMembers:
        //     familyMembers.map((f) => FamilyMember.fromMap(f)).toList(),
        // familyMode: familyMembers.isNotEmpty,
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

        await friendController.followFriend(
            widget.userId, tastyId, 'Tasty AI', context);

        await prefs.setBool('is_first_time_user', true);

        // Close loading dialog
        Get.back();

        // Only navigate if all the above operations succeeded
        Get.offAll(() => const PostOnboardingWalkthrough());

        try {
          await requestUMPConsent();
        } catch (e) {
          print("Error requesting UMP consent: $e");
        }
      } catch (e) {
        // Close loading dialog
        Get.back();

        print("Error saving user data: $e");
        Get.snackbar(
          'Error',
          'Failed to save user data. Please try again.',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      print("Error in _submitOnboarding: $e");
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Container(
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
                    setState(() {
                      _currentPage = value;
                      _validateInputs();
                    });
                  },
                  children: [
                    _buildNamePage(),
                    _buildGoalsPage(textTheme: Theme.of(context).textTheme),
                    _buildPreferencePage(),
                    _buildMeasurementsPage(),
                    _buildSettingsPage(),
                    _buildFeatureTourPage(),
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
    );
  }

  /// Name Input Page
  Widget _buildNamePage() {
    return _buildPage(
      textTheme: Theme.of(context).textTheme,
      title: "Welcome to $appName!",
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
      child2: Container(
        padding: EdgeInsets.all(getPercentageWidth(5, context)),
        decoration: BoxDecoration(
          color: kDarkGrey,
          borderRadius: BorderRadius.circular(10),
        ),
        child: SafeTextFormField(
          controller: dobController,
          style:
              TextStyle(color: kDarkGrey, fontSize: getTextScale(3.5, context)),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFF3F3F3),
            enabledBorder: outlineInputBorder(10),
            focusedBorder: outlineInputBorder(10),
            border: outlineInputBorder(10),
            labelStyle: const TextStyle(color: Color(0xffefefef)),
            hintStyle: TextStyle(
                color: kLightGrey, fontSize: getTextScale(3.5, context)),
            hintText: "Enter your date of birth (MM-dd) (optional)",
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
      child3: Column(
        children: [
          Text(
            "Gender (Optional)",
            style: TextStyle(
              color: getThemeProvider(context).isDarkMode ? kWhite : kDarkGrey,
              fontSize: getTextScale(3.5, context),
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: getPercentageHeight(2, context)),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      selectedGender = 'male';
                    });
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      vertical: getPercentageHeight(2, context),
                      horizontal: getPercentageWidth(3, context),
                    ),
                    decoration: BoxDecoration(
                      color: selectedGender == 'male'
                          ? kAccentLight
                          : Colors.transparent,
                      border: Border.all(
                        color: selectedGender == 'male'
                            ? kAccentLight
                            : getThemeProvider(context).isDarkMode
                                ? kWhite
                                : kDarkGrey,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Text(
                      'Male',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: selectedGender == 'male'
                            ? kWhite
                            : getThemeProvider(context).isDarkMode
                                ? kWhite
                                : kDarkGrey,
                        fontSize: getTextScale(3.5, context),
                        fontWeight: selectedGender == 'male'
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
                      selectedGender = 'female';
                    });
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      vertical: getPercentageHeight(2, context),
                      horizontal: getPercentageWidth(3, context),
                    ),
                    decoration: BoxDecoration(
                      color: selectedGender == 'female'
                          ? kAccentLight
                          : Colors.transparent,
                      border: Border.all(
                        color: selectedGender == 'female'
                            ? kAccentLight
                            : getThemeProvider(context).isDarkMode
                                ? kWhite
                                : kDarkGrey,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Text(
                      'Female',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: selectedGender == 'female'
                            ? kWhite
                            : getThemeProvider(context).isDarkMode
                                ? kWhite
                                : kDarkGrey,
                        fontSize: getTextScale(3.5, context),
                        fontWeight: selectedGender == 'female'
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (selectedGender.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(top: getPercentageHeight(1, context)),
              child: Text(
                'Gender helps calculate more accurate calorie and macro recommendations',
                style: TextStyle(
                  color: kLightGrey,
                  fontSize: getTextScale(2.8, context),
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
      description:
          'Let\'s personalize your experience with us by telling us a bit about you.',
    );
  }

  Widget _buildPreferencePage() {
    return ChooseDietScreen(
      isOnboarding: true,
      onPreferencesSelected: (diet, allergies, cuisineType) {
        setState(() {
          selectedDiet = diet;
          selectedAllergies = allergies;
          selectedCuisineType = cuisineType;
        });
      },
    );
  }

  /// Feature Tour Page
  Widget _buildFeatureTourPage() {
    final features = [
      {
        'title': 'Build Your Meal Plan',
        'description': 'Build healthy meal plans and track your nutrition',
        'icon': Icons.restaurant_menu
      },
      {
        'title': 'Spin the Wheel',
        'description': 'Discover exciting new recipes and meal ideas',
        'icon': Icons.refresh
      },
      {
        'title': 'Family Mode',
        'description':
            'Manage your family\'s meals and build healthy habits together',
        'icon': Icons.family_restroom
      },
      {
        'title': 'Plan in Advance',
        'description':
            'Add your special days and share them with your friends and family',
        'icon': Icons.calendar_month
      },
      {
        'title': 'Chat with Tasty AI',
        'description':
            'Get personalized meal plans, shopping lists and recipe ideas from Tasty AI',
        'icon': Icons.chat_bubble
      }
    ];

    return _buildPage(
      textTheme: Theme.of(context).textTheme,
      title: "Key Features",
      description: "Here's are some of the features you can use with $appName:",
      child1: Container(
        padding: EdgeInsets.all(getPercentageWidth(5, context)),
        decoration: BoxDecoration(
          color: kDarkGrey,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: features
              .map((feature) => Padding(
                    padding: EdgeInsets.symmetric(
                        vertical: getPercentageHeight(1, context)),
                    child: ListTile(
                      leading: Icon(
                        feature['icon'] as IconData,
                        color: kAccentLight,
                        size: getPercentageWidth(6, context),
                      ),
                      title: Text(
                        feature['title'] as String,
                        style: TextStyle(
                          color: kWhite,
                          fontSize: getTextScale(3.5, context),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        feature['description'] as String,
                        style: TextStyle(
                          color: kWhite,
                          fontSize: getTextScale(3, context),
                        ),
                      ),
                    ),
                  ))
              .toList(),
        ),
      ),
      child2: const SizedBox.shrink(),
      child3: const SizedBox.shrink(),
    );
  }

  /// Goals Selection Page
  Widget _buildGoalsPage({required TextTheme textTheme}) {
    return _buildPage(
      textTheme: textTheme,
      title: "How can we help you?",
      child1: Theme(
        data: ThemeData(
          radioTheme: RadioThemeData(
            fillColor: WidgetStateProperty.resolveWith<Color>((states) {
              if (states.contains(WidgetState.selected)) {
                return kAccentLight;
              }
              return kWhite;
            }),
          ),
        ),
        child: Container(
          padding: EdgeInsets.all(getPercentageWidth(5, context)),
          decoration: BoxDecoration(
            color: kDarkGrey,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: healthGoalsNoFamily.map((goal) {
              return RadioListTile<String>(
                title: Text(
                  goal,
                  style: textTheme.titleMedium?.copyWith(
                      color: selectedGoals.contains(goal)
                          ? kAccentLight
                          : kWhite,
                      fontSize: getTextScale(4, context)),
                ),
                value: goal,
                groupValue:
                    selectedGoals.isNotEmpty ? selectedGoals.first : null,
                onChanged: (value) async {
                  setState(() {
                    selectedGoals = value != null ? [value] : [];
                    _validateInputs();
                  });
                },
                activeColor: kAccentLight,
              );
            }).toList(),
          ),
        ),
      ),
      description:
          'When you select a goal, we will tailor our recommendations to your needs.',
      child2: const SizedBox.shrink(),
      child3: const SizedBox.shrink(),
    );
  }

  /// Combined Measurements Page
  Widget _buildMeasurementsPage() {
    return _buildPage(
      textTheme: Theme.of(context).textTheme,
      title: "Your Measurements",
      description:
          "Enter your weight details to keep track of your progress (optional).",
      child1: Container(
        padding: EdgeInsets.all(getPercentageWidth(5, context)),
        decoration: BoxDecoration(
          color: kDarkGrey,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Current Weight:",
              style: TextStyle(
                color: kWhite,
                fontSize: getTextScale(4, context),
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: getPercentageHeight(1, context)),
            _buildMeasurementInput(
              weightController,
              ["kg", "lb"],
              selectedWeightUnit,
              (value) {
                setState(() {
                  selectedWeightUnit = value;
                  _validateInputs();
                });
              },
              (value) {
                _validateInputs();
              },
            ),
          ],
        ),
      ),
      child2: Container(
        padding: EdgeInsets.all(getPercentageWidth(5, context)),
        decoration: BoxDecoration(
          color: kDarkGrey,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Target Weight:",
              style: TextStyle(
                color: kWhite,
                fontSize: getTextScale(4, context),
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: getPercentageHeight(1, context)),
            _buildMeasurementInput(
              targetWeightController,
              ["kg", "lb"],
              selectedWeightUnit,
              (value) {
                setState(() {
                  selectedWeightUnit = value;
                  _validateInputs();
                });
              },
              (value) {
                _validateInputs();
              },
            ),
          ],
        ),
      ),
      child3: const SizedBox.shrink(),
    );
  }

  /// Combined Settings Page
  Widget _buildSettingsPage() {
    return _buildPage(
      textTheme: Theme.of(context).textTheme,
      title: "App Settings",
      description: "Customize your app experience and enable features.",
      child1: Container(
        padding: EdgeInsets.all(getPercentageWidth(5, context)),
        decoration: BoxDecoration(
          color: kDarkGrey,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            SwitchListTile(
              title: Text(
                "Enable Dark Mode",
                style: TextStyle(
                  color: kWhite,
                  fontSize: getTextScale(4, context),
                  fontWeight: FontWeight.w500,
                ),
              ),
              subtitle: Text(
                "Switch between light and dark theme",
                style: TextStyle(
                  color: kWhite,
                  fontSize: getTextScale(3, context),
                ),
              ),
              value:
                  Provider.of<ThemeProvider>(context, listen: false).isDarkMode,
              onChanged: (value) {
                setState(() {
                  Provider.of<ThemeProvider>(context, listen: false)
                      .toggleTheme();
                });
              },
              activeColor: kAccentLight,
              inactiveTrackColor:
                  getThemeProvider(context).isDarkMode ? kWhite : kLightGrey,
              inactiveThumbColor:
                  getThemeProvider(context).isDarkMode ? kWhite : kLightGrey,
            ),
            Divider(color: kWhite, height: getPercentageHeight(4, context)),
            SwitchListTile(
              title: Text(
                "Enable AI Assistant",
                style: TextStyle(
                  color: kWhite,
                  fontSize: getTextScale(4, context),
                  fontWeight: FontWeight.w500,
                ),
              ),
              subtitle: Text(
                "Go Premium for personalized AI guidance and premium features - 30 days free trial",
                style: TextStyle(
                  color: kWhite,
                  fontSize: getTextScale(3, context),
                ),
              ),
              value: enableAITrial,
              onChanged: (value) async {
                setState(() {
                  enableAITrial = value;
                });
                if (value) {
                  final prefs = await SharedPreferences.getInstance();
                  prefs.setString(
                      'ai_trial_start_date', DateTime.now().toIso8601String());
                }
              },
              activeColor: kAccentLight,
              inactiveTrackColor:
                  getThemeProvider(context).isDarkMode ? kWhite : kLightGrey,
              inactiveThumbColor:
                  getThemeProvider(context).isDarkMode ? kWhite : kLightGrey,
            ),
          ],
        ),
      ),
      child2: const SizedBox.shrink(),
      child3: const SizedBox.shrink(),
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
                    style: textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: kAccent),
                  )
                : const SizedBox.shrink(),
            SizedBox(height: getPercentageHeight(2, context)),
            Text(
              description,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: getTextScale(3.5, context),
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

  Widget _buildMeasurementInput(
    TextEditingController controller,
    List<String> units,
    String selectedUnit,
    Function(String) onUnitChange,
    Function(String) onTextChanged,
  ) {
    return Row(
      children: [
        Expanded(
          child: SafeTextField(
            controller: controller,
            style: TextStyle(
              color: kDarkGrey,
              fontSize: getTextScale(3.5, context),
            ),
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFFF3F3F3),
              enabledBorder: outlineInputBorder(10),
              focusedBorder: outlineInputBorder(10),
              border: outlineInputBorder(10),
              labelStyle: const TextStyle(color: Color(0xffefefef)),
              hintStyle: TextStyle(
                  color: kLightGrey, fontSize: getTextScale(3.5, context)),
              hintText: "Enter your weight",
              floatingLabelBehavior: FloatingLabelBehavior.always,
              contentPadding: EdgeInsets.only(
                top: getPercentageHeight(1.5, context),
                bottom: getPercentageHeight(1.5, context),
                right: getPercentageWidth(2, context),
                left: getPercentageWidth(2, context),
              ),
            ),
            onChanged: onTextChanged,
          ),
        ),
        SizedBox(width: getPercentageWidth(2, context)),
        Container(
          decoration: BoxDecoration(
            color: kWhite,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: kDarkGrey,
              width: getPercentageWidth(0.5, context),
            ),
          ),
          padding:
              EdgeInsets.symmetric(horizontal: getPercentageWidth(3, context)),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: selectedUnit,
              items: units
                  .map((u) => DropdownMenuItem(
                        value: u,
                        child: Text(
                          u,
                          style: TextStyle(
                              color: kDarkGrey,
                              fontSize: getTextScale(3.5, context)),
                        ),
                      ))
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  onUnitChange(value);
                }
              },
              dropdownColor: kWhite,
              icon: Icon(Icons.arrow_drop_down,
                  color: kDarkGrey, size: getPercentageWidth(4, context)),
            ),
          ),
        ),
      ],
    );
  }

  void _nextPage() {
    if (_isNextEnabled) {
      if (_currentPage < 5) {
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
          _currentPage == 5 ? "Finish" : "Next",
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
            print('formError: $formError');
            // Consent gathering failed, but you can still check if ads can be requested
            _setFirebaseConsent();
          } else {
            print('formError: null');
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
