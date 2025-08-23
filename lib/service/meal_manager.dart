import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'dart:convert';

import '../constants.dart';
import '../data_models/meal_model.dart';
import '../service/meal_api_service.dart';

class MealManager extends GetxController {
  static MealManager instance = Get.find();
  final RxList<Meal> _meals = <Meal>[].obs;
  List<Meal> get meals => _meals;

  @override
  void onInit() {
    super.onInit();
    fetchMeals();
  }

  // Fetch meals from Firestore, excluding duplicates by title
  Future<void> fetchMeals() async {
    try {
      final snapshot = await firestore.collection('meals').get();
      if (snapshot.docs.isEmpty) {
        _meals.value = [];
        return;
      }

      // Use a map to track seen titles and keep only first occurrence
      final seenTitles = <String, bool>{};
      _meals.value = snapshot.docs
          .map((doc) {
            try {
              final data = doc.data();
              final meal = Meal.fromJson(doc.id, data);

              // Skip if we've seen this title before
              if (seenTitles[meal.title.toLowerCase()] == true) {
                return null;
              }

              seenTitles[meal.title.toLowerCase()] = true;
              return meal;
            } catch (e) {
              return null;
            }
          })
          .whereType<Meal>()
          .toList();
    } catch (e) {
      _meals.value = [];
    }
  }

  Future<List<Meal>> fetchMealsByCategory(String category) async {
    if (category.isEmpty) {
      return [];
    }
    try {
      QuerySnapshot snapshot;
      if (category.toLowerCase() == 'balanced' ||
          category.toLowerCase() == 'general' ||
          category.toLowerCase() == 'all') {
        snapshot = await firestore.collection('meals').get();
      } else {
        snapshot = await firestore
            .collection('meals')
            .where('categories', arrayContains: category.toLowerCase())
            .get();
      }

      if (snapshot.docs.isEmpty) {
        return [];
      }

      return snapshot.docs
          .map((doc) {
            try {
              final data = doc.data() as Map<String, dynamic>;
              return Meal.fromJson(doc.id, data);
            } catch (e) {
              return null;
            }
          })
          .whereType<Meal>()
          .toList();
    } catch (e) {
      return [];
    }
  }

  // Fetch meals by technique (for technique screen)
  Future<List<Meal>> fetchMealsByTechnique(String technique) async {
    if (technique.isEmpty) {
      return [];
    }
    try {
      final snapshot = await firestore
          .collection('meals')
          .where('techniques', arrayContains: technique.toLowerCase())
          .get();

      if (snapshot.docs.isEmpty) {
        return [];
      }

      return snapshot.docs
          .map((doc) {
            try {
              final data = doc.data() as Map<String, dynamic>;
              return Meal.fromJson(doc.id, data);
            } catch (e) {
              return null;
            }
          })
          .whereType<Meal>()
          .toList();
    } catch (e) {
      return [];
    }
  }

