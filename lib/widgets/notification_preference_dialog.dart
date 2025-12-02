import 'package:flutter/material.dart';
import '../constants.dart';
import '../helper/utils.dart';

/// Widget for showing notification preference dialog
class NotificationPreferenceDialog extends StatelessWidget {
  final VoidCallback? onNotificationsInitialized;

  const NotificationPreferenceDialog({
    super.key,
    this.onNotificationsInitialized,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = getThemeProvider(context).isDarkMode;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: isDarkMode ? kDarkGrey : kWhite,
      title: Row(
        children: [
          Icon(Icons.notifications_active,
              color: kAccent, size: getIconScale(8, context)),
          SizedBox(width: getPercentageWidth(3, context)),
          Expanded(
            child: Text(
              'Enable Notifications?',
              style: TextStyle(
                color: isDarkMode ? kWhite : kDarkGrey,
                fontSize: getTextScale(4.5, context),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      content: Text(
        'Stay on track with meal reminders, hydration alerts, and personalized nutrition tips!',
        style: TextStyle(
          color: isDarkMode ? kWhite.withOpacity(0.9) : kDarkGrey,
          fontSize: getTextScale(3.5, context),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () async {
            try {
              // User declined
              await authController.updateUserData({
                'settings.notificationsEnabled': false,
                'settings.notificationPreferenceSet': true,
              });
              if (context.mounted) {
                Navigator.of(context).pop();
              }
            } catch (e) {
              debugPrint('Error updating notification preference: $e');
              if (context.mounted) {
                Navigator.of(context).pop();
              }
            }
          },
          child: Text(
            'Not Now',
            style: TextStyle(
              color: isDarkMode ? kWhite.withOpacity(0.7) : kLightGrey,
              fontSize: getTextScale(3.5, context),
            ),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: kAccent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            padding: EdgeInsets.symmetric(
              horizontal: getPercentageWidth(6, context),
              vertical: getPercentageHeight(1.5, context),
            ),
          ),
          onPressed: () async {
            try {
              // User accepted
              await authController.updateUserData({
                'settings.notificationsEnabled': true,
                'settings.notificationPreferenceSet': true,
              });
              if (context.mounted) {
                Navigator.of(context).pop();
              }

              // Call the initialization callback
              onNotificationsInitialized?.call();

              // Show success message
              if (context.mounted) {
                showTastySnackbar(
                  'Notifications Enabled',
                  'You\'ll now receive helpful reminders!',
                  context,
                  backgroundColor: kAccent,
                );
              }
            } catch (e) {
              debugPrint('Error enabling notifications: $e');
              if (context.mounted) {
                Navigator.of(context).pop();
                showTastySnackbar(
                  'Error',
                  'Failed to enable notifications. Please try again.',
                  context,
                  backgroundColor: Colors.red,
                );
              }
            }
          },
          child: Text(
            'Enable',
            style: TextStyle(
              color: kWhite,
              fontSize: getTextScale(3.5, context),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}

