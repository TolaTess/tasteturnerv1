import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import '../data_models/macro_data.dart';
import '../constants.dart';
import 'meal_api_service.dart';
import 'battle_service.dart';

class MacroManager extends GetxController {
  static final MacroManager instance = Get.put(MacroManager());
  final BattleService _battleService = Get.find<BattleService>();

  List<MacroData> _demoIngredientData = [];
  RxList<Map<String, dynamic>> _ingredientBattle = <Map<String, dynamic>>[].obs;

  // Getter to retrieve ingredients
  List<MacroData> get ingredient => _demoIngredientData;
  List<Map<String, dynamic>> get ingredientBattle => _ingredientBattle;
  final RxList<MacroData> shoppingList = <MacroData>[].obs;

  Future<void> fetchIngredients() async {
    try {
      final snapshot = await firestore.collection('ingredients').get();
      if (snapshot.docs.isEmpty) {
        _demoIngredientData = [];
        return;
      }
      _demoIngredientData = snapshot.docs
          .map((doc) {
            try {
              return MacroData.fromJson(doc.data(), doc.id);
            } catch (e) {
              print('Error parsing ingredient data: $e');
              return null;
            }
          })
          .whereType<MacroData>()
          .toList();
    } catch (e) {
      print('Error fetching ingredients: $e');
      _demoIngredientData = [];
    }
  }

  Future<void> fetchIngredientBattle() async {
    try {
      final activeBattles = await _battleService.getActiveBattles();
      _ingredientBattle.value = activeBattles;
    } catch (e) {
      print('Error fetching ingredient battle: $e');
      _ingredientBattle.value = [];
    }
  }

  Future<List<String>> getMacroDataByType(String type) async {
    if (type.isEmpty) {
      return [];
    }
    String lowerType = type.toLowerCase();
    await _ensureDataFetched();

    // Use the getter to retrieve data
    return ingredient
        .where((macro) => macro.type.toLowerCase() == lowerType)
        .map((macro) => macro.title)
        .where((title) => title.isNotEmpty)
        .toList();
  }

  // Helper method to get current week number
  int getCurrentWeek() {
    final now = DateTime.now();
    final firstDayOfYear = DateTime(now.year, 1, 1);
    final days = now.difference(firstDayOfYear).inDays;
    return (days / 7).ceil();
  }

  Future<void> saveShoppingList(
      String userId, List<MacroData> newShoppingList) async {
    try {
      if (newShoppingList.isEmpty) {
        print("Error: Attempted to save an empty shopping list.");
        throw Exception("Shopping list is empty.");
      }

      final currentWeek = getCurrentWeek();
      final userMealsRef = firestore
          .collection('userMeals')
          .doc(userId)
          .collection('shoppingList')
          .doc('week_$currentWeek');

      // Get the existing document first
      final docSnapshot = await userMealsRef.get();
      List<String> existingItemIds = [];

      if (docSnapshot.exists) {
        final data = docSnapshot.data();
        if (data != null && data['itemIds'] != null) {
          existingItemIds = List<String>.from(data['itemIds']);
        }
      }

      // Get IDs from new items and filter out nulls
      final List<String> newItemIds = newShoppingList
          .map((item) => item.id)
          .where((id) => id != null)
          .cast<String>()
          .toList();

      // Merge existing and new items, removing duplicates
      final Set<String> mergedItemIds = {...existingItemIds, ...newItemIds};

      // Save the merged data with week information
      await userMealsRef.set({
        'itemIds': mergedItemIds.toList(),
        'week': currentWeek,
        'year': DateTime.now().year,
        'created_at': docSnapshot.exists ? FieldValue.serverTimestamp() : null,
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print("Error saving shopping list: $e");
      throw Exception("Failed to save shopping list");
    }
  }

  Future<List<MacroData>> fetchMyShoppingList(String userId) async {
    try {
      final currentWeek = getCurrentWeek();
      final userMealsRef = firestore
          .collection('userMeals')
          .doc(userId)
          .collection('shoppingList')
          .doc('week_$currentWeek');

      final docSnapshot = await userMealsRef.get();

      if (!docSnapshot.exists) {
        print("No shopping list found for week $currentWeek.");
        return [];
      }

      // Extract item IDs from the document
      final data = docSnapshot.data();
      if (data != null && data['itemIds'] != null) {
        final List<String> itemIds = List<String>.from(data['itemIds']);

        if (itemIds.isEmpty) return [];

        // Fetch complete MacroData objects using the IDs
        final List<MacroData> items = [];

        // Batch the queries to avoid hitting Firestore limits
        const int batchSize = 10;
        for (var i = 0; i < itemIds.length; i += batchSize) {
          final end =
              (i + batchSize < itemIds.length) ? i + batchSize : itemIds.length;
          final batch = itemIds.sublist(i, end);

          final QuerySnapshot querySnapshot = await firestore
              .collection('ingredients')
              .where(FieldPath.documentId, whereIn: batch)
              .get();

          items.addAll(querySnapshot.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return MacroData.fromJson(data, doc.id);
          }));
        }

        return items;
      }

      return [];
    } catch (e) {
      print("Error fetching shopping list: $e");
      return [];
    }
  }

