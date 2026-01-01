import 'dart:math';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart' show debugPrint;
import 'package:get/get.dart';
import '../data_models/macro_data.dart';
import '../constants.dart';
import '../helper/utils.dart';
import 'meal_api_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';

class MacroManager extends GetxController {
  static MacroManager get instance {
    if (!Get.isRegistered<MacroManager>()) {
      debugPrint('⚠️ MacroManager not registered, registering now');
      return Get.put(MacroManager());
    }
    return Get.find<MacroManager>();
  }

  static int _instanceCount = 0;
  final FirebaseFunctions functions = FirebaseFunctions.instance;
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final FirebaseAuth auth = FirebaseAuth.instance;

  List<MacroData> _demoIngredientData = [];
  RxList<MacroData> generatedShoppingList = <MacroData>[].obs;
  RxList<MacroData> manualShoppingList = <MacroData>[].obs;
  RxBool isShoppingListLoading = true.obs;

  StreamSubscription? _shoppingListSubscription;

  MacroManager() {
    _instanceCount++;
    debugPrint(
        'MacroManager constructor called. Instance count: $_instanceCount, hashCode: ${hashCode}');
  }

  // Getter to retrieve ingredients
  List<MacroData> get ingredient => _demoIngredientData;
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
      debugPrint('MacroManager _initializeIngredients error: $e');
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
  /// When ingredient ID is missing, uses the ingredient name (normalized) as the ID.
  Future<void> saveShoppingList(List<MacroData> items) async {
    try {
      debugPrint('saveShoppingList: Starting to save ${items.length} items');

      final HttpsCallable callable =
          functions.httpsCallable('addManualItemsToShoppingList');

      // Convert the List<MacroData> to the format expected by the Cloud Function.
      final List<Map<String, String?>> itemsPayload = items.map((item) {
        // The amount is stored in the macros map as a workaround.
        final amount = item.macros['amount'] as String?;
        // Use ID if available, otherwise use normalized title as ID
        final ingredientId = item.id?.isNotEmpty == true
            ? item.id
            : item.title.toLowerCase().trim();
        return {
          'ingredientId': ingredientId,
          'amount': amount,
        };
      }).toList();

      debugPrint(
          'saveShoppingList: Calling cloud function with ${itemsPayload.length} items');
      debugPrint(
          'saveShoppingList: Items: ${itemsPayload.map((i) => i['ingredientId']).join(', ')}');

      final result = await callable.call(<String, dynamic>{
        'items': itemsPayload,
      });

      debugPrint('saveShoppingList: Cloud function returned: $result');
    } on FirebaseFunctionsException catch (e) {
      debugPrint(
          'saveShoppingList: FirebaseFunctionsException - Code: ${e.code}, Message: ${e.message}, Details: ${e.details}');
      rethrow; // Re-throw so caller can handle the error
    } catch (e, stackTrace) {
      debugPrint('saveShoppingList: Unexpected error: $e');
      debugPrint('saveShoppingList: Stack trace: $stackTrace');
      rethrow; // Re-throw so caller can handle the error
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
    // Cancel existing subscription if any
    _shoppingListSubscription?.cancel();

    _shoppingListSubscription = firestore
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
      debugPrint('Error listening to shopping list: $e');
      // Show user-friendly error notification
      try {
        Get.snackbar(
          'Connection Error',
          'Unable to load shopping list. Please check your connection.',
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 3),
        );
      } catch (_) {
        // Ignore if Get.context is not available
      }
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
      final context = Get.context;
      if (context != null) {
        showTastySnackbar(
            'Something went wrong', 'Please try again later', context,
            backgroundColor: kRed);
      }
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

  // Cache for spin wheel ingredient lists
  Map<String, List<String>>? _cachedSpinWheelLists;
  DateTime? _cacheTimestamp;
  static const Duration _cacheExpiry = Duration(hours: 1);

  /// Fetches curated ingredient lists for spin wheel from Firestore
  /// Falls back to hardcoded lists if Firestore fetch fails
  Future<Map<String, List<String>>> getSpinWheelIngredientLists() async {
    try {
      // Check cache first
      if (_cachedSpinWheelLists != null &&
          _cacheTimestamp != null &&
          DateTime.now().difference(_cacheTimestamp!) < _cacheExpiry) {
        return _cachedSpinWheelLists!;
      }

      // Try to fetch from Firestore
      final docSnapshot = await firestore
          .collection('appConfig')
          .doc('spinWheelIngredients')
          .get();

      if (docSnapshot.exists) {
        final data = docSnapshot.data();
        if (data != null) {
          final Map<String, List<String>> lists = {};

          // Extract lists for each category
          for (final category in ['protein', 'grain', 'vegetable', 'fruit']) {
            if (data[category] != null && data[category] is List) {
              lists[category] = (data[category] as List)
                  .map((e) => e.toString().toLowerCase().trim())
                  .where((e) => e.isNotEmpty)
                  .toList();
            }
          }

          // Only use Firestore data if we have at least one category
          if (lists.isNotEmpty) {
            _cachedSpinWheelLists = lists;
            _cacheTimestamp = DateTime.now();
            return lists;
          }
        }
      }
    } catch (e) {
      debugPrint(
          'Error fetching spin wheel ingredient lists from Firestore: $e');
    }

    // Fallback to hardcoded lists
    _cachedSpinWheelLists =
        Map<String, List<String>>.from(fallbackSpinWheelIngredients);
    _cacheTimestamp = DateTime.now();
    return _cachedSpinWheelLists!;
  }

  Future<List<MacroData>> fetchAndEnsureIngredientsExist(List<String> names,
      {String? categoryType}) async {
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
                type: categoryType ?? "Unknown",
                mediaPaths: [],
                macros: {},
                categories: categoryType != null ? [categoryType] : [],
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
      await fetchIngredients();
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
  Future<String> generateAndFetchShoppingList() async {
    try {
      final userId = userService.userId;
      if (userId == null) {
        debugPrint('Cannot generate shopping list: No user ID');
        return 'error';
      }

      final now = DateTime.now();
      final dateStr =
          "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

      debugPrint('Generating shopping list for user: $userId, date: $dateStr');

      final HttpsCallable callable = functions.httpsCallable(
        'generateAndSaveWeeklyShoppingList',
        options: HttpsCallableOptions(timeout: const Duration(minutes: 9)),
      );

      final result = await callable.call({
        'userId': userId,
        'date': dateStr,
      });

      debugPrint('Generation result: ${result.data}');

      // If result.data is null, it means no meals were found
      if (result.data == null) {
        return 'no_meals';
      }

      return 'success';
    } catch (e) {
      debugPrint('Error generating shopping list: $e');
      return 'error';
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
            // Ensure ingredients are loaded before processing
            await _ensureDataFetched();

            for (var entry in itemMap.entries) {
              final key = entry.key;
              final isSelected = entry.value as bool;

              final parts = key.split('/');
              final id = parts[0];
              final amount = parts.length > 1 ? parts.sublist(1).join('/') : '';

              // Look up the ingredient name by ID from the ingredients list
              String title = id; // Fallback to ID if not found
              String image = intPlaceholderImage;
              String type = '';

              // Find the ingredient in the loaded ingredients list
              final ingredient = _demoIngredientData.firstWhere(
                (ing) => ing.id == id,
                orElse: () => MacroData(
                  id: id,
                  title: id,
                  type: '',
                  macros: {},
                  categories: [],
                  features: {},
                  mediaPaths: [],
                ),
              );

              // Use the ingredient's actual title and other properties
              title = ingredient.title.isNotEmpty ? ingredient.title : id;
              image = ingredient.image.isNotEmpty
                  ? ingredient.image
                  : intPlaceholderImage;
              type = ingredient.type;

              final newItem = MacroData(
                  id: key,
                  title: title,
                  isSelected: isSelected,
                  macros: {'amount': amount},
                  image: image,
                  type: type,
                  // These are dummy values as they aren't needed for the shopping list item view
                  mediaPaths: ingredient.mediaPaths.isNotEmpty
                      ? ingredient.mediaPaths
                      : [],
                  categories: ingredient.categories,
                  features: ingredient.features);
              processedList.add(newItem);
            }
            return processedList;
          }

          newGeneratedList = await processItems(generatedData);
          newManualList = await processItems(manualData);
        }

        generatedShoppingList.assignAll(newGeneratedList);
        manualShoppingList.assignAll(newManualList);
      } catch (e) {
        debugPrint('Error processing shopping list data: $e');
        generatedShoppingList.clear();
        manualShoppingList.clear();
      } finally {
        isShoppingListLoading.value = false;
      }
    }, onError: (e) {
      debugPrint('Error listening to shopping list: $e');
      isShoppingListLoading.value = false;
      // Show user-friendly error notification
      try {
        Get.snackbar(
          'Connection Error',
          'Unable to load shopping list. Please check your connection.',
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 3),
        );
      } catch (_) {
        // Ignore if Get.context is not available
      }
    });
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
    final random = Random(DateTime.now().millisecondsSinceEpoch);

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
        // Shuffle before taking to ensure randomization
        final shuffled = List<MacroData>.from(typeIngredients);
        shuffled.shuffle(random);
        // Take up to targetCount ingredients of this type
        final ingredientsToAdd = shuffled.take(targetCount).toList();
        result.addAll(ingredientsToAdd);
      }
    }

    // If we still don't have enough ingredients (some types might be empty),
    // fill with remaining ingredients from any type
    if (result.length < n) {
      final remainingIngredients =
          ingredient.where((item) => !result.contains(item)).toList();
      // Shuffle remaining ingredients before taking
      remainingIngredients.shuffle(random);
      result.addAll(remainingIngredients.take(n - result.length).toList());
    }

    // Final shuffle of the entire result to mix types
    result.shuffle(random);
    return result;
  }

  /// Force refresh ingredients data
  Future<void> forceRefreshIngredients() async {
    _demoIngredientData.clear();
    _isFetching = false;
    await fetchIngredients();
  }

  /// Generate and save a new 54321 shopping list from ingredients collection
  /// This is the main public method to be called from the UI
  Future<Map<String, dynamic>?> generateAndSave54321ShoppingList() async {
    try {
      // Generate the shopping list
      final shoppingListData = await generate54321ShoppingListFromIngredients();

      // Save to Firestore
      await save54321ShoppingListToFirestore(shoppingListData);

      return shoppingListData;
    } catch (e) {
      return null;
    }
  }

  /// Generate a 54321 shopping list from local ingredients collection
  /// 5 vegetables, 4 fruits, 3 proteins, 2 condiments/sauces, 1 grain, 1 treat
  /// Filters ingredients based on user's diet preferences
  Future<Map<String, dynamic>>
      generate54321ShoppingListFromIngredients() async {
    try {
      await _ensureDataFetched();

      if (ingredient.isEmpty) {
        return _getFallback54321Data();
      }

      // Get user's diet preference (single string)
      final dietPreference = userService
              .currentUser.value?.settings['dietPreference']
              ?.toString()
              .toLowerCase() ??
          'balanced';

      // Get excluded ingredients from Firebase
      final excludedIngredients = await _getExcludedIngredients();

      // Categorize ingredients by type and filter by diet preference and exclusions
      final vegetables = ingredient
          .where((item) =>
              item.type.toLowerCase() == 'vegetable' &&
              _isIngredientAllowedForDiet(item, dietPreference) &&
              _isIngredientNotExcluded(item, excludedIngredients))
          .toList();
      final fruits = ingredient
          .where((item) =>
              item.type.toLowerCase() == 'fruit' &&
              _isIngredientAllowedForDiet(item, dietPreference) &&
              _isIngredientNotExcluded(item, excludedIngredients))
          .toList();
      final proteins = ingredient
          .where((item) =>
              item.type.toLowerCase() == 'protein' &&
              _isIngredientAllowedForDiet(item, dietPreference) &&
              _isIngredientNotExcluded(item, excludedIngredients))
          .toList();
      final grains = ingredient
          .where((item) =>
              item.type.toLowerCase() == 'grain' &&
              _isIngredientAllowedForDiet(item, dietPreference) &&
              _isIngredientNotExcluded(item, excludedIngredients))
          .toList();
      final condiments = ingredient
          .where((item) =>
              (item.type.toLowerCase() == 'condiment' ||
                  item.type.toLowerCase() == 'sauce' ||
                  item.type.toLowerCase() == 'spread') &&
              _isIngredientAllowedForDiet(item, dietPreference) &&
              _isIngredientNotExcluded(item, excludedIngredients))
          .toList();
      final treats = ingredient
          .where((item) =>
              (item.type.toLowerCase() == 'treat' ||
                  item.type.toLowerCase() == 'snack' ||
                  item.type.toLowerCase() == 'dessert') &&
              _isIngredientAllowedForDiet(item, dietPreference) &&
              _isIngredientNotExcluded(item, excludedIngredients))
          .toList();

      // Shuffle and select items
      vegetables.shuffle(Random());
      fruits.shuffle(Random());
      proteins.shuffle(Random());
      grains.shuffle(Random());
      condiments.shuffle(Random());
      treats.shuffle(Random());

      // Build the shopping list with diet-appropriate adjustments
      final shoppingList = <String, List<Map<String, dynamic>>>{};
      final selectedIngredients =
          <String>[]; // Track selected ingredients for variation checks

      // Add vegetables (or skip if carnivore)
      if (vegetables.isNotEmpty && dietPreference != 'carnivore') {
        final selectedVegetables =
            _selectVariedIngredients(vegetables, 5, selectedIngredients);
        shoppingList['vegetables'] = selectedVegetables
            .map((item) => {
                  'name': item.title,
                  'amount': _getAmountForCategory('vegetable'),
                  'category': 'vegetable',
                  'notes': _getNoteForCategory('vegetable')
                })
            .toList();
        selectedIngredients
            .addAll(selectedVegetables.map((item) => item.title.toLowerCase()));
      }

      // Add fruits (or skip if carnivore, limit if keto)
      if (fruits.isNotEmpty && dietPreference != 'carnivore') {
        final fruitCount =
            (dietPreference == 'keto' || dietPreference == 'ketogenic') ? 2 : 4;
        final selectedFruits =
            _selectVariedIngredients(fruits, fruitCount, selectedIngredients);
        shoppingList['fruits'] = selectedFruits
            .map((item) => {
                  'name': item.title,
                  'amount': _getAmountForCategory('fruit'),
                  'category': 'fruit',
                  'notes': _getNoteForCategory('fruit')
                })
            .toList();
        selectedIngredients
            .addAll(selectedFruits.map((item) => item.title.toLowerCase()));
      }

      // Add proteins (essential for all diets)
      if (proteins.isNotEmpty) {
        final proteinCount = dietPreference == 'carnivore'
            ? 6
            : 3; // More proteins for carnivore
        final selectedProteins = _selectVariedIngredients(
            proteins, proteinCount, selectedIngredients);
        shoppingList['proteins'] = selectedProteins
            .map((item) => {
                  'name': item.title,
                  'amount': _getAmountForCategory('protein'),
                  'category': 'protein',
                  'notes': _getNoteForCategory('protein')
                })
            .toList();
        selectedIngredients
            .addAll(selectedProteins.map((item) => item.title.toLowerCase()));
      }

      // Add condiments/sauces (if available)
      if (dietPreference == 'carnivore') {
        // For carnivore diet, use static sauce options
        final carnivoreSauces = ['Ghee', 'Butter', 'Tallow', 'Lard'];
        carnivoreSauces.shuffle(Random());
        final selectedSauces = carnivoreSauces.take(2).toList();

        shoppingList['sauces'] = selectedSauces
            .map((sauce) => {
                  'name': sauce,
                  'amount': _getAmountForCategory('sauce'),
                  'category': 'sauce',
                  'notes': _getNoteForCategory('sauce')
                })
            .toList();
        selectedIngredients
            .addAll(selectedSauces.map((sauce) => sauce.toLowerCase()));
      } else if (condiments.isNotEmpty) {
        final selectedCondiments =
            _selectVariedIngredients(condiments, 2, selectedIngredients);
        shoppingList['sauces'] = selectedCondiments
            .map((item) => {
                  'name': item.title,
                  'amount': _getAmountForCategory('sauce'),
                  'category': 'sauce',
                  'notes': _getNoteForCategory('sauce')
                })
            .toList();
        selectedIngredients
            .addAll(selectedCondiments.map((item) => item.title.toLowerCase()));
      }

      // Add grains (skip for keto, carnivore, paleo)
      if (grains.isNotEmpty &&
          !['keto', 'ketogenic', 'carnivore', 'paleo']
              .contains(dietPreference)) {
        final selectedGrains =
            _selectVariedIngredients(grains, 1, selectedIngredients);
        shoppingList['grains'] = selectedGrains
            .map((item) => {
                  'name': item.title,
                  'amount': _getAmountForCategory('grain'),
                  'category': 'grain',
                  'notes': _getNoteForCategory('grain')
                })
            .toList();
        selectedIngredients
            .addAll(selectedGrains.map((item) => item.title.toLowerCase()));
      }

      // Add treats (if available and allowed)
      if (treats.isNotEmpty) {
        final selectedTreats =
            _selectVariedIngredients(treats, 1, selectedIngredients);
        shoppingList['treats'] = selectedTreats
            .map((item) => {
                  'name': item.title,
                  'amount': _getAmountForCategory('treat'),
                  'category': 'treat',
                  'notes': _getNoteForCategory('treat')
                })
            .toList();
        selectedIngredients
            .addAll(selectedTreats.map((item) => item.title.toLowerCase()));
      }

      // If we don't have enough items due to diet restrictions, add more proteins or vegetables
      final totalCurrentItems = shoppingList.values
          .map((list) => list.length)
          .fold(0, (a, b) => a + b);

      if (totalCurrentItems < 10) {
        // Add more proteins if available
        final remainingProteins =
            proteins.skip(shoppingList['proteins']?.length ?? 0).toList();
        if (remainingProteins.isNotEmpty &&
            (shoppingList['proteins']?.length ?? 0) < 6) {
          final additionalProteins = _selectVariedIngredients(
              remainingProteins, 2, selectedIngredients);
          final additionalProteinsData = additionalProteins
              .map((item) => {
                    'name': item.title.replaceAll('cooked', '').trim(),
                    'amount': _getAmountForCategory('protein'),
                    'category': 'protein',
                    'notes': _getNoteForCategory('protein')
                  })
              .toList();
          shoppingList['proteins'] = [
            ...(shoppingList['proteins'] ?? []),
            ...additionalProteinsData
          ];
          selectedIngredients.addAll(
              additionalProteins.map((item) => item.title.toLowerCase()));
        }

        // Add more vegetables if not carnivore
        if (dietPreference != 'carnivore') {
          final remainingVegetables =
              vegetables.skip(shoppingList['vegetables']?.length ?? 0).toList();
          if (remainingVegetables.isNotEmpty &&
              (shoppingList['vegetables']?.length ?? 0) < 7) {
            final additionalVegetables = _selectVariedIngredients(
                remainingVegetables, 2, selectedIngredients);
            final additionalVegetablesData = additionalVegetables
                .map((item) => {
                      'name': item.title.replaceAll('cooked', '').trim(),
                      'amount': _getAmountForCategory('vegetable'),
                      'category': 'vegetable',
                      'notes': _getNoteForCategory('vegetable')
                    })
                .toList();
            shoppingList['vegetables'] = [
              ...(shoppingList['vegetables'] ?? []),
              ...additionalVegetablesData
            ];
            selectedIngredients.addAll(
                additionalVegetables.map((item) => item.title.toLowerCase()));
          }
        }
      }

      // Calculate total items
      final totalItems = shoppingList.values
          .map((list) => (list as List).length)
          .reduce((a, b) => a + b);

      // Generate tips and meal ideas based on diet preference
      final tips = _generateShoppingTips(dietPreference);
      final mealIdeas = _generateMealIdeas(shoppingList, dietPreference);
      final estimatedCost = _estimateCost(totalItems);

      return {
        'shoppingList': shoppingList,
        'totalItems': totalItems,
        'estimatedCost': estimatedCost,
        'tips': tips,
        'mealIdeas': mealIdeas,
      };
    } catch (e) {
      return _getFallback54321Data();
    }
  }

  /// Get realistic amount for ingredients based on category
  String _getAmountForCategory(String category) {
    switch (category.toLowerCase()) {
      case 'vegetable':
        final vegetableAmounts = ['1 bunch', '500g', '1 bag'];
        return vegetableAmounts[Random().nextInt(vegetableAmounts.length)];

      case 'fruit':
        final fruitAmounts = ['500g', '3 pieces', '1 bag'];
        return fruitAmounts[Random().nextInt(fruitAmounts.length)];

      case 'protein':
        final proteinAmounts = ['500g', '1 pack', '800g'];
        return proteinAmounts[Random().nextInt(proteinAmounts.length)];

      case 'sauce':
        final sauceAmounts = [
          '250ml',
          '500ml',
        ];
        return sauceAmounts[Random().nextInt(sauceAmounts.length)];

      case 'grain':
        final grainAmounts = ['500g', '1 bag', '1 pack'];
        return grainAmounts[Random().nextInt(grainAmounts.length)];

      case 'treat':
        final treatAmounts = ['100g', '1 bar', '1 piece'];
        return treatAmounts[Random().nextInt(treatAmounts.length)];

      default:
        return '1 piece';
    }
  }

  /// Get relevant note for ingredients based on category
  String _getNoteForCategory(String category) {
    switch (category.toLowerCase()) {
      case 'vegetable':
        final vegetableNotes = [
          'Fresh and crisp',
          'Organic if possible',
          'Mixed colors',
          'Seasonal variety',
        ];
        return vegetableNotes[Random().nextInt(vegetableNotes.length)];

      case 'fruit':
        final fruitNotes = [
          'Ripe and sweet',
          'Juicy and fresh',
        ];
        return fruitNotes[Random().nextInt(fruitNotes.length)];

      case 'protein':
        final proteinNotes = ['Fresh if possible', 'Organic if possible'];
        return proteinNotes[Random().nextInt(proteinNotes.length)];

      case 'sauce':
        final sauceNotes = [
          'Check expiry date',
          'Shake before use',
          'Store in cool place',
          'Natural ingredients',
          'No artificial colors',
          'Low sodium option'
        ];
        return sauceNotes[Random().nextInt(sauceNotes.length)];

      case 'grain':
        final grainNotes = ['Whole grain preferred', 'Store in cool dry place'];
        return grainNotes[Random().nextInt(grainNotes.length)];

      case 'treat':
        final treatNotes = [
          'Check ingredients',
          'Moderate portion',
          'No artificial flavors',
          'Enjoy in moderation',
          'Premium quality'
        ];
        return treatNotes[Random().nextInt(treatNotes.length)];

      default:
        return 'Fresh and good quality';
    }
  }

  /// Generate shopping tips based on diet preference
  List<String> _generateShoppingTips(String dietPreference) {
    final tips = <String>[];

    // Base tips for everyone
    tips.addAll([
      'Buy seasonal produce for better prices and freshness',
      'Check for sales on proteins and bulk items',
      'Store ingredients properly to extend their shelf life',
    ]);

    // Diet-specific tips
    switch (dietPreference) {
      case 'keto':
      case 'ketogenic':
        tips.addAll([
          'Focus on high-fat, low-carb options',
          'Check nutrition labels for hidden carbs',
          'Buy avocados and nuts for healthy fats'
        ]);
        break;
      case 'carnivore':
        tips.addAll([
          'Choose grass-fed and organic meats when possible',
          'Buy organ meats for additional nutrients',
          'Consider buying in bulk for better prices'
        ]);
        break;
      case 'vegan':
        tips.addAll([
          'Check labels for hidden animal products',
          'Buy a variety of plant proteins',
          'Choose fortified plant milks for B12 and calcium'
        ]);
        break;
      case 'paleo':
        tips.addAll([
          'Focus on whole, unprocessed foods',
          'Buy organic when possible',
          'Avoid packaged foods with additives'
        ]);
        break;
      default:
        tips.add('Plan your meals around the ingredients you buy');
    }

    return tips.take(5).toList();
  }

  /// Generate meal ideas based on selected ingredients and diet preference
  List<String> _generateMealIdeas(
      Map<String, dynamic> shoppingList, String dietPreference) {
    final ideas = <String>[];

    // Get ingredient names for meal ideas
    final vegetables =
        (shoppingList['vegetables'] as List<Map<String, dynamic>>?)
                ?.map((v) => v['name'] as String)
                .toList() ??
            [];
    final fruits = (shoppingList['fruits'] as List<Map<String, dynamic>>?)
            ?.map((f) => f['name'] as String)
            .toList() ??
        [];
    final proteins = (shoppingList['proteins'] as List<Map<String, dynamic>>?)
            ?.map((p) => p['name'] as String)
            .toList() ??
        [];
    final grains = (shoppingList['grains'] as List<Map<String, dynamic>>?)
            ?.map((g) => g['name'] as String)
            .toList() ??
        [];

    // Generate diet-appropriate meal ideas
    if (dietPreference == 'carnivore') {
      if (proteins.isNotEmpty) {
        ideas.add(
            'Pan-seared ${capitalizeFirstLetter(proteins.first)} with butter');
        if (proteins.length > 1) {
          ideas.add(
              '${capitalizeFirstLetter(proteins[1])} steak with bone broth');
        }
        ideas.add('Grilled ${proteins.first} with sea salt');
      }
    } else if (dietPreference == 'vegan') {
      if (vegetables.isNotEmpty && proteins.isNotEmpty) {
        ideas.add(
            '${capitalizeFirstLetter(proteins.first)} stir-fry with ${capitalizeFirstLetter(vegetables.first)}');
      }
      if (fruits.isNotEmpty) {
        ideas.add(
            '${capitalizeFirstLetter(fruits.first)} smoothie bowl with plant protein');
      }
      if (vegetables.length >= 2) {
        ideas.add(
            'Roasted ${capitalizeFirstLetter(vegetables[0])} and ${capitalizeFirstLetter(vegetables[1])} Buddha bowl');
      }
    } else {
      // General meal ideas
      if (vegetables.isNotEmpty && proteins.isNotEmpty) {
        ideas.add(
            'Grilled ${capitalizeFirstLetter(proteins.first)} with roasted ${capitalizeFirstLetter(vegetables.first)}');
      }
      if (proteins.isNotEmpty && grains.isNotEmpty) {
        ideas.add(
            '${capitalizeFirstLetter(proteins.first)} with ${capitalizeFirstLetter(grains.first)}');
      }
      if (fruits.isNotEmpty) {
        ideas.add('Fresh ${capitalizeFirstLetter(fruits.first)} smoothie bowl');
      }
      if (vegetables.length >= 2) {
        ideas.add(
            'Mixed ${capitalizeFirstLetter(vegetables[0])} and ${capitalizeFirstLetter(vegetables[1])} salad');
      }
    }

    return ideas.take(3).toList();
  }

  /// Estimate cost based on number of items
  String _estimateCost(int totalItems) {
    if (totalItems <= 10) return '\$30-50';
    if (totalItems <= 15) return '\$50-70';
    return '\$70-100';
  }

  /// Fallback data when ingredients are not available
  Map<String, dynamic> _getFallback54321Data() {
    return {
      'shoppingList': {
        'vegetables': [
          {
            'name': 'Spinach',
            'amount': '1 bunch',
            'category': 'vegetable',
            'notes': 'Fresh and crisp'
          },
          {
            'name': 'Carrots',
            'amount': '500g',
            'category': 'vegetable',
            'notes': 'Organic if possible'
          },
          {
            'name': 'Bell Peppers',
            'amount': '3 pieces',
            'category': 'vegetable',
            'notes': 'Mixed colors'
          },
          {
            'name': 'Broccoli',
            'amount': '1 head',
            'category': 'vegetable',
            'notes': 'Fresh green'
          },
          {
            'name': 'Tomatoes',
            'amount': '4 pieces',
            'category': 'vegetable',
            'notes': 'Ripe and firm'
          }
        ],
        'fruits': [
          {
            'name': 'Bananas',
            'amount': '1 bunch',
            'category': 'fruit',
            'notes': 'Yellow with green tips'
          },
          {
            'name': 'Apples',
            'amount': '6 pieces',
            'category': 'fruit',
            'notes': 'Crisp and sweet'
          },
          {
            'name': 'Oranges',
            'amount': '4 pieces',
            'category': 'fruit',
            'notes': 'Juicy and fresh'
          },
          {
            'name': 'Berries',
            'amount': '250g',
            'category': 'fruit',
            'notes': 'Mixed berries'
          }
        ],
        'proteins': [
          {
            'name': 'Chicken Breast',
            'amount': '500g',
            'category': 'protein',
            'notes': 'Skinless and boneless'
          },
          {
            'name': 'Eggs',
            'amount': '12 pieces',
            'category': 'protein',
            'notes': 'Fresh farm eggs'
          },
          {
            'name': 'Salmon',
            'amount': '300g',
            'category': 'protein',
            'notes': 'Wild caught if available'
          }
        ],
        'sauces': [
          {
            'name': 'Olive Oil',
            'amount': '250ml',
            'category': 'sauce',
            'notes': 'Extra virgin'
          },
          {
            'name': 'Hummus',
            'amount': '200g',
            'category': 'sauce',
            'notes': 'Classic or flavored'
          }
        ],
        'grains': [
          {
            'name': 'Brown Rice',
            'amount': '500g',
            'category': 'grain',
            'notes': 'Organic whole grain'
          }
        ],
        'treats': [
          {
            'name': 'Dark Chocolate',
            'amount': '100g',
            'category': 'treat',
            'notes': '70% cocoa or higher'
          }
        ]
      },
      'totalItems': 16,
      'estimatedCost': '\$50-70',
      'tips': [
        'Buy seasonal produce for better prices',
        'Check for sales on proteins',
        'Store vegetables properly to extend freshness'
      ],
      'mealIdeas': [
        'Grilled chicken with roasted vegetables',
        'Salmon with rice and steamed broccoli',
        'Egg scramble with fresh vegetables'
      ]
    };
  }

  /// Get excluded ingredients from local constant
  Future<List<String>> _getExcludedIngredients() async {
    try {
      // Use local excludeIngredients constant from utils.dart
      return excludeIngredients.map((e) => e.trim().toLowerCase()).toList();
    } catch (e) {
      debugPrint('Error getting excluded ingredients: $e');
      return [];
    }
  }

  /// Check if an ingredient should be excluded based on type and excluded ingredients list
  bool _isIngredientNotExcluded(
      MacroData ingredient, List<String> excludedIngredients) {
    final ingredientType = ingredient.type.toLowerCase();
    final ingredientTitle = ingredient.title.toLowerCase();

    // Check if ingredient type is in excluded types
    final excludedTypes = [
      'sweetener',
      'pastry',
      'dairy',
      'oil',
      'herb',
      'spice',
      'liquid'
    ];
    if (excludedTypes.contains(ingredientType)) {
      return false;
    }

    // Check if ingredient title contains any excluded ingredient
    for (final excluded in excludedIngredients) {
      if (ingredientTitle.contains(excluded) ||
          excluded.contains(ingredientTitle)) {
        return false;
      }
    }

    return true;
  }

  /// Select varied ingredients avoiding duplicates and similar items
  List<MacroData> _selectVariedIngredients(List<MacroData> ingredients,
      int count, List<String> selectedIngredients) {
    final selected = <MacroData>[];
    final available = List<MacroData>.from(ingredients);

    while (selected.length < count && available.isNotEmpty) {
      // Find ingredients that don't conflict with already selected ones
      final nonConflicting = available.where((ingredient) {
        final ingredientTitle = ingredient.title.toLowerCase();

        // Check if this ingredient conflicts with any already selected
        for (final selectedTitle in selectedIngredients) {
          if (_ingredientsConflict(ingredientTitle, selectedTitle)) {
            return false;
          }
        }

        // Check if this ingredient conflicts with any in the current selection
        for (final selectedIngredient in selected) {
          if (_ingredientsConflict(
              ingredientTitle, selectedIngredient.title.toLowerCase())) {
            return false;
          }
        }

        return true;
      }).toList();

      if (nonConflicting.isEmpty) {
        // If no non-conflicting ingredients, just take the first available
        selected.add(available.removeAt(0));
      } else {
        // Select a random non-conflicting ingredient
        nonConflicting.shuffle(Random());
        final selectedIngredient = nonConflicting.first;
        selected.add(selectedIngredient);
        available.remove(selectedIngredient);
      }
    }

    return selected;
  }

  /// Check if two ingredients conflict (are too similar)
  bool _ingredientsConflict(String ingredient1, String ingredient2) {
    // Split ingredients into words for better comparison
    final words1 = ingredient1
        .split(RegExp(r'[\s\-_]+'))
        .where((w) => w.isNotEmpty)
        .toList();
    final words2 = ingredient2
        .split(RegExp(r'[\s\-_]+'))
        .where((w) => w.isNotEmpty)
        .toList();

    // Check if any word from one ingredient appears in the other
    for (final word1 in words1) {
      for (final word2 in words2) {
        if (word1 == word2 ||
            (word1.length > 2 &&
                word2.length > 2 &&
                (word1.contains(word2) || word2.contains(word1)))) {
          return true;
        }
      }
    }

    // Check for common variations (e.g., "pork" vs "pork belly", "lemon" vs "lemon zest")
    if (ingredient1.contains(ingredient2) ||
        ingredient2.contains(ingredient1)) {
      return true;
    }

    return false;
  }

  /// Check if an ingredient is allowed for the user's diet preference
  bool _isIngredientAllowedForDiet(
      MacroData ingredient, String dietPreference) {
    if (dietPreference.isEmpty || dietPreference == 'balanced') {
      return true; // No diet restrictions, allow all ingredients
    }

    final ingredientType = ingredient.type.toLowerCase();
    final ingredientTitle = ingredient.title.toLowerCase();
    final ingredientCategories =
        ingredient.categories.map((c) => c.toLowerCase()).toList();

    switch (dietPreference) {
      case 'keto':
      case 'ketogenic':
        // Keto: Only low-carb foods - vegetables, proteins, fats, limited fruits
        return ingredientCategories.contains('vegetable') ||
            ingredientCategories.contains('meat') ||
            ingredientCategories.contains('fish') ||
            ingredientCategories.contains('poultry') ||
            ingredientCategories.contains('seafood') ||
            ingredientCategories.contains('egg') ||
            ingredientCategories.contains('dairy') ||
            ingredientCategories.contains('oil') ||
            ingredientCategories.contains('nut') ||
            ingredientCategories.contains('seed') ||
            ingredientCategories.contains('keto') ||
            ingredientType == 'vegetable' ||
            ingredientType == 'dairy' ||
            ingredientType == 'oil' ||
            ingredientType == 'nut' ||
            ingredientType == 'seed' ||
            (ingredientCategories.contains('fruit') &&
                _isLowCarbFruit(ingredientTitle)) ||
            (ingredientType == 'fruit' && _isLowCarbFruit(ingredientTitle));

      case 'carnivore':
        // Carnivore: Only animal products
        return ingredientCategories.contains('meat') ||
            ingredientCategories.contains('fish') ||
            ingredientCategories.contains('poultry') ||
            ingredientCategories.contains('seafood') ||
            ingredientCategories.contains('egg') ||
            ingredientCategories.contains('dairy') ||
            ingredientCategories.contains('red meat') ||
            ingredientCategories.contains('game meat') ||
            ingredientCategories.contains('white meat') ||
            ingredientCategories.contains('carnivore') ||
            ingredientCategories.contains('dairy') ||
            _isMeat(ingredientTitle) ||
            _isFish(ingredientTitle) ||
            _isCarnivoreSauce(ingredientTitle);

      case 'vegan':
        // Vegan: Only plant-based foods
        return ingredientCategories.contains('vegetable') ||
            ingredientCategories.contains('fruit') ||
            ingredientCategories.contains('grain') ||
            ingredientCategories.contains('legume') ||
            ingredientCategories.contains('nut') ||
            ingredientCategories.contains('seed') ||
            ingredientCategories.contains('oil') ||
            ingredientCategories.contains('vegan') ||
            ingredientType == 'vegetable' ||
            ingredientType == 'fruit' ||
            ingredientType == 'grain' ||
            ingredientType == 'legume' ||
            ingredientType == 'nut' ||
            ingredientType == 'seed' ||
            ingredientType == 'oil';

      case 'vegetarian':
        // Vegetarian: Only plant-based foods + dairy and eggs
        return ingredientCategories.contains('vegetable') ||
            ingredientCategories.contains('fruit') ||
            ingredientCategories.contains('grain') ||
            ingredientCategories.contains('legume') ||
            ingredientCategories.contains('nut') ||
            ingredientCategories.contains('seed') ||
            ingredientCategories.contains('oil') ||
            ingredientCategories.contains('dairy') ||
            ingredientCategories.contains('egg') ||
            ingredientCategories.contains('vegetarian') ||
            ingredientType == 'vegetable' ||
            ingredientType == 'fruit' ||
            ingredientType == 'grain' ||
            ingredientType == 'legume' ||
            ingredientType == 'nut' ||
            ingredientType == 'seed' ||
            ingredientType == 'oil' ||
            ingredientType == 'dairy' ||
            ingredientType == 'egg';

      case 'paleo':
        // Paleo: Only whole foods - vegetables, fruits, proteins, nuts, seeds
        return ingredientCategories.contains('vegetable') ||
            ingredientCategories.contains('fruit') ||
            ingredientCategories.contains('meat') ||
            ingredientCategories.contains('fish') ||
            ingredientCategories.contains('poultry') ||
            ingredientCategories.contains('seafood') ||
            ingredientCategories.contains('egg') ||
            ingredientCategories.contains('nut') ||
            ingredientCategories.contains('seed') ||
            ingredientCategories.contains('oil') ||
            ingredientType == 'vegetable' ||
            ingredientType == 'fruit' ||
            ingredientType == 'protein' ||
            ingredientType == 'nut' ||
            ingredientType == 'seed' ||
            ingredientType == 'oil' ||
            ingredientType == 'egg';

      case 'pescatarian':
        // Pescatarian: Only fish, seafood, vegetables, fruits, grains, dairy, eggs
        return ingredientCategories.contains('fish') ||
            ingredientCategories.contains('seafood') ||
            ingredientCategories.contains('vegetable') ||
            ingredientCategories.contains('fruit') ||
            ingredientCategories.contains('grain') ||
            ingredientCategories.contains('dairy') ||
            ingredientCategories.contains('egg') ||
            ingredientCategories.contains('nut') ||
            ingredientCategories.contains('seed') ||
            ingredientCategories.contains('oil') ||
            ingredientCategories.contains('pescatarian') ||
            ingredientType == 'vegetable' ||
            ingredientType == 'fruit' ||
            ingredientType == 'grain' ||
            ingredientType == 'dairy' ||
            ingredientType == 'egg' ||
            ingredientType == 'nut' ||
            ingredientType == 'seed' ||
            ingredientType == 'oil' ||
            _isFish(ingredientTitle);

      case 'gluten-free':
        // Gluten-free: Everything except gluten-containing foods
        return !ingredientCategories.contains('gluten') &&
            !ingredientCategories.contains('wheat') &&
            !ingredientCategories.contains('barley') &&
            !ingredientCategories.contains('rye') &&
            !_containsGluten(ingredientTitle);

      case 'dairy-free':
        // Dairy-free: Everything except dairy products
        return !ingredientCategories.contains('dairy') &&
            !ingredientCategories.contains('milk') &&
            !ingredientCategories.contains('cheese') &&
            !_isDairy(ingredientTitle);

      case 'low-carb':
        // Low-carb: Limited grains and high-carb foods
        return !ingredientCategories.contains('grain') &&
            !ingredientCategories.contains('high-carb') &&
            !ingredientCategories.contains('sugar') &&
            ingredientType != 'grain' &&
            !_isHighCarb(ingredientTitle);
    }

    return true;
  }

  /// Helper methods for diet filtering
  bool _isLowCarbFruit(String title) {
    final lowCarbFruits = [
      'avocado',
      'berries',
      'strawberry',
      'raspberry',
      'blackberry',
      'lime',
      'lemon'
    ];
    return lowCarbFruits.any((fruit) => title.contains(fruit));
  }

  bool _isMeat(String title) {
    final meats = ['chicken', 'beef', 'pork', 'lamb', 'turkey', 'duck', 'meat'];
    return meats.any((meat) => title.contains(meat));
  }

  bool _isFish(String title) {
    final fish = [
      'fish',
      'salmon',
      'tuna',
      'cod',
      'mackerel',
      'sardine',
      'trout'
    ];
    return fish.any((f) => title.contains(f));
  }

  bool _isDairy(String title) {
    final dairy = ['milk', 'cheese', 'butter', 'yogurt', 'cream', 'dairy'];
    return dairy.any((d) => title.contains(d));
  }

  bool _containsGluten(String title) {
    final glutenSources = ['wheat', 'barley', 'rye', 'bread', 'pasta', 'flour'];
    return glutenSources.any((gluten) => title.contains(gluten));
  }

  bool _isHighCarb(String title) {
    final highCarbFoods = [
      'potato',
      'rice',
      'pasta',
      'bread',
      'banana',
      'grape',
      'mango'
    ];
    return highCarbFoods.any((carb) => title.contains(carb));
  }

  bool _isCarnivoreSauce(String title) {
    final carnivoreSauces = ['ghee', 'butter', 'tallow', 'lard'];
    return carnivoreSauces.any((sauce) => title.contains(sauce));
  }

  /// Save 54321 shopping list to Firestore
  /// Automatically deletes older lists to keep only the 2 most recent ones
  Future<void> save54321ShoppingListToFirestore(
      Map<String, dynamic> shoppingListData) async {
    try {
      final userId = auth.currentUser?.uid;
      if (userId == null) {
        return;
      }

      final now = DateTime.now();
      final dateId =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}-${now.minute.toString().padLeft(2, '0')}-${now.second.toString().padLeft(2, '0')}';

      // Check existing lists and delete old ones if more than 1 exist
      await _cleanupOld54321Lists(userId);

      final docRef = firestore
          .collection('userMeals')
          .doc(userId)
          .collection('shoppingList54321')
          .doc(dateId);

      await docRef.set({
        'shoppingList': shoppingListData['shoppingList'],
        'totalItems': shoppingListData['totalItems'],
        'estimatedCost': shoppingListData['estimatedCost'],
        'tips': shoppingListData['tips'],
        'mealIdeas': shoppingListData['mealIdeas'],
        'timestamp': FieldValue.serverTimestamp(),
        'generatedAt': now.toIso8601String(),
        'userId': userId,
        'generatedFrom':
            'ingredients_collection', // Mark as generated from ingredients
      });
    } catch (e) {
      return;
    }
  }

  /// Clean up old 54321 shopping lists, keeping only the 2 most recent ones
  Future<void> _cleanupOld54321Lists(String userId) async {
    try {
      final querySnapshot = await firestore
          .collection('userMeals')
          .doc(userId)
          .collection('shoppingList54321')
          .orderBy('timestamp', descending: true)
          .get();

      // If we have more than 1 existing list, delete the oldest ones
      if (querySnapshot.docs.length > 1) {
        final docsToDelete =
            querySnapshot.docs.skip(1).toList(); // Skip the most recent one

        // Delete the older lists
        final batch = firestore.batch();
        for (final doc in docsToDelete) {
          batch.delete(doc.reference);
        }
        await batch.commit();

        debugPrint(
            'Cleaned up ${docsToDelete.length} old 54321 shopping lists');
      }
    } catch (e) {
      debugPrint('Error cleaning up old 54321 lists: $e');
    }
  }

  /// Get the latest 54321 shopping list from Firestore
  Future<Map<String, dynamic>?> getLatest54321ShoppingList() async {
    try {
      final userId = auth.currentUser?.uid;
      if (userId == null) {
        debugPrint('No user ID found for getting 54321 shopping list');
        return null;
      }

      final querySnapshot = await firestore
          .collection('userMeals')
          .doc(userId)
          .collection('shoppingList54321')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final doc = querySnapshot.docs.first;
        final data = doc.data();
        debugPrint('Retrieved 54321 shopping list from Firestore: ${doc.id}');

        return {
          'id': doc.id,
          'shoppingList': data['shoppingList'],
          'totalItems': data['totalItems'] ?? 0,
          'estimatedCost': data['estimatedCost'] ?? 'Not available',
          'tips': data['tips'] ?? [],
          'mealIdeas': data['mealIdeas'] ?? [],
          'generatedAt': data['generatedAt'],
          'timestamp': data['timestamp'],
          'generatedFrom': data['generatedFrom'] ?? 'unknown',
        };
      }

      return null;
    } catch (e) {
      debugPrint('Error getting 54321 shopping list from Firestore: $e');
      return null;
    }
  }

  /// Check for new meals in meal plans that haven't been added to the shopping list
  /// Returns the count of meals in the meal plan for the current week
  Future<int> checkForNewMealPlanItems(String userId, String weekId) async {
    try {
      // 1. Get current week's start and end dates
      final now = DateTime.now();
      final weekStart = _getWeekStart(now);
      final weekEnd = weekStart.add(const Duration(days: 6));

      // Format dates as YYYY-MM-DD
      final formatDate = (DateTime date) {
        final y = date.year;
        final m = date.month.toString().padLeft(2, '0');
        final d = date.day.toString().padLeft(2, '0');
        return '$y-$m-$d';
      };

      final startDateStr = formatDate(weekStart);
      final endDateStr = formatDate(weekEnd);

      debugPrint(
          'Checking for meals in meal plan between: $startDateStr and $endDateStr');

      // 2. Query meal plans for the current week
      final mealsSnapshot = await firestore
          .collection('mealPlans')
          .doc(userId)
          .collection('date')
          .where(FieldPath.documentId, isGreaterThanOrEqualTo: startDateStr)
          .where(FieldPath.documentId, isLessThanOrEqualTo: endDateStr)
          .get();

      if (mealsSnapshot.docs.isEmpty) {
        debugPrint('No meal plans found for the current week');
        return 0;
      }

      // 3. Count unique meals from all date documents in the week
      // Count actual meal entries (not unique IDs) from mealPlans/{userId}/date/{date}
      int totalMealsCount = 0;
      final dateMealCounts = <String, int>{};

      for (final dayDoc in mealsSnapshot.docs) {
        final data = dayDoc.data();
        final mealPaths = data['meals'] as List<dynamic>? ?? [];
        final mealCount = mealPaths.length;
        dateMealCounts[dayDoc.id] = mealCount;
        totalMealsCount += mealCount;
      }

      if (totalMealsCount == 0) {
        debugPrint('No meals found in meal plans for the week');
        return 0;
      }

      // 4. Check if shopping list exists and has items
      final shoppingListRef = firestore
          .collection('userMeals')
          .doc(userId)
          .collection('shoppingList')
          .doc(weekId);

      final shoppingListDoc = await shoppingListRef.get();
      final hasShoppingList = shoppingListDoc.exists &&
          shoppingListDoc.data() != null &&
          (shoppingListDoc.data()!['generatedItems'] as Map<String, dynamic>? ??
                  {})
              .isNotEmpty;

      // 5. If shopping list is empty or doesn't exist, return meal count
      if (!hasShoppingList) {
        return totalMealsCount;
      }

      // 6. If shopping list exists, check if meal plans were updated after shopping list
      final shoppingListTimestamp =
          shoppingListDoc.data()?['updatedAt'] as Timestamp?;
      if (shoppingListTimestamp != null) {
        final shoppingListTime = shoppingListTimestamp.toDate();
        int newMealsCount = 0;

        // Get the meal IDs that were used to generate the shopping list (if stored)
        final processedMealIdsData =
            shoppingListDoc.data()?['processedMealIds'];
        final processedMealIds = processedMealIdsData != null
            ? (processedMealIdsData as List<dynamic>)
                .map((e) => e.toString())
                .toSet()
            : <String>{};

        // Check if we have processed meal IDs (new shopping lists) or not (old shopping lists)
        final hasProcessedMealIds = processedMealIds.isNotEmpty;

        // Check each meal plan document to see if it was updated after shopping list
        for (final dayDoc in mealsSnapshot.docs) {
          final mealPlanTimestamp = dayDoc.data()['timestamp'] as Timestamp?;
          if (mealPlanTimestamp != null) {
            final mealPlanTime = mealPlanTimestamp.toDate();
            final mealPaths = dayDoc.data()['meals'] as List<dynamic>? ?? [];

            if (mealPlanTime.isAfter(shoppingListTime)) {
              // This meal plan was updated after shopping list was generated

              if (hasProcessedMealIds) {
                // Count only meals that weren't already processed (accurate counting)
                // Extract meal ID from path (format: "mealId" or "mealId/userId")
                for (final mealPath in mealPaths) {
                  final mealId = mealPath.toString().split('/').first;
                  if (!processedMealIds.contains(mealId)) {
                    newMealsCount++;
                  }
                }
              } else {
                // Old shopping list without processedMealIds - count all meals in updated days
                // This is less accurate but still detects new meals
                newMealsCount += mealPaths.length;
              }
            }
          } else {
            debugPrint('Date ${dayDoc.id}: No timestamp found');
          }
        }

        if (newMealsCount > 0) {
          return newMealsCount;
        }
      } else {
        debugPrint('Shopping list has no updatedAt timestamp');
      }

      // 7. If we can't determine, return 0 (shopping list exists and seems up to date)
      return 0;
    } catch (e) {
      debugPrint('Error checking for new meal plan items: $e');
      return 0;
    }
  }

  /// Get the start of the week (Monday) for a given date
  DateTime _getWeekStart(DateTime date) {
    final daysFromMonday = date.weekday - 1; // Monday = 1, so subtract 1
    return DateTime(date.year, date.month, date.day)
        .subtract(Duration(days: daysFromMonday));
  }
}
