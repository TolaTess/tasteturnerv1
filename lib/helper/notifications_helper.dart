// Check if we've already sent a notification today for steps goal
// and send one if we haven't
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import '../constants.dart';
import '../service/battle_management.dart';

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
            'Congratulations! You reached your goal of $targetSteps steps today. Keep moving! 10 points awarded!',
      );
      await BattleManagement.instance
          .updateUserPoints(userService.userId ?? '', 10);

      // Mark that we've sent a notification today
      await prefs.setBool(stepNotificationKey, true);
    }
  } catch (e) {
    print('Error sending step goal notification: $e');
  }
}

Future<void> deleteImagesFromStorage(List<String> imageUrls,
    {String? folder}) async {
  for (var url in imageUrls) {
    if (url.startsWith('http')) {
      try {
        final uri = Uri.parse(url);
        final segments = uri.pathSegments;
        final imageName = segments.isNotEmpty ? segments.last : null;
        if (imageName != null) {
          final storagePath = extractStoragePathFromUrl(url);
          if (storagePath != null) {
            final ref = firebaseStorage.ref().child(storagePath);
            await ref.delete();
          }
        }
      } catch (e) {
        print('Error deleting image from storage: $e');
      }
    }
  }
}

String? extractStoragePathFromUrl(String url) {
  final uri = Uri.parse(url);
  final path = uri.path; // e.g. /v0/b/<bucket>/o/post_images%2Fabc123.jpg
  final oIndex = path.indexOf('/o/');
  if (oIndex == -1) return null;
  final encodedFullPath = path.substring(oIndex + 3); // after '/o/'
  // Remove any trailing segments after the file path (e.g., before '?')
  final questionMarkIndex = encodedFullPath.indexOf('?');
  final encodedPath = questionMarkIndex == -1
      ? encodedFullPath
      : encodedFullPath.substring(0, questionMarkIndex);
  return Uri.decodeFull(encodedPath);
}
