// Check if we've already sent a notification today for steps goal
// and send one if we haven't
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants.dart';

void checkAndSendStepGoalNotification(int currentSteps, int targetSteps) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final String today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final String stepNotificationKey = 'step_goal_notification_$today';

    // Check if we've already sent a notification today
    final bool alreadySentToday = prefs.getBool(stepNotificationKey) ?? false;

    if (!alreadySentToday) {
      // Send notification
      await notificationService.showNotification(
        id: 2002, // Unique ID for step goal notification
        title: 'Daily Step Goal Achieved! 🏃‍♂️',
        body:
            'Congratulations! You reached your goal of $targetSteps steps today. Keep moving!',
      );

      // Mark that we've sent a notification today
      await prefs.setBool(stepNotificationKey, true);
    }
  } catch (e) {
    print('Error sending step goal notification: $e');
  }
}
