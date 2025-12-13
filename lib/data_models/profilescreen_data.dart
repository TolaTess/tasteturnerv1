import 'package:get/get.dart';
import 'package:flutter/foundation.dart' show debugPrint;

import '../constants.dart';
import '../helper/utils.dart';

class BadgeAchievementData {
  final String title;
  final String description;
  final List<String> userids;
  final String image;

  BadgeAchievementData({
    required this.title,
    required this.description,
    required this.userids,
    required this.image,
  });
}

class BadgeController extends GetxController {
  static BadgeController get instance {
    try {
      return Get.find<BadgeController>();
    } catch (e) {
      debugPrint('⚠️ BadgeController not found, creating instance');
      return Get.put(BadgeController());
    }
  }

  // Observable list to hold badges
  var badgeAchievements = <BadgeAchievementData>[].obs;
  // Observable list to hold user IDs
  var userIdsForBadge = <String>[].obs;

  List<BadgeAchievementData> getMyBadge(String userid) {
    return badgeAchievements
        .where((badge) => badge.userids.any((users) => users == userid))
        .toList(); // Return the matching MacroData objects
  }

  /// Add a badge to Firestore
  Future<void> addBadge(BadgeAchievementData badge) async {
    try {
      final badgeCollection = firestore.collection('badges');
      await badgeCollection.add({
        'title': badge.title,
        'description': badge.description,
        'userids': badge.userids,
        'image': badge.image,
      });
    } catch (e) {
      final context = Get.context;
      if (context != null) {
        showTastySnackbar(
            'Something went wrong', 'Please try again later', context,
            backgroundColor: kRed);
      }
    }
  }

  /// Fetch all badges from Firestore
  Future<void> fetchBadges() async {
    try {
      final badgeCollection = firestore.collection('badges');
      final querySnapshot = await badgeCollection.get();
      badgeAchievements.value = querySnapshot.docs.map((doc) {
        final data = doc.data();
        return BadgeAchievementData(
          title: data['title'] ?? '',
          description: data['description'] ?? '',
          userids: List<String>.from(data['userids'] ?? []),
          image: data['image'] ?? '',
        );
      }).toList();
    } catch (e) {
      final context = Get.context;
      if (context != null) {
        showTastySnackbar(
            'Something went wrong', 'Please try again later', context,
            backgroundColor: kRed);
      }
    }
  }

  /// Fetch badges associated with a specific user ID
  Future<void> fetchBadgesByUserId(String userId) async {
    try {
      final badgeCollection = firestore.collection('badges');
      final querySnapshot = await badgeCollection
          .where('userids',
              arrayContains: userId) // Query badges for this user ID
          .get();

      // Map Firestore data to BadgeAchievementData objects
      badgeAchievements.value = querySnapshot.docs.map((doc) {
        final data = doc.data();
        return BadgeAchievementData(
          title: data['title'] ?? '',
          description: data['description'] ?? '',
          userids: List<String>.from(data['userids'] ?? []),
          image: data['image'] ?? '',
        );
      }).toList();
    } catch (e) {
      final context = Get.context;
      if (context != null) {
        showTastySnackbar(
            'Something went wrong', 'Please try again later', context,
            backgroundColor: kRed);
      }
    }
  }

  /// Fetch all user IDs for a specific badge ID
  Future<void> fetchUserIdsByBadgeId(String badgeId) async {
    try {
      final badgeDoc = await firestore.collection('badges').doc(badgeId).get();

      if (badgeDoc.exists) {
        final data = badgeDoc.data();
        if (data != null && data['userids'] is List) {
          userIdsForBadge.value = List<String>.from(data['userids']);
        } else {
          userIdsForBadge.clear();
        }
      } else {
        userIdsForBadge.clear();
      }
    } catch (e) {
      final context = Get.context;
      if (context != null) {
        showTastySnackbar(
            'Something went wrong', 'Please try again later', context,
            backgroundColor: kRed);
      }
    }
  }
}
