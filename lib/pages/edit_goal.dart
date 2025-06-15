import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../constants.dart';
import '../helper/utils.dart';
import '../service/notification_service.dart';
import '../widgets/daily_routine_list.dart';
import '../widgets/icon_widget.dart';
import 'safe_text_field.dart';

class NutritionSettingsPage extends StatefulWidget {
  final bool isRoutineExpand;
  const NutritionSettingsPage({super.key, this.isRoutineExpand = false});

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

  @override
  void initState() {
    super.initState();

    final settings = userService.currentUser!.settings;
    waterController.text = settings['waterIntake']?.toString() ?? '';
    foodController.text = settings['foodGoal'] ?? '';
    goalWeightController.text = settings['goalWeight']?.toString() ?? '';
    startingWeightController.text =
        settings['startingWeight']?.toString() ?? '';
    currentWeightController.text = settings['currentWeight']?.toString() ?? '';
    fitnessGoalController.text = settings['fitnessGoal']?.toString() ?? '';
    dietPerfController.text = settings['dietPreference']?.toString() ?? '';
    targetStepsController.text = settings['targetSteps']?.toString() ?? '';
    heightController.text = settings['height']?.toString() ?? '';
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
    return Scaffold(
      appBar: AppBar(
        leading: InkWell(
          onTap: () => Navigator.pop(context),
          child: const IconCircleButton(),
        ),
        title: Text(
          "",
          style: TextStyle(
            fontSize: getTextScale(4, context),
          ),
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
                Center(
                  child: Text(
                    "Edit Goals",
                    style: TextStyle(
                      fontSize: getTextScale(4, context),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              if (!widget.isRoutineExpand)
                SizedBox(height: getPercentageHeight(2, context)),
              if (!widget.isRoutineExpand)
                SafeTextFormField(
                  controller: waterController,
                  style: TextStyle(
                      color: isDarkMode ? kWhite : kDarkGrey,
                      fontSize: getTextScale(3.2, context)),
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: "Daily Water Intake (liters)",
                    labelStyle: TextStyle(
                        color: isDarkMode ? kWhite : kDarkGrey,
                        fontSize: getTextScale(3, context)),
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
                  style: TextStyle(
                      color: isDarkMode ? kWhite : kDarkGrey,
                      fontSize: getTextScale(3.2, context)),
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: "Calories",
                    labelStyle: TextStyle(
                        color: isDarkMode ? kWhite : kDarkGrey,
                        fontSize: getTextScale(3, context)),
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
                  title: Text("Health & Fitness",
                      style: TextStyle(fontSize: getTextScale(3.5, context))),
                  collapsedIconColor: kAccent,
                  iconColor: kAccent,
                  textColor: kAccent,
                  collapsedTextColor: isDarkMode ? kWhite : kDarkGrey,
                  children: [
                    SizedBox(height: getPercentageHeight(1, context)),
                    SafeTextFormField(
                      controller: dietPerfController,
                      style: TextStyle(
                          color: isDarkMode ? kWhite : kDarkGrey,
                          fontSize: getTextScale(3.2, context)),
                      keyboardType: TextInputType.text,
                      decoration: InputDecoration(
                        labelText: "Diet Preference",
                        labelStyle: TextStyle(
                            color: isDarkMode ? kWhite : kDarkGrey,
                            fontSize: getTextScale(3, context)),
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
                      controller: targetStepsController,
                      style: TextStyle(
                          color: isDarkMode ? kWhite : kDarkGrey,
                          fontSize: getTextScale(3.2, context)),
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: "Target Steps",
                        labelStyle: TextStyle(
                            color: isDarkMode ? kWhite : kDarkGrey,
                            fontSize: getTextScale(3, context)),
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
                    SizedBox(height: getPercentageHeight(1, context)),
                    SafeTextFormField(
                      controller: fitnessGoalController,
                      style: TextStyle(
                          color: isDarkMode ? kWhite : kDarkGrey,
                          fontSize: getTextScale(3.2, context)),
                      decoration: InputDecoration(
                        labelText: "Fitness Goal",
                        labelStyle: TextStyle(
                            color: isDarkMode ? kWhite : kDarkGrey,
                            fontSize: getTextScale(3, context)),
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
                                    style: TextStyle(
                                        color: isDarkMode ? kWhite : kDarkGrey,
                                        fontSize: getTextScale(3, context)),
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
                    style: TextStyle(fontSize: getTextScale(3.5, context)),
                  ),
                  collapsedIconColor: kAccent,
                  iconColor: kAccent,
                  textColor: kAccent,
                  collapsedTextColor: isDarkMode ? kWhite : kDarkGrey,
                  children: [
                    SizedBox(height: getPercentageHeight(1, context)),
                    SafeTextFormField(
                      controller: startingWeightController,
                      style: TextStyle(
                          color: isDarkMode ? kWhite : kDarkGrey,
                          fontSize: getTextScale(3.2, context)),
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: "Starting Weight (kg)",
                        labelStyle: TextStyle(
                            color: isDarkMode ? kWhite : kDarkGrey,
                            fontSize: getTextScale(3, context)),
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
                      style: TextStyle(
                          color: isDarkMode ? kWhite : kDarkGrey,
                          fontSize: getTextScale(3.2, context)),
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: "Goal Weight (kg)",
                        labelStyle: TextStyle(
                            color: isDarkMode ? kWhite : kDarkGrey,
                            fontSize: getTextScale(3, context)),
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
                      style: TextStyle(
                          color: isDarkMode ? kWhite : kDarkGrey,
                          fontSize: getTextScale(3.2, context)),
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: "Current Weight (kg)",
                        labelStyle: TextStyle(
                            color: isDarkMode ? kWhite : kDarkGrey,
                            fontSize: getTextScale(3, context)),
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
                  userId: userService.currentUser?.userId ??
                      userService.userId ??
                      '',
                  isRoutineEdit: widget.isRoutineExpand),

              if (!widget.isRoutineExpand)
                SizedBox(height: getPercentageHeight(5, context)),

              // Save Button
              if (!widget.isRoutineExpand)
                ElevatedButton(
                  onPressed: _saveSettings,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                    backgroundColor:
                        isDarkMode ? kLightGrey : kAccent.withOpacity(0.50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(50),
                    ),
                  ),
                  child: Text("Save Settings",
                      style: TextStyle(
                          fontSize: getTextScale(3, context), color: kWhite)),
                ),

              SizedBox(height: getPercentageHeight(2, context)),
            ],
          ),
        ),
      ),
    );
  }
}
