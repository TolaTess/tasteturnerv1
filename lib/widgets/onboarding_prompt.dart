import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../constants.dart';
import '../helper/utils.dart';
import '../helper/onboarding_prompt_helper.dart';

class OnboardingPrompt extends StatelessWidget {
  final String title;
  final String message;
  final String actionText;
  final VoidCallback onAction;
  final String dismissText;
  final VoidCallback onDismiss;
  final String promptType;
  final String storageKey;

  const OnboardingPrompt({
    super.key,
    required this.title,
    required this.message,
    required this.actionText,
    required this.onAction,
    this.dismissText = 'Maybe Later',
    required this.onDismiss,
    this.promptType = 'banner',
    required this.storageKey,
  });

  @override
  Widget build(BuildContext context) {
    if (promptType == 'banner') {
      return _buildBanner(context);
    } else if (promptType == 'card') {
      return _buildCard(context);
    } else {
      return _buildBottomSheet(context);
    }
  }

  Widget _buildBanner(BuildContext context) {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: getPercentageWidth(2, context),
        vertical: getPercentageHeight(1, context),
      ),
      padding: EdgeInsets.all(getPercentageWidth(3, context)),
      decoration: BoxDecoration(
        color: kAccentLight.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: kAccentLight.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lightbulb_outline,
                color: kAccentLight,
                size: getPercentageWidth(5, context),
              ),
              SizedBox(width: getPercentageWidth(2, context)),
              Expanded(
                child: Text(
                  title,
                  style: textTheme.titleMedium?.copyWith(
                    color: kAccentLight,
                    fontWeight: FontWeight.w600,
                    fontSize: getTextScale(4, context),
                  ),
                ),
              ),
              GestureDetector(
                onTap: () async {
                  await _markPromptShown();
                  onDismiss();
                },
                child: Icon(
                  Icons.close,
                  color: isDarkMode ? kWhite : kDarkGrey,
                  size: getPercentageWidth(4, context),
                ),
              ),
            ],
          ),
          SizedBox(height: getPercentageHeight(1, context)),
          Text(
            message,
            style: textTheme.bodyMedium?.copyWith(
              color: isDarkMode ? kWhite : kDarkGrey,
              fontSize: getTextScale(3.5, context),
            ),
          ),
          SizedBox(height: getPercentageHeight(2, context)),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    await _markPromptShown();
                    onAction();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kAccentLight,
                    foregroundColor: kWhite,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: EdgeInsets.symmetric(
                      vertical: getPercentageHeight(1.5, context),
                    ),
                  ),
                  child: Text(
                    actionText,
                    style: TextStyle(
                      fontSize: getTextScale(3.5, context),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              SizedBox(width: getPercentageWidth(2, context)),
              TextButton(
                onPressed: () async {
                  await _markPromptShown();
                  onDismiss();
                },
                child: Text(
                  dismissText,
                  style: TextStyle(
                    color: isDarkMode ? kWhite : kDarkGrey,
                    fontSize: getTextScale(3.5, context),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCard(BuildContext context) {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: getPercentageWidth(2, context),
        vertical: getPercentageHeight(1, context),
      ),
      padding: EdgeInsets.all(getPercentageWidth(4, context)),
      decoration: BoxDecoration(
        color: isDarkMode ? kDarkGrey : kWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: kAccentLight.withValues(alpha: 0.3),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.track_changes,
                color: kAccentLight,
                size: getPercentageWidth(5, context),
              ),
              SizedBox(width: getPercentageWidth(2, context)),
              Expanded(
                child: Text(
                  title,
                  style: textTheme.titleMedium?.copyWith(
                    color: isDarkMode ? kWhite : kDarkGrey,
                    fontWeight: FontWeight.w600,
                    fontSize: getTextScale(4, context),
                  ),
                ),
              ),
              GestureDetector(
                onTap: () async {
                  await _markPromptShown();
                  onDismiss();
                },
                child: Icon(
                  Icons.close,
                  color: isDarkMode ? kWhite : kDarkGrey,
                  size: getPercentageWidth(4, context),
                ),
              ),
            ],
          ),
          SizedBox(height: getPercentageHeight(1, context)),
          Text(
            message,
            style: textTheme.bodyMedium?.copyWith(
              color: isDarkMode ? kWhite : kDarkGrey,
              fontSize: getTextScale(3.5, context),
            ),
          ),
          SizedBox(height: getPercentageHeight(2, context)),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    await _markPromptShown();
                    onAction();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kAccentLight,
                    foregroundColor: kWhite,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: EdgeInsets.symmetric(
                      vertical: getPercentageHeight(1.5, context),
                    ),
                  ),
                  child: Text(
                    actionText,
                    style: TextStyle(
                      fontSize: getTextScale(3.5, context),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              SizedBox(width: getPercentageWidth(2, context)),
              TextButton(
                onPressed: () async {
                  await _markPromptShown();
                  onDismiss();
                },
                child: Text(
                  dismissText,
                  style: TextStyle(
                    color: isDarkMode ? kWhite : kDarkGrey,
                    fontSize: getTextScale(3.5, context),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomSheet(BuildContext context) {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: EdgeInsets.all(getPercentageWidth(4, context)),
      decoration: BoxDecoration(
        color: isDarkMode ? kDarkGrey : kWhite,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.restaurant_menu,
                color: kAccentLight,
                size: getPercentageWidth(6, context),
              ),
              SizedBox(width: getPercentageWidth(2, context)),
              Expanded(
                child: Text(
                  title,
                  style: textTheme.titleLarge?.copyWith(
                    color: isDarkMode ? kWhite : kDarkGrey,
                    fontWeight: FontWeight.w600,
                    fontSize: getTextScale(4.5, context),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: getPercentageHeight(2, context)),
          Text(
            message,
            style: textTheme.bodyLarge?.copyWith(
              color: isDarkMode ? kWhite : kDarkGrey,
              fontSize: getTextScale(3.8, context),
            ),
          ),
          SizedBox(height: getPercentageHeight(3, context)),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    await _markPromptShown();
                    onAction();
                    Get.back();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kAccentLight,
                    foregroundColor: kWhite,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: EdgeInsets.symmetric(
                      vertical: getPercentageHeight(2, context),
                    ),
                  ),
                  child: Text(
                    actionText,
                    style: TextStyle(
                      fontSize: getTextScale(4, context),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              SizedBox(width: getPercentageWidth(2, context)),
              Expanded(
                child: TextButton(
                  onPressed: () async {
                    await _markPromptShown();
                    onDismiss();
                    Get.back();
                  },
                  child: Text(
                    dismissText,
                    style: TextStyle(
                      color: isDarkMode ? kWhite : kDarkGrey,
                      fontSize: getTextScale(4, context),
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: getPercentageHeight(1, context)),
        ],
      ),
    );
  }

  Future<void> _markPromptShown() async {
    switch (storageKey) {
      case OnboardingPromptHelper.PROMPT_GOALS_SHOWN:
        await OnboardingPromptHelper.markGoalsPromptShown();
        break;
      case OnboardingPromptHelper.PROMPT_DIETARY_SHOWN:
        await OnboardingPromptHelper.markDietaryPromptShown();
        break;
      case OnboardingPromptHelper.PROMPT_WEIGHT_SHOWN:
        await OnboardingPromptHelper.markWeightPromptShown();
        break;
      case OnboardingPromptHelper.PROMPT_PROFILE_SHOWN:
        await OnboardingPromptHelper.markProfilePromptShown();
        break;
    }
  }
}
