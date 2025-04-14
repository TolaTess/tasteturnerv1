import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';

import '../constants.dart';

class HelperController extends GetxController {
  static HelperController instance = Get.find();

  final RxList<Map<String, dynamic>> plans = RxList<Map<String, dynamic>>([]);
  final RxList<Map<String, dynamic>> category =
      RxList<Map<String, dynamic>>([]);

  @override
  void onInit() {
    super.onInit();
    fetchPlans();
    fetchCategorys();
  }

// Fetch plans from Firestore
  Future<void> fetchPlans() async {
    try {
      final snapshot = await firestore.collection('plans').get();
      if (snapshot.docs.isEmpty) {
        plans.value = [];
        return;
      }

      plans.value = snapshot.docs
          .map((doc) {
            try {
              final data = doc.data();
              return {
                'months': (data['months'] as num?)?.toInt() ?? 0,
                'price': (data['price'] as num?)?.toDouble() ?? 0.0,
                'price_per_month':
                    (data['price_per_month'] as num?)?.toDouble() ?? 0.0,
                'isPopular': data['isPopular'] as bool? ?? false,
              };
            } catch (e) {
              print('Error parsing plan data: $e');
              return null;
            }
          })
          .whereType<Map<String, dynamic>>()
          .toList();
    } catch (e) {
      print('Error fetching plans: $e');
      plans.value = [];
    }
  }

  Future<void> fetchCategorys() async {
    try {
      final snapshot = await firestore.collection('category').get();
      if (snapshot.docs.isEmpty) {
        category.value = [];
        return;
      }

      category.value = snapshot.docs
          .map((doc) {
            try {
              final data = doc.data();
              final name = data['name'] as String? ?? '';
              if (name.isEmpty) {
                print('Category name is empty for document ${doc.id}');
                return null;
              }
              return {
                'id': doc.id,
                'name': name,
              };
            } catch (e) {
              print('Error parsing category data: $e');
              return null;
            }
          })
          .whereType<Map<String, dynamic>>()
          .toList()
        ..sort((a, b) => a['name'].compareTo(b['name']));
    } catch (e) {
      print('Error fetching categories: $e');
      category.value = [];
    }
  }

  Future<List<Map<String, dynamic>>> getAllChallenges() async {
    try {
      final QuerySnapshot snapshot =
          await firestore.collection('group_cha').get();
      if (snapshot.docs.isEmpty) {
        return [];
      }

      final now = DateTime.now();

      return snapshot.docs
          .map((doc) {
            try {
              final data = doc.data() as Map<String, dynamic>;
              final String? endDateString = data['endDate'];
              if (endDateString == null) {
                print('End date is missing for challenge ${doc.id}');
                return null;
              }

              final DateTime? endDate = DateTime.tryParse(endDateString);
              if (endDate == null) {
                print('Invalid end date format for challenge ${doc.id}');
                return null;
              }

              if (endDate.isAfter(now)) {
                return {
                  'id': doc.id,
                  ...data,
                };
              }
              return null;
            } catch (e) {
              print('Error parsing challenge data: $e');
              return null;
            }
          })
          .whereType<Map<String, dynamic>>()
          .toList();
    } catch (e) {
      print("Error fetching all challenges: $e");
      return [];
    }
  }

  Future<void> addChallenge(Map<String, dynamic> challenge) async {
    try {
      if (!challenge.containsKey('endDate')) {
        throw Exception('Challenge must have an end date');
      }
      await firestore.collection('group_cha').add(challenge);
    } catch (e) {
      print('Error adding challenge: $e');
      throw Exception('Failed to add challenge: $e');
    }
  }

  Future<void> updateChallenge(
      String id, Map<String, dynamic> updatedData) async {
    try {
      if (id.isEmpty) {
        throw Exception('Invalid challenge ID');
      }
      await firestore.collection('group_cha').doc(id).update(updatedData);
    } catch (e) {
      print('Error updating challenge: $e');
      throw Exception('Failed to update challenge: $e');
    }
  }

  Future<void> deleteChallenge(String id) async {
    try {
      if (id.isEmpty) {
        throw Exception('Invalid challenge ID');
      }
      await firestore.collection('group_cha').doc(id).delete();
    } catch (e) {
      print('Error deleting challenge: $e');
      throw Exception('Failed to delete challenge: $e');
    }
  }
}
