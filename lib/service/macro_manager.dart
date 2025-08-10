import 'dart:math';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import '../data_models/macro_data.dart';
import '../constants.dart';
import '../helper/utils.dart';
import 'meal_api_service.dart';
import 'battle_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';

class MacroManager extends GetxController {
  static final MacroManager instance = Get.put(MacroManager());
  static int _instanceCount = 0;
  final BattleService _battleService = Get.find<BattleService>();
  final FirebaseFunctions functions = FirebaseFunctions.instance;
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final FirebaseAuth auth = FirebaseAuth.instance;

  List<MacroData> _demoIngredientData = [];
  RxList<Map<String, dynamic>> _ingredientBattle = <Map<String, dynamic>>[].obs;
  RxList<MacroData> generatedShoppingList = <MacroData>[].obs;
  RxList<MacroData> manualShoppingList = <MacroData>[].obs;
  RxBool isShoppingListLoading = true.obs;

  StreamSubscription? _shoppingListSubscription;

  MacroManager() {
    _instanceCount++;
    print(
        'MacroManager constructor called. Instance count: $_instanceCount, hashCode: ${hashCode}');
  }

  // Getter to retrieve ingredients
  List<MacroData> get ingredient => _demoIngredientData;
  List<Map<String, dynamic>> get ingredientBattle => _ingredientBattle;
  final RxMap<String, bool> shoppingList = <String, bool>{}.obs;
  final RxMap<String, bool> previousShoppingList = <String, bool>{}.obs;
  final RxMap<String, bool> groceryList = <String, bool>{}.obs;

  @override
  void onInit() {
    super.onInit();

    if (userService.userId != null) {
      _listenToShoppingList(userService.userId!);
    }

    // Initialize ingredients data on startup
    _initializeIngredients();

    // Listen for auth changes to start/stop the listener
    auth.authStateChanges().listen((user) {
      _shoppingListSubscription?.cancel();
      if (user != null) {
        _listenToShoppingList(user.uid);
      } else {
        // Clear lists when user logs out
        generatedShoppingList.clear();
        manualShoppingList.clear();
        isShoppingListLoading.value = false;
      }
    });
  }

  Future<void> _initializeIngredients() async {
    try {
      await fetchIngredients();
    } catch (e) {
      print('MacroManager _initializeIngredients error: $e');
    }
  }

  @override
  void onClose() {
    _shoppingListSubscription?.cancel();
    super.onClose();
  }

