// Add FamilyMembersDialog widget for family nutrition goal
import 'package:flutter/material.dart';

import '../constants.dart';
import '../helper/utils.dart';
import '../service/user_service.dart';
import 'safe_text_field.dart';

class FamilyMembersDialog extends StatefulWidget {
  final List<Map<String, String>> initialMembers;
  final Function(List<Map<String, String>>) onMembersChanged;

  const FamilyMembersDialog({
    Key? key,
    required this.initialMembers,
    required this.onMembersChanged,
  }) : super(key: key);

  @override
  _FamilyMembersDialogState createState() => _FamilyMembersDialogState();
}

class _FamilyMembersDialogState extends State<FamilyMembersDialog> {
  List<Map<String, String>> members = [];
  List<TextEditingController> nameControllers = [];
  final List<String> ageGroups = ['Baby', 'Toddler', 'Child', 'Teen', 'Adult'];

  @override
  void initState() {
    super.initState();
    members = List.from(widget.initialMembers);
    if (members.isEmpty) {
      members.add({
        'name': '',
        'ageGroup': ageGroups[0],
        'fitnessGoal': 'Family Nutrition',
        'foodGoal': '1000',
      });
    }
    // Ensure all members have goal and calories
    for (var m in members) {
      m['fitnessGoal'] ??= 'Family Nutrition';
      m['foodGoal'] ??= _getCaloriesForAgeGroup(m['ageGroup'] ?? ageGroups[0]);
    }
    nameControllers = members
        .map((m) => TextEditingController(text: m['name'] ?? ''))
        .toList();
  }

  @override
  void dispose() {
    for (var c in nameControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _addMember() {
    // Check if user is premium to allow multiple family members
    final isPremium = userService.currentUser.value?.isPremium ?? false;
    final maxMembers =
        isPremium ? 10 : 1; // Premium users can add up to 10, free users only 1

    if (members.length >= maxMembers) {
      showTastySnackbar(
        'Member Limit Reached',
        isPremium
            ? 'You can add up to 10 family members.'
            : 'Free users can only add 1 family member. Upgrade to Premium for more!',
        context,
        backgroundColor: kAccentLight,
      );
      return;
    }

    setState(() {
      members.add({
        'name': '',
        'ageGroup': ageGroups[0],
        'fitnessGoal': 'Family Nutrition',
        'foodGoal': _getCaloriesForAgeGroup(ageGroups[0]),
      });
      nameControllers.add(TextEditingController());
    });
  }

  void _removeMember(int index) {
    setState(() {
      if (index < members.length && index < nameControllers.length) {
        members.removeAt(index);
        nameControllers[index].dispose();
        nameControllers.removeAt(index);
      }
    });
  }

  void _onDone() {
    // Defensive: ensure lists are in sync
    if (members.length != nameControllers.length) {
      // Rebuild controllers to match members
      nameControllers.forEach((c) => c.dispose());
      nameControllers = members
          .map((m) => TextEditingController(text: m['name'] ?? ''))
          .toList();
    }
    // Update members from controllers
    for (int i = 0; i < members.length; i++) {
      members[i]['name'] = nameControllers[i].text;
    }
    widget.onMembersChanged(
        members.map((m) => Map<String, String>.from(m)).toList());
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      backgroundColor:
          getThemeProvider(context).isDarkMode ? kDarkGrey : kWhite,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Add Family Members',
              style: TextStyle(
                  color:
                      getThemeProvider(context).isDarkMode ? kWhite : kDarkGrey,
                  fontSize: getTextScale(3.5, context))),
          if (userService.currentUser.value?.isPremium != true)
            Text(
              'Free users can add 1 family member. Upgrade to Premium for more!',
              style: TextStyle(
                  color: kAccentLight,
                  fontSize: getTextScale(2.5, context),
                  fontStyle: FontStyle.italic),
            ),
        ],
      ),
      content: SizedBox(
        width: getPercentageWidth(70, context),
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: members.length,
          itemBuilder: (context, index) {
            // Defensive: check bounds
            if (index >= nameControllers.length) {
              return const SizedBox.shrink();
            }
            final normalizedAgeGroups =
                ageGroups.map((e) => e.trim()).toSet().toList();
            final selectedValue = members[index]['ageGroup']?.trim();
            return Row(
              children: [
                Expanded(
                  child: SafeTextField(
                    style: TextStyle(
                        color: getThemeProvider(context).isDarkMode
                            ? kWhite
                            : kDarkGrey,
                        fontSize: getTextScale(3, context)),
                    decoration: InputDecoration(
                        labelText: 'Name',
                        labelStyle: TextStyle(
                            color: getThemeProvider(context).isDarkMode
                                ? kWhite
                                : kDarkGrey)),
                    controller: nameControllers[index],
                    onChanged: (val) {}, // No-op, update on Done
                    keyboardType: TextInputType.name,
                  ),
                ),
                SizedBox(width: getPercentageWidth(2, context)),
                Container(
                  decoration: BoxDecoration(
                    color: getThemeProvider(context).isDarkMode
                        ? kDarkGrey
                        : kWhite,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: kDarkGrey,
                      width: getPercentageWidth(0.5, context),
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      dropdownColor: getThemeProvider(context).isDarkMode
                          ? kLightGrey
                          : kBackgroundColor,
                      value: normalizedAgeGroups.contains(selectedValue)
                          ? selectedValue
                          : null,
                      items: normalizedAgeGroups
                          .map((group) => DropdownMenuItem(
                                value: group,
                                child: Text(group,
                                    style: TextStyle(
                                        color:
                                            getThemeProvider(context).isDarkMode
                                                ? kWhite
                                                : kDarkGrey)),
                              ))
                          .toList(),
                      onChanged: (val) {
                        setState(() {
                          members[index]['ageGroup'] = val!;
                          members[index]['foodGoal'] =
                              _getCaloriesForAgeGroup(val);
                          members[index]['fitnessGoal'] = 'Family Nutrition';
                        });
                      },
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.remove_circle,
                      color: Colors.red, size: getIconScale(7, context)),
                  onPressed: members.length > 1
                      ? () {
                          _removeMember(index);
                        }
                      : null,
                ),
              ],
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: Text('Cancel',
              style: TextStyle(
                  color:
                      getThemeProvider(context).isDarkMode ? kWhite : kDarkGrey,
                  fontSize: getTextScale(3, context))),
        ),
        TextButton(
          onPressed: _addMember,
          child: Text(
            userService.currentUser.value?.isPremium == true
                ? 'Add Member'
                : 'Add Member (Premium)',
            style: TextStyle(
                color: userService.currentUser.value?.isPremium == true
                    ? kAccentLight
                    : kLightGrey,
                fontSize: getTextScale(3, context)),
          ),
        ),
        TextButton(
          onPressed: _onDone,
          child: Text('Done',
              style: TextStyle(
                  color: kAccent, fontSize: getTextScale(3, context))),
        ),
      ],
    );
  }

  String _getCaloriesForAgeGroup(String ageGroup) {
    switch (ageGroup.toLowerCase()) {
      case 'baby':
        return '1000';
      case 'toddler':
        return '1200';
      case 'child':
        return '1800';
      case 'teen':
        return '2200';
      case 'adult':
        return '2000';
      default:
        return '2000';
    }
  }
}

