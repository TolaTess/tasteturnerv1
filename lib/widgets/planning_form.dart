import 'package:flutter/material.dart';
import '../constants.dart';
import '../helper/utils.dart';
import '../pages/safe_text_field.dart';

class PlanningForm extends StatefulWidget {
  final Function(Map<String, dynamic>) onSubmit;
  final bool isDarkMode;
  final Map<String, dynamic>? initialData;

  const PlanningForm({
    Key? key,
    required this.onSubmit,
    required this.isDarkMode,
    this.initialData,
  }) : super(key: key);

  @override
  State<PlanningForm> createState() => _PlanningFormState();
}

class _PlanningFormState extends State<PlanningForm> {
  final _formKey = GlobalKey<FormState>();
  final _additionalDetailsController = TextEditingController();

  String? selectedDuration;
  String? selectedGoal;
  String? selectedDietType;
  String? selectedActivityLevel;

  final List<String> durationOptions = [
    '7 days',
    '14 days',
    '30 days',
    '60 days',
    '90 days',
    'Custom',
  ];

  final List<String> goalOptions = [
    'Lose Weight',
    'Gain Muscle',
    'Maintain Weight',
    'Improve Health',
    'Custom',
  ];

  final List<String> dietTypeOptions = [
    'Carnivore',
    'Vegan',
    'Vegetarian',
    'Keto',
    'Paleo',
    'Mediterranean',
    'No Restrictions',
    'Custom',
  ];

  final List<String> activityLevelOptions = [
    'Sedentary (little to no exercise)',
    'Lightly Active (light exercise 1-3 days/week)',
    'Moderately Active (moderate exercise 3-5 days/week)',
    'Very Active (hard exercise 6-7 days/week)',
    'Extremely Active (very hard exercise, physical job)',
  ];

  @override
  void initState() {
    super.initState();
    // Load initial data if provided (for amending)
    if (widget.initialData != null) {
      selectedDuration = widget.initialData!['duration'] as String?;
      selectedGoal = widget.initialData!['goal'] as String?;
      selectedDietType = widget.initialData!['dietType'] as String?;
      selectedActivityLevel = widget.initialData!['activityLevel'] as String?;
      _additionalDetailsController.text = 
          widget.initialData!['additionalDetails'] as String? ?? '';
    }
  }

