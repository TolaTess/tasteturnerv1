import 'dart:async';
import 'package:get/get.dart';
import 'package:flutter/material.dart' show debugPrint;

import '../constants.dart';

class FirebaseService extends GetxController {
  static FirebaseService get instance {
    return Get.find<FirebaseService>(); // Always registered in main.dart
  }

  final RxMap<String, dynamic> generalData = <String, dynamic>{}.obs;
  Future<List<Map<String, dynamic>>> fetchPlans() async {
    try {
      final snapshot = await firestore.collection('plans').get();
      if (snapshot.docs.isEmpty) {
        return [];
      }
      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      debugPrint('Error fetching plans: $e');
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
      debugPrint('Error checking if recipe is favorite: $e');
      return false;
    }
  }

  Future<void> toggleFavorite(String? userId, String itemId) async {
    if (userId == null || userId.isEmpty || itemId.isEmpty) {
      debugPrint('Invalid user ID or item ID');
      return;
    }
    try {
      final userDocRef = firestore.collection('users').doc(userId);
      final userDoc = await userDocRef.get();

      if (!userDoc.exists) {
        return;
      }

      final userData = userDoc.data();
      if (userData == null) {
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
      debugPrint('Error toggling favorite: $e');
    }
  }

  // --------------------------ADD to DB-------------------------------------
}
