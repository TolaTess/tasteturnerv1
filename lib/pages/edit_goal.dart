import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../constants.dart';
import '../helper/utils.dart';
import '../widgets/category_selector.dart';
import '../widgets/daily_routine_list.dart';
import '../widgets/icon_widget.dart';
import '../widgets/primary_button.dart';
import 'safe_text_field.dart';

class NutritionSettingsPage extends StatefulWidget {
  final bool isRoutineExpand;
  final bool isHealthExpand;
  const NutritionSettingsPage(
      {super.key, this.isRoutineExpand = false, this.isHealthExpand = false});

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


  void _saveSettings() {
    if (_formKey.currentState?.validate() ?? false) {
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

      // Check if fitness goal is family nutrition
      final bool isFamilyNutrition =
          fitnessGoalController.text == 'Family Nutrition';

      // Update both settings and familyMode if needed
      if (isFamilyNutrition) {
        authController
            .updateUserData({'settings': updatedSettings, 'familyMode': true});
      } else {
        authController
            .updateUserData({'settings': updatedSettings, 'familyMode': false});
      }

      Get.snackbar('Success', 'Settings updated successfully!',
          snackPosition: SnackPosition.BOTTOM);

      Navigator.pop(context);
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
                  style: textTheme.bodyMedium
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
                  style: textTheme.bodyMedium
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
              SizedBox(height: getPercentageHeight(1, context)),
              if (!widget.isRoutineExpand)
                ExpansionTile(
                  initiallyExpanded: widget.isHealthExpand,
                  title: Text("Health & Fitness",
                      style: textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w500)),
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
                      style: textTheme.bodyMedium
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
                      style: textTheme.bodyMedium
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
                              itemCount: healthGoals.length,
                              itemBuilder: (context, index) {
                                return ListTile(
                                  title: Text(
                                    healthGoals[index],
                                    style: textTheme.bodyMedium?.copyWith(
                                        color: isDarkMode ? kWhite : kDarkGrey),
                                  ),
                                  onTap: () {
                                    fitnessGoalController.text =
                                        healthGoals[index];
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
                      style: textTheme.bodyMedium
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
                      style: textTheme.bodyMedium
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
                      style: textTheme.bodyMedium
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
