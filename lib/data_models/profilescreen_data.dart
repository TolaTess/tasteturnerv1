//data model for SearchContent
import 'package:get/get.dart';

import '../constants.dart';

// class SearchContentData {
//   final String image, postType;

//   SearchContentData({
//     required this.image,
//     required this.postType,
//   });
// }

// List<SearchContentData> searchContentDatas = [
//   SearchContentData(
//     image: "assets/images/news/news-1.jpg",
//     postType: "single",
//   ),
//   SearchContentData(
//     image: "assets/images/news/news-2.jpg",
//     postType: "slideshow",
//   ),
//   SearchContentData(
//     image: "assets/images/news/news-3.jpg",
//     postType: "video",
//   ),
//   SearchContentData(
//     image: "assets/images/news/news-4.jpg",
//     postType: "slideshow",
//   ),
//   SearchContentData(
//     image: "assets/images/news/news-5.jpg",
//     postType: "slideshow",
//   ),
//   SearchContentData(
//     image: "assets/images/news/news-6.jpg",
//     postType: "video",
//   ),
//   SearchContentData(
//     image: "assets/images/news/news-7.jpg",
//     postType: "single",
//   ),
//   SearchContentData(
//     image: "assets/images/news/news-8.jpg",
//     postType: "slideshow",
//   ),
//   SearchContentData(
//     image: "assets/images/news/news-9.jpg",
//     postType: "video",
//   ),
//   SearchContentData(
//     image: "assets/images/news/news-10.jpg",
//     postType: "single",
//   ),
//   SearchContentData(
//     image: "assets/images/news/news-11.jpg",
//     postType: "slideshow",
//   ),
//   SearchContentData(
//     image: "assets/images/news/news-12.jpg",
//     postType: "video",
//   ),
//   SearchContentData(
//     image: "assets/images/news/news-13.jpg",
//     postType: "slideshow",
//   ),
//   SearchContentData(
//     image: "assets/images/news/news-13.jpg",
//     postType: "single",
//   ),
//   SearchContentData(
//     image: "assets/images/news/news-15.jpg",
//     postType: "single",
//   ),
//   SearchContentData(
//     image: "assets/images/news/news-16.jpg",
//     postType: "video",
//   ),
//   SearchContentData(
//     image: "assets/images/news/news-17.jpg",
//     postType: "slideshow",
//   ),
//   SearchContentData(
//     image: "assets/images/news/news-18.jpg",
//     postType: "video",
//   ),
//   SearchContentData(
//     image: "assets/images/news/news-19.jpg",
//     postType: "single",
//   ),
//   SearchContentData(
//     image: "assets/images/news/news-20.jpg",
//     postType: "slideshow",
//   ),
//   SearchContentData(
//     image: "assets/images/video-1.jpg",
//     postType: "slideshow",
//   ),
//   SearchContentData(
//     image: "assets/images/video-2.jpg",
//     postType: "slideshow",
//   ),
//   SearchContentData(
//     image: "assets/images/video-3.jpg",
//     postType: "slideshow",
//   ),
//   SearchContentData(
//     image: "assets/images/video-4.jpg",
//     postType: "slideshow",
//   ),
//   SearchContentData(
//     image: "assets/images/video-5.jpg",
//     postType: "slideshow",
//   ),
//   SearchContentData(
//     image: "assets/images/video-5.jpg",
//     postType: "slideshow",
//   ),
//   SearchContentData(
//     image: "assets/images/video-7.jpg",
//     postType: "slideshow",
//   ),
// ];

class BadgeAchievementData {
  final String title;
  final String description;
  final List<String> userids;

  BadgeAchievementData({
    required this.title,
    required this.description,
    required this.userids,
  });
}

class BadgeController extends GetxController {
  static BadgeController instance = Get.find();

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
      });
    } catch (e) {
      print("Error adding badge: $e");
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
        );
      }).toList();
    } catch (e) {
      print("Error fetching badges: $e");
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
        );
      }).toList();
    } catch (e) {
      print("Error fetching badges for user $userId: $e");
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
          print("No user IDs found for badge $badgeId.");
          userIdsForBadge.clear();
        }
      } else {
        print("Badge with ID $badgeId does not exist.");
        userIdsForBadge.clear();
      }
    } catch (e) {
      print("Error fetching user IDs for badge $badgeId: $e");
    }
  }
}