  Future<void> fetchIngredients() async {
    try {
      final snapshot = await firestore.collection('ingredients').get();

      if (snapshot.docs.isEmpty) {
        _demoIngredientData = [];
        return;
      }

      List<MacroData> tempList = [];
      int successCount = 0;
      int errorCount = 0;

      for (var doc in snapshot.docs) {
        try {
          final data = doc.data();
          final macro = MacroData.fromJson(data, doc.id);
          tempList.add(macro);
          successCount++;
        } catch (docError) {
          errorCount++;
        }
      }

      _demoIngredientData = tempList;
    } catch (e) {
      _demoIngredientData = [];
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

  /// Saves a list of ingredients to the manual shopping list by calling a Cloud Function.
  /// Used for features like the "Spin the Wheel".
  Future<void> saveShoppingList(List<MacroData> items) async {
    try {
      final HttpsCallable callable =
          functions.httpsCallable('addManualItemsToShoppingList');

      // Convert the List<MacroData> to the format expected by the Cloud Function.
      final List<Map<String, String?>> itemsPayload = items.map((item) {
        // The amount is stored in the macros map as a workaround.
        final amount = item.macros['amount'] as String?;
        return {
          'ingredientId': item.id,
          'amount': amount,
        };
      }).toList();

      await callable.call(<String, dynamic>{
        'items': itemsPayload,
      });
    } on FirebaseFunctionsException catch (e) {
      return;
    } catch (e) {
      return;
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
        return [];
      }

      // Extract item IDs from the document
      final data = docSnapshot.data();
      if (data != null && data['items'] != null) {
        final List<String> itemIds = List<String>.from(data['items'].keys);

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
      return [];
    }
  }

  /// Fetch shopping list and listen for real-time updates
  void fetchShoppingList(String userId, String currentWeek) {
    firestore
        .collection('userMeals')
        .doc(userId)
        .collection('shoppingList')
        .doc(currentWeek)
        .snapshots()
        .listen((docSnapshot) async {
      if (docSnapshot.exists && docSnapshot.data() != null) {
        final data = docSnapshot.data();
        if (data != null && data['items'] != null) {
          final Map<String, dynamic> itemsMap =
              Map<String, dynamic>.from(data['items']);
          final Map<String, bool> statusMap =
              itemsMap.map((key, value) => MapEntry(key, value == true));
          if (statusMap.isEmpty) {
            shoppingList.clear();
            return;
          }

          shoppingList.assignAll(statusMap);
        } else {
          shoppingList.clear();
        }
      } else {
        shoppingList.clear();
      }
    }, onError: (e) {
      return;
    });
  }

  /// Toggles an item's purchased status in Firestore.
  /// This function reads the document, modifies the map in memory,
  /// and writes the entire map back to overcome Firestore's path limitations with '/'.
  Future<void> markItemPurchased(String key, bool isPurchased,
      {required bool isManual}) async {
    final userId = auth.currentUser?.uid;
    if (userId == null) {
      return;
    }

    final weekId = getCurrentWeek();
    final docRef = firestore
        .collection('userMeals')
        .doc(userId)
        .collection('shoppingList')
        .doc(weekId);

    try {
      await firestore.runTransaction((transaction) async {
        final docSnapshot = await transaction.get(docRef);

        if (!docSnapshot.exists) {
          return;
        }

        // Get the entire data map from the document.
        final data = docSnapshot.data()!;
        final mapFieldToUpdate = isManual ? 'manualItems' : 'generatedItems';

        // Make a mutable copy of the specific map we need to change.
        final Map<String, dynamic> itemsMap =
            Map<String, dynamic>.from(data[mapFieldToUpdate] ?? {});

        // Update the value for our specific key.
        if (itemsMap.containsKey(key)) {
          itemsMap[key] = isPurchased;
        } else {
          return;
        }

        // Write the entire modified map back to the document.
        transaction.update(docRef, {mapFieldToUpdate: itemsMap});
      });
    } catch (e) {
      return;
    }
  }

  Future<void> removeFromShoppingList(String userId, MacroData item,
      {bool isManual = false}) async {
    try {
      if (item.id == null) {
        return;
      }

      final currentWeek = getCurrentWeek();
      final userMealsRef = firestore
          .collection('userMeals')
          .doc(userId)
          .collection('shoppingList')
          .doc(currentWeek);

      // Determine which field to update based on whether it's manual or generated
      final fieldToUpdate = isManual ? 'manualItems' : 'generatedItems';

      // Remove the ingredient id from the appropriate map
      await userMealsRef.set({
        fieldToUpdate: {item.id!: FieldValue.delete()},
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Refresh the shopping lists after deletion
      await refreshShoppingLists(userId, currentWeek);
    } catch (e) {
      print('Error removing item from shopping list: $e');
      return;
    }
  }

  Future<void> refreshShoppingLists(String userId, String weekId) async {
    try {
      // Use Future.delayed to avoid calling during build phase
      Future.delayed(const Duration(milliseconds: 100), () {
        _listenToShoppingList(userId);
      });
    } catch (e) {
      print('Error refreshing shopping lists: $e');
    }
  }

  // Add method to fetch shopping list for a specific week
  Future<Map<String, bool>> fetchShoppingListForWeekWithStatus(
      String userId, String week) async {
    try {
      final userMealsRef = firestore
          .collection('userMeals')
          .doc(userId)
          .collection('shoppingList')
          .doc(week);

      final docSnapshot = await userMealsRef.get();

      if (!docSnapshot.exists) {
        return {};
      }

      final data = docSnapshot.data();
      if (data != null && data['items'] != null) {
        final Map<String, dynamic> itemsMap =
            Map<String, dynamic>.from(data['items']);
        final Map<String, bool> statusMap =
            itemsMap.map((key, value) => MapEntry(key, value == true));
        return statusMap;
      }

      return {};
    } catch (e) {
      return {};
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

  bool _isFetching = false;

  Future<void> _ensureDataFetched() async {
    if (_demoIngredientData.isNotEmpty) {
      return;
    }

    if (_isFetching) {
      // Wait for the current fetch to complete
      while (_isFetching) {
        await Future.delayed(Duration(milliseconds: 100));
      }
      return;
    }

    _isFetching = true;
    try {
      print('_ensureDataFetched: fetching ingredients');
      print('Before fetch - ingredient.length: ${ingredient.length}');
      await fetchIngredients();
      print('After fetch - ingredient.length: ${ingredient.length}');
    } finally {
      _isFetching = false;
    }
  }

  Future<List<MacroData>> getIngredients() async {
    await _ensureDataFetched();

    return ingredient;
  }

  Future<List<MacroData>> getIngredientsByCategory(String category) async {
    await _ensureDataFetched();
    String lowerCaseCategory = category.toLowerCase();

    if (lowerCaseCategory == "general" || lowerCaseCategory == "all") {
      return ingredient;
    }

    if (lowerCaseCategory == 'smoothie') {
      return ingredient
          .where((ingredient) => ingredient.techniques.any((technique) =>
              technique.toLowerCase().contains('smoothie') ||
              technique.toLowerCase().contains('blending') ||
              technique.toLowerCase().contains('juicing')))
          .toList();
    }
    if (lowerCaseCategory == 'soup') {
      return ingredient
          .where((ingredient) => ingredient.techniques.any((technique) =>
              technique.toLowerCase().contains('soup') ||
              technique.toLowerCase().contains('stewing')))
          .toList();
    }
    return ingredient
        .where((ingredient) => ingredient.techniques.any(
            (technique) => technique.toLowerCase().contains(lowerCaseCategory)))
        .toList();
  }

  Future<List<Map<String, dynamic>>> getIngredientsBattle(
      String category) async {
    try {
      // Get current battle date from general/data document
      final currentBattleKey = firebaseService.generalData['currentBattle'];
      final battleDeadline = firebaseService.generalData['battleDeadline'];

      if (currentBattleKey == null) {
        print('No current battle found in general data');
        return [];
      }

      // Get battle data from battles/general document (where dates are stored)
      final battleRef = firestore.collection('battles').doc('general');
      final battleDoc = await battleRef.get();

      if (!battleDoc.exists) {
        print('No general data document found');
        return [];
      }

      final battleData = battleDoc.data() as Map<String, dynamic>;

      // Use nested structure: dates.{battleId}
      if (!battleData.containsKey('dates') ||
          battleData['dates'] is! Map<String, dynamic>) {
        print('No dates structure found');
        return [];
      }

      final datesMap = battleData['dates'] as Map<String, dynamic>;
      if (!datesMap.containsKey(currentBattleKey)) {
        print('No battle data found for: $currentBattleKey');
        return [];
      }

      final currentBattle = datesMap[currentBattleKey] as Map<String, dynamic>;

      // Check if battle is still active
      if (currentBattle['status'] != 'active') {
        print('Battle is not active, status: ${currentBattle['status']}');
        return [];
      }

      // Check if battle deadline has passed
      if (battleDeadline != null) {
        DateTime deadline;
        if (battleDeadline is Timestamp) {
          deadline = battleDeadline.toDate();
        } else if (battleDeadline is String) {
          deadline = DateTime.parse(battleDeadline);
        } else {
          deadline = DateTime.now().add(const Duration(days: 7));
        }

        if (DateTime.now().isAfter(deadline)) {
          print('Battle deadline has passed: $deadline');
          return [];
        }
      }

      // Get ingredients from the battle
      final ingredients = currentBattle['ingredients'] as List<dynamic>?;
      if (ingredients == null || ingredients.isEmpty) {
        print('No ingredients found in current battle');
        return [];
      }

      // Build the battle ingredients list
      final List<Map<String, dynamic>> battleIngredients = [];

      for (final ingredient in ingredients) {
        final ingredientData = ingredient as Map<String, dynamic>;
        battleIngredients.add({
          'id': ingredientData['id'],
          'name': ingredientData['name'],
          'image': ingredientData['image'],
          'categoryId':
              currentBattleKey, // Use the battle date key as category ID
        });
      }

      return battleIngredients;
    } catch (e) {
      print('Error getting ingredients battle: $e');
      return [];
    }
  }

  Future<bool> isMacroTypePresent(
      List<MacroData> macroList, String type) async {
    return macroList
        .any((macro) => macro.type.toLowerCase() == type.toLowerCase());
  }

  Future<List<String>> getUniqueTypes(List<MacroData> macroDataList) async {
    return macroDataList
        .map((macro) => macro.type)
        .where((type) => type.isNotEmpty)
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
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  Future<MacroData?> fetchIngredientByName(String ingredientName) async {
    try {
      final querySnapshot = await firestore
          .collection('ingredients')
          .where('title', isEqualTo: ingredientName.trim())
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final ingredientDoc = querySnapshot.docs.first;
        return MacroData.fromJson(ingredientDoc.data(), ingredientDoc.id);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<MacroData?> addIngredient(MacroData ingredient) async {
    try {
      final docRef =
          await firestore.collection('ingredients').add(ingredient.toJson());
      // Set the id on the MacroData object
      final macroWithId = ingredient.copyWith(id: docRef.id);
      // Optionally, add to local cache
      _demoIngredientData.add(macroWithId);
      return macroWithId;
    } catch (e) {
      return null;
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
        }
      }
    } catch (e) {
      return [];
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
      return {
        'ingredients': [],
        'meals': [],
      };
    }
  }

  Future<void> addMacro(MacroData macro) async {
    await firestore.collection('ingredients').add(macro.toJson());
  }

  // New function to call the Cloud Function and trigger shopping list generation
  Future<void> generateAndFetchShoppingList() async {
    try {
      final HttpsCallable callable =
          functions.httpsCallable('generateAndSaveWeeklyShoppingList');
      final result = await callable.call();
      // The listener will automatically pick up the new list
    } catch (e) {
      return;
    }
  }

  /// Listens to the weekly shopping list document in real-time.
  /// This is now the single source of truth for the shopping list UI.
  void _listenToShoppingList(String userId) {
    isShoppingListLoading.value = true;
    final weekId = getCurrentWeek();

    final docRef = firestore
        .collection('userMeals')
        .doc(userId)
        .collection('shoppingList')
        .doc(weekId);

    _shoppingListSubscription = docRef.snapshots().listen((snapshot) async {
      isShoppingListLoading.value = true;
      try {
        List<MacroData> newGeneratedList = [];
        List<MacroData> newManualList = [];

        if (snapshot.exists && snapshot.data() != null) {
          final data = snapshot.data()!;
          final generatedData = data['generatedItems'] as Map<String, dynamic>?;
          final manualData = data['manualItems'] as Map<String, dynamic>?;

          // Helper to process a map of items
          Future<List<MacroData>> processItems(
              Map<String, dynamic>? itemMap) async {
            if (itemMap == null) return [];

            List<MacroData> processedList = [];
            for (var entry in itemMap.entries) {
              final key = entry.key;
              final isSelected = entry.value as bool;

              final parts = key.split('/');
              final id = parts[0];
              final amount = parts.length > 1 ? parts.sublist(1).join('/') : '';

              final ingredientDoc =
                  await firestore.collection('ingredients').doc(id).get();
              if (ingredientDoc.exists) {
                final data = ingredientDoc.data()!;
                final image = data['mediaPaths'] != null &&
                        (data['mediaPaths'] as List).isNotEmpty
                    ? data['mediaPaths'][0]
                    : 'assets/images/placeholder.jpg';

                final newItem = MacroData(
                    id: key,
                    title: data['title'] ?? 'Unknown Ingredient',
                    isSelected: isSelected,
                    macros: {'amount': amount},
                    image: image,
                    // These are dummy values as they aren't needed for the shopping list item view
                    mediaPaths: [],
                    type: '',
                    categories: [],
                    features: {});
                processedList.add(newItem);
              }
            }
            return processedList;
          }

          newGeneratedList = await processItems(generatedData);
          newManualList = await processItems(manualData);
        }

        generatedShoppingList.assignAll(newGeneratedList);
        manualShoppingList.assignAll(newManualList);
      } catch (e) {
        generatedShoppingList.clear();
        manualShoppingList.clear();
      } finally {
        isShoppingListLoading.value = false;
      }
    });
  }

  Future<Map<String, String>> _fetchIngredientsData(List<String> ids) async {
    if (ids.isEmpty) return {};
    final Map<String, String> ingredientsMap = {};

    // Firestore 'whereIn' queries are limited to 30 elements per query.
    for (var i = 0; i < ids.length; i += 30) {
      final sublist = ids.sublist(i, i + 30 > ids.length ? ids.length : i + 30);
      try {
        final snapshot = await firestore
            .collection('ingredients')
            .where(FieldPath.documentId, whereIn: sublist)
            .get();
        for (var doc in snapshot.docs) {
          ingredientsMap[doc.id] =
              (doc.data()['title'] as String?) ?? 'No Title';
        }
      } catch (e) {
        return {};
      }
    }
    return ingredientsMap;
  }

  /// Returns the first [n] ingredients after ensuring data is fetched.
  /// Evenly distributes ingredients across 4 types (protein, grain, vegetable, fruit).
  Future<List<MacroData>> getFirstNIngredients(int n) async {
    await _ensureDataFetched();

    if (ingredient.isEmpty) return [];

    // Define the required types
    final requiredTypes = ['protein', 'grain', 'vegetable', 'fruit'];

    // Calculate how many ingredients per type
    final perType = n ~/ 4; // Integer division
    final remainder = n % 4; // Remaining ingredients to distribute

    List<MacroData> result = [];

    // Get ingredients for each type
    for (int i = 0; i < requiredTypes.length; i++) {
      final type = requiredTypes[i];
      final typeIngredients = ingredient
          .where((item) => item.type.toLowerCase() == type.toLowerCase())
          .toList();

      // Calculate how many ingredients this type should get
      int targetCount = perType;
      if (i < remainder) {
        targetCount += 1; // Distribute remainder among first few types
      }

      if (typeIngredients.isNotEmpty) {
        // Take up to targetCount ingredients of this type
        final ingredientsToAdd = typeIngredients.take(targetCount).toList();
        result.addAll(ingredientsToAdd);
      }
    }

    // If we still don't have enough ingredients (some types might be empty),
    // fill with remaining ingredients from any type
    if (result.length < n) {
      final remainingIngredients = ingredient
          .where((item) => !result.contains(item))
          .take(n - result.length)
          .toList();
      result.addAll(remainingIngredients);
    }

    return result;
  }

  /// Force refresh ingredients data
  Future<void> forceRefreshIngredients() async {
    _demoIngredientData.clear();
    _isFetching = false;
    await fetchIngredients();
  }
}
