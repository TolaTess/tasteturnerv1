import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import '../constants.dart';
import '../pages/dietary_choose_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'utils.dart';

String calculateRecommendedGoals(String goal) {
  final userCalories =
      userService.currentUser.value?.settings['foodGoals'] ?? 2000;

  if (goal == 'Healthy Eating') {
    return userCalories.toString();
  } else if (goal == 'Lose Weight') {
    return 1500 > userCalories ? '1500' : userCalories.toString();
  } else if (goal == 'Gain Muscle') {
    return 2500 < userCalories ? '2500' : userCalories.toString();
  } else {
    return userCalories.toString(); // Default to user's calories
  }
}

void navigateToChooseDiet(BuildContext context,
    {bool isDontShowPicker = false, String? familyMemberName, String? familyMemberKcal, String? familyMemberGoal, String? familyMemberType}) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => ChooseDietScreen(
        isOnboarding: false,
        isDontShowPicker: isDontShowPicker,
        familyMemberName: familyMemberName,
        familyMemberKcal: familyMemberKcal,
        familyMemberGoal: familyMemberGoal,
        familyMemberType: familyMemberType,
      ),
    ),
  );
}

Widget getAvatar(String? avatar, BuildContext context, bool isDarkMode) {
  switch (avatar?.toLowerCase()) {
    case 'infant':
    case 'baby':
      return SvgPicture.asset('assets/images/svg/baby.svg',
          height: getPercentageWidth(7, context),
          width: getPercentageWidth(7, context),
          colorFilter: ColorFilter.mode(
              isDarkMode ? kWhite : kDarkGrey, BlendMode.srcIn));
    case 'toddler':
      return SvgPicture.asset('assets/images/svg/toddler.svg',
          height: getPercentageWidth(7, context),
          width: getPercentageWidth(7, context),
          colorFilter: ColorFilter.mode(
              isDarkMode ? kWhite : kDarkGrey, BlendMode.srcIn));
    case 'child':
      return SvgPicture.asset('assets/images/svg/child.svg',
          height: getPercentageWidth(7, context),
          width: getPercentageWidth(7, context),
          colorFilter: ColorFilter.mode(
              isDarkMode ? kWhite : kDarkGrey, BlendMode.srcIn));
    case 'teen':
      return SvgPicture.asset('assets/images/svg/teen.svg',
          height: getPercentageWidth(6, context),
          width: getPercentageWidth(6, context),
          colorFilter: ColorFilter.mode(
              isDarkMode ? kWhite : kDarkGrey, BlendMode.srcIn));
    default:
      return SvgPicture.asset('assets/images/svg/adult.svg',
          height: getPercentageWidth(6, context),
          width: getPercentageWidth(6, context),
          colorFilter: ColorFilter.mode(
              isDarkMode ? kWhite : kDarkGrey, BlendMode.srcIn));
  }
}

Color getMealTypeColor(String type) {
  switch (type.toLowerCase()) {
    case 'protein':
      return kAccent.withValues(alpha: 0.5);
    case 'grain':
      return kBlue.withValues(alpha: 0.5);
    case 'vegetable':
      return kAccentLight.withValues(alpha: 0.5);
    case 'fruit':
      return kPurple.withValues(alpha: 0.5);
    default:
      return kPink.withValues(alpha: 0.5);
  }
}

String getMealTypeImage(String type) {
  switch (type.toLowerCase()) {
    case 'protein':
      return 'assets/images/meat.jpg';
    case 'grain':
      return 'assets/images/grain.jpg';
    case 'vegetable':
      return 'assets/images/vegetable.jpg';
    default:
      return 'assets/images/placeholder.jpg';
  }
}

Widget buildAddMealTypeLegend(BuildContext context, String mealType,
    {bool isSelected = false, bool isColored = false}) {
  final textTheme = Theme.of(context).textTheme;

  return Container(
    decoration: BoxDecoration(
      color: isSelected
          ? kAccentLight.withValues(alpha: 0.3)
          : kAccent.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(10),
      border: isSelected ? Border.all(color: kAccentLight, width: 2) : null,
    ),
    padding: EdgeInsets.symmetric(
      horizontal: getPercentageWidth(2, context),
      vertical: getPercentageHeight(1, context),
    ),
    child: Column(
      children: [
        Icon(Icons.square_rounded,
            color: isSelected ? kAccentLight : getMealTypeColor(mealType)),
        SizedBox(width: getPercentageWidth(2, context)),
        Text(
          capitalizeFirstLetter(mealType),
          style: textTheme.bodyMedium?.copyWith(
            color: isSelected ? kAccentLight : getMealTypeColor(mealType),
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ],
    ),
  );
}
