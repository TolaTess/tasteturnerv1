import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../constants.dart';
import '../helper/utils.dart';
import '../widgets/category_selector.dart';
import '../widgets/daily_routine_list.dart';
import '../widgets/icon_widget.dart';
import '../widgets/primary_button.dart';
import '../pages/family_member.dart';
import '../data_models/user_data_model.dart';
import '../data_models/cycle_tracking_model.dart';
import '../service/cycle_adjustment_service.dart';
import 'safe_text_field.dart';

class NutritionSettingsPage extends StatefulWidget {
  final bool isRoutineExpand;
  final bool isHealthExpand;
  final bool isFamilyModeExpand;
  final bool isWeightExpand;
  const NutritionSettingsPage(
      {super.key,
      this.isRoutineExpand = false,
      this.isHealthExpand = false,
      this.isFamilyModeExpand = false,
      this.isWeightExpand = false});

  @override
  _NutritionSettingsPageState createState() => _NutritionSettingsPageState();
}

class _NutritionSettingsPageState extends State<NutritionSettingsPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController foodController = TextEditingController();
  final TextEditingController proteinController = TextEditingController();
  final TextEditingController carbsController = TextEditingController();
  final TextEditingController fatController = TextEditingController();
  final TextEditingController waterController = TextEditingController();
  final TextEditingController goalWeightController = TextEditingController();
  final TextEditingController startingWeightController =
      TextEditingController();
  final TextEditingController currentWeightController = TextEditingController();
  final TextEditingController fitnessGoalController = TextEditingController();
  final TextEditingController dietPerfController = TextEditingController();
  final TextEditingController targetStepsController = TextEditingController();
  final TextEditingController heightController = TextEditingController();
  final TextEditingController cycleLengthController = TextEditingController();
  List<Map<String, dynamic>> _categoryDatasIngredient = [];
  String selectedDietCategoryId = '';
  String selectedDietCategoryName = '';
  bool isFamilyModeEnabled = false;
  bool isCycleTrackingEnabled = false;
  DateTime? lastPeriodStart;
  final cycleAdjustmentService = CycleAdjustmentService.instance;

  @override
  void initState() {
    super.initState();

    _categoryDatasIngredient = [...helperController.category];

    final user = userService.currentUser.value;
    if (user != null) {
      final settings = user.settings;
      foodController.text = settings['foodGoal'] ?? '';
      proteinController.text = settings['proteinGoal']?.toString() ?? '';
      carbsController.text = settings['carbsGoal']?.toString() ?? '';
      fatController.text = settings['fatGoal']?.toString() ?? '';
      waterController.text = settings['waterIntake']?.toString() ?? '';
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

      // Initialize cycle tracking from settings
      final cycleDataRaw = user.settings['cycleTracking'];
      if (cycleDataRaw != null && cycleDataRaw is Map) {
        final cycleData = Map<String, dynamic>.from(cycleDataRaw);
        isCycleTrackingEnabled = cycleData['isEnabled'] as bool? ?? false;
        cycleLengthController.text = (cycleData['cycleLength'] as num?)?.toString() ?? '28';
        
        // Handle lastPeriodStart - could be String (ISO8601) or Timestamp
        final lastPeriodStartValue = cycleData['lastPeriodStart'];
        if (lastPeriodStartValue != null) {
          if (lastPeriodStartValue is String) {
            lastPeriodStart = DateTime.tryParse(lastPeriodStartValue);
          } else if (lastPeriodStartValue is Timestamp) {
            lastPeriodStart = lastPeriodStartValue.toDate();
          }
        }
      } else {
        cycleLengthController.text = '28'; // Default
        isCycleTrackingEnabled = false;
      }
    }
  }

  @override
  void dispose() {
    foodController.dispose();
    proteinController.dispose();
    carbsController.dispose();
    fatController.dispose();
    waterController.dispose();
    goalWeightController.dispose();
    startingWeightController.dispose();
    currentWeightController.dispose();
    fitnessGoalController.dispose();
    dietPerfController.dispose();
    targetStepsController.dispose();
    heightController.dispose();
    cycleLengthController.dispose();
    super.dispose();
  }

  Future<void> _saveSettings() async {
    if (_formKey.currentState?.validate() ?? false) {
      try {
        // Prepare updated settings map
        final updatedSettings = {
          'foodGoal': foodController.text,
          'proteinGoal': proteinController.text,
          'carbsGoal': carbsController.text,
          'fatGoal': fatController.text,
          'waterIntake': waterController.text,
          'goalWeight': goalWeightController.text,
          'startingWeight': startingWeightController.text,
          'currentWeight': currentWeightController.text,
          'fitnessGoal': fitnessGoalController.text,
          'dietPreference': dietPerfController.text,
          'targetSteps': targetStepsController.text,
          'height': heightController.text,
          'cycleTracking': {
            'isEnabled': isCycleTrackingEnabled,
            'lastPeriodStart': lastPeriodStart?.toIso8601String(),
            'cycleLength': int.tryParse(cycleLengthController.text) ?? 28,
          },
        };

        // Update both settings and familyMode
        await authController.updateUserData(
            {'settings': updatedSettings, 'familyMode': isFamilyModeEnabled});

        Get.snackbar('Success', 'Settings updated successfully!',
            snackPosition: SnackPosition.BOTTOM);

        Navigator.pop(context);
      } catch (e) {
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
              if (!widget.isRoutineExpand && !widget.isWeightExpand)
                SizedBox(height: getPercentageHeight(2, context)),
              // Nutrition Goals Grid
              if (!widget.isRoutineExpand && !widget.isWeightExpand)
                ExpansionTile(
                  initiallyExpanded: true,
                  collapsedIconColor: kAccent,
                  iconColor: kAccent,
                  textColor: kAccent,
                  collapsedTextColor: isDarkMode ? kWhite : kDarkGrey,
                  title: Text(
                    "Daily Nutrition Goals",
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: isDarkMode ? kWhite : kDarkGrey,
                    ),
                  ),
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: getPercentageHeight(0.5, context)),
                        GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: 2,
                          crossAxisSpacing: getPercentageWidth(2, context),
                          mainAxisSpacing: getPercentageHeight(1.5, context),
                          childAspectRatio: 3.2,
                          children: [
                            SafeTextFormField(
                              controller: foodController,
                              style: textTheme.bodyLarge?.copyWith(
                                  color: isDarkMode ? kWhite : kDarkGrey),
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: "Calories",
                                labelStyle: textTheme.bodyMedium?.copyWith(
                                    color: isDarkMode ? kWhite : kDarkGrey),
                                enabledBorder: outlineInputBorder(20),
                                focusedBorder: outlineInputBorder(20),
                                border: outlineInputBorder(20),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return "Required";
                                }
                                return null;
                              },
                            ),
                            SafeTextFormField(
                              controller: proteinController,
                              style: textTheme.bodyLarge?.copyWith(
                                  color: isDarkMode ? kWhite : kDarkGrey),
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: "Protein (g)",
                                labelStyle: textTheme.bodyMedium?.copyWith(
                                    color: isDarkMode ? kWhite : kDarkGrey),
                                enabledBorder: outlineInputBorder(20),
                                focusedBorder: outlineInputBorder(20),
                                border: outlineInputBorder(20),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return "Required";
                                }
                                return null;
                              },
                            ),
                            SafeTextFormField(
                              controller: carbsController,
                              style: textTheme.bodyLarge?.copyWith(
                                  color: isDarkMode ? kWhite : kDarkGrey),
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: "Carbs (g)",
                                labelStyle: textTheme.bodyMedium?.copyWith(
                                    color: isDarkMode ? kWhite : kDarkGrey),
                                enabledBorder: outlineInputBorder(20),
                                focusedBorder: outlineInputBorder(20),
                                border: outlineInputBorder(20),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return "Required";
                                }
                                return null;
                              },
                            ),
                            SafeTextFormField(
                              controller: fatController,
                              style: textTheme.bodyLarge?.copyWith(
                                  color: isDarkMode ? kWhite : kDarkGrey),
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: "Fat (g)",
                                labelStyle: textTheme.bodyMedium?.copyWith(
                                    color: isDarkMode ? kWhite : kDarkGrey),
                                enabledBorder: outlineInputBorder(20),
                                focusedBorder: outlineInputBorder(20),
                                border: outlineInputBorder(20),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return "Required";
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),

              if (!widget.isRoutineExpand)
                SizedBox(height: getPercentageHeight(1.5, context)),

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
                collapsedIconColor:
                    widget.isFamilyModeExpand ? kAccent : kAccent,
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
                              FirebaseAnalytics.instance
                                  .logEvent(name: 'family_mode_enabled');
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
                      style: textTheme.titleMedium?.copyWith(
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
                      controller: waterController,
                      style: textTheme.bodyLarge
                          ?.copyWith(color: isDarkMode ? kWhite : kDarkGrey),
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: "Daily Water Intake (ml)",
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
                        labelText: "Nutrition Goal",
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
              if (!widget.isRoutineExpand || widget.isWeightExpand)
                SizedBox(height: getPercentageHeight(1, context)),
              if (!widget.isRoutineExpand || widget.isWeightExpand)
                ExpansionTile(
                  title: Text(
                    "Weight Management",
                    style: textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w500),
                  ),
                  initiallyExpanded: widget.isWeightExpand,
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

              // Cycle Tracking Section (Optional)
              SizedBox(height: getPercentageHeight(1, context)),
              ExpansionTile(
                title: Text(
                  "Cycle Tracking (Optional)",
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                collapsedIconColor: kAccent,
                iconColor: kAccent,
                textColor: kAccent,
                collapsedTextColor: isDarkMode ? kWhite : kDarkGrey,
                children: [
                  SizedBox(height: getPercentageHeight(1, context)),
                  // Enable/Disable Toggle
                  SwitchListTile(
                    title: Text(
                      'Enable Cycle Syncing',
                      style: textTheme.bodyLarge?.copyWith(
                        color: isDarkMode ? kWhite : kDarkGrey,
                      ),
                    ),
                    subtitle: Text(
                      'Adjust macro goals based on your menstrual cycle phase',
                      style: textTheme.bodySmall?.copyWith(
                        color: isDarkMode ? kLightGrey : kDarkGrey.withValues(alpha: 0.7),
                      ),
                    ),
                    value: isCycleTrackingEnabled,
                    onChanged: (value) {
                      setState(() {
                        isCycleTrackingEnabled = value;
                      });
                    },
                    activeColor: kAccent,
                  ),
                  if (isCycleTrackingEnabled) ...[
                    SizedBox(height: getPercentageHeight(1, context)),
                    // Last Period Start Date
                    ListTile(
                      title: Text(
                        'Last Period Start',
                        style: textTheme.bodyMedium?.copyWith(
                          color: isDarkMode ? kWhite : kDarkGrey,
                        ),
                      ),
                      subtitle: Text(
                        lastPeriodStart != null
                            ? DateFormat('MMM dd, yyyy').format(lastPeriodStart!)
                            : 'Not set',
                        style: textTheme.bodySmall?.copyWith(
                          color: kAccent,
                        ),
                      ),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: lastPeriodStart ?? DateTime.now(),
                          firstDate: DateTime.now().subtract(const Duration(days: 365)),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) {
                          setState(() {
                            lastPeriodStart = picked;
                          });
                        }
                      },
                    ),
                    SizedBox(height: getPercentageHeight(1, context)),
                    // Cycle Length
                    SafeTextFormField(
                      controller: cycleLengthController,
                      style: textTheme.bodyLarge
                          ?.copyWith(color: isDarkMode ? kWhite : kDarkGrey),
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: "Average Cycle Length (days)",
                        labelStyle: textTheme.bodyMedium
                            ?.copyWith(color: isDarkMode ? kWhite : kDarkGrey),
                        enabledBorder: outlineInputBorder(20),
                        focusedBorder: outlineInputBorder(20),
                        border: outlineInputBorder(20),
                      ),
                      validator: (value) {
                        if (isCycleTrackingEnabled && (value == null || value.isEmpty)) {
                          return "Please enter your cycle length.";
                        }
                        final length = int.tryParse(value ?? '');
                        if (isCycleTrackingEnabled && (length == null || length < 21 || length > 35)) {
                          return "Cycle length should be between 21-35 days.";
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: getPercentageHeight(1, context)),
                    // Show current phase if enabled
                    if (lastPeriodStart != null) ...[
                      Builder(
                        builder: (context) {
                          final phase = cycleAdjustmentService.getCurrentPhase(
                            lastPeriodStart,
                            int.tryParse(cycleLengthController.text) ?? 28,
                          );
                          final phaseName = cycleAdjustmentService.getPhaseName(phase);
                          final phaseEmoji = cycleAdjustmentService.getPhaseEmoji(phase);
                          final phaseColor = cycleAdjustmentService.getPhaseColor(phase);
                          
                          return Container(
                            padding: EdgeInsets.all(getPercentageWidth(3, context)),
                            decoration: BoxDecoration(
                              color: phaseColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: phaseColor.withValues(alpha: 0.3),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  phaseEmoji,
                                  style: TextStyle(fontSize: getTextScale(5, context)),
                                ),
                                SizedBox(width: getPercentageWidth(2, context)),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Current Phase: $phaseName',
                                        style: textTheme.bodyLarge?.copyWith(
                                          color: isDarkMode ? kWhite : kDarkGrey,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      SizedBox(height: getPercentageHeight(0.5, context)),
                                      Text(
                                        _getPhaseDescription(phase),
                                        style: textTheme.bodySmall?.copyWith(
                                          color: isDarkMode ? kLightGrey : kDarkGrey.withValues(alpha: 0.7),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ],
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

  String _getPhaseDescription(CyclePhase phase) {
    switch (phase) {
      case CyclePhase.menstrual:
        return 'During your period: +100 calories recommended';
      case CyclePhase.follicular:
        return 'Post-period phase: Use base goals';
      case CyclePhase.ovulation:
        return 'Ovulation phase: Use base goals';
      case CyclePhase.luteal:
        return 'Pre-period phase: +200 calories, +20g carbs recommended';
    }
  }
}