  @override
  void dispose() {
    _additionalDetailsController.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    if (_formKey.currentState!.validate()) {
      final formData = {
        'duration': selectedDuration ?? '',
        'goal': selectedGoal ?? '',
        'dietType': selectedDietType ?? '',
        'activityLevel': selectedActivityLevel ?? '',
        'additionalDetails': _additionalDetailsController.text.trim(),
      };
      debugPrint('PlanningForm: Submitting form data: $formData');
      widget.onSubmit(formData);
    } else {
      debugPrint('PlanningForm: Form validation failed');
    }
  }

  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<String> options,
    required Function(String?) onChanged,
    required IconData icon,
  }) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.only(bottom: getPercentageHeight(2, context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: textTheme.bodyMedium?.copyWith(
              color: widget.isDarkMode ? kWhite : kBlack,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: getPercentageHeight(0.5, context)),
          Container(
            decoration: BoxDecoration(
              color: widget.isDarkMode ? kDarkGrey : kWhite,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: value != null
                    ? kAccent
                    : (widget.isDarkMode ? kLightGrey : kDarkGrey)
                        .withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: DropdownButtonFormField<String>(
              value: value,
              isExpanded: true,
              decoration: InputDecoration(
                contentPadding: EdgeInsets.symmetric(
                  horizontal: getPercentageWidth(3, context),
                  vertical: getPercentageHeight(1.5, context),
                ),
                prefixIcon: Icon(
                  icon,
                  color: kAccent,
                  size: getIconScale(5, context),
                ),
                border: InputBorder.none,
              ),
              dropdownColor: widget.isDarkMode ? kDarkGrey : kWhite,
              style: textTheme.bodyMedium?.copyWith(
                color: widget.isDarkMode ? kWhite : kBlack,
                fontSize: getTextScale(3.5, context),
              ),
              icon: Icon(
                Icons.arrow_drop_down,
                color: widget.isDarkMode ? kWhite : kBlack,
              ),
              selectedItemBuilder: (BuildContext context) {
                return options.map<Widget>((String option) {
                  return Container(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      option,
                      style: textTheme.bodyMedium?.copyWith(
                        color: widget.isDarkMode ? kWhite : kBlack,
                        fontSize: getTextScale(3.5, context),
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  );
                }).toList();
              },
              items: options.map((String option) {
                return DropdownMenuItem<String>(
                  value: option,
                  child: Text(
                    option,
                    style: textTheme.bodyMedium?.copyWith(
                      color: widget.isDarkMode ? kWhite : kBlack,
                      fontSize: getTextScale(3.5, context),
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                );
              }).toList(),
              onChanged: onChanged,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please select $label';
                }
                return null;
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: getPercentageWidth(4, context),
        vertical: getPercentageHeight(1, context),
      ),
      padding: EdgeInsets.all(getPercentageWidth(4, context)),
      decoration: BoxDecoration(
        color: widget.isDarkMode ? kDarkGrey : kWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: kAccent.withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  Icons.edit_note,
                  color: kAccent,
                  size: getIconScale(6, context),
                ),
                SizedBox(width: getPercentageWidth(2, context)),
                Text(
                  'Program Details',
                  style: textTheme.titleMedium?.copyWith(
                    color: kAccent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            SizedBox(height: getPercentageHeight(2, context)),
            _buildDropdown(
              label: 'Duration',
              value: selectedDuration,
              options: durationOptions,
              icon: Icons.calendar_today,
              onChanged: (value) {
                setState(() {
                  selectedDuration = value;
                });
              },
            ),
            _buildDropdown(
              label: 'Goal',
              value: selectedGoal,
              options: goalOptions,
              icon: Icons.flag,
              onChanged: (value) {
                setState(() {
                  selectedGoal = value;
                });
              },
            ),
            _buildDropdown(
              label: 'Diet Type',
              value: selectedDietType,
              options: dietTypeOptions,
              icon: Icons.restaurant,
              onChanged: (value) {
                setState(() {
                  selectedDietType = value;
                });
              },
            ),
            _buildDropdown(
              label: 'Activity Level',
              value: selectedActivityLevel,
              options: activityLevelOptions,
              icon: Icons.fitness_center,
              onChanged: (value) {
                setState(() {
                  selectedActivityLevel = value;
                });
              },
            ),
            Padding(
              padding: EdgeInsets.only(bottom: getPercentageHeight(2, context)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Additional Details (Optional)',
                    style: textTheme.bodyMedium?.copyWith(
                      color: widget.isDarkMode ? kWhite : kBlack,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: getPercentageHeight(0.5, context)),
                  SafeTextField(
                    controller: _additionalDetailsController,
                    maxLines: 3,
                    style: textTheme.bodyMedium?.copyWith(
                      color: widget.isDarkMode ? kWhite : kBlack,
                    ),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: widget.isDarkMode ? kDarkGrey : kWhite,
                      enabledBorder: outlineInputBorder(12),
                      focusedBorder: outlineInputBorder(12),
                      border: outlineInputBorder(12),
                      hintText: 'Any specific requirements, preferences, or notes...',
                      hintStyle: textTheme.bodySmall?.copyWith(
                        color: (widget.isDarkMode ? kWhite : kDarkGrey)
                            .withValues(alpha: 0.5),
                      ),
                      contentPadding: EdgeInsets.all(
                        getPercentageWidth(3, context),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _handleSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kAccent,
                  padding: EdgeInsets.symmetric(
                    vertical: getPercentageHeight(1.5, context),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Continue',
                  style: textTheme.bodyLarge?.copyWith(
                    color: kWhite,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

