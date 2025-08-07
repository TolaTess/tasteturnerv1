import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:get/get.dart';

import '../constants.dart';

class HelperController extends GetxController {
  static HelperController instance = Get.find();

  final RxList<Map<String, dynamic>> plans = RxList<Map<String, dynamic>>([]);
  final RxList<Map<String, dynamic>> category =
      RxList<Map<String, dynamic>>([]);
  final RxList<Map<String, dynamic>> macros = RxList<Map<String, dynamic>>([]);
  final RxList<Map<String, dynamic>> headers = RxList<Map<String, dynamic>>([]);
  final RxList<Map<String, dynamic>> kidsCategory =
      RxList<Map<String, dynamic>>([]);
  final RxList<Map<String, dynamic>> mainCategory =
      RxList<Map<String, dynamic>>([]);
  RxMap<String, dynamic> winners = <String, dynamic>{}.obs;
  final RxList<Map<String, dynamic>> rainbow = RxList<Map<String, dynamic>>([]);
  @override
  void onInit() {
    super.onInit();
    fetchPlans();
    fetchCategorys();
    fetchHeaders();
    fetchMacros();
    fetchWinners();
    fetchKidsCategory();
    fetchRainbows();
    fetchMainCategory();
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

  Future<void> fetchMainCategory() async {
    try {
      final snapshot = await firestore.collection('mainCategory').get();
      if (snapshot.docs.isEmpty) {
        mainCategory.value = [];
        return;
      }

      mainCategory.value = snapshot.docs
          .map((doc) {
            try {
              final data = doc.data();
              return {
                'id': doc.id,
                'name': data['name'] as String? ?? '',
              };
            } catch (e) {
              print('Error parsing main category data: $e');
              return null;
            }
          })
          .whereType<Map<String, dynamic>>()
          .toList();
    } catch (e) {
      print('Error fetching main category: $e');
      mainCategory.value = [];
    }
  }

  Future<void> fetchKidsCategory() async {
    try {
      final snapshot = await firestore.collection('kidsfilter').get();
      if (snapshot.docs.isEmpty) {
        kidsCategory.value = [];
        return;
      }

      kidsCategory.value = snapshot.docs
          .map((doc) {
            try {
              final data = doc.data();
              return {
                'id': doc.id,
                'name': data['name'] as String? ?? '',
              };
            } catch (e) {
              print('Error parsing kids category data: $e');
              return null;
            }
          })
          .whereType<Map<String, dynamic>>()
          .toList();
    } catch (e) {
      print('Error fetching kids category: $e');
      kidsCategory.value = [];
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

  Future<void> fetchMacros() async {
    try {
      final snapshot = await firestore.collection('macros').get();
      if (snapshot.docs.isEmpty) {
        print('No macros documents found');
        macros.value = [];
        return;
      }

      macros.value = snapshot.docs
          .map((doc) {
            try {
              final data = doc.data();

              final categories = data['categories'];
              List<dynamic> categoriesList = [];

              if (categories != null) {
                if (categories is List) {
                  categoriesList = categories;
                } else if (categories is String) {
                  categoriesList = [categories];
                }
              }

              final result = {
                'id': doc.id,
                'name': data['name'] as String? ?? '',
                'bestFor': data['bestFor'] as List<dynamic>? ?? [],
                'equipment': data['equipment'] as List<dynamic>? ?? [],
                'heatType': data['heatType'] as String? ?? '',
                'description': data['description'] as String? ?? '',
              };
              return result;
            } catch (e) {
              print('Error parsing macro data: $e');
              return null;
            }
          })
          .whereType<Map<String, dynamic>>()
          .toList();
    } catch (e) {
      print('Error fetching macros: $e');
      macros.value = [];
    }
  }

  Future<void> fetchRainbows() async {
    try {
      final snapshot = await firestore.collection('rainbows').get();
      if (snapshot.docs.isEmpty) {
        rainbow.value = [];
        return;
      }

      rainbow.value = snapshot.docs
          .map((doc) {
            try {
              final data = doc.data();
              final name = data['name'] as String? ?? '';
              final description = data['description'] as String? ?? '';
              if (name.isEmpty) {
                print('Category name is empty for document ${doc.id}');
                return null;
              }
              return {
                'id': doc.id,
                'name': name,
                'description': description,
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
              final description = data['description'] as String? ?? '';
              if (name.isEmpty) {
                print('Category name is empty for document ${doc.id}');
                return null;
              }
              return {
                'id': doc.id,
                'name': name,
                'description': description,
                'facts': data['facts'] as List<dynamic>? ?? [],
                'kidsFriendly': data['kidsFriendly'] as bool? ?? false,
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

  Future<void> saveMealPlan(
      String userId, String formattedDate, String dayType) async {
    await firestore
        .collection('mealPlans')
        .doc(userId)
        .collection('date')
        .doc(formattedDate)
        .set({
      'userId': userId,
      'dayType': dayType,
      'isSpecial': dayType.isNotEmpty && dayType != 'regular_day',
      'date': formattedDate,
      'meals': FieldValue.arrayUnion(
          []), // Only initialize if meals field doesn't exist
    }, SetOptions(merge: true));
    FirebaseAnalytics.instance.logEvent(name: 'special_day_added');
  }

  Future<void> saveMealPlanBuddy(String userId, String formattedDate,
      String dayType, List<String> selectedMealIds) async {
    // Get existing document to preserve meals if selectedMealIds is empty
    final docRef = firestore
        .collection('mealPlans')
        .doc(userId)
        .collection('date')
        .doc(formattedDate);

    final docSnapshot = await docRef.get();

    // If selectedMealIds is empty and doc exists, keep existing meals
    final List<String> mealsToSave =
        selectedMealIds.isEmpty && docSnapshot.exists
            ? (docSnapshot.data()?['meals'] as List<dynamic>).cast<String>()
            : selectedMealIds;

    await docRef.set({
      'userId': userId,
      'dayType': dayType,
      'isSpecial': dayType.isNotEmpty && dayType != 'regular_day',
      'date': formattedDate,
      'meals': mealsToSave,
    }, SetOptions(merge: true));
  }
}
