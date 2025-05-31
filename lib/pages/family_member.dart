
// Add FamilyMembersDialog widget for family nutrition goal
import 'package:flutter/material.dart';

import '../constants.dart';
import '../helper/utils.dart';
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
    } else {
      // Ensure all members have goal and calories
      for (var m in members) {
        m['fitnessGoal'] ??= 'Family Nutrition';
        m['foodGoal'] ??=
            _getCaloriesForAgeGroup(m['ageGroup'] ?? ageGroups[0]);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      backgroundColor:
          getThemeProvider(context).isDarkMode ? kDarkGrey : kWhite,
      title: Text('Add Family Members',
          style: TextStyle(
              color:
                  getThemeProvider(context).isDarkMode ? kWhite : kDarkGrey)),
      content: SizedBox(
        width: 300,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: members.length,
          itemBuilder: (context, index) {
            return Row(
              children: [
                Expanded(
                  child: SafeTextField(
                    style: TextStyle(
                        color: getThemeProvider(context).isDarkMode
                            ? kWhite
                            : kDarkGrey),
                    decoration: InputDecoration(
                        labelText: 'Name',
                        labelStyle: TextStyle(
                            color: getThemeProvider(context).isDarkMode
                                ? kWhite
                                : kDarkGrey)),
                    onChanged: (val) => members[index]['name'] = val,
                    controller:
                        TextEditingController(text: capitalizeFirstLetter(members[index]['name'] ?? '')),
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
                      value: members[index]['ageGroup'],
                      items: ageGroups.map((group) {
                        return DropdownMenuItem(
                          value: group,
                          child: Text(group,
                              style: TextStyle(
                                  color: getThemeProvider(context).isDarkMode
                                      ? kWhite
                                      : kDarkGrey)),
                        );
                      }).toList(),
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
                      color: Colors.red, size: getPercentageWidth(5, context)),
                  onPressed: members.length > 1
                      ? () {
                          setState(() {
                            members.removeAt(index);
                          });
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
            setState(() {
              members.add({
                'name': '',
                'ageGroup': ageGroups[0],
                'fitnessGoal': 'Family Nutrition',
                'foodGoal': _getCaloriesForAgeGroup(ageGroups[0]),
              });
            });
          },
          child: Text('Add Member',
              style: TextStyle(
                  color: getThemeProvider(context).isDarkMode
                      ? kWhite
                      : kDarkGrey)),
        ),
        TextButton(
          onPressed: () {
            widget.onMembersChanged(members);
            Navigator.of(context).pop();
          },
          child: Text('Done', style: TextStyle(color: kAccent)),
        ),
      ],
    );
  }

  String _getCaloriesForAgeGroup(String ageGroup) {
    switch (ageGroup) {
      case 'Baby':
        return '1000';
      case 'Toddler':
        return '1200';
      case 'Child':
        return '1800';
      case 'Teen':
        return '2200';
      case 'Adult':
        return '2000';
      default:
        return '2000';
    }
  }
}