class EditFamilyMemberDialog extends StatefulWidget {
  final Map<String, String> familyMember;
  final Function(Map<String, String>) onMemberUpdated;

  const EditFamilyMemberDialog({
    Key? key,
    required this.familyMember,
    required this.onMemberUpdated,
  }) : super(key: key);

  @override
  _EditFamilyMemberDialogState createState() => _EditFamilyMemberDialogState();
}

class _EditFamilyMemberDialogState extends State<EditFamilyMemberDialog> {
  late TextEditingController nameController;
  late TextEditingController fitnessGoalController;
  late TextEditingController foodGoalController;
  String selectedAgeGroup = 'Adult';

  final List<String> ageGroups = ['Baby', 'Toddler', 'Child', 'Teen', 'Adult'];

  @override
  void initState() {
    super.initState();
    nameController =
        TextEditingController(text: capitalizeFirstLetter(widget.familyMember['name'] ?? ''));
    fitnessGoalController = TextEditingController(
        text: capitalizeFirstLetter(widget.familyMember['fitnessGoal'] ?? 'Healthy Eating'));
    foodGoalController =
        TextEditingController(text: capitalizeFirstLetter(widget.familyMember['foodGoal'] ?? '2000'));
    selectedAgeGroup = capitalizeFirstLetter(widget.familyMember['ageGroup'] ?? 'Adult');
  }

  @override
  void dispose() {
    nameController.dispose();
    fitnessGoalController.dispose();
    foodGoalController.dispose();
    super.dispose();
  }

