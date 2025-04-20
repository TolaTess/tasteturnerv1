import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';

import '../constants.dart';

class HelperController extends GetxController {
  static HelperController instance = Get.find();

  final RxList<Map<String, dynamic>> plans = RxList<Map<String, dynamic>>([]);
  final RxList<Map<String, dynamic>> category =
      RxList<Map<String, dynamic>>([]);
  final RxList<Map<String, dynamic>> headers = RxList<Map<String, dynamic>>([]);
  RxMap<String, dynamic> winners = <String, dynamic>{}.obs;

  @override
  void onInit() {
    super.onInit();
    fetchPlans();
    fetchCategorys();
    fetchHeaders();
    fetchWinners();
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

  Future<void> fetchHeaders() async {
    try {
      final snapshot = await firestore.collection('headers').get();
      if (snapshot.docs.isEmpty) {
        headers.value = [];
        return;
      }

      headers.value = snapshot.docs
          .map((doc) {
            try {
              final data = doc.data();
              return {
                'id': doc.id,
                'name': data['name'] as String? ?? '',
              };
            } catch (e) {
              print('Error parsing header data: $e');
              return null;
            }
          })
          .whereType<Map<String, dynamic>>()
          .toList();
    } catch (e) {
      print('Error fetching headers: $e');
      headers.value = [];
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

  Future<void> fetchWinners() async {
    try {
      final snapshot = await firestore.collection('winners').doc('dates').get();
      if (!snapshot.exists) {
        winners.value = {};
        return;
      }

      winners.clear();
      final datesData = snapshot.data() as Map<String, dynamic>;

      // Find active week
      String? activeWeek;
      for (var weekDate in datesData.keys) {
        final weekData = datesData[weekDate];
        if (weekData is Map<String, dynamic> && weekData['isActive'] == true) {
          activeWeek = weekDate;
          break;
        }
      }

      if (activeWeek == null) {
        winners.value = {};
        return;
      }

      final activeWeekData = datesData[activeWeek];
      if (activeWeekData is! Map<String, dynamic>) {
        winners.value = {};
        return;
      }

      try {
        final categories = activeWeekData['categories'] as Map<String, dynamic>;
        final List<Map<String, dynamic>> allWinners = [];

        for (var category in categories.keys) {
          final userIds = categories[category] as List<dynamic>;

          for (String userId in userIds) {
            String position = '';
            String cleanUserId = userId;

            // Extract position and clean user ID
            if (userId.endsWith('-1st')) {
              position = '1st';
              cleanUserId = userId.replaceAll('-1st', '');
            } else if (userId.endsWith('-2nd')) {
              position = '2nd';
              cleanUserId = userId.replaceAll('-2nd', '');
            } else if (userId.endsWith('-3rd')) {
              position = '3rd';
              cleanUserId = userId.replaceAll('-3rd', '');
            }

            if (position.isNotEmpty && cleanUserId.isNotEmpty) {
              final userDoc =
                  await firestore.collection('users').doc(cleanUserId).get();
              if (userDoc.exists) {
                allWinners.add({
                  'userId': cleanUserId,
                  'displayName': userDoc.data()?['displayName'] ?? 'Unknown',
                  'position': position,
                  'category': category,
                  'date': activeWeekData['date'],
                });
              }
            }
          }
        }

        // Sort winners by category and position
        allWinners.sort((a, b) {
          int categoryCompare = a['category'].compareTo(b['category']);
          if (categoryCompare != 0) return categoryCompare;
          return a['position'].compareTo(b['position']);
        });

        winners.value = {
          'weekId': activeWeek,
          'date': activeWeekData['date'],
          'winners': allWinners,
        };
      } catch (e) {
        print('Error processing winners data: $e');
        winners.value = {};
      }
    } catch (e) {
      print('Error fetching winners: $e');
      winners.value = {};
    }
  }

  Future<void> saveWinners(String weekId,
      Map<String, List<String>> categoryWinners, String date) async {
    try {
      // First, deactivate all other weeks
      final snapshot = await firestore.collection('winners').doc('dates').get();
      if (snapshot.exists) {
        final datesData = snapshot.data() as Map<String, dynamic>;
        for (var week in datesData.keys) {
          if (datesData[week] is Map<String, dynamic>) {
            await firestore.collection('winners').doc('dates').update({
              '$week.isActive': false,
            });
          }
        }
      }

      // Create a map for each category's winners
      Map<String, dynamic> winnersData = {};
      categoryWinners.forEach((category, userIds) {
        winnersData[category] = userIds;
      });

      // Save the winners with categories
      await firestore.collection('winners').doc('dates').set({
        weekId: {
          'date': date,
          'categories': winnersData,
          'isActive': true,
        }
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error saving winners: $e');
      throw Exception('Failed to save winners: $e');
    }
  }
}