  /// Fetch shopping list and listen for real-time updates
  void fetchShoppingList(String userId) {
    final currentWeek = getCurrentWeek();
    firestore
        .collection('userMeals')
        .doc(userId)
        .collection('shoppingList')
        .doc('week_$currentWeek')
        .snapshots()
        .listen((docSnapshot) async {
      if (docSnapshot.exists && docSnapshot.data() != null) {
        final data = docSnapshot.data();
        if (data != null && data['itemIds'] != null) {
          final List<String> itemIds = List<String>.from(data['itemIds']);

          if (itemIds.isEmpty) {
            shoppingList.clear();
            return;
          }

          try {
            final List<MacroData> items = [];

            // Batch the queries
            const int batchSize = 10;
            for (var i = 0; i < itemIds.length; i += batchSize) {
              final end = (i + batchSize < itemIds.length)
                  ? i + batchSize
                  : itemIds.length;
              final batch = itemIds.sublist(i, end);

              final QuerySnapshot querySnapshot = await firestore
                  .collection('ingredients')
                  .where(FieldPath.documentId, whereIn: batch)
                  .get();

              items.addAll(querySnapshot.docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return MacroData.fromJson(data, doc.id);
              }));
            }

            shoppingList.assignAll(items);
          } catch (e) {
            print("Error fetching shopping list items: $e");
            shoppingList.clear();
          }
        } else {
          shoppingList.clear();
        }
      } else {
        shoppingList.clear();
      }
    }, onError: (e) {
      print("Error fetching shopping list: $e");
    });
  }

  /// Add an item to the shopping list
  Future<void> addToShoppingList(String userId, MacroData item) async {
    try {
      if (item.id == null) {
        print("Cannot add item with null ID");
        return;
      }

      final currentWeek = getCurrentWeek();
      final userMealsRef = firestore
          .collection('userMeals')
          .doc(userId)
          .collection('shoppingList')
          .doc('week_$currentWeek');

      final docSnapshot = await userMealsRef.get();
      List<String> itemIds = [];

      if (docSnapshot.exists && docSnapshot.data() != null) {
        final data = docSnapshot.data()!;
        if (data.containsKey('itemIds')) {
          itemIds =
              List<String>.from(data['itemIds'].where((id) => id != null));
        }
      }

      // Prevent duplicate items
      if (!itemIds.contains(item.id)) {
        itemIds.add(item.id!);
        await userMealsRef.set({
          'itemIds': itemIds,
          'week': currentWeek,
          'year': DateTime.now().year,
          'updated_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      print("Error adding to shopping list: $e");
    }
  }

  Future<void> removeFromShoppingList(String userId, MacroData item) async {
    try {
      if (item.id == null) {
        print("Cannot remove item with null ID");
        return;
      }

      final currentWeek = getCurrentWeek();
      final userMealsRef = firestore
          .collection('userMeals')
          .doc(userId)
          .collection('shoppingList')
          .doc('week_$currentWeek');

      final DocumentSnapshot docSnapshot = await userMealsRef.get();

      if (!docSnapshot.exists || docSnapshot.data() == null) {
        print("No shopping list found for week $currentWeek.");
        return;
      }

      final data = docSnapshot.data() as Map<String, dynamic>;

      if (!data.containsKey('itemIds')) {
        print("No items found in the shopping list.");
        return;
      }

      List<String> itemIds =
          List<String>.from(data['itemIds'].where((id) => id != null));
      itemIds.remove(item.id!);

      await userMealsRef.set({
        'itemIds': itemIds,
        'week': currentWeek,
        'year': DateTime.now().year,
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print("Error removing item from shopping list: $e");
      throw Exception("Failed to remove item from shopping list");
    }
  }

  // Add method to fetch shopping list for a specific week
  Future<List<MacroData>> fetchShoppingListForWeek(String userId, int week,
      [int? year]) async {
    try {
      year ??= DateTime.now().year;
      final userMealsRef = firestore
          .collection('userMeals')
          .doc(userId)
          .collection('shoppingList')
          .doc('week_$week');

      final docSnapshot = await userMealsRef.get();

      if (!docSnapshot.exists) {
        print("No shopping list found for week $week of year $year.");
        return [];
      }

      final data = docSnapshot.data();
      if (data != null && data['itemIds'] != null && data['year'] == year) {
        final List<String> itemIds = List<String>.from(data['itemIds']);
        if (itemIds.isEmpty) return [];

        final List<MacroData> items = [];
        const int batchSize = 10;

        for (var i = 0; i < itemIds.length; i += batchSize) {
          final end =
              (i + batchSize < itemIds.length) ? i + batchSize : itemIds.length;
          final batch = itemIds.sublist(i, end);

          final QuerySnapshot querySnapshot = await firestore
              .collection('ingredients')
              .where(FieldPath.documentId, whereIn: batch)
              .get();

          items.addAll(querySnapshot.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return MacroData.fromJson(data, doc.id);
          }));
        }

        return items;
      }

      return [];
    } catch (e) {
      print("Error fetching shopping list for week $week: $e");
      return [];
    }
  }

  Future<List<MacroData>> fetchAndEnsureIngredientsExist(
      List<String> names) async {
    try {
      final fetchedItems = await getIngredientsByTitles(names);

      // Convert the fetched items into a Map for quick lookup
      final Map<String, MacroData> existingItemsMap = {
        for (var item in fetchedItems) item.title.toLowerCase(): item
      };

      List<MacroData> completeList = names.map((name) {
        final key = name.toLowerCase();
        // If item exists in Firestore, return it; otherwise, create a placeholder
        return existingItemsMap.containsKey(key)
            ? existingItemsMap[key]!
            : MacroData(
                title: name,
                type: "Unknown",
                mediaPaths: [],
                macros: {},
                categories: [],
                features: {},
              );
      }).toList();

      return completeList;
    } catch (e) {
      print("Error fetching ingredients 4: $e");
      return [];
    }
  }

  Future<List<MacroData>> getIngredientsByTitles(List<String> names) async {
    List<String> lowerCaseTitles =
        names.map((name) => name.toLowerCase()).toList();
    await _ensureDataFetched();

    // Use the getter to filter ingredients
    return ingredient
        .where((macro) => lowerCaseTitles.contains(macro.title.toLowerCase()))
        .toList();
  }

  Future<List<MacroData>> getTwoIngredients(String category) async {
    String lowerCaseCategory = category.toLowerCase();
    await _ensureDataFetched();

    if (lowerCaseCategory == "all") {
      return _getRandomMacroData(ingredient, 2);
    }

    List<MacroData> filteredData = ingredient
        .where((macro) => macro.categories
            .any((cat) => cat.toLowerCase() == lowerCaseCategory))
        .toList();

    return _getRandomMacroData(filteredData, 2);
  }

  Future<void> _ensureDataFetched() async {
    if (_demoIngredientData.isEmpty) {
      await fetchIngredients();
    }
  }

  Future<void> _ensureDataFetchedBattle() async {
    if (_ingredientBattle.isEmpty) {
      await fetchIngredientBattle();
    }
  }

  Future<List<MacroData>> getIngredientsByCategory(String category) async {
    await _ensureDataFetched();
    String lowerCaseCategory = category.toLowerCase();

    if (lowerCaseCategory == "all") {
      return ingredient;
    }

    return ingredient
        .where((macro) => macro.categories
            .any((cat) => cat.toLowerCase() == lowerCaseCategory))
        .toList();
  }

  Future<List<Map<String, dynamic>>> getIngredientsBattle(
      String category) async {
    try {
      final battles = await _battleService.getBattlesByCategory(category);
      if (battles.isEmpty) return [];

      final activeBattles = battles.where((battle) {
        final dates = battle['dates'] as Map<String, dynamic>;
        // Check all dates in the battle for an active status
        return dates.values.any((dateData) =>
            dateData is Map<String, dynamic> &&
            dateData['status'] == 'active' &&
            !DateTime.now().isAfter(DateTime.parse(dateData['ended_at'])));
      }).toList();

      if (activeBattles.isEmpty) return [];

      // Find the battle with the earliest active date
      final currentBattle = activeBattles.reduce((a, b) {
        final aDates = a['dates'] as Map<String, dynamic>;
        final bDates = b['dates'] as Map<String, dynamic>;

        // Find earliest active date for each battle
        final aActiveDate = aDates.entries
            .where((entry) => entry.value['status'] == 'active')
            .map((entry) => entry.key)
            .reduce((a, b) => a.compareTo(b) < 0 ? a : b);

        final bActiveDate = bDates.entries
            .where((entry) => entry.value['status'] == 'active')
            .map((entry) => entry.key)
            .reduce((a, b) => a.compareTo(b) < 0 ? a : b);

        return aActiveDate.compareTo(bActiveDate) < 0 ? a : b;
      });

      // Get the earliest active date for this battle
      final dates = currentBattle['dates'] as Map<String, dynamic>;
      final activeDate = dates.entries
          .where((entry) => entry.value['status'] == 'active')
          .map((entry) => entry.key)
          .reduce((a, b) => a.compareTo(b) < 0 ? a : b);

      final battleData = dates[activeDate];
      if (battleData == null) return [];

      // Check if battle has ended
      final endDate = DateTime.parse(battleData['ended_at']);
      if (DateTime.now().isAfter(endDate)) {
        return [];
      }

      final List<Map<String, dynamic>> battleIngredients = [];
      for (String ingredientId in battleData['ingredients']) {
        final ingredient = await fetchIngredient(ingredientId);
        if (ingredient != null) {
          battleIngredients.add({
            'id': ingredientId,
            'name': ingredient.title,
            'image': ingredient.mediaPaths.isNotEmpty
                ? ingredient.mediaPaths.first
                : '',
            'categoryId': currentBattle['id'],
            'dueDate': battleData['ended_at'],
          });
        }
      }
      return battleIngredients;
    } catch (e) {
      print('Error getting ingredients battle: $e');
      return [];
    }
  }

  Future<void> joinBattle(String userId, String battleId, String categoryName,
      String userName, String userImage) async {
    try {
      await _battleService.joinBattle(
        battleId: battleId,
        userId: userId,
        userName: userName,
        userImage: userImage,
      );
      _ensureDataFetchedBattle();
    } catch (e) {
      print('Error joining battle: $e');
      rethrow;
    }
  }

  Future<bool> isUserInBattle(String userId, String battleId) async {
    if (userId.isEmpty || battleId.isEmpty) return false;

    try {
      return await _battleService.hasUserJoinedBattle(battleId, userId);
    } catch (e) {
      print('Error checking if user is in battle: $e');
      return false;
    }
  }

  Future<void> removeUserFromBattle(String userId, String battleId) async {
    try {
      // This functionality needs to be implemented in BattleService
      await _battleService.removeUserFromBattle(userId, battleId);
      _ensureDataFetchedBattle();
    } catch (e) {
      print('Error removing user from battle: $e');
      rethrow;
    }
  }

  Future<bool> isMacroTypePresent(
      List<MacroData> macroList, String type) async {
    return macroList
        .any((macro) => macro.type.toLowerCase() == type.toLowerCase());
  }

  Future<List<String>> getUniqueTypes(List<MacroData> macroDataList) async {
    return ingredient
        .map((macroDataList) => macroDataList.type)
        .toSet()
        .toList();
  }

  Future<MacroData?> fetchIngredient(String ingredientId) async {
    try {
      final ingredientDoc =
          await firestore.collection('ingredients').doc(ingredientId).get();
      if (ingredientDoc.exists) {
        return MacroData.fromJson(ingredientDoc.data()!, ingredientId);
      } else {
        print('Ingredient with ID $ingredientId not found');
        return null;
      }
    } catch (e) {
      print('Error fetching ingredient: $e');
      return null;
    }
  }

  Future<MacroData?> fetchIngredientByName(String ingredientName) async {
    try {
      final querySnapshot = await firestore
          .collection('ingredients')
          .where('name', isEqualTo: ingredientName.trim())
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final ingredientDoc = querySnapshot.docs.first;
        return MacroData.fromJson(ingredientDoc.data(), ingredientDoc.id);
      } else {
        print('Ingredient with name $ingredientName not found');
        return null;
      }
    } catch (e) {
      print('Error fetching ingredient: $e');
      return null;
    }
  }

  Future<void> addIngredient(MacroData ingredient) async {
    try {
      await firestore.collection('ingredients').add(ingredient.toJson());
    } catch (e) {
      print('Error adding ingredient: $e');
    }
  }

  List<MacroData> _getRandomMacroData(
      List<MacroData> macroDataList, int count) {
    if (macroDataList.isEmpty) {
      return [];
    }
    macroDataList.shuffle(Random());
    return macroDataList.take(count).toList();
  }

  Future<List<Map<String, dynamic>>> getIngredientsWithDetails(
      Map<String, String> ingredientMap) async {
    List<Map<String, dynamic>> ingredientDetails = [];
    try {
      for (var entry in ingredientMap.entries) {
        final snapshot = await firestore
            .collection('ingredients')
            .where('name', isEqualTo: entry.key)
            .get();

        if (snapshot.docs.isNotEmpty) {
          final ingredient = snapshot.docs.first.data();
          ingredientDetails.add({
            'name': ingredient['name'],
            'image': ingredient['image'],
            'measurement': entry.value,
          });
        } else {
          print('Ingredient ${entry.key} not found in Firestore.');
        }
      }
    } catch (e) {
      print('Error fetching ingredients 3: $e');
    }
    return ingredientDetails;
  }

  Future<List<Map<String, dynamic>>> searchIngredients(String query) async {
    try {
      query = query.toLowerCase().trim();

      // Get all ingredients that match the query in name or type
      final snapshot = await firestore.collection('ingredients').get();

      return snapshot.docs.map((doc) => doc.data()).where((ingredient) {
        final name = (ingredient['name'] as String).toLowerCase();
        final type = (ingredient['type'] as String).toLowerCase();
        return name.contains(query) || type.contains(query);
      }).toList();
    } catch (e) {
      print('Error searching ingredients: $e');
      return [];
    }
  }

  // New method to combine search results from both local ingredients and API meals
  Future<Map<String, List<dynamic>>> searchMealsAndIngredients(
      String query) async {
    try {
      // Search local ingredients
      final ingredients = await searchIngredients(query);

      // Search API meals using Get.find to get the instance
      final mealApiService = Get.find<MealApiService>();
      final meals =
          await mealApiService.fetchMeals(searchQuery: query, limit: 5);

      return {
        'ingredients': ingredients,
        'meals': meals,
      };
    } catch (e) {
      print('Error searching meals and ingredients: $e');
      return {
        'ingredients': [],
        'meals': [],
      };
    }
  }

  Future<void> addMacro(MacroData macro) async {
    await firestore.collection('ingredients').add(macro.toJson());
  }
}
