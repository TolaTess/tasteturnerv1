import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';
import '../data_models/user_data_model.dart';
import '../helper/utils.dart';
import '../pages/dietary_choose_screen.dart';
import '../pages/safe_text_field.dart';
import '../themes/theme_provider.dart';
import '../widgets/bottom_nav.dart';

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
  final TextEditingController heightController = TextEditingController();
  final TextEditingController weightController = TextEditingController();
  final TextEditingController targetWeightController = TextEditingController();
  final TextEditingController dobController = TextEditingController();
  String selectedSex = '';
  String selectedActivityLevel = '';
  String selectedHeightUnit = 'cm';
  String selectedWeightUnit = 'kg';
  List<String> selectedGoals = [];
  bool enableAITrial = false;
  bool syncHealthData = false;
  bool _isNextEnabled = false;

  // Add dietary preferences
  String selectedDiet = '';
  Set<String> selectedAllergies = {};
  String selectedCuisineType = '';

  // Add this to your state variables
  bool _isTextVisible = false;

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
    heightController.dispose();
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
        location: '',
        userType: 'user',
        isPremium: enableAITrial,
        syncHealth: syncHealthData,
        settings: {
          'waterIntake': '2000',
          'foodGoal': '2000',
          "height": "${heightController.text} $selectedHeightUnit",
          'goalWeight': "${targetWeightController.text} $selectedWeightUnit",
          'startingWeight': "${weightController.text} $selectedWeightUnit",
          "currentWeight": "${weightController.text} $selectedWeightUnit",
          'fitnessGoal': selectedGoals.isNotEmpty
              ? selectedGoals.first
              : 'General Fitness',
          'targetSteps': '10000',
          'dietPreference': selectedDiet.isNotEmpty ? selectedDiet : 'Balanced',
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
      );

      try {
        // Save user data to Firestore
        await firestore.collection('users').doc(widget.userId).set(
              newUser.toMap(),
              SetOptions(merge: true),
            );

        // Set current user
        userService.currentUser = newUser;
        userService.userId = widget.userId;

        // Save to local storage using toJson()
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('userData', jsonEncode(newUser.toJson()));

        // Create buddy chat
        final String buddyChatId =
            await chatController.getOrCreateChatId(widget.userId, 'buddy');

        await firestore.collection('users').doc(widget.userId).set(
          {'buddyChatId': buddyChatId},
          SetOptions(merge: true),
        );

        await prefs.setString('buddyChatId', buddyChatId);

        // Close loading dialog
        Get.back();

        // Only navigate if all the above operations succeeded
        Get.offAll(() => const BottomNavSec());
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
    }
  }

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
                    _buildGoalsPage(),
                    _buildPreferencePage(),
                    _buildMeasurementsPage(),
                    _buildSettingsPage(),
                    _buildFeatureTourPage(),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: _buildNavigationButtons(),
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
      title: "Welcome to $appName!",
      child1: SafeTextFormField(
        controller: nameController,
        style: const TextStyle(color: kDarkGrey),
        onChanged: (_) => _validateInputs(),
        decoration: InputDecoration(
          filled: true,
          fillColor: const Color(0xFFF3F3F3),
          enabledBorder: outlineInputBorder(10),
          focusedBorder: outlineInputBorder(10),
          border: outlineInputBorder(10),
          labelStyle: const TextStyle(color: Color(0xffefefef)),
          hintStyle: const TextStyle(color: kLightGrey),
          hintText: "Enter your name",
          floatingLabelBehavior: FloatingLabelBehavior.always,
          contentPadding: const EdgeInsets.only(
            top: 16,
            bottom: 16,
            right: 10,
            left: 10,
          ),
        ),
      ),
      child2: SafeTextFormField(
        controller: dobController,
        style: const TextStyle(color: kDarkGrey),
        decoration: InputDecoration(
          filled: true,
          fillColor: const Color(0xFFF3F3F3),
          enabledBorder: outlineInputBorder(10),
          focusedBorder: outlineInputBorder(10),
          border: outlineInputBorder(10),
          labelStyle: const TextStyle(color: Color(0xffefefef)),
          hintStyle: const TextStyle(color: kLightGrey),
          hintText: "Enter your date of birth (MM-dd)",
          floatingLabelBehavior: FloatingLabelBehavior.always,
          contentPadding: const EdgeInsets.only(
            top: 16,
            bottom: 16,
            right: 10,
            left: 10,
          ),
        ),
      ),
      child3: const SizedBox.shrink(),
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
        'title': 'Log Your Meals',
        'description': 'Track your nutrition and build healthy habits',
        'icon': Icons.restaurant_menu
      },
      {
        'title': 'Spin the Wheel',
        'description': 'Discover exciting new recipes and meal ideas',
        'icon': Icons.refresh
      },
      {
        'title': 'Chat with Tasty',
        'description':
            'Get personalized nutrition advice and recipe meal plans',
        'icon': Icons.chat_bubble
      }
    ];

    return _buildPage(
      title: "Key Features",
      description: "Here's are some of the features you can use with $appName:",
      child1: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: kDarkGrey,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: features
              .map((feature) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: ListTile(
                      leading: Icon(
                        feature['icon'] as IconData,
                        color: kAccentLight,
                        size: 32,
                      ),
                      title: Text(
                        feature['title'] as String,
                        style: const TextStyle(
                          color: kWhite,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        feature['description'] as String,
                        style: const TextStyle(
                          color: kWhite,
                          fontSize: 14,
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
  Widget _buildGoalsPage() {
    return _buildPage(
      title: "What are your goals?",
      child1: Theme(
        data: ThemeData(
          checkboxTheme: CheckboxThemeData(
            fillColor: WidgetStateProperty.resolveWith<Color>((states) {
              if (states.contains(WidgetState.selected)) {
                return kAccentLight;
              }
              return kWhite;
            }),
            checkColor: WidgetStateProperty.all<Color>(kWhite),
          ),
        ),
        child: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: kDarkGrey,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: healthGoals.map((goal) {
              return CheckboxListTile(
                title: Text(
                  goal,
                  style: const TextStyle(color: kWhite),
                ),
                value: selectedGoals.contains(goal),
                onChanged: (value) {
                  setState(() {
                    value!
                        ? selectedGoals.add(goal)
                        : selectedGoals.remove(goal);
                    _validateInputs();
                  });
                },
              );
            }).toList(),
          ),
        ),
      ),
      description: 'Select your goals to help us personalize your experience.',
      child2: const SizedBox.shrink(),
      child3: const SizedBox.shrink(),
    );
  }

  /// Combined Measurements Page
  Widget _buildMeasurementsPage() {
    return _buildPage(
      title: "Your Body Measurements",
      description:
          "Enter your height and weight details to keep track of your progress (optional).",
      child1: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: kDarkGrey,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Height:",
                  style: TextStyle(
                    color: kWhite,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 10),
                _buildMeasurementInput(
                  heightController,
                  ["cm", "ft"],
                  selectedHeightUnit,
                  (value) {
                    setState(() {
                      selectedHeightUnit = value;
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
        ],
      ),
      child2: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: kDarkGrey,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Current Weight:",
              style: TextStyle(
                color: kWhite,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 10),
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
      child3: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: kDarkGrey,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Target Weight:",
              style: TextStyle(
                color: kWhite,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 10),
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
    );
  }

  /// Combined Settings Page
  Widget _buildSettingsPage() {
    return _buildPage(
      title: "App Settings",
      description: "Customize your app experience and enable features.",
      child1: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: kDarkGrey,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            SwitchListTile(
              title: const Text(
                "Enable Dark Mode",
                style: TextStyle(
                  color: kWhite,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              subtitle: const Text(
                "Switch between light and dark theme",
                style: TextStyle(
                  color: kWhite,
                  fontSize: 12,
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
            const Divider(color: kWhite, height: 32),
            SwitchListTile(
              title: const Text(
                "Enable AI Assistant",
                style: TextStyle(
                  color: kWhite,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              subtitle: const Text(
                "Go Premium for personalized AI guidance and support - 30 days free trial",
                style: TextStyle(
                  color: kWhite,
                  fontSize: 12,
                ),
              ),
              value: enableAITrial,
              onChanged: (value) {
                setState(() {
                  enableAITrial = value;
                  _validateInputs();
                });
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
  }) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            title.contains("Welcome to $appName!")
                ? const SizedBox(height: 70)
                : const SizedBox(height: 30),
            title.isNotEmpty
                ? Text(
                    title,
                    style: const TextStyle(
                      fontSize: 20,
                      overflow: TextOverflow.ellipsis,
                      fontWeight: FontWeight.w600,
                    ),
                  )
                : const SizedBox.shrink(),
            const SizedBox(height: 20),
            Text(
              description,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color:
                    getThemeProvider(context).isDarkMode ? kWhite : kDarkGrey,
              ),
            ),
            const SizedBox(height: 50),
            const SizedBox(height: 20),
            child1,
            const SizedBox(height: 20),
            child2,
            const SizedBox(height: 20),
            child3,
            const SizedBox(height: 50),
            if (!title.contains("Key Features") &&
                !title.contains("What are your goals?") &&
                !title.contains("Your Body Measurements") &&
                !title.contains("App Settings"))
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0.8, end: 1.0),
                duration: const Duration(milliseconds: 1500),
                curve: Curves.elasticOut,
                builder: (context, scale, child) {
                  return Transform.scale(
                    scale: scale,
                    child: AnimatedBuilder(
                      animation: _bounceController,
                      builder: (context, child) {
                        return Transform.translate(
                          offset: Offset(
                            sin(DateTime.now().millisecondsSinceEpoch / 300) *
                                3,
                            cos(DateTime.now().millisecondsSinceEpoch / 300) *
                                3,
                          ),
                          child: child,
                        );
                      },
                      child: const CircleAvatar(
                        backgroundColor: kAccentLight,
                        radius: 100,
                        backgroundImage: AssetImage(
                          'assets/images/tasty/tasty_splash.png',
                        ),
                      ),
                    ),
                  );
                },
              ),
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
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFFF3F3F3),
              enabledBorder: outlineInputBorder(10),
              focusedBorder: outlineInputBorder(10),
              border: outlineInputBorder(10),
              labelStyle: const TextStyle(color: Color(0xffefefef)),
              hintStyle: const TextStyle(color: kLightGrey),
              hintText: "Enter your height",
              floatingLabelBehavior: FloatingLabelBehavior.always,
              contentPadding: const EdgeInsets.only(
                top: 10,
                bottom: 10,
                right: 10,
                left: 10,
              ),
            ),
            onChanged: onTextChanged,
          ),
        ),
        const SizedBox(width: 10),
        Container(
          decoration: BoxDecoration(
            color: kWhite,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: kDarkGrey,
              width: 1.5,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: selectedUnit,
              items: units
                  .map((u) => DropdownMenuItem(
                        value: u,
                        child: Text(
                          u,
                          style: const TextStyle(color: kDarkGrey),
                        ),
                      ))
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  onUnitChange(value);
                }
              },
              dropdownColor: kWhite,
              icon: const Icon(Icons.arrow_drop_down, color: kDarkGrey),
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
  Widget _buildNavigationButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          backgroundColor: _isNextEnabled ? kAccent : kLightGrey,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(50),
          ),
        ),
        onPressed: _isNextEnabled ? _nextPage : null,
        child: Text(
          _currentPage == 5 ? "Finish" : "Next",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: _isNextEnabled ? kWhite : kDarkGrey,
          ),
        ),
      ),
    );
  }
}
