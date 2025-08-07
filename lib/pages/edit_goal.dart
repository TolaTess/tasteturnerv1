import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../constants.dart';
import '../helper/utils.dart';
import '../widgets/category_selector.dart';
import '../widgets/daily_routine_list.dart';
import '../widgets/icon_widget.dart';
import '../widgets/primary_button.dart';
import '../pages/family_member.dart';
import '../data_models/user_data_model.dart';
import 'safe_text_field.dart';

class NutritionSettingsPage extends StatefulWidget {
  final bool isRoutineExpand;
  final bool isHealthExpand;
  final bool isFamilyModeExpand;
  const NutritionSettingsPage(
      {super.key,
      this.isRoutineExpand = false,
      this.isHealthExpand = false,
      this.isFamilyModeExpand = false});

  @override
  _NutritionSettingsPageState createState() => _NutritionSettingsPageState();
}

class _NutritionSettingsPageState extends State<NutritionSettingsPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController waterController = TextEditingController();
  final TextEditingController foodController = TextEditingController();
  final TextEditingController goalWeightController = TextEditingController();
  final TextEditingController startingWeightController =
      TextEditingController();
  final TextEditingController currentWeightController = TextEditingController();
  final TextEditingController fitnessGoalController = TextEditingController();
  final TextEditingController dietPerfController = TextEditingController();
  final TextEditingController targetStepsController = TextEditingController();
  final TextEditingController heightController = TextEditingController();
  List<Map<String, dynamic>> _categoryDatasIngredient = [];
  String selectedDietCategoryId = '';
  String selectedDietCategoryName = '';
  bool isFamilyModeEnabled = false;

  @override
  void initState() {
    super.initState();

    _categoryDatasIngredient = [...helperController.category];

    final user = userService.currentUser.value;
    if (user != null) {
      final settings = user.settings;
      waterController.text = settings['waterIntake']?.toString() ?? '';
      foodController.text = settings['foodGoal'] ?? '';
      goalWeightController.text = settings['goalWeight']?.toString() ?? '';
      startingWeightController.text =
          settings['startingWeight']?.toString() ?? '';
      currentWeightController.text =
          settings['currentWeight']?.toString() ?? '';
      fitnessGoalController.text = settings['fitnessGoal']?.toString() ?? '';
      dietPerfController.text = settings['dietPreference']?.toString() ?? '';
      targetStepsController.text = settings['targetSteps']?.toString() ?? '';
      heightController.text = settings['height']?.toString() ?? '';

      // Initialize selectedDietCategoryId and Name from user settings if possible
      final dietPref = settings['dietPreference']?.toString() ?? '';
      final foundDiet = _categoryDatasIngredient.firstWhere(
        (cat) => cat['name'].toString().toLowerCase() == dietPref.toLowerCase(),
        orElse: () => _categoryDatasIngredient.isNotEmpty
            ? _categoryDatasIngredient[0]
            : {'id': '', 'name': ''},
      );
      selectedDietCategoryId = foundDiet['id'] ?? '';
      selectedDietCategoryName = foundDiet['name'] ?? '';
      dietPerfController.text = selectedDietCategoryName;

      // Initialize family mode from user data
      isFamilyModeEnabled = user.familyMode ?? false;
    }
  }

  @override
  void dispose() {
    waterController.dispose();
    foodController.dispose();
    goalWeightController.dispose();
    startingWeightController.dispose();
    currentWeightController.dispose();
    fitnessGoalController.dispose();
    dietPerfController.dispose();
    targetStepsController.dispose();
    heightController.dispose();
    super.dispose();
  }

  Future<void> _saveSettings() async {
    if (_formKey.currentState?.validate() ?? false) {
      try {
        // Prepare updated settings map
        final updatedSettings = {
          'waterIntake': waterController.text,
          'foodGoal': foodController.text,
          'goalWeight': goalWeightController.text,
          'startingWeight': startingWeightController.text,
          'currentWeight': currentWeightController.text,
          'fitnessGoal': fitnessGoalController.text,
          'dietPreference': dietPerfController.text,
          'targetSteps': targetStepsController.text,
          'height': heightController.text,
        };

        // Update both settings and familyMode
        await authController.updateUserData(
            {'settings': updatedSettings, 'familyMode': isFamilyModeEnabled});

        Get.snackbar('Success', 'Settings updated successfully!',
            snackPosition: SnackPosition.BOTTOM);

        Navigator.pop(context);
      } catch (e) {
        print('Error saving settings: $e');
        Get.snackbar('Error', 'Failed to save settings. Please try again.',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.red,
            colorText: Colors.white);
      }
    }
  }

  void _showFamilyMembersDialog() {
    List<Map<String, String>> familyMembers = [];

    // Convert existing family members to the format expected by FamilyMembersDialog
    if (userService.currentUser.value?.familyMembers != null) {
      familyMembers = userService.currentUser.value!.familyMembers!
          .map((member) => {
                'name': member.name,
                'ageGroup': member.ageGroup,
                'fitnessGoal': member.fitnessGoal,
                'foodGoal': member.foodGoal,
              })
          .toList();
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => FamilyMembersDialog(
        initialMembers: familyMembers,
        onMembersChanged: (members) async {
          if (members.isNotEmpty && members.first['name']?.isNotEmpty == true) {
            await _saveFamilyMembers(members);
          }
        },
      ),
    );
  }

  Future<void> _saveFamilyMembers(List<Map<String, String>> members) async {
    try {
      // Convert to FamilyMember objects
      final familyMembers = members
          .where((m) => m['name']?.isNotEmpty == true)
          .map((m) => FamilyMember(
                name: m['name']!,
                ageGroup: m['ageGroup']!,
                fitnessGoal: m['fitnessGoal']!,
                foodGoal: m['foodGoal']!,
              ))
          .toList();

      if (familyMembers.isEmpty) return;

      // Update user in Firestore
      await firestore.collection('users').doc(userService.userId).update({
        'familyMembers': familyMembers.map((f) => f.toMap()).toList(),
        'familyMode': familyMembers.isNotEmpty,
      });

      // Update local user data
      final currentUser = userService.currentUser.value;
      if (currentUser != null) {
        final updatedUser = UserModel(
          userId: currentUser.userId,
          displayName: currentUser.displayName,
          bio: currentUser.bio,
          dob: currentUser.dob,
          profileImage: currentUser.profileImage,
          following: currentUser.following,
          settings: currentUser.settings,
          preferences: currentUser.preferences,
          userType: currentUser.userType,
          isPremium: currentUser.isPremium,
          created_At: currentUser.created_At,
          freeTrialDate: currentUser.freeTrialDate,
          familyMode: familyMembers.isNotEmpty,
          familyMembers: familyMembers,
        );
        userService.setUser(updatedUser);
      }

      // Update local state
      setState(() {
        isFamilyModeEnabled = familyMembers.isNotEmpty;
      });

      // Show success message
      if (mounted) {
        showTastySnackbar(
          'Family Members Updated!',
          'Your family members have been updated successfully.',
          context,
          backgroundColor: kAccentLight,
        );
      }
    } catch (e) {
      print('Error saving family members: $e');
      if (mounted) {
        showTastySnackbar(
          'Error',
          'Failed to save family members. Please try again.',
          context,
          backgroundColor: Colors.red,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        leading: InkWell(
          onTap: () => Get.back(),
          child: const IconCircleButton(),
        ),
        title: Text(
          "Edit Goals",
          style: textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w500),
        ),
      ),
      body: Padding(
        padding:
            EdgeInsets.symmetric(horizontal: getPercentageWidth(2, context)),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              SizedBox(height: getPercentageHeight(2, context)),
              // Nutrition Section
              if (!widget.isRoutineExpand)
                SizedBox(height: getPercentageHeight(2, context)),
              if (!widget.isRoutineExpand)
                SafeTextFormField(
                  controller: waterController,
                  style: textTheme.bodyLarge
                      ?.copyWith(color: isDarkMode ? kWhite : kDarkGrey),
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: "Daily Water Intake (mls)",
                    labelStyle: textTheme.bodyMedium
                        ?.copyWith(color: isDarkMode ? kWhite : kDarkGrey),
                    enabledBorder: outlineInputBorder(20),
                    focusedBorder: outlineInputBorder(20),
                    border: outlineInputBorder(20),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return "Please enter your daily water intake.";
                    }
                    return null;
                  },
                ),
              if (!widget.isRoutineExpand)
                SizedBox(height: getPercentageHeight(1, context)),
              if (!widget.isRoutineExpand)
                SafeTextFormField(
                  controller: foodController,
                  style: textTheme.bodyLarge
                      ?.copyWith(color: isDarkMode ? kWhite : kDarkGrey),
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: "Calories",
                    labelStyle: textTheme.bodyMedium
                        ?.copyWith(color: isDarkMode ? kWhite : kDarkGrey),
                    enabledBorder: outlineInputBorder(20),
                    focusedBorder: outlineInputBorder(20),
                    border: outlineInputBorder(20),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return "Please enter your calorie goal.";
                    }
                    return null;
                  },
                ),
              SizedBox(height: getPercentageHeight(2, context)),
              // Family Mode ExpansionTile
              ExpansionTile(
                initiallyExpanded: widget.isFamilyModeExpand,
                title: Text(
                  "Family Mode",
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: widget.isFamilyModeExpand
                        ? kAccent
                        : (isDarkMode ? kWhite : kDarkGrey),
                  ),
                ),
                collapsedIconColor: widget.isFamilyModeExpand ? kAccent : kAccent,
                iconColor: kAccent,
                textColor: kAccent,
                collapsedTextColor: widget.isFamilyModeExpand
                    ? kAccent
                    : (isDarkMode ? kWhite : kDarkGrey),
                children: [
                  SizedBox(height: getPercentageHeight(1, context)),
                  // Family Mode Toggle
                  Container(
                    padding: EdgeInsets.all(getPercentageWidth(3, context)),
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? kDarkGrey.withValues(alpha: 0.3)
                          : kLightGrey.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: widget.isFamilyModeExpand ? kAccent : kLightGrey,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Enable Family Mode',
                                style: textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: isDarkMode ? kWhite : kDarkGrey,
                                ),
                              ),
                              SizedBox(
                                  height: getPercentageHeight(0.5, context)),
                              Text(
                                'Manage nutrition for your family members',
                                style: textTheme.bodySmall?.copyWith(
                                  color: isDarkMode
                                      ? kLightGrey
                                      : kDarkGrey.withValues(alpha: 0.7),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: isFamilyModeEnabled,
                          onChanged: (value) {
                            setState(() {
                              isFamilyModeEnabled = value;
                            });
                          },
                          activeColor: kAccent,
                          activeTrackColor: kAccent.withValues(alpha: 0.3),
                          inactiveTrackColor: isDarkMode
                              ? kLightGrey.withValues(alpha: 0.3)
                              : kLightGrey,
                          inactiveThumbColor: isDarkMode ? kWhite : kDarkGrey,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: getPercentageHeight(2, context)),

                  // Family Members Management (only show if family mode is enabled)
                  if (isFamilyModeEnabled) ...[
                    Container(
                      padding: EdgeInsets.all(getPercentageWidth(3, context)),
                      decoration: BoxDecoration(
                        color: isDarkMode
                            ? kDarkGrey.withValues(alpha: 0.3)
                            : kLightGrey.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: kAccent,
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Family Members',
                                style: textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: isDarkMode ? kWhite : kDarkGrey,
                                ),
                              ),
                              TextButton.icon(
                                onPressed: () {
                                  _showFamilyMembersDialog();
                                },
                                icon: Icon(Icons.edit,
                                    size: getIconScale(5, context),
                                    color: kAccent),
                                label: Text(
                                  'Edit',
                                  style: TextStyle(
                                      color: kAccent,
                                      fontSize: getTextScale(3, context)),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: getPercentageHeight(1, context)),
                          Text(
                            'Manage your family members\' nutrition goals',
                            style: textTheme.bodySmall?.copyWith(
                              color: isDarkMode
                                  ? kLightGrey
                                  : kDarkGrey.withValues(alpha: 0.7),
                            ),
                          ),
                          SizedBox(height: getPercentageHeight(1, context)),
                          // Show current family members count
                          Text(
                            '${userService.currentUser.value?.familyMembers?.length ?? 0} family member${(userService.currentUser.value?.familyMembers?.length ?? 0) == 1 ? '' : 's'} added',
                            style: textTheme.bodyMedium?.copyWith(
                              color: kAccent,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              SizedBox(height: getPercentageHeight(1, context)),
              if (!widget.isRoutineExpand)
                ExpansionTile(
                  initiallyExpanded: widget.isHealthExpand,
                  title: Text("Health & Fitness",
                      style: textTheme.titleMedium
                          ?.copyWith(
                              fontWeight: FontWeight.w500,
                              color: widget.isHealthExpand
                                  ? kAccent
                                  : (isDarkMode ? kWhite : kDarkGrey))),
                  collapsedIconColor: kAccent,
                  iconColor: kAccent,
                  textColor: kAccent,
                  collapsedTextColor: isDarkMode ? kWhite : kDarkGrey,
                  children: [
                    SizedBox(height: getPercentageHeight(1, context)),
                    CategorySelector(
                      categories: _categoryDatasIngredient,
                      selectedCategoryId: selectedDietCategoryId,
                      onCategorySelected: (id, name) {
                        setState(() {
                          selectedDietCategoryId = id;
                          selectedDietCategoryName = name;
                          dietPerfController.text = name;
                        });
                      },
                      isDarkMode: isDarkMode,
                      accentColor: kAccentLight,
                      darkModeAccentColor: kDarkModeAccent,
                    ),
                    SizedBox(height: getPercentageHeight(2, context)),
                    SafeTextFormField(
                      controller: targetStepsController,
                      style: textTheme.bodyLarge
                          ?.copyWith(color: isDarkMode ? kWhite : kDarkGrey),
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: "Target Steps",
                        labelStyle: textTheme.bodyMedium
                            ?.copyWith(color: isDarkMode ? kWhite : kDarkGrey),
                        enabledBorder: outlineInputBorder(20),
                        focusedBorder: outlineInputBorder(20),
                        border: outlineInputBorder(20),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return "Please enter your target steps.";
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: getPercentageHeight(2, context)),
                    SafeTextFormField(
                      controller: fitnessGoalController,
                      style: textTheme.bodyLarge
                          ?.copyWith(color: isDarkMode ? kWhite : kDarkGrey),
                      decoration: InputDecoration(
                        labelText: "Fitness Goal",
                        labelStyle: textTheme.bodyMedium
                            ?.copyWith(color: isDarkMode ? kWhite : kDarkGrey),
                        enabledBorder: outlineInputBorder(20),
                        focusedBorder: outlineInputBorder(20),
                        border: outlineInputBorder(20),
                        suffixIcon: const Icon(Icons.arrow_drop_down),
                        suffixIconColor: kAccent,
                      ),
                      readOnly: true,
                      onTap: () {
                        showModalBottomSheet(
                          context: context,
                          constraints: const BoxConstraints(
                              maxHeight: 300), // Control height
                          builder: (context) => Container(
                            color: isDarkMode ? kDarkGrey : kWhite,
                            child: ListView.builder(
                              itemCount: healthGoalsNoFamily.length,
                              itemBuilder: (context, index) {
                                return ListTile(
                                  title: Text(
                                    healthGoalsNoFamily[index],
                                    style: textTheme.bodyMedium?.copyWith(
                                        color: isDarkMode ? kWhite : kDarkGrey),
                                  ),
                                  onTap: () {
                                    fitnessGoalController.text =
                                        healthGoalsNoFamily[index];
                                    Navigator.pop(context);
                                  },
                                );
                              },
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              if (!widget.isRoutineExpand)
                SizedBox(height: getPercentageHeight(1, context)),
              if (!widget.isRoutineExpand)
                ExpansionTile(
                  title: Text(
                    "Weight Management",
                    style: textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w500),
                  ),
                  collapsedIconColor: kAccent,
                  iconColor: kAccent,
                  textColor: kAccent,
                  collapsedTextColor: isDarkMode ? kWhite : kDarkGrey,
                  children: [
                    SizedBox(height: getPercentageHeight(1, context)),
                    SafeTextFormField(
                      controller: startingWeightController,
                      style: textTheme.bodyLarge
                          ?.copyWith(color: isDarkMode ? kWhite : kDarkGrey),
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: "Starting Weight (kg)",
                        labelStyle: textTheme.bodyMedium
                            ?.copyWith(color: isDarkMode ? kWhite : kDarkGrey),
                        enabledBorder: outlineInputBorder(20),
                        focusedBorder: outlineInputBorder(20),
                        border: outlineInputBorder(20),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return "Please enter your starting weight.";
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: getPercentageHeight(1, context)),
                    SafeTextFormField(
                      controller: goalWeightController,
                      style: textTheme.bodyLarge
                          ?.copyWith(color: isDarkMode ? kWhite : kDarkGrey),
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: "Goal Weight (kg)",
                        labelStyle: textTheme.bodyMedium
                            ?.copyWith(color: isDarkMode ? kWhite : kDarkGrey),
                        enabledBorder: outlineInputBorder(20),
                        focusedBorder: outlineInputBorder(20),
                        border: outlineInputBorder(20),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return "Please enter your goal weight.";
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: getPercentageHeight(1, context)),
                    SafeTextFormField(
                      controller: currentWeightController,
                      style: textTheme.bodyLarge
                          ?.copyWith(color: isDarkMode ? kWhite : kDarkGrey),
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: "Current Weight (kg)",
                        labelStyle: textTheme.bodyMedium
                            ?.copyWith(color: isDarkMode ? kWhite : kDarkGrey),
                        enabledBorder: outlineInputBorder(20),
                        focusedBorder: outlineInputBorder(20),
                        border: outlineInputBorder(20),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return "Please enter your current weight.";
                        }
                        return null;
                      },
                    ),
                  ],
                ),

              SizedBox(height: getPercentageHeight(1, context)),

              DailyRoutineList(
                  userId: userService.userId ?? userService.userId ?? '',
                  isRoutineEdit: widget.isRoutineExpand),

              if (!widget.isRoutineExpand)
                SizedBox(height: getPercentageHeight(5, context)),

              // Save Button
              if (!widget.isRoutineExpand)
                AppButton(
                  onPressed: _saveSettings,
                  text: "Save Settings",
                  width: userService.currentUser.value?.isPremium == true
                      ? 100
                      : 40,
                  type: AppButtonType.secondary,
                ),

              SizedBox(height: getPercentageHeight(2, context)),
            ],
          ),
        ),
      ),
    );
  }
}