  // Fetch all meals (for searching when on technique screen)
  Future<List<Meal>> fetchAllMeals() async {
    try {
      final snapshot = await firestore.collection('meals').get();

      if (snapshot.docs.isEmpty) {
        return [];
      }

      return snapshot.docs
          .map((doc) {
            try {
              final data = doc.data() as Map<String, dynamic>;
              return Meal.fromJson(doc.id, data);
            } catch (e) {
              return null;
            }
          })
          .whereType<Meal>()
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<Meal>> getMealsByTitles(List<String> names) async {
    if (names.isEmpty) {
      return [];
    }

    try {
      final snapshot = await firestore
          .collection('meals')
          .where('title', whereIn: names)
          .get();

      if (snapshot.docs.isEmpty) {
        return [];
      }

      return snapshot.docs
          .map((doc) {
            try {
              return Meal.fromJson(doc.id, doc.data());
            } catch (e) {
              return null;
            }
          })
          .whereType<Meal>()
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<Meal>> fetchAndEnsureMealsExist(List<String> names) async {
    try {
      final fetchedItems = await getMealsByTitles(names);

      // Convert the fetched items into a Map for quick lookup
      final Map<String, Meal> existingItemsMap = {
        for (var item in fetchedItems) item.title.toLowerCase(): item
      };

      List<Meal> completeList = names.map((name) {
        final key = name.toLowerCase();
        // If item exists in Firestore, return it; otherwise, create a placeholder
        return existingItemsMap.containsKey(key)
            ? existingItemsMap[key]!
            : Meal(
                mealId: '',
                title: name,
                userId: '',
                mediaPaths: [],
                ingredients: {},
                categories: [],
                serveQty: 0,
                calories: 0,
                createdAt: DateTime.now(),
              );
      }).toList();

      return completeList;
    } catch (e) {
      return [];
    }
  }

  Future<List<Meal>> fetchNewMeals() async {
    try {
      final snapshot = await firestore
          .collection('meals')
          .orderBy('createdAt', descending: true)
          .get();

      final meals = snapshot.docs.map((doc) {
        final data = doc.data();
        return Meal.fromJson(doc.id, data);
      }).toList();

      _meals.value = meals; // If you still want to update local state

      return meals; // ✅ Return the list of meals
    } catch (e) {
      return [];
    }
  }
  // // Add a meal to Firestore and update the local list
  Future<void> addMeal(Meal meal) async {
    try {
      final docRef = firestore.collection('meals').doc();

      // Merge `createdAt` into meal's data
      final mealData = meal.copyWith(
        mealId: docRef.id,
        createdAt: DateTime.now(),
      );

      await docRef.set(mealData.toJson());

      // Add to local state
      _meals.add(mealData);
    } catch (e) {
      return;
    }
  }

  // Remove a meal locally and from Firestore
  Future<void> removeMeal(String mealId) async {
    try {
      await firestore.collection('meals').doc(mealId).delete();
      _meals.removeWhere((meal) => meal.mealId == mealId);
    } catch (e) {
      return;
    }
  }

  Future<Meal?> getMealbyMealID(String mealId) async {
    try {
      final meal = await firestore.collection('meals').doc(mealId).get();

      if (!meal.exists) {
        return null;
      }

      final mealData = meal.data();
      if (mealData == null) {
        return null;
      }

      try {
        final meal = Meal.fromJson(mealId, mealData as Map<String, dynamic>);
        return meal;
      } catch (parseError) {
        return null;
      }
    } catch (e) {
      print('❌ Error fetching meal with ID $mealId: $e');
      return null;
    }
  }

  Future<List<Meal>> getMealsByMealIds(List<String> mealIds) async {
    try {
      // Initialize an empty list to hold the Meal objects
      final List<Meal> meals = [];
      final apiService = MealApiService();

      // Separate API and Firestore meal IDs
      final List<String> firestoreMealIds = [];
      final List<String> apiMealIds = [];

      for (var id in mealIds) {
        if (id.startsWith('api_')) {
          apiMealIds.add(id.substring(4)); // Remove 'api_' prefix
        } else {
          firestoreMealIds.add(id);
        }
      }

      // Fetch Firestore meals in batches
      if (firestoreMealIds.isNotEmpty) {
        const int batchSize = 10;
        for (int i = 0; i < firestoreMealIds.length; i += batchSize) {
          final batchIds = firestoreMealIds.sublist(
            i,
            i + batchSize > firestoreMealIds.length
                ? firestoreMealIds.length
                : i + batchSize,
          );

          final QuerySnapshot mealsSnapshot = await firestore
              .collection('meals')
              .where(FieldPath.documentId, whereIn: batchIds)
              .get();

          meals.addAll(mealsSnapshot.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return Meal.fromJson(doc.id, data);
          }));
        }
      }

      // Fetch API meals one by one
      if (apiMealIds.isNotEmpty) {
        for (String mealId in apiMealIds) {
          try {
            final response = await http.get(
              Uri.parse('${MealApiService.baseUrl}/lookup.php?i=$mealId'),
            );

            if (response.statusCode == 200) {
              final data = json.decode(response.body);
              final mealsData = data['meals'] as List<dynamic>?;

              if (mealsData != null && mealsData.isNotEmpty) {
                final apiMeal = apiService
                    .convertToMeal(mealsData[0] as Map<String, dynamic>);
                meals.add(apiMeal);
              }
            }
            // Add a small delay to prevent rate limiting
            await Future.delayed(const Duration(milliseconds: 100));
          } catch (e) {}
        }
      }

      return meals;
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> searchMeals(String query) async {
    try {
      final snapshot = await firestore
          .collection('meals')
          .where('title', isGreaterThanOrEqualTo: query)
          .where('title', isLessThan: '${query}z')
          .get();
      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<Meal>> fetchFavoriteMeals() async {
    try {
      String? currentUserId = userService.userId;

      if (currentUserId == null || currentUserId.isEmpty) {
        throw Exception('User ID is null or empty');
      }

      // Fetch the user's document
      final DocumentSnapshot userDoc =
          await firestore.collection('users').doc(currentUserId).get();

      if (!userDoc.exists) {
        throw Exception('User document does not exist');
      }

      // Get the array of favorite meal IDs
      final List<dynamic>? favoriteMealIds = (userDoc.data()
          as Map<String, dynamic>?)?['favorites'] as List<dynamic>?;

      if (favoriteMealIds == null || favoriteMealIds.isEmpty) {
        return []; // Return an empty list if there are no favorites
      }

      final List<Meal> favoriteMeals = [];
      final apiService = MealApiService();

      // Separate API and Firestore meal IDs
      final List<String> firestoreMealIds = [];
      final List<String> apiMealIds = [];

      for (var id in favoriteMealIds) {
        if (id.toString().startsWith('api_')) {
          apiMealIds.add(id.toString().replaceFirst('api_', ''));
        } else {
          firestoreMealIds.add(id.toString());
        }
      }

      // Fetch Firestore meals in batches
      if (firestoreMealIds.isNotEmpty) {
        const int batchSize = 10;
        for (int i = 0; i < firestoreMealIds.length; i += batchSize) {
          final batchIds = firestoreMealIds.sublist(
            i,
            i + batchSize > firestoreMealIds.length
                ? firestoreMealIds.length
                : i + batchSize,
          );

          final QuerySnapshot mealsSnapshot = await firestore
              .collection('meals')
              .where(FieldPath.documentId, whereIn: batchIds)
              .get();

          favoriteMeals.addAll(mealsSnapshot.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return Meal.fromJson(doc.id, data);
          }));
        }
      }

      // Fetch API meals one by one
      if (apiMealIds.isNotEmpty) {
        for (String mealId in apiMealIds) {
          try {
            final response = await http.get(
              Uri.parse('${MealApiService.baseUrl}/lookup.php?i=$mealId'),
            );

            if (response.statusCode == 200) {
              final data = json.decode(response.body);
              final meals = data['meals'] as List<dynamic>?;

              if (meals != null && meals.isNotEmpty) {
                final apiMeal =
                    apiService.convertToMeal(meals[0] as Map<String, dynamic>);
                favoriteMeals.add(apiMeal);
              }
            }
            // Add a small delay to prevent rate limiting
            await Future.delayed(const Duration(milliseconds: 100));
          } catch (e) {
            print('Error fetching API meal $mealId: $e');
          }
        }
      }

      return favoriteMeals;
    } catch (e) {
      throw Exception('Could not fetch favorite meals');
    }
  }

  Future<void> updateMealType(
      String mealToRemove, String mealToAdd, String date) async {
    try {
      final docRef = firestore
          .collection('mealPlans')
          .doc(userService.userId!)
          .collection('date')
          .doc(date);

      final doc = await docRef.get();
      if (!doc.exists) return;

      List<dynamic> meals = List.from(doc['meals'] ?? []);
      int index = meals.indexOf(mealToRemove);
      if (index != -1) {
        meals[index] = mealToAdd;
        await docRef.update({'meals': meals});
      }
    } catch (e) {
      return;
    }
  }

  //___________________MEAL PLAN____________________________

  Future<void> addMealPlan(DateTime date, List<String> mealIds) async {
    try {
      final formattedDate = DateFormat('yyyy-MM-dd').format(date);
      final docRef = firestore
          .collection('mealPlans')
          .doc(userService.userId!)
          .collection('date')
          .doc(formattedDate);

      // Get existing meal plan document
      final docSnapshot = await docRef.get();
      List<String> existingMealIds = [];

      if (docSnapshot.exists) {
        final data = docSnapshot.data();
        if (data != null && data['meals'] != null) {
          existingMealIds = List<String>.from(data['meals']);
        }
      }

      // Merge existing and new meal IDs, removing duplicates
      final mergedMealIds = {...existingMealIds, ...mealIds}.toList();

      final mealPlan = {
        'date': formattedDate,
        'meals': mergedMealIds,
        'isSpecial': true,
        'dayType': 'spin_special',
      };

      await docRef.set(mealPlan, SetOptions(merge: true));
    } catch (e) {
      return;
    }
  }

  Future<List<Map<String, dynamic>>> getMealPlansOrderedByDate() async {
    try {
      // Fetch meal plans ordered by date
      final querySnapshot = await firestore
          .collection('mealPlans')
          .orderBy('date', descending: false) // Ascending order (oldest first)
          .get();

      final List<Map<String, dynamic>> mealPlansWithMeals = [];

      // Process each meal plan
      for (final doc in querySnapshot.docs) {
        final mealPlanData = doc.data();
        final mealIds = List<String>.from(mealPlanData['meals']);
        final meals = await getMealsByMealIds(mealIds);

        // Add meal plan data along with associated meals
        mealPlansWithMeals.add({
          'id': doc.id,
          'date': mealPlanData['date'],
          'meals': meals, // List of Meal objects
        });
      }

      return mealPlansWithMeals;
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getMealPlansByDate(DateTime date) async {
    try {
      // Fetch meal plans for the specific date
      final querySnapshot = await firestore
          .collection('mealPlans')
          .where('date', isEqualTo: date.toIso8601String())
          .get();

      final List<Map<String, dynamic>> mealPlansWithMeals = [];

      // Process each meal plan
      for (final doc in querySnapshot.docs) {
        final mealPlanData = doc.data();
        final mealIds = List<String>.from(mealPlanData['meals']);
        final meals = await getMealsByMealIds(mealIds);

        // Add meal plan data along with associated meals
        mealPlansWithMeals.add({
          'id': doc.id,
          'date': mealPlanData['date'],
          'meals': meals, // List of Meal objects
        });
      }

      return mealPlansWithMeals;
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getMealPlansForWeek(
      DateTime startDate, DateTime endDate) async {
    try {
      final querySnapshot = await firestore
          .collection('mealPlans')
          .where('date', isGreaterThanOrEqualTo: startDate.toIso8601String())
          .where('date', isLessThanOrEqualTo: endDate.toIso8601String())
          .orderBy('date', descending: false) // Optional: chronological order
          .get();

      return querySnapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      return [];
    }
  }
}
