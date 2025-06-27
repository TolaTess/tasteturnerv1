import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import '../constants.dart';
import '../pages/dietary_choose_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'utils.dart';

String calculateRecommendedGoals(String goal) {
  if (goal == "Lose Weight") {
    return "";
  } else if (goal == "Gain Muscle") {
    return "";
  } else {
    return '';
  }
}

Future<bool> checkMealPlanGenerationLimit(BuildContext context) async {
  try {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final firestore = FirebaseFirestore.instance;

    final generations = await firestore
        .collection('mealPlans')
        .doc(userService.userId)
        .collection('buddy')
        .where('timestamp', isGreaterThanOrEqualTo: startOfMonth)
        .get();

    return generations.docs.length < 5;
  } catch (e) {
    print('Error checking generation limit: $e');
    return false;
  }
}

void showGenerationLimitDialog(BuildContext context,
    {bool isDarkMode = false}) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      backgroundColor: isDarkMode ? kDarkGrey : kWhite,
      title: const Text('Generation Limit Reached'),
      content: const Text(
        'You have reached your limit of 5 meal plan generations per month. Try again next week!',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}

void navigateToChooseDiet(BuildContext context, {bool isDontShowPicker = false}) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => ChooseDietScreen(
        isOnboarding: false,
        isDontShowPicker: isDontShowPicker,
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