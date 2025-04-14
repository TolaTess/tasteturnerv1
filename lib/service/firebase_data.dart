import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:get/get.dart';

import '../constants.dart';
import '../data_models/user_data_model.dart';

class FirebaseService extends GetxController {
  static FirebaseService instance = Get.find();

  Future<List<Map<String, dynamic>>> fetchPlans() async {
    try {
      final snapshot = await firestore.collection('plans').get();
      if (snapshot.docs.isEmpty) {
        return [];
      }
      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      print('Error fetching plans: $e');
      return []; // Return empty list instead of rethrowing
    }
  }

  // --------------------------FAV-------------------------------------

  Future<bool> isRecipeFavorite(String? userId, String itemId) async {
    if (userId == null || userId.isEmpty || itemId.isEmpty) {
      return false;
    }
    try {
      final userDoc = await firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        return false;
      }
      final userData = userDoc.data();
      if (userData == null) {
        return false;
      }
      final favorites = userData['favorites'];
      if (favorites == null) {
        return false;
      }
      return (favorites as List<dynamic>).contains(itemId);
    } catch (e) {
      print('Error checking if recipe is favorite: $e');
      return false;
    }
  }

  Future<void> toggleFavorite(String? userId, String itemId) async {
    if (userId == null || userId.isEmpty || itemId.isEmpty) {
      print('Invalid user ID or item ID');
      return;
    }
    try {
      final userDocRef = firestore.collection('users').doc(userId);
      final userDoc = await userDocRef.get();

      if (!userDoc.exists) {
        print('User document not found');
        return;
      }

      final userData = userDoc.data();
      if (userData == null) {
        print('User data is null');
        return;
      }

      final List<String> favorites =
          List<String>.from(userData['favorites'] ?? []);

      if (favorites.contains(itemId)) {
        favorites.remove(itemId);
      } else {
        favorites.add(itemId);
      }

      await userDocRef.update({'favorites': favorites});
    } catch (e) {
      print('Error toggling favorite: $e');
    }
  }

  // --------------------------ADD to DB-------------------------------------

  Future<void> addUsers(UserModel user) async {
    try {
      // Create a new document reference with an auto-generated ID
      DocumentReference postRef = firestore.collection('users').doc();

      // Set the post data with the auto-generated ID
      await postRef.set(user.toMap());
    } catch (e) {
      print("Error adding user: $e");
    }
  }
}