  void _saveChanges() {
    if (nameController.text.trim().isEmpty) {
      showTastySnackbar(
        'Name Required',
        'Please enter a name for the family member.',
        context,
        backgroundColor: kRed,
      );
      return;
    }

    final updatedMember = {
      'name': nameController.text.trim(),
      'ageGroup': selectedAgeGroup,
      'fitnessGoal': fitnessGoalController.text.trim(),
      'foodGoal': foodGoalController.text.trim(),
    };

    widget.onMemberUpdated(updatedMember);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = getThemeProvider(context).isDarkMode;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      backgroundColor: isDarkMode ? kDarkGrey : kWhite,
      title: Text(
        'Edit Family Member',
        style: TextStyle(
          color: isDarkMode ? kWhite : kDarkGrey,
          fontSize: getTextScale(4, context),
          fontWeight: FontWeight.w600,
        ),
      ),
      content: SizedBox(
        width: getPercentageWidth(80, context),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Name Field
              Text(
                'Name',
                style: TextStyle(
                  color: isDarkMode ? kWhite : kDarkGrey,
                  fontSize: getTextScale(3, context),
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: getPercentageHeight(1, context)),
              SafeTextField(
                controller: nameController,
                maxLines: 1,
                style: TextStyle(
                  color: isDarkMode ? kWhite : kDarkGrey,
                  fontSize: getTextScale(3, context),
                ),
                decoration: InputDecoration(
                  hintText: 'Enter family member name',
                  hintStyle: TextStyle(
                    color: isDarkMode
                        ? kLightGrey
                        : kDarkGrey.withValues(alpha: 0.6),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: kAccent, width: 2),
                  ),
                ),
                keyboardType: TextInputType.name,
              ),

              SizedBox(height: getPercentageHeight(3, context)),

              // Age Group Field
              Text(
                'Age Group',
                style: TextStyle(
                  color: isDarkMode ? kWhite : kDarkGrey,
                  fontSize: getTextScale(3, context),
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: getPercentageHeight(1, context)),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: kDarkGrey),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedAgeGroup,
                    isExpanded: true,
                    dropdownColor: isDarkMode ? kLightGrey : kBackgroundColor,
                    padding: EdgeInsets.symmetric(
                        horizontal: getPercentageWidth(3, context)),
                    items: ageGroups.map((ageGroup) {
                      return DropdownMenuItem<String>(
                        value: ageGroup,
                        child: Text(
                          ageGroup,
                          style: TextStyle(
                            color: isDarkMode ? kWhite : kDarkGrey,
                            fontSize: getTextScale(3, context),
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedAgeGroup = value!;
                        // Update calories based on age group
                        foodGoalController.text =
                            _getCaloriesForAgeGroup(value);
                      });
                    },
                  ),
                ),
              ),

              SizedBox(height: getPercentageHeight(3, context)),

              // Fitness Goal Field
              Text(
                'Nutrition Goal',
                style: TextStyle(
                  color: isDarkMode ? kWhite : kDarkGrey,
                  fontSize: getTextScale(3, context),
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: getPercentageHeight(1, context)),
              SafeTextField(
                controller: fitnessGoalController,
                style: TextStyle(
                  color: isDarkMode ? kWhite : kDarkGrey,
                  fontSize: getTextScale(3, context),
                ),
                decoration: InputDecoration(
                  hintText:
                      'Enter nutrition goal (e.g., Low Sugar, Nut-Free, Weight Loss)',
                  hintStyle: TextStyle(
                    color: isDarkMode
                        ? kLightGrey
                        : kDarkGrey.withValues(alpha: 0.6),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: kAccent, width: 2),
                  ),
                ),
                keyboardType: TextInputType.text,
              ),

              SizedBox(height: getPercentageHeight(3, context)),

              // Daily Calories Field
              Text(
                'Daily Calories',
                style: TextStyle(
                  color: isDarkMode ? kWhite : kDarkGrey,
                  fontSize: getTextScale(3, context),
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: getPercentageHeight(1, context)),
              SafeTextField(
                controller: foodGoalController,
                style: TextStyle(
                  color: isDarkMode ? kWhite : kDarkGrey,
                  fontSize: getTextScale(3, context),
                ),
                decoration: InputDecoration(
                  hintText: 'Enter daily calorie goal',
                  hintStyle: TextStyle(
                    color: isDarkMode
                        ? kLightGrey
                        : kDarkGrey.withValues(alpha: 0.6),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: kAccent, width: 2),
                  ),
                  suffixText: 'kcal',
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Cancel',
            style: TextStyle(
              color: isDarkMode ? kWhite : kDarkGrey,
              fontSize: getTextScale(3, context),
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
          onPressed: _saveChanges,
          child: Text(
            'Save Changes',
            style: TextStyle(
              color: kWhite,
              fontSize: getTextScale(3, context),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  String _getCaloriesForAgeGroup(String ageGroup) {
    switch (ageGroup.toLowerCase()) {
      case 'baby':
        return '1000';
      case 'toddler':
        return '1200';
      case 'child':
        return '1800';
      case 'teen':
        return '2200';
      case 'adult':
        return '2000';
      default:
        return '2000';
    }
  }
}
