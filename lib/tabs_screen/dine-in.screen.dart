import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image/image.dart' as img;
import '../constants.dart';
import '../data_models/macro_data.dart';
import '../helper/helper_functions.dart';
import '../helper/helper_files.dart';
import '../helper/utils.dart';
import '../service/macro_manager.dart';
import '../service/gemini_service.dart' as gemini;
import '../widgets/primary_button.dart';
import '../widgets/info_icon_widget.dart';
import '../detail_screen/recipe_detail.dart';
import '../screens/buddy_screen.dart';

class DineInScreen extends StatefulWidget {
  const DineInScreen({super.key});

  @override
  State<DineInScreen> createState() => _DineInScreenState();
}

class _DineInScreenState extends State<DineInScreen> {
  final MacroManager _macroManager = Get.find<MacroManager>();
  final ImagePicker _imagePicker = ImagePicker();

  // Fridge feature variables
  List<String> fridgeIngredients = [];
  final TextEditingController _fridgeController = TextEditingController();
  final FocusNode _fridgeFocusNode = FocusNode();
  bool isAnalyzingFridge = false;
  File? _fridgeImage;
  List<Map<String, dynamic>> _fridgeRecipes = [];
  bool _showFridgeRecipes = false;
  StreamSubscription? _mealUpdateSubscription;
  List<StreamSubscription> _mealSubscriptions = [];

  // Pantry mode
  bool isPantryMode = false;

  // Pantry items
  List<Map<String, dynamic>> pantryItems = [];
  bool isLoadingPantry = false;

  // Autocomplete suggestions
  List<String> ingredientSuggestions = [];
  final LayerLink _suggestionsLayerLink = LayerLink();
  OverlayEntry? _suggestionsOverlay;

  // Recently used ingredients
  List<String> recentlyUsedIngredients = [];

  // Recipe filter/cuisine selection
  String? selectedCuisineFilter;

  // Common pantry items for quick add (dry goods, long-term storage)
  static const List<String> commonPantryItems = [
    'rice',
    'pasta',
    'flour',
    'sugar',
    'salt',
    'pepper',
    'olive oil',
    'beans',
    'lentils',
    'quinoa',
    'oats',
    'cereal',
    'canned tomatoes',
    'canned beans',
    'spices',
    'herbs',
    'nuts',
    'seeds',
    'honey',
    'vinegar',
    'baking powder',
    'baking soda',
    'coconut oil',
    'soy sauce',
    'broth',
  ];

  // Common fridge items for quick add (perishables, short-term storage)
  static const List<String> commonFridgeItems = [
    'milk',
    'cheese',
    'eggs',
    'butter',
    'yogurt',
    'chicken',
    'beef',
    'pork',
    'fish',
    'tomatoes',
    'lettuce',
    'spinach',
    'broccoli',
    'carrots',
    'onions',
    'garlic',
    'bell peppers',
    'mushrooms',
    'lemons',
    'limes',
    'apples',
    'bananas',
    'berries',
    'bread',
    'leftovers',
  ];

  // Legacy variables (for backward compatibility - can be removed if not needed)
  MacroData? selectedCarb;
  MacroData? selectedProtein;
  bool isLoading = false;
  bool isAccepted = false;
  Map<String, dynamic>? selectedMeal;
  final Random _random = Random();
  List<String> excludedIngredients = [];

  @override
  void initState() {
    super.initState();
    loadExcludedIngredients();
    // Load local data immediately (fast operations)
    _loadSavedMeal();
    _loadFridgeData();
    _loadFridgeRecipesFromSharedPreferences();
    _loadRecentlyUsedIngredients();

    // Defer Firestore query to after first frame to avoid blocking UI
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _fetchPantryItems();
      }
    });

    debugPrint('Excluded ingredients: ${excludedIngredients.length}');
  }

  /// Load recently used ingredients from SharedPreferences
  Future<void> _loadRecentlyUsedIngredients() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final recent = prefs.getStringList('recently_used_ingredients') ?? [];
      setState(() {
        recentlyUsedIngredients = recent.take(10).toList();
      });
    } catch (e) {
      debugPrint('Error loading recently used ingredients: $e');
    }
  }

  /// Save recently used ingredients to SharedPreferences
  Future<void> _saveRecentlyUsedIngredients(String ingredient) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final recent = List<String>.from(recentlyUsedIngredients);

      // Remove if already exists
      recent.remove(ingredient.toLowerCase());

      // Add to front
      recent.insert(0, ingredient.toLowerCase());

      // Keep only last 10
      final updated = recent.take(10).toList();

      await prefs.setStringList('recently_used_ingredients', updated);
      setState(() {
        recentlyUsedIngredients = updated;
      });
    } catch (e) {
      debugPrint('Error saving recently used ingredients: $e');
    }
  }

  /// Check if ingredient is in pantry
  bool _isIngredientInPantry(String ingredientName) {
    return pantryItems.any(
      (item) =>
          (item['name'] as String? ?? '').toLowerCase() ==
          ingredientName.toLowerCase(),
    );
  }

  @override
  void dispose() {
    _fridgeController.dispose();
    _fridgeFocusNode.dispose();
    _mealUpdateSubscription?.cancel();
    for (final subscription in _mealSubscriptions) {
      subscription.cancel();
    }
    _mealSubscriptions.clear();
    _removeSuggestionsOverlay();
    super.dispose();
  }

  void _removeSuggestionsOverlay() {
    _suggestionsOverlay?.remove();
    _suggestionsOverlay = null;
  }

  void loadExcludedIngredients() {
    excludedIngredients = excludeIngredients.toList();
  }

  // Set up Firestore listeners to update meals when they're processed off-device
  void _setupMealUpdateListeners() {
    // Cancel existing subscriptions
    _mealUpdateSubscription?.cancel();
    for (final subscription in _mealSubscriptions) {
      subscription.cancel();
    }
    _mealSubscriptions.clear();

    // Get all meal IDs from current fridge recipes
    final mealIds = _fridgeRecipes
        .where((recipe) => recipe['mealId'] != null)
        .map((recipe) => recipe['mealId'] as String)
        .toList();

    if (mealIds.isEmpty) {
      debugPrint('No meal IDs to listen to');
      return;
    }

    debugPrint(
        'Setting up real-time Firestore listeners for ${mealIds.length} meals');

    final firestore = FirebaseFirestore.instance;

    // Firestore whereIn supports max 10 items, so we need to batch if needed
    const int maxWhereInItems = 10;

    if (mealIds.length <= maxWhereInItems) {
      // Single listener for <= 10 meals
      _setupSingleMealListener(firestore, mealIds);
    } else {
      // Multiple listeners for > 10 meals (individual document listeners)
      _setupBatchedMealListeners(firestore, mealIds);
    }
  }

  void _setupSingleMealListener(
      FirebaseFirestore firestore, List<String> mealIds) {
    _mealUpdateSubscription = firestore
        .collection('meals')
        .where(FieldPath.documentId, whereIn: mealIds)
        .snapshots()
        .listen((snapshot) {
      _processMealUpdates(snapshot.docs);
    }, onError: (e) {
      debugPrint('Error in meal listener: $e');
    });
  }

  void _setupBatchedMealListeners(
      FirebaseFirestore firestore, List<String> mealIds) {
    // For > 10 meals, use individual document listeners
    // This is more efficient than polling and provides real-time updates
    for (final mealId in mealIds) {
      final subscription = firestore
          .collection('meals')
          .doc(mealId)
          .snapshots()
          .listen((docSnapshot) {
        if (docSnapshot.exists) {
          _processMealUpdates([docSnapshot]);
        }
      }, onError: (e) {
        debugPrint('Error listening to meal $mealId: $e');
      });
      _mealSubscriptions.add(subscription);
    }
  }

  void _processMealUpdates(List<DocumentSnapshot> docs) {
    if (docs.isEmpty || !mounted) return;

    bool hasUpdates = false;
    final updatedRecipes = List<Map<String, dynamic>>.from(_fridgeRecipes);

    for (final doc in docs) {
      final mealId = doc.id;
      final mealData = doc.data() as Map<String, dynamic>?;

      if (mealData == null) continue;

      // Find the recipe with this mealId and update it
      final recipeIndex = updatedRecipes.indexWhere(
        (recipe) => recipe['mealId'] == mealId,
      );

      if (recipeIndex != -1) {
        final existingRecipe = updatedRecipes[recipeIndex];
        final status = mealData['status']?.toString() ?? 'pending';

        // Only update if status changed from pending to completed
        if (status == 'completed' && existingRecipe['status'] != 'completed') {
          updatedRecipes[recipeIndex] = {
            ...existingRecipe,
            'title': mealData['title']?.toString() ?? existingRecipe['title'],
            'description': mealData['description']?.toString() ??
                existingRecipe['description'],
            'cookingTime': mealData['cookingTime']?.toString() ??
                existingRecipe['cookingTime'],
            'difficulty': mealData['difficulty']?.toString() ??
                existingRecipe['difficulty'],
            'calories': mealData['calories'] ?? existingRecipe['calories'],
            'ingredients':
                mealData['ingredients'] ?? existingRecipe['ingredients'],
            'instructions':
                mealData['instructions'] ?? existingRecipe['instructions'],
            'status': status,
          };
          hasUpdates = true;
          debugPrint('Updated meal $mealId: ${mealData['title']}');
        }
      }
    }

    if (hasUpdates && mounted) {
      setState(() {
        _fridgeRecipes = updatedRecipes;
      });
      // Save updated recipes
      _saveFridgeRecipesToSharedPreferences();
    }
  }

  // Local storage keys
  static const String _selectedMealKey = 'dine_in_selected_meal';
  static const String _selectedCarbKey = 'dine_in_selected_carb';
  static const String _selectedProteinKey = 'dine_in_selected_protein';
  static const String _mealTimestampKey = 'dine_in_meal_timestamp';

  // Save meal to local storage
  Future<void> _saveMealToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      if (selectedMeal != null) {
        await prefs.setString(_selectedMealKey, jsonEncode(selectedMeal));
        // Save timestamp when meal is saved
        await prefs.setInt(
            _mealTimestampKey, DateTime.now().millisecondsSinceEpoch);
      }

      if (selectedCarb != null) {
        await prefs.setString(
            _selectedCarbKey, jsonEncode(selectedCarb!.toJson()));
      }

      if (selectedProtein != null) {
        await prefs.setString(
            _selectedProteinKey, jsonEncode(selectedProtein!.toJson()));
      }
    } catch (e) {
      showTastySnackbar(
          'Something went wrong', 'Please try again later', Get.context!,
          backgroundColor: kRed);
    }
  }

  // Load meal from local storage
  Future<void> _loadSavedMeal() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Check if meal is expired (older than 7 days)
      final timestamp = prefs.getInt(_mealTimestampKey);
      final now = DateTime.now().millisecondsSinceEpoch;
      final sevenDaysInMs = 7 * 24 * 60 * 60 * 1000; // 7 days in milliseconds

      bool isMealExpired = false;
      if (timestamp != null) {
        isMealExpired = (now - timestamp) > sevenDaysInMs;
      }

      // Load selected meal only if not expired
      final savedMeal = prefs.getString(_selectedMealKey);
      if (savedMeal != null && !isMealExpired) {
        selectedMeal = jsonDecode(savedMeal);
      } else if (isMealExpired) {
        // Clear expired meal data
        await prefs.remove(_selectedMealKey);
        await prefs.remove(_mealTimestampKey);
      }

      // Load selected ingredients
      final savedCarb = prefs.getString(_selectedCarbKey);
      if (savedCarb != null) {
        final carbData = jsonDecode(savedCarb);
        selectedCarb = MacroData.fromJson(carbData, carbData['id'] ?? '');
      }

      final savedProtein = prefs.getString(_selectedProteinKey);
      if (savedProtein != null) {
        final proteinData = jsonDecode(savedProtein);
        selectedProtein =
            MacroData.fromJson(proteinData, proteinData['id'] ?? '');
      }

      if (mounted) {
        setState(() {
          // If we loaded ingredients and meal, set accepted state
          if (selectedCarb != null &&
              selectedProtein != null &&
              selectedMeal != null) {
            isAccepted = true;
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading meal from storage: $e');
    }
  }

  // Fridge feature methods
  Future<void> _loadFridgeData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedIngredients = prefs.getStringList('fridge_ingredients') ?? [];
      final savedImagePath = prefs.getString('fridge_image_path');

      setState(() {
        fridgeIngredients = savedIngredients;
        if (savedImagePath != null && File(savedImagePath).existsSync()) {
          _fridgeImage = File(savedImagePath);
        }
      });
    } catch (e) {
      debugPrint('Error loading fridge data: $e');
    }
  }

  Future<void> _saveFridgeData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('fridge_ingredients', fridgeIngredients);
      if (_fridgeImage != null) {
        await prefs.setString('fridge_image_path', _fridgeImage!.path);
      }
    } catch (e) {
      debugPrint('Error saving fridge data: $e');
    }
  }

  Future<void> _pickFridgeImage() async {
    try {
      // Show media selection dialog to choose camera or gallery
      final selectedOption = await showMediaSelectionDialog(
        isCamera: true,
        context: context,
        isVideo: false,
      );

      if (selectedOption == null) {
        return; // User cancelled the dialog
      }

      // Check camera permission if user selected camera option
      if (selectedOption == 'photo') {
        final isDarkMode = getThemeProvider(context).isDarkMode;
        final hasPermission =
            await checkAndRequestCameraPermission(context, isDarkMode);
        if (!hasPermission) {
          return; // Permission denied or user cancelled
        }
      }

      ImageSource source;
      if (selectedOption == 'photo') {
        source = ImageSource.camera;
      } else if (selectedOption == 'gallery') {
        source = ImageSource.gallery;
      } else {
        return; // Invalid selection
      }

      // Show loading indicator for camera operations
      if (source == ImageSource.camera) {
        showTastySnackbar(
          'Opening Camera',
          'Please wait while the camera opens...',
          context,
          backgroundColor: kAccent,
        );
      }

      debugPrint('Starting image picker with source: $source');

      // Add timeout to prevent hanging (increased to 60 seconds for slower devices)
      final XFile? image = await _imagePicker
          .pickImage(
        source: source,
        imageQuality: 90, // Higher quality to preserve color accuracy
        maxWidth: 1024,
        maxHeight: 1024,
        preferredCameraDevice:
            CameraDevice.rear, // Use rear camera for better quality
      )
          .timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          debugPrint('Image picker timed out after 60 seconds');
          throw TimeoutException(
              'Camera operation timed out. Please try again or use gallery instead.',
              const Duration(seconds: 60));
        },
      );
      debugPrint('Image picker completed, result: ${image?.path}');

      if (image != null) {
        // Clear previous ingredients and recipes when analyzing a new image
        setState(() {
          fridgeIngredients.clear();
          _fridgeRecipes.clear();
          _showFridgeRecipes = false;
        });

        // Process the image to fix any color issues (like green tint)
        final processedImage = await _processImage(File(image.path));
        setState(() {
          _fridgeImage = processedImage;
        });
        await _analyzeFridgeImage();
      } else {
        debugPrint('No image selected');
      }
    } catch (e) {
      debugPrint('Error in _pickFridgeImage: $e');

      String errorMessage =
          'Chef, couldn\'t access the camera. Please try again.';
      if (e is TimeoutException) {
        errorMessage = 'Camera operation timed out, Chef. Please try again.';
      } else if (e.toString().contains('permission')) {
        errorMessage =
            'Camera permission denied, Chef. Please enable camera access in settings.';
      } else if (e.toString().contains('camera')) {
        errorMessage =
            'Camera not available, Chef. Please try using gallery instead.';
      }

      showTastySnackbar(
        'Couldn\'t access camera, Chef',
        errorMessage,
        context,
        backgroundColor: kRed,
      );
    }
  }

  /// Process image to fix color issues like green tint from camera
  Future<File> _processImage(File imageFile) async {
    try {
      debugPrint('Processing image to fix color issues...');

      // Read the image file
      final Uint8List imageBytes = await imageFile.readAsBytes();

      // Decode the image
      img.Image? image = img.decodeImage(imageBytes);
      if (image == null) {
        debugPrint('Failed to decode image, returning original');
        return imageFile;
      }

      // Apply color corrections to fix green tint
      // First, try to correct color balance specifically for green tint
      image = img.adjustColor(
        image,
        // red: 1.1, // Increase red channel slightly
        // green: 0.95, // Reduce green channel to counter green tint
        // blue: 1.05, // Increase blue channel slightly
        saturation: 1.1, // Slightly increase saturation
        contrast: 1.05, // Slightly increase contrast
        brightness: 1.02, // Slightly increase brightness
      );

      // Apply gamma correction to improve color balance
      image = img.gamma(image, gamma: 1.1);

      // Additional color correction for severe green tint
      // image = img.colorMatrix(image, [
      //   1.1, -0.1, -0.1, 0, 0, // Red channel: increase red, reduce green/blue
      //   -0.1, 0.9, -0.1, 0, 0, // Green channel: reduce green, reduce red/blue
      //   -0.1, -0.1, 1.1, 0, 0, // Blue channel: increase blue, reduce red/green
      //   0, 0, 0, 1, 0, // Alpha channel: no change
      // ]);

      // Convert back to bytes
      final processedBytes = img.encodeJpg(image, quality: 85);

      // Create a new file with processed image
      final tempDir = Directory.systemTemp;
      final processedFile = File(
          '${tempDir.path}/processed_fridge_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await processedFile.writeAsBytes(processedBytes);

      debugPrint('Image processed successfully: ${processedFile.path}');
      return processedFile;
    } catch (e) {
      debugPrint('Error processing image: $e');
      // Return original file if processing fails
      return imageFile;
    }
  }

  Future<void> _analyzeFridgeImage() async {
    if (_fridgeImage == null) return;

    setState(() {
      isAnalyzingFridge = true;
    });

    try {
      // Check if user can use AI features
      if (!canUseAI()) {
        showPremiumRequiredDialog(
            context, getThemeProvider(context).isDarkMode);
        setState(() {
          isAnalyzingFridge = false;
        });
        return;
      }

      // Analyze the fridge image with specialized AI method
      final analysisResult = await gemini.geminiService.analyzeFridgeImage(
        imageFile: _fridgeImage!,
      );

      debugPrint('=== Fridge Analysis Result ===');
      debugPrint('Analysis result: $analysisResult');

      // Check if there's an error in the result
      if (analysisResult.containsKey('error') &&
          analysisResult['error'] == true) {
        debugPrint('Analysis failed with error: ${analysisResult['message']}');
        showTastySnackbar(
          'Couldn\'t analyze the pantry, Chef',
          'Failed to analyze image, Chef: ${analysisResult['message']}',
          context,
          backgroundColor: kRed,
        );
        setState(() {
          isAnalyzingFridge = false;
        });
        return;
      }

      if (analysisResult['ingredients'] != null) {
        // Safely convert ingredients to List
        dynamic ingredientsRaw = analysisResult['ingredients'];
        List<dynamic> ingredients;

        if (ingredientsRaw is List) {
          ingredients = ingredientsRaw;
        } else if (ingredientsRaw is Map) {
          // If it's a Map, convert to List (shouldn't happen but handle it)
          debugPrint('WARNING: ingredients is a Map, converting to List');
          ingredients = [ingredientsRaw];
        } else {
          debugPrint(
              'ERROR: ingredients is unexpected type: ${ingredientsRaw.runtimeType}');
          ingredients = [];
        }

        debugPrint('Raw ingredients: $ingredients');

        final ingredientNames = ingredients
            .map((item) {
              // Safe extraction of name with null checking
              if (item is Map<String, dynamic>) {
                return item['name'] as String? ?? '';
              } else if (item is Map) {
                return (item['name'] as String?) ?? '';
              }
              return '';
            })
            .where((name) => name.isNotEmpty)
            .toList();

        debugPrint('Extracted ingredient names: $ingredientNames');

        if (isPantryMode) {
          // In pantry mode: only save to pantry (long-term storage)
          await _saveIngredientsToPantry(ingredientNames);
          // Refresh pantry items to show the newly added items
          await _fetchPantryItems();
        } else {
          // In fridge mode: save to fridge (short-term) and optionally prompt for pantry
          setState(() {
            fridgeIngredients = ingredientNames;
          });
          debugPrint('Updated fridgeIngredients: $fridgeIngredients');
          await _saveFridgeData();
          // Prompt user to optionally save to pantry
          await _promptSaveToPantry(ingredientNames);
        }

        // If we have suggested meals from the analysis, use them directly
        // Only show recipes in fridge mode, not pantry mode
        if (analysisResult['suggestedMeals'] != null && !isPantryMode) {
          // Safely convert suggestedMeals to List
          dynamic suggestedMealsRaw = analysisResult['suggestedMeals'];
          List<dynamic> suggestedMeals;

          if (suggestedMealsRaw is List) {
            suggestedMeals = suggestedMealsRaw;
          } else if (suggestedMealsRaw is Map) {
            // If it's a Map, convert to List (shouldn't happen but handle it)
            debugPrint('WARNING: suggestedMeals is a Map, converting to List');
            suggestedMeals = [suggestedMealsRaw];
          } else {
            debugPrint(
                'ERROR: suggestedMeals is unexpected type: ${suggestedMealsRaw.runtimeType}');
            suggestedMeals = [];
          }

          debugPrint('Suggested meals: $suggestedMeals');

          setState(() {
            // Convert each meal properly to preserve all fields
            _fridgeRecipes = suggestedMeals.map((meal) {
              // Handle different map types (Map, Map<String, dynamic>, etc.)
              Map<String, dynamic> mealMap;
              if (meal is Map<String, dynamic>) {
                mealMap = meal;
              } else if (meal is Map) {
                // Convert generic Map to Map<String, dynamic>
                mealMap = Map<String, dynamic>.from(meal);
              } else {
                debugPrint(
                    'Meal is not a Map, type: ${meal.runtimeType}, value: $meal');
                return {
                  'title': 'Untitled Recipe',
                  'description': 'No description',
                  'cookingTime': 'Unknown',
                  'difficulty': 'medium',
                  'calories': 0,
                  'ingredients': {},
                };
              }

              // Extract title with proper null/empty handling
              final title = mealMap['title'];
              final titleString = (title?.toString() ?? '').trim();

              final processedMeal = {
                'title':
                    titleString.isNotEmpty ? titleString : 'Untitled Recipe',
                'description':
                    mealMap['description']?.toString() ?? 'No description',
                'cookingTime': mealMap['cookingTime']?.toString() ?? 'Unknown',
                'difficulty': mealMap['difficulty']?.toString() ?? 'medium',
                'calories': mealMap['calories'] is num
                    ? mealMap['calories'] as num
                    : (mealMap['calories'] is String
                        ? int.tryParse(mealMap['calories'] as String) ?? 0
                        : 0),
                'ingredients': mealMap['ingredients'] is Map
                    ? Map<String, dynamic>.from(mealMap['ingredients'] as Map)
                    : <String, dynamic>{},
                'mealId':
                    mealMap['mealId']?.toString(), // Store mealId if present
              };

              debugPrint('Processed meal title: ${processedMeal['title']}');
              return processedMeal;
            }).toList();
            _showFridgeRecipes = true;
          });

          debugPrint('Updated _fridgeRecipes: $_fridgeRecipes');
          debugPrint('_showFridgeRecipes: $_showFridgeRecipes');

          // If meals came from cloud function, extract mealIds and skip saving
          final isCloudFunction = analysisResult['source'] == 'cloud_function';
          debugPrint(
              'Is cloud function: $isCloudFunction, mealIds present: ${analysisResult['mealIds'] != null}');

          if (isCloudFunction && analysisResult['mealIds'] != null) {
            // Safely extract mealIdsMap
            dynamic mealIdsRaw = analysisResult['mealIds'];
            Map<String, dynamic> mealIdsMap;

            if (mealIdsRaw is Map<String, dynamic>) {
              mealIdsMap = mealIdsRaw;
            } else if (mealIdsRaw is Map) {
              mealIdsMap = Map<String, dynamic>.from(mealIdsRaw);
            } else {
              debugPrint(
                  'ERROR: mealIds is not a Map, type: ${mealIdsRaw.runtimeType}');
              mealIdsMap = {};
            }

            debugPrint('Meal IDs from cloud function: $mealIdsMap');
            debugPrint('Meal IDs keys: ${mealIdsMap.keys.toList()}');

            // Update recipes with mealIds from cloud function
            setState(() {
              _fridgeRecipes = _fridgeRecipes.map((recipe) {
                final title = recipe['title'] as String? ?? '';
                debugPrint('Checking recipe title: "$title"');

                // Try exact match first
                if (mealIdsMap.containsKey(title)) {
                  recipe['mealId'] = mealIdsMap[title];
                  debugPrint(
                      'Assigned mealId ${mealIdsMap[title]} to recipe: $title (exact match)');
                } else {
                  // Try case-insensitive and trimmed match
                  final normalizedTitle = title.trim().toLowerCase();
                  String? matchedKey;
                  for (final key in mealIdsMap.keys) {
                    if (key.trim().toLowerCase() == normalizedTitle) {
                      matchedKey = key;
                      break;
                    }
                  }

                  if (matchedKey != null) {
                    recipe['mealId'] = mealIdsMap[matchedKey];
                    debugPrint(
                        'Assigned mealId ${mealIdsMap[matchedKey]} to recipe: $title (normalized match with "$matchedKey")');
                  } else {
                    debugPrint(
                        'WARNING: Could not find mealId for recipe: "$title"');
                    debugPrint(
                        'Available keys in mealIdsMap: ${mealIdsMap.keys.toList()}');
                  }
                }
                return recipe;
              }).toList();
            });

            // Save recipes to SharedPreferences with mealIds
            await _saveFridgeRecipesToSharedPreferences();

            // Set up listeners for meal updates (meals already saved by cloud function)
            _setupMealUpdateListeners();

            // Show success message
            showTastySnackbar(
              'Analysis Complete!',
              'Found ${ingredientNames.length} ingredients and ${suggestedMeals.length} recipe suggestions. Meals are being processed.',
              context,
              backgroundColor: kAccent,
            );
          } else {
            // Client-side fallback: save recipes manually
            // Save recipes to SharedPreferences for persistence
            await _saveFridgeRecipesToSharedPreferences();

            if (_fridgeRecipes.isNotEmpty) {
              for (var recipe in _fridgeRecipes) {
                _saveRecipeToDatabase(recipe);
              }
            }

            // Show success message
            showTastySnackbar(
              'Analysis Complete!',
              'Found ${ingredientNames.length} ingredients and ${suggestedMeals.length} recipe suggestions',
              context,
              backgroundColor: kAccent,
            );
          }
        } else {
          // Only generate recipes in fridge mode, not pantry mode
          if (!isPantryMode) {
            debugPrint('No suggested meals found, generating recipes...');
            // Fallback to generating recipes from ingredients
            await _generateFridgeRecipes();

            // Show success message for ingredients only
            showTastySnackbar(
              'Analysis Complete!',
              'Found ${ingredientNames.length} ingredients',
              context,
              backgroundColor: kAccent,
            );
          } else {
            // In pantry mode, just show success message for ingredients
            showTastySnackbar(
              'Analysis Complete!',
              'Found ${ingredientNames.length} ingredients',
              context,
              backgroundColor: kAccent,
            );
          }
        }
      } else {
        debugPrint('No ingredients found in analysis result');
        showTastySnackbar(
          'Analysis Complete',
          'No ingredients detected in the image',
          context,
          backgroundColor: Colors.orange,
        );
      }
    } catch (e) {
      showTastySnackbar(
        'Couldn\'t analyze the pantry image, Chef',
        'Failed to analyze fridge image, Chef: $e',
        context,
        backgroundColor: kRed,
      );
    }

    setState(() {
      isAnalyzingFridge = false;
    });
  }

  Future<void> _addManualIngredient() async {
    final text = _fridgeController.text.trim();
    if (text.isEmpty) return;

    final ingredients = text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    _fridgeController.clear();

    // Save to recently used
    for (var ingredient in ingredients) {
      await _saveRecentlyUsedIngredients(ingredient);
    }

    if (isPantryMode) {
      // In pantry mode: only save to pantry (long-term storage)
      await _saveIngredientsToPantry(ingredients);
      // Refresh pantry items to show the newly added items
      await _fetchPantryItems();
    } else {
      // In fridge mode: save to fridge (short-term) and optionally prompt for pantry
      setState(() {
        fridgeIngredients.addAll(ingredients);
      });
      await _saveFridgeData();
      // Prompt user to optionally save to pantry
      await _promptSaveToPantry(ingredients);
    }
    // await _generateFridgeRecipes();
  }

  /// Prompt user to save ingredients to pantry
  Future<void> _promptSaveToPantry(List<String> newIngredients) async {
    if (newIngredients.isEmpty) return;

    final isDarkMode = getThemeProvider(context).isDarkMode;
    final Set<String> selectedIngredients = Set.from(newIngredients);

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          backgroundColor: isDarkMode ? kDarkGrey : kWhite,
          title: Text(
            'Save to Pantry?',
            style: TextStyle(
              color: isDarkMode ? kWhite : kBlack,
            ),
          ),
          content: Container(
            width: MediaQuery.of(context).size.width * 0.8,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.4,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Save these ingredients to your pantry?',
                  style: TextStyle(
                    color: isDarkMode ? kLightGrey : kDarkGrey,
                    fontSize: getTextScale(3, context),
                  ),
                ),
                SizedBox(height: getPercentageHeight(1, context)),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: newIngredients.length,
                    itemBuilder: (context, index) {
                      final ingredient = newIngredients[index];
                      final isSelected =
                          selectedIngredients.contains(ingredient);

                      return CheckboxListTile(
                        title: Text(
                          capitalizeFirstLetter(ingredient),
                          style: TextStyle(
                            color: isDarkMode ? kWhite : kBlack,
                            fontSize: getTextScale(3, context),
                          ),
                        ),
                        value: isSelected,
                        onChanged: (value) {
                          setDialogState(() {
                            if (value == true) {
                              selectedIngredients.add(ingredient);
                            } else {
                              selectedIngredients.remove(ingredient);
                            }
                          });
                        },
                        activeColor: kAccent,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, 'skip'),
              child: Text(
                'Skip',
                style: TextStyle(
                  color: isDarkMode ? kWhite : kAccent,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, 'select'),
              child: Text(
                'Select Items',
                style: TextStyle(
                  color: kAccent,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, 'save_all'),
              style: ElevatedButton.styleFrom(
                backgroundColor: kAccent,
              ),
              child: Text(
                'Save All',
                style: TextStyle(color: kWhite),
              ),
            ),
          ],
        ),
      ),
    );

    if (result == 'save_all') {
      // Save all ingredients
      await _saveIngredientsToPantry(newIngredients);
    } else if (result == 'select') {
      // Show selection dialog
      await _showSelectItemsToSaveDialog(newIngredients);
    }
    // If 'skip', do nothing
  }

  /// Show dialog to select specific items to save to pantry
  Future<void> _showSelectItemsToSaveDialog(List<String> ingredients) async {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    final Set<String> selectedIngredients = Set.from(ingredients);

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          backgroundColor: isDarkMode ? kDarkGrey : kWhite,
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Select Items to Save',
                style: TextStyle(
                  color: isDarkMode ? kWhite : kBlack,
                ),
              ),
              if (ingredients.length > 1)
                TextButton(
                  onPressed: () {
                    setDialogState(() {
                      if (selectedIngredients.length == ingredients.length) {
                        selectedIngredients.clear();
                      } else {
                        selectedIngredients.addAll(ingredients);
                      }
                    });
                  },
                  child: Text(
                    selectedIngredients.length == ingredients.length
                        ? 'Deselect All'
                        : 'Select All',
                    style: TextStyle(
                      color: kAccent,
                      fontSize: getTextScale(3, context),
                    ),
                  ),
                ),
            ],
          ),
          content: Container(
            width: MediaQuery.of(context).size.width * 0.8,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.5,
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: ingredients.length,
              itemBuilder: (context, index) {
                final ingredient = ingredients[index];
                final isSelected = selectedIngredients.contains(ingredient);

                return CheckboxListTile(
                  title: Text(
                    capitalizeFirstLetter(ingredient),
                    style: TextStyle(
                      color: isDarkMode ? kWhite : kBlack,
                      fontSize: getTextScale(3.5, context),
                    ),
                  ),
                  value: isSelected,
                  onChanged: (value) {
                    setDialogState(() {
                      if (value == true) {
                        selectedIngredients.add(ingredient);
                      } else {
                        selectedIngredients.remove(ingredient);
                      }
                    });
                  },
                  activeColor: kAccent,
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: isDarkMode ? kWhite : kAccent,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: selectedIngredients.isEmpty
                  ? null
                  : () async {
                      Navigator.pop(dialogContext);
                      try {
                        await _saveIngredientsToPantry(selectedIngredients.toList());
                        // Refresh pantry items to show the newly added items
                        await _fetchPantryItems();
                      } catch (e) {
                        debugPrint('Error saving ingredients to pantry: $e');
                        if (mounted && context.mounted) {
                          showTastySnackbar(
                            'Error',
                            'Failed to save ingredients to pantry. Please try again.',
                            context,
                            backgroundColor: Colors.red,
                          );
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: kAccent,
              ),
              child: Text(
                'Save Selected (${selectedIngredients.length})',
                style: TextStyle(color: kWhite),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Show filter dialog for cuisine/style selection
  Future<String?> _showRecipeFilterDialog() async {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    final cuisineTypes = helperController.headers.isNotEmpty
        ? List<Map<String, dynamic>>.from(helperController.headers)
        : [];

    // Add common dining styles if not in cuisine types
    final commonStyles = [
      'Fine Dining',
      'Casual',
      'Quick & Easy',
      'Comfort Food',
      'Healthy',
      'Gourmet',
    ];

    // Combine cuisine types with common styles, avoiding duplicates
    final allFilters = <String>{};
    for (var cuisine in cuisineTypes) {
      final name = cuisine['name']?.toString() ?? '';
      if (name.isNotEmpty) {
        allFilters.add(name);
      }
    }
    for (var style in commonStyles) {
      allFilters.add(style);
    }

    final filterList = allFilters.toList()..sort();

    return await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        backgroundColor: isDarkMode ? kDarkGrey : kWhite,
        title: Text(
          'Select Cuisine/Style',
          style: TextStyle(
            color: isDarkMode ? kWhite : kBlack,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Container(
          width: MediaQuery.of(context).size.width * 0.8,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.5,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Option to clear filter
                ListTile(
                  leading: Icon(
                    selectedCuisineFilter == null
                        ? Icons.check_circle
                        : Icons.circle_outlined,
                    color: kAccent,
                  ),
                  title: Text(
                    'Any Style',
                    style: TextStyle(
                      color: isDarkMode ? kWhite : kBlack,
                      fontWeight: selectedCuisineFilter == null
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(dialogContext, null);
                  },
                ),
                Divider(color: isDarkMode ? kLightGrey : kDarkGrey),
                // Filter options
                ...filterList.map((filter) {
                  final isSelected = selectedCuisineFilter == filter;
                  return ListTile(
                    leading: Icon(
                      isSelected ? Icons.check_circle : Icons.circle_outlined,
                      color: kAccent,
                    ),
                    title: Text(
                      filter,
                      style: TextStyle(
                        color: isDarkMode ? kWhite : kBlack,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(dialogContext, filter);
                    },
                  );
                }).toList(),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(dialogContext, selectedCuisineFilter),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: isDarkMode ? kWhite : kAccent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _generateFridgeRecipes() async {
    // In pantry mode, use pantry items; otherwise use fridge ingredients
    final ingredientsToUse = isPantryMode
        ? pantryItems.map((item) => item['name'] as String).toList()
        : fridgeIngredients;

    if (ingredientsToUse.length < 3) {
      showTastySnackbar(
        'Not Enough Ingredients',
        'Please add at least 3 ingredients to generate recipes',
        context,
        backgroundColor: Colors.orange,
      );
      return;
    }

    setState(() {
      isAnalyzingFridge = true;
    });

    try {
      // Check if user can use AI features
      if (!canUseAI()) {
        showPremiumRequiredDialog(
            context, getThemeProvider(context).isDarkMode);
        setState(() {
          isAnalyzingFridge = false;
        });
        return;
      }

      // Create mock MacroData objects for the ingredients
      final mockIngredients = ingredientsToUse
          .map((ingredient) => MacroData(
                id: 'fridge_${ingredient.toLowerCase().replaceAll(' ', '_')}',
                title: ingredient,
                type: 'ingredient',
                mediaPaths: [],
                calories: 0,
                macros: {},
                categories: [],
                features: {},
                image: '',
              ))
          .toList();

      // Generate recipes using the existing service
      // Pass the selected cuisine filter if available
      final recipes = await gemini.geminiService.generateMealsFromIngredients(
        mockIngredients,
        context,
        true, // isDineIn
        cuisineFilter: selectedCuisineFilter,
      );

      // Check if meal generation failed
      if (recipes['source'] == 'failed' || recipes['error'] == true) {
        showMealGenerationErrorDialog(
          context,
          recipes['message'] ?? 'Failed to generate meals. Please try again.',
          onRetry: () async {
            try {
              final retryRecipes =
                  await gemini.geminiService.generateMealsFromIngredients(
                mockIngredients,
                context,
                true,
                cuisineFilter: selectedCuisineFilter,
              );
              if (retryRecipes['source'] != 'failed' &&
                  retryRecipes['error'] != true &&
                  retryRecipes['meals'] != null) {
                setState(() {
                  _fridgeRecipes =
                      List<Map<String, dynamic>>.from(retryRecipes['meals']);
                  _showFridgeRecipes = true;
                });
                await _saveFridgeRecipesToSharedPreferences();
              }
            } catch (e) {
              showTastySnackbar(
                'Couldn\'t generate dishes, Chef',
                'Failed to generate meals, Chef: $e',
                context,
                backgroundColor: kRed,
              );
            }
          },
        );
        return;
      }

      if (recipes['meals'] != null) {
        setState(() {
          _fridgeRecipes = List<Map<String, dynamic>>.from(recipes['meals']);
          _showFridgeRecipes = true;
        });

        // Save recipes to SharedPreferences for persistence
        await _saveFridgeRecipesToSharedPreferences();
      }
    } catch (e) {
      showTastySnackbar(
        'Couldn\'t generate recipes, Chef',
        'Failed to generate recipes, Chef: $e',
        context,
        backgroundColor: kRed,
      );
    }

    setState(() {
      isAnalyzingFridge = false;
    });
  }

  void _removeFridgeIngredient(String ingredient) {
    setState(() {
      fridgeIngredients.remove(ingredient);
    });
    _saveFridgeData();
  }

  /// Show ingredient actions menu
  void _showIngredientActionsMenu(String ingredient, BuildContext context) {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    final isInPantry = _isIngredientInPantry(ingredient);

    showModalBottomSheet(
      context: context,
      backgroundColor: isDarkMode ? kDarkGrey : kWhite,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.all(getPercentageWidth(4, context)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              capitalizeFirstLetter(ingredient),
              style: TextStyle(
                fontSize: getTextScale(4, context),
                fontWeight: FontWeight.w600,
                color: isDarkMode ? kWhite : kBlack,
              ),
            ),
            SizedBox(height: getPercentageHeight(2, context)),
            if (!isInPantry)
              ListTile(
                leading: Icon(Icons.inventory_2, color: kAccent),
                title: Text(
                  'Add to Pantry',
                  style: TextStyle(
                    color: isDarkMode ? kWhite : kBlack,
                  ),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  try {
                    await _saveIngredientsToPantry([ingredient]);
                    // Refresh pantry items to show the newly added item
                    await _fetchPantryItems();
                  } catch (e) {
                    debugPrint('Error saving ingredient to pantry: $e');
                    if (mounted && context.mounted) {
                      showTastySnackbar(
                        'Error',
                        'Failed to save ingredient to pantry. Please try again.',
                        context,
                        backgroundColor: Colors.red,
                      );
                    }
                  }
                },
              ),
            if (isInPantry)
              ListTile(
                leading: Icon(Icons.delete_outline, color: Colors.red),
                title: Text(
                  'Remove from Pantry',
                  style: TextStyle(
                    color: isDarkMode ? kWhite : kBlack,
                  ),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  await _removeFromPantry(ingredient);
                },
              ),
            ListTile(
              leading: Icon(Icons.close, color: Colors.orange),
              title: Text(
                'Remove from List',
                style: TextStyle(
                  color: isDarkMode ? kWhite : kBlack,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _removeFridgeIngredient(ingredient);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Remove ingredient from pantry
  Future<void> _removeFromPantry(String ingredientName) async {
    try {
      final userId = userService.userId;
      if (userId == null || userId.isEmpty) return;

      final ingredientId = ingredientName
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]'), '_')
          .replaceAll(RegExp(r'_+'), '_');

      await firestore
          .collection('users')
          .doc(userId)
          .collection('pantry')
          .doc(ingredientId)
          .delete();

      // Refresh pantry items
      await _fetchPantryItems();

      if (mounted) {
        showTastySnackbar(
          'Removed',
          'Removed from pantry',
          context,
          backgroundColor: kAccent,
        );
      }
    } catch (e) {
      debugPrint('Error removing from pantry: $e');
      if (mounted) {
        showTastySnackbar(
          'Couldn\'t remove from pantry, Chef',
          'Failed to remove from pantry, Chef. Please try again.',
          context,
          backgroundColor: kRed,
        );
      }
    }
  }

  /// Show pantry management view
  void _showPantryManagementView() {
    final isDarkMode = getThemeProvider(context).isDarkMode;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        backgroundColor: isDarkMode ? kDarkGrey : kWhite,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'My Pantry',
              style: TextStyle(
                color: isDarkMode ? kWhite : kBlack,
              ),
            ),
            Text(
              '${pantryItems.length} items',
              style: TextStyle(
                color: isDarkMode ? kLightGrey : kDarkGrey,
                fontSize: getTextScale(3, context),
              ),
            ),
          ],
        ),
        content: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.6,
          ),
          child: pantryItems.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.inventory_2_outlined,
                        size: getIconScale(15, context),
                        color: isDarkMode ? kLightGrey : kDarkGrey,
                      ),
                      SizedBox(height: getPercentageHeight(2, context)),
                      Text(
                        'The pantry is empty, Chef.',
                        style: TextStyle(
                          color: isDarkMode ? kLightGrey : kDarkGrey,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: pantryItems.length,
                  itemBuilder: (context, index) {
                    final item = pantryItems[index];
                    final name = item['name'] as String? ?? 'Unknown';
                    final calories = item['calories'] as int? ?? 0;

                    return ListTile(
                      leading: Icon(
                        Icons.inventory_2,
                        color: kAccent,
                      ),
                      title: Text(
                        capitalizeFirstLetter(name),
                        style: TextStyle(
                          color: isDarkMode ? kWhite : kBlack,
                          fontSize: getTextScale(3.5, context),
                        ),
                      ),
                      subtitle: calories > 0
                          ? Text(
                              '${calories} kcal',
                              style: TextStyle(
                                color: isDarkMode ? kLightGrey : kDarkGrey,
                                fontSize: getTextScale(2.5, context),
                              ),
                            )
                          : null,
                      trailing: IconButton(
                        icon: Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () async {
                          await _removeFromPantry(name);
                          if (mounted) {
                            Navigator.pop(dialogContext);
                            _showPantryManagementView();
                          }
                        },
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              'Close',
              style: TextStyle(
                color: isDarkMode ? kWhite : kAccent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _clearFridge() {
    setState(() {
      fridgeIngredients.clear();
      _fridgeImage = null;
      _fridgeRecipes.clear();
      _showFridgeRecipes = false;
    });
    _saveFridgeData();
    _clearFridgeRecipesFromSharedPreferences(); // Also clear from SharedPreferences
  }

  /// Save ingredients to Firestore pantry collection
  Future<void> _saveIngredientsToPantry(
      [List<String>? ingredientsToSave]) async {
    try {
      final userId = userService.userId;
      if (userId == null || userId.isEmpty) {
        debugPrint('Cannot save to pantry: userId is empty');
        return;
      }

      // Use provided list or default to all fridgeIngredients
      final ingredients = ingredientsToSave ?? fridgeIngredients;

      if (ingredients.isEmpty) {
        debugPrint('No ingredients to save to pantry');
        return;
      }

      final pantryRef =
          firestore.collection('users').doc(userId).collection('pantry');

      int savedCount = 0;

      // Save each ingredient to pantry
      for (var ingredientName in ingredients) {
        if (ingredientName.trim().isEmpty) continue;

        // Create a document ID from ingredient name (sanitized)
        final ingredientId = ingredientName
            .toLowerCase()
            .replaceAll(RegExp(r'[^a-z0-9]'), '_')
            .replaceAll(RegExp(r'_+'), '_');

        // Check if ingredient already exists
        final existingDoc = await pantryRef.doc(ingredientId).get();

        if (existingDoc.exists) {
          // Update existing ingredient
          await pantryRef.doc(ingredientId).update({
            'name': ingredientName,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else {
          // Create new ingredient entry
          // Note: We don't have full nutrition data from image analysis,
          // so we'll store basic info and let user fill in details later
          await pantryRef.doc(ingredientId).set({
            'name': ingredientName,
            'type': 'ingredient', // Could be enhanced to detect type
            'calories': 0, // To be filled by user or enhanced analysis
            'protein': 0.0,
            'carbs': 0.0,
            'fat': 0.0,
            'addedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
            'source': isPantryMode ? 'pantry_mode' : 'fridge_analysis',
          });
        }
        savedCount++;
      }

      debugPrint('Saved $savedCount ingredients to pantry');

      // Refresh pantry items list
      await _fetchPantryItems();

      if (mounted) {
        showTastySnackbar(
          'Pantry Updated',
          '$savedCount ingredient(s) saved to your pantry',
          context,
          backgroundColor: kAccent,
        );
      }
    } catch (e) {
      debugPrint('Error saving ingredients to pantry: $e');
      if (mounted) {
        showTastySnackbar(
          'Couldn\'t save to pantry, Chef',
          'Failed to save ingredients to pantry, Chef. Please try again.',
          context,
          backgroundColor: kRed,
        );
      }
    }
  }

  /// Fetch pantry items from Firestore
  Future<void> _fetchPantryItems() async {
    try {
      final userId = userService.userId;
      if (userId == null || userId.isEmpty) {
        return;
      }

      setState(() {
        isLoadingPantry = true;
      });

      final pantryRef =
          firestore.collection('users').doc(userId).collection('pantry');

      final snapshot = await pantryRef.get();

      setState(() {
        pantryItems = snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'name': data['name'] as String? ?? '',
            'type': data['type'] as String? ?? 'ingredient',
            'calories': data['calories'] as int? ?? 0,
            'protein': (data['protein'] as num?)?.toDouble() ?? 0.0,
            'carbs': (data['carbs'] as num?)?.toDouble() ?? 0.0,
            'fat': (data['fat'] as num?)?.toDouble() ?? 0.0,
            'addedAt': data['addedAt'],
            'updatedAt': data['updatedAt'],
          };
        }).toList();
        isLoadingPantry = false;
      });

      debugPrint('Fetched ${pantryItems.length} pantry items');
    } catch (e) {
      debugPrint('Error fetching pantry items: $e');
      setState(() {
        isLoadingPantry = false;
      });
    }
  }

  /// Show pantry ingredient selector dialog
  Future<void> _showPantryIngredientSelector() async {
    if (pantryItems.isEmpty) {
      showTastySnackbar(
        'Empty Pantry, Chef',
        'The pantry is empty. Add ingredients to pantry mode first, Chef.',
        context,
        backgroundColor: Colors.orange,
      );
      return;
    }

    final isDarkMode = getThemeProvider(context).isDarkMode;
    final Set<String> selectedIngredientIds = {};

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          backgroundColor: isDarkMode ? kDarkGrey : kWhite,
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Add from Pantry',
                style: TextStyle(
                  color: isDarkMode ? kWhite : kBlack,
                ),
              ),
              if (pantryItems.length > 1)
                TextButton(
                  onPressed: () {
                    setDialogState(() {
                      if (selectedIngredientIds.length == pantryItems.length) {
                        selectedIngredientIds.clear();
                      } else {
                        selectedIngredientIds.addAll(
                          pantryItems.map((item) => item['id'] as String),
                        );
                      }
                    });
                  },
                  child: Text(
                    selectedIngredientIds.length == pantryItems.length
                        ? 'Deselect All'
                        : 'Select All',
                    style: TextStyle(
                      color: kAccent,
                      fontSize: getTextScale(3, context),
                    ),
                  ),
                ),
            ],
          ),
          content: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.6,
            ),
            child: pantryItems.isEmpty
                ? Center(
                    child: Text(
                      'No items in the pantry, Chef.',
                      style: TextStyle(
                        color: isDarkMode ? kLightGrey : kDarkGrey,
                      ),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: pantryItems.length,
                    itemBuilder: (context, index) {
                      final item = pantryItems[index];
                      final itemId = item['id'] as String;
                      final itemName = item['name'] as String;
                      final isSelected = selectedIngredientIds.contains(itemId);
                      final isAlreadyAdded = fridgeIngredients.any(
                          (ing) => ing.toLowerCase() == itemName.toLowerCase());

                      return CheckboxListTile(
                        title: Text(
                          itemName,
                          style: TextStyle(
                            color: isDarkMode ? kWhite : kBlack,
                            fontSize: getTextScale(3.5, context),
                            decoration: isAlreadyAdded
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                        subtitle: item['calories'] != null &&
                                item['calories'] > 0
                            ? Text(
                                '${item['calories']} kcal',
                                style: TextStyle(
                                  color: isDarkMode ? kLightGrey : kDarkGrey,
                                  fontSize: getTextScale(2.5, context),
                                ),
                              )
                            : null,
                        value: isSelected,
                        onChanged: isAlreadyAdded
                            ? null
                            : (value) {
                                setDialogState(() {
                                  if (value == true) {
                                    selectedIngredientIds.add(itemId);
                                  } else {
                                    selectedIngredientIds.remove(itemId);
                                  }
                                });
                              },
                        secondary: isAlreadyAdded
                            ? Icon(
                                Icons.check_circle,
                                color: Colors.green,
                                size: getIconScale(5, context),
                              )
                            : Icon(
                                Icons.inventory_2,
                                color: kAccent,
                                size: getIconScale(5, context),
                              ),
                        activeColor: kAccent,
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: isDarkMode ? kWhite : kAccent,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: selectedIngredientIds.isEmpty
                  ? null
                  : () {
                      final selectedItems = pantryItems
                          .where((item) => selectedIngredientIds
                              .contains(item['id'] as String))
                          .map((item) => item['name'] as String)
                          .toList();

                      // Filter out items already in fridgeIngredients
                      final newItems = selectedItems
                          .where((name) => !fridgeIngredients.any(
                              (ing) => ing.toLowerCase() == name.toLowerCase()))
                          .toList();

                      if (newItems.isNotEmpty) {
                        setState(() {
                          fridgeIngredients.addAll(newItems);
                        });
                        _saveFridgeData();
                        Navigator.pop(dialogContext);
                        showTastySnackbar(
                          'Added',
                          'Added ${newItems.length} ingredient(s) from pantry',
                          context,
                          backgroundColor: kAccent,
                        );
                      } else {
                        Navigator.pop(dialogContext);
                        showTastySnackbar(
                          'Already Added',
                          'Selected items are already in your list',
                          context,
                          backgroundColor: Colors.orange,
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: kAccent,
              ),
              child: Text(
                'Add Selected (${selectedIngredientIds.length})',
                style: TextStyle(color: kWhite),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Get ingredient suggestions based on query
  List<String> _getIngredientSuggestions(String query) {
    if (query.isEmpty) {
      return [];
    }

    final queryLower = query.toLowerCase();
    final suggestions = <String>[];

    // Prioritize pantry items
    for (var item in pantryItems) {
      final name = (item['name'] as String? ?? '').toLowerCase();
      if (name.contains(queryLower)) {
        suggestions.add(item['name'] as String);
        if (suggestions.length >= 10) break;
      }
    }

    // Sort by relevance: exact match first, then starts with, then contains
    suggestions.sort((a, b) {
      final aLower = a.toLowerCase();
      final bLower = b.toLowerCase();

      if (aLower == queryLower) return -1;
      if (bLower == queryLower) return 1;

      if (aLower.startsWith(queryLower)) return -1;
      if (bLower.startsWith(queryLower)) return 1;

      return 0;
    });

    return suggestions.take(10).toList();
  }

  /// Show autocomplete suggestions overlay
  void _showSuggestionsOverlay(List<String> suggestions) {
    _removeSuggestionsOverlay();

    if (suggestions.isEmpty || !_fridgeFocusNode.hasFocus) {
      return;
    }

    final isDarkMode = getThemeProvider(context).isDarkMode;
    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    _suggestionsOverlay = OverlayEntry(
      builder: (context) => Positioned(
        width: renderBox.size.width * 0.9,
        child: CompositedTransformFollower(
          link: _suggestionsLayerLink,
          showWhenUnlinked: false,
          offset: Offset(0, renderBox.size.height + 4),
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            color: isDarkMode ? kDarkGrey : kWhite,
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.3,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: kAccent.withValues(alpha: 0.3),
                ),
              ),
              child: ListView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: suggestions.length,
                itemBuilder: (context, index) {
                  final suggestion = suggestions[index];
                  final isPantryItem = pantryItems.any(
                    (item) =>
                        (item['name'] as String? ?? '').toLowerCase() ==
                        suggestion.toLowerCase(),
                  );

                  return InkWell(
                    onTap: () {
                      _selectSuggestion(suggestion);
                    },
                    child: ListTile(
                      leading: Icon(
                        isPantryItem ? Icons.inventory_2 : Icons.food_bank,
                        color: isPantryItem ? kAccent : kLightGrey,
                        size: getIconScale(5, context),
                      ),
                      title: Text(
                        capitalizeFirstLetter(suggestion),
                        style: TextStyle(
                          color: isDarkMode ? kWhite : kBlack,
                          fontSize: getTextScale(3.5, context),
                        ),
                      ),
                      trailing: isPantryItem
                          ? Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: getPercentageWidth(2, context),
                                vertical: getPercentageHeight(0.3, context),
                              ),
                              decoration: BoxDecoration(
                                color: kAccent.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'Pantry',
                                style: TextStyle(
                                  color: kAccent,
                                  fontSize: getTextScale(2.5, context),
                                ),
                              ),
                            )
                          : null,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_suggestionsOverlay!);
  }

  /// Select a suggestion and add it to ingredients
  void _selectSuggestion(String suggestion) {
    _fridgeController.text = suggestion;
    _fridgeFocusNode.unfocus();
    _removeSuggestionsOverlay();

    // Optionally auto-add or let user confirm
    // For now, just populate the field
  }

  /// Navigate to meal planning with pantry context
  void _navigateToMealPlanningWithPantry() {
    // In pantry mode, use pantry items; otherwise use fridge ingredients
    final ingredientsToUse = isPantryMode
        ? pantryItems.map((item) => item['name'] as String).toList()
        : fridgeIngredients;

    if (ingredientsToUse.isEmpty) {
      showTastySnackbar(
        'No ingredients in the pantry, Chef',
        'Add ingredients to your ${isPantryMode ? "pantry" : "fridge"} first, Chef',
        context,
        backgroundColor: kRed,
      );
      return;
    }

    // Navigate to buddy screen meal mode with pantry context
    Get.to(
      () => const TastyScreen(screen: 'buddy'),
      arguments: {
        'mealPlanMode': true,
        'pantryIngredients': ingredientsToUse,
        'pantryMode': true,
      },
    );
  }

  // Save a recipe from fridge analysis to the database using saveBasicMealsToFirestore
  Future<void> _saveRecipeToDatabase(Map<String, dynamic> recipeData) async {
    try {
      debugPrint('Saving recipe with data: $recipeData');
      debugPrint('Cooking time: ${recipeData['cookingTime']}');
      debugPrint('Calories: ${recipeData['calories']}');

      // Convert recipe data to the format expected by saveBasicMealsToFirestore
      final basicMealData = {
        'title': recipeData['title'] ?? 'Untitled Recipe',
        'mealType': 'fridge-generated',
        'type': 'fridge-recipe',
        'description': recipeData['description'] ?? '',
        'cookingTime': recipeData['cookingTime'] ?? '',
        'cookingMethod': '',
        'ingredients': _convertIngredientsToMap(recipeData['ingredients']),
        'instructions': [],
        'calories': _safeParseInt(recipeData['calories']) ?? 0,
      };

      debugPrint('Basic meal data: $basicMealData');

      // Use saveBasicMealsToFirestore to save the recipe
      final saveResult = await gemini.geminiService.saveBasicMealsToFirestore(
        [basicMealData],
        'fridge-generated',
      );

      debugPrint('Recipe saved with result: $saveResult');

      // Update the recipe in _fridgeRecipes with the actual mealId from Firestore
      if (saveResult['mealIds'] != null) {
        final mealIds = saveResult['mealIds'] as Map<String, dynamic>;
        final recipeTitle = recipeData['title'] ?? 'Untitled Recipe';
        final mealId = mealIds[recipeTitle];

        if (mealId != null) {
          // Find and update the recipe in _fridgeRecipes with the mealId
          final recipeIndex = _fridgeRecipes
              .indexWhere((recipe) => recipe['title'] == recipeTitle);
          if (recipeIndex != -1) {
            setState(() {
              _fridgeRecipes[recipeIndex]['mealId'] = mealId;
            });
            debugPrint(
                'Updated recipe with mealId: $mealId for title: $recipeTitle');

            // Save the updated recipe to SharedPreferences for persistence
            await _saveFridgeRecipesToSharedPreferences();

            // Set up listeners for meal updates after saving
            _setupMealUpdateListeners();
          }
        }
      }

      showTastySnackbar(
        'Recipe Saved!',
        'Recipe has been saved and will be processed by the cloud',
        context,
        backgroundColor: kAccent,
      );
    } catch (e) {
      debugPrint('Error saving recipe: $e');
      showTastySnackbar(
        'Couldn\'t save recipe, Chef',
        'Failed to save recipe, Chef: $e',
        context,
        backgroundColor: kRed,
      );
    }
  }

  // Convert ingredients map to proper format
  Map<String, String> _convertIngredientsToMap(dynamic ingredients) {
    if (ingredients is Map) {
      return ingredients.map((key, value) => MapEntry(
            key.toString(),
            value.toString(),
          ));
    }
    return {};
  }

  // Safe integer parsing helper
  int? _safeParseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) {
      // Remove any non-numeric characters except decimal point and minus sign
      final cleanString = value.replaceAll(RegExp(r'[^\d.-]'), '');
      return int.tryParse(cleanString);
    }
    if (value is double) return value.toInt();
    if (value is num) return value.toInt();
    return null;
  }

  // Navigate to recipe detail page
  void _navigateToRecipeDetail(Map<String, dynamic> recipeData) {
    debugPrint(
        'Navigating to recipe detail with mealId: ${recipeData['mealId']}');
    try {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RecipeDetailScreen(
            mealId: recipeData['mealId'],
            screen: 'fridge-recipe',
          ),
        ),
      );
    } catch (e) {
      debugPrint('Error navigating to recipe detail: $e');
      showTastySnackbar(
        'Couldn\'t open recipe details, Chef',
        'Failed to open recipe details, Chef. Please try again.',
        context,
        backgroundColor: kRed,
      );
    }
  }

  // Save fridge recipes to SharedPreferences for persistence
  Future<void> _saveFridgeRecipesToSharedPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Add timestamp to new recipes if they don't have one
      final now = DateTime.now().millisecondsSinceEpoch;
      final recipesWithTimestamp = _fridgeRecipes.map((recipe) {
        if (!recipe.containsKey('savedAt') || recipe['savedAt'] == null) {
          recipe['savedAt'] = now;
        }
        return Map<String, dynamic>.from(recipe);
      }).toList();

      // Load existing recipes from SharedPreferences
      final existingRecipesJson = prefs.getStringList('fridge_recipes') ?? [];
      final existingRecipes = existingRecipesJson
          .map((recipeJson) {
            try {
              return Map<String, dynamic>.from(jsonDecode(recipeJson));
            } catch (e) {
              debugPrint('Error parsing existing recipe: $e');
              return null;
            }
          })
          .where((recipe) => recipe != null)
          .cast<Map<String, dynamic>>()
          .toList();

      // Merge existing and new recipes, removing duplicates by mealId or title
      final allRecipes = <Map<String, dynamic>>[];

      // Add existing recipes that aren't in the new list
      for (final existing in existingRecipes) {
        final existingMealId = existing['mealId'] as String?;
        final existingTitle = existing['title'] as String?;

        bool isDuplicate = false;
        for (final newRecipe in recipesWithTimestamp) {
          final newMealId = newRecipe['mealId'] as String?;
          final newTitle = newRecipe['title'] as String?;

          // Match by mealId if both have it, otherwise match by title
          if (existingMealId != null &&
              newMealId != null &&
              existingMealId == newMealId) {
            isDuplicate = true;
            break;
          } else if (existingTitle != null &&
              newTitle != null &&
              existingTitle == newTitle) {
            isDuplicate = true;
            break;
          }
        }

        if (!isDuplicate) {
          allRecipes.add(existing);
        }
      }

      // Add all new recipes (they will override duplicates)
      allRecipes.addAll(recipesWithTimestamp);

      // Sort by savedAt timestamp (newest first)
      allRecipes.sort((a, b) {
        final aTime = a['savedAt'] as int? ?? 0;
        final bTime = b['savedAt'] as int? ?? 0;
        return bTime.compareTo(aTime); // Descending order (newest first)
      });

      // Keep only the 5 most recent recipes
      final recipesToSave = allRecipes.take(5).toList();

      // Save to SharedPreferences
      final recipesJson =
          recipesToSave.map((recipe) => jsonEncode(recipe)).toList();
      await prefs.setStringList('fridge_recipes', recipesJson);

      debugPrint(
          'Saved ${recipesToSave.length} fridge recipes to SharedPreferences (max 5, removed ${allRecipes.length - recipesToSave.length} oldest)');
    } catch (e) {
      debugPrint('Error saving fridge recipes to SharedPreferences: $e');
    }
  }

  // Load fridge recipes from SharedPreferences
  Future<void> _loadFridgeRecipesFromSharedPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final recipesJson = prefs.getStringList('fridge_recipes') ?? [];

      if (recipesJson.isNotEmpty) {
        final loadedRecipes = recipesJson
            .map((recipeJson) {
              try {
                final recipe =
                    Map<String, dynamic>.from(jsonDecode(recipeJson));
                // Add timestamp to old recipes that don't have one (treat as very old)
                if (!recipe.containsKey('savedAt') ||
                    recipe['savedAt'] == null) {
                  recipe['savedAt'] = 0; // Very old timestamp
                }
                return recipe;
              } catch (e) {
                debugPrint('Error parsing recipe from SharedPreferences: $e');
                return null;
              }
            })
            .where((recipe) => recipe != null)
            .cast<Map<String, dynamic>>()
            .toList();

        if (loadedRecipes.isNotEmpty) {
          // Sort by savedAt (newest first) and limit to 5
          loadedRecipes.sort((a, b) {
            final aTime = a['savedAt'] as int? ?? 0;
            final bTime = b['savedAt'] as int? ?? 0;
            return bTime.compareTo(aTime); // Descending order (newest first)
          });

          final recipesToLoad = loadedRecipes.take(5).toList();

          setState(() {
            _fridgeRecipes = recipesToLoad;
            _showFridgeRecipes = true;
          });
          debugPrint(
              'Loaded ${recipesToLoad.length} fridge recipes from SharedPreferences (max 5)');
        }
      }
    } catch (e) {
      debugPrint('Error loading fridge recipes from SharedPreferences: $e');
    }
  }

  // Clear fridge recipes from SharedPreferences
  Future<void> _clearFridgeRecipesFromSharedPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('fridge_recipes');
      debugPrint('Cleared fridge recipes from SharedPreferences');
    } catch (e) {
      debugPrint('Error clearing fridge recipes from SharedPreferences: $e');
    }
  }

  Widget _buildFridgeInterface(bool isDarkMode, TextTheme textTheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Fridge image or placeholder
        if (_fridgeImage != null) ...[
          Container(
            height: getPercentageHeight(15, context),
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kAccent.withValues(alpha: 0.3)),
            ),
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    _fridgeImage!,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    colorBlendMode: BlendMode.srcOver,
                    color: null, // Ensure no color tinting
                  ),
                ),
                // Loading overlay
                if (isAnalyzingFridge)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.black.withValues(alpha: 0.5),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(
                              color: kAccent,
                              strokeWidth: 3,
                            ),
                            SizedBox(height: getPercentageHeight(1, context)),
                            Text(
                              'Analyzing ingredients...',
                              style: textTheme.bodyMedium?.copyWith(
                                color: kWhite,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(height: getPercentageHeight(1, context)),
        ],

        // Add ingredients section
        Container(
          padding: EdgeInsets.all(getPercentageWidth(3, context)),
          decoration: BoxDecoration(
            color: kAccent.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: kAccent.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.kitchen, color: kAccent),
                  SizedBox(width: getPercentageWidth(2, context)),
                  Expanded(
                    child: Text(
                      isPantryMode ? 'Pantry Mode' : 'Add Ingredients',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: kAccent,
                      ),
                    ),
                  ),
                  // Pantry Mode Toggle and View Pantry Button
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // View Pantry Button
                      if (pantryItems.isNotEmpty)
                        IconButton(
                          icon: Icon(
                            Icons.inventory_2,
                            color: kAccent,
                            size: getIconScale(5, context),
                          ),
                          tooltip: 'View Pantry (${pantryItems.length})',
                          onPressed: () {
                            _showPantryManagementView();
                          },
                        ),
                      Text(
                        'Pantry',
                        style: textTheme.bodySmall?.copyWith(
                          color: isDarkMode ? kLightGrey : kDarkGrey,
                        ),
                      ),
                      SizedBox(width: getPercentageWidth(1, context)),
                      Switch(
                        value: isPantryMode,
                        onChanged: (value) {
                          setState(() {
                            isPantryMode = value;
                          });
                          // Refresh pantry items when switching to pantry mode
                          if (value) {
                            _fetchPantryItems();
                          }
                        },
                        activeColor: kAccent,
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(height: getPercentageHeight(1, context)),

              // Text input for manual entry with autocomplete
              CompositedTransformTarget(
                link: _suggestionsLayerLink,
                child: TextField(
                  controller: _fridgeController,
                  focusNode: _fridgeFocusNode,
                  onChanged: (value) {
                    if (value.isNotEmpty) {
                      final suggestions = _getIngredientSuggestions(value);
                      _showSuggestionsOverlay(suggestions);
                    } else {
                      _removeSuggestionsOverlay();
                    }
                  },
                  onSubmitted: (value) {
                    _fridgeFocusNode.unfocus();
                    _removeSuggestionsOverlay();
                  },
                  onTap: () {
                    if (_fridgeController.text.isNotEmpty) {
                      final suggestions =
                          _getIngredientSuggestions(_fridgeController.text);
                      _showSuggestionsOverlay(suggestions);
                    }
                  },
                  decoration: InputDecoration(
                    hintText:
                        'Enter ingredients separated by commas (e.g., chicken, rice, broccoli)',
                    hintStyle: textTheme.bodySmall?.copyWith(
                      color: isDarkMode ? kLightGrey : kDarkGrey,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          BorderSide(color: kAccent.withValues(alpha: 0.3)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          BorderSide(color: kAccent.withValues(alpha: 0.3)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: kAccent),
                    ),
                  ),
                  style: textTheme.bodyMedium?.copyWith(
                    color: isDarkMode ? kWhite : kBlack,
                  ),
                  maxLines: 2,
                ),
              ),
              SizedBox(height: getPercentageHeight(1, context)),

              // Quick add common items section
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isPantryMode
                            ? 'Quick Add Common Pantry Items'
                            : 'Quick Add Common Fridge Items',
                        style: textTheme.bodySmall?.copyWith(
                          color: isDarkMode ? kLightGrey : kDarkGrey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          // Add all common items to input (comma separated)
                          final currentText = _fridgeController.text.trim();
                          final commonItems = isPantryMode
                              ? commonPantryItems
                              : commonFridgeItems;
                          // Check against appropriate list based on mode
                          final itemsToAdd = commonItems.where((item) {
                            if (isPantryMode) {
                              return !pantryItems.any((p) =>
                                  (p['name'] as String).toLowerCase() ==
                                  item.toLowerCase());
                            } else {
                              return !fridgeIngredients.any(
                                  (f) => f.toLowerCase() == item.toLowerCase());
                            }
                          }).join(', ');
                          if (itemsToAdd.isNotEmpty) {
                            _fridgeController.text = currentText.isEmpty
                                ? itemsToAdd
                                : '$currentText, $itemsToAdd';
                            _fridgeController.selection =
                                TextSelection.fromPosition(
                              TextPosition(
                                  offset: _fridgeController.text.length),
                            );
                          }
                        },
                        child: Text(
                          'Add All',
                          style: textTheme.bodySmall?.copyWith(
                            color: kAccent,
                            fontSize: getTextScale(2.5, context),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: getPercentageHeight(0.5, context)),
                  Wrap(
                    spacing: getPercentageWidth(1, context),
                    runSpacing: getPercentageHeight(0.5, context),
                    children: (isPantryMode
                            ? commonPantryItems
                            : commonFridgeItems)
                        .where((item) {
                          // Filter based on mode
                          if (isPantryMode) {
                            return !pantryItems.any((p) =>
                                (p['name'] as String).toLowerCase() ==
                                item.toLowerCase());
                          } else {
                            return !fridgeIngredients.any(
                                (f) => f.toLowerCase() == item.toLowerCase());
                          }
                        })
                        .take(12) // Show first 12 items
                        .map((item) {
                          final isInPantry = _isIngredientInPantry(item);
                          return GestureDetector(
                            onTap: () {
                              // Add item to input field
                              final currentText = _fridgeController.text.trim();
                              if (currentText.isEmpty) {
                                _fridgeController.text =
                                    capitalizeFirstLetter(item);
                              } else {
                                // Check if item already in input
                                final itemsInInput = currentText
                                    .split(',')
                                    .map((e) => e.trim().toLowerCase())
                                    .toList();
                                if (!itemsInInput
                                    .contains(item.toLowerCase())) {
                                  _fridgeController.text =
                                      '$currentText, ${capitalizeFirstLetter(item)}';
                                }
                              }
                              // Move cursor to end
                              _fridgeController.selection =
                                  TextSelection.fromPosition(
                                TextPosition(
                                    offset: _fridgeController.text.length),
                              );
                              // Focus the input
                              _fridgeFocusNode.requestFocus();
                            },
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: getPercentageWidth(2, context),
                                vertical: getPercentageHeight(0.5, context),
                              ),
                              decoration: BoxDecoration(
                                color: isInPantry
                                    ? kAccent.withValues(alpha: 0.15)
                                    : kLightGrey.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isInPantry
                                      ? kAccent.withValues(alpha: 0.5)
                                      : kLightGrey.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isInPantry)
                                    Icon(
                                      Icons.inventory_2,
                                      size: getIconScale(3, context),
                                      color: kAccent,
                                    ),
                                  if (isInPantry)
                                    SizedBox(
                                        width:
                                            getPercentageWidth(0.5, context)),
                                  Text(
                                    capitalizeFirstLetter(item),
                                    style: textTheme.bodySmall?.copyWith(
                                      color: isInPantry
                                          ? kAccent
                                          : (isDarkMode ? kWhite : kBlack),
                                      fontWeight: FontWeight.w500,
                                      fontSize: getTextScale(2.5, context),
                                    ),
                                  ),
                                  SizedBox(
                                      width: getPercentageWidth(0.5, context)),
                                  Icon(
                                    Icons.add_circle_outline,
                                    size: getIconScale(3, context),
                                    color: isInPantry
                                        ? kAccent
                                        : (isDarkMode ? kLightGrey : kDarkGrey),
                                  ),
                                ],
                              ),
                            ),
                          );
                        })
                        .toList(),
                  ),
                ],
              ),
              SizedBox(height: getPercentageHeight(1, context)),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed:
                          isAnalyzingFridge ? null : () => _pickFridgeImage(),
                      icon: Icon(Icons.camera_alt,
                          color: isAnalyzingFridge ? kLightGrey : kAccent),
                      label: Text(
                        isAnalyzingFridge ? 'Analyzing...' : 'Add Photo',
                        style: textTheme.bodyMedium?.copyWith(
                            color: isAnalyzingFridge ? kLightGrey : kAccent),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                            color: isAnalyzingFridge ? kLightGrey : kAccent),
                      ),
                    ),
                  ),
                  SizedBox(width: getPercentageWidth(2, context)),
                  Expanded(
                    child: AppButton(
                      text: isAnalyzingFridge
                          ? 'Analyzing...'
                          : 'Add Ingredients',
                      onPressed: isAnalyzingFridge
                          ? () {}
                          : () => _addManualIngredient(),
                      type: AppButtonType.follow,
                      color: isAnalyzingFridge ? kLightGrey : kAccent,
                    ),
                  ),
                ],
              ),
              // Add from Pantry button (only in fridge mode)
              if (!isPantryMode && pantryItems.isNotEmpty) ...[
                SizedBox(height: getPercentageHeight(1, context)),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: isLoadingPantry
                        ? null
                        : () => _showPantryIngredientSelector(),
                    icon: Icon(
                      Icons.inventory_2,
                      color: isLoadingPantry ? kLightGrey : kAccent,
                    ),
                    label: Text(
                      isLoadingPantry
                          ? 'Preparing...'
                          : 'Add from Pantry (${pantryItems.length})',
                      style: textTheme.bodyMedium?.copyWith(
                        color: isLoadingPantry ? kLightGrey : kAccent,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: isLoadingPantry ? kLightGrey : kAccent,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),

        SizedBox(height: getPercentageHeight(1, context)),

        // Use in Meal Plan button (when pantry mode is enabled)
        if (isPantryMode && pantryItems.isNotEmpty) ...[
          SizedBox(height: getPercentageHeight(1, context)),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _navigateToMealPlanningWithPantry,
              icon: Icon(Icons.restaurant_menu, color: kWhite),
              label: Text(
                'Use in Meal Plan',
                style: textTheme.titleMedium?.copyWith(
                  color: kWhite,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: kAccent,
                padding: EdgeInsets.symmetric(
                  vertical: getPercentageHeight(1.5, context),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],

        // Recently used ingredients (only in fridge mode)
        if (!isPantryMode && recentlyUsedIngredients.isNotEmpty) ...[
          Text(
            'Recently Used',
            style: textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: kAccent,
            ),
          ),
          SizedBox(height: getPercentageHeight(0.5, context)),
          Wrap(
            spacing: getPercentageWidth(1, context),
            runSpacing: getPercentageHeight(0.5, context),
            children: recentlyUsedIngredients
                .where((ing) => !fridgeIngredients
                    .any((f) => f.toLowerCase() == ing.toLowerCase()))
                .take(5)
                .map((ingredient) {
              final isInPantry = _isIngredientInPantry(ingredient);
              return GestureDetector(
                onTap: () async {
                  if (isPantryMode) {
                    // In pantry mode: only save to pantry
                    await _saveIngredientsToPantry([ingredient]);
                    await _fetchPantryItems();
                  } else {
                    // In fridge mode: add to fridge
                    setState(() {
                      if (!fridgeIngredients.any(
                          (f) => f.toLowerCase() == ingredient.toLowerCase())) {
                        fridgeIngredients.add(ingredient);
                      }
                    });
                    await _saveFridgeData();
                  }
                  await _saveRecentlyUsedIngredients(ingredient);
                },
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: getPercentageWidth(2, context),
                    vertical: getPercentageHeight(0.5, context),
                  ),
                  decoration: BoxDecoration(
                    color: isInPantry
                        ? kAccent.withValues(alpha: 0.15)
                        : kLightGrey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isInPantry
                          ? kAccent.withValues(alpha: 0.5)
                          : kLightGrey.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isInPantry)
                        Icon(
                          Icons.inventory_2,
                          size: getIconScale(3.5, context),
                          color: kAccent,
                        ),
                      if (isInPantry)
                        SizedBox(width: getPercentageWidth(0.5, context)),
                      Text(
                        capitalizeFirstLetter(ingredient),
                        style: textTheme.bodySmall?.copyWith(
                          color: isInPantry
                              ? kAccent
                              : (isDarkMode ? kWhite : kBlack),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          SizedBox(height: getPercentageHeight(1, context)),
        ],

        SizedBox(height: getPercentageHeight(2, context)),
        // Current ingredients list
        // In pantry mode: show pantry items from Firestore
        // In fridge mode: show fridgeIngredients (items added from pantry or manually)
        if ((isPantryMode && pantryItems.isNotEmpty) ||
            (!isPantryMode && fridgeIngredients.isNotEmpty)) ...[
          Text(
            isPantryMode
                ? 'Your Pantry (${pantryItems.length})'
                : 'Your Fridge Items (${fridgeIngredients.length})',
            style: textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: kAccent,
            ),
          ),
          SizedBox(height: getPercentageHeight(1, context)),
          Wrap(
            spacing: getPercentageWidth(1, context),
            runSpacing: getPercentageHeight(0.5, context),
            children: (isPantryMode
                    ? pantryItems.map((item) => item['name'] as String).toList()
                    : fridgeIngredients)
                .map((ingredient) {
              final isInPantry = _isIngredientInPantry(ingredient);
              return GestureDetector(
                onLongPress: () =>
                    _showIngredientActionsMenu(ingredient, context),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: getPercentageWidth(2, context),
                    vertical: getPercentageHeight(0.5, context),
                  ),
                  decoration: BoxDecoration(
                    color: isInPantry
                        ? kAccent.withValues(alpha: 0.2)
                        : kAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isInPantry
                          ? kAccent.withValues(alpha: 0.7)
                          : kAccent.withValues(alpha: 0.5),
                      width: isInPantry ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isInPantry)
                        Icon(
                          Icons.inventory_2,
                          size: getIconScale(3.5, context),
                          color: kAccent,
                        ),
                      if (isInPantry)
                        SizedBox(width: getPercentageWidth(0.5, context)),
                      Text(
                        capitalizeFirstLetter(ingredient),
                        style: textTheme.bodySmall?.copyWith(
                          color: kAccent,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(width: getPercentageWidth(1, context)),
                      GestureDetector(
                        onTap: () {
                          if (isPantryMode) {
                            _removeFromPantry(ingredient);
                          } else {
                            _removeFridgeIngredient(ingredient);
                          }
                        },
                        child: Icon(
                          Icons.close,
                          size: getIconScale(4, context),
                          color: kAccent,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          SizedBox(height: getPercentageHeight(2, context)),

          // Generate recipes button - only show in fridge mode (not pantry mode)
          if (!isPantryMode && fridgeIngredients.isNotEmpty) ...[
            // Filter button - always show above Generate Recipes button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final selectedFilter = await _showRecipeFilterDialog();
                  if (selectedFilter != selectedCuisineFilter) {
                    setState(() {
                      selectedCuisineFilter = selectedFilter;
                    });
                  }
                },
                icon: Icon(
                  Icons.filter_alt,
                  color: selectedCuisineFilter != null
                      ? kAccent
                      : (isDarkMode ? kWhite : kBlack),
                  size: getIconScale(4, context),
                ),
                label: Text(
                  selectedCuisineFilter != null
                      ? 'Filter: ${selectedCuisineFilter}'
                      : 'Select Cuisine/Style Filter',
                  style: textTheme.bodyMedium?.copyWith(
                    color: selectedCuisineFilter != null
                        ? kAccent
                        : (isDarkMode ? kWhite : kBlack),
                    fontWeight: selectedCuisineFilter != null
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.symmetric(
                    horizontal: getPercentageWidth(3, context),
                    vertical: getPercentageHeight(1.2, context),
                  ),
                  side: BorderSide(
                    color: selectedCuisineFilter != null
                        ? kAccent
                        : (isDarkMode ? kLightGrey : kDarkGrey),
                    width: 1.5,
                  ),
                  backgroundColor: selectedCuisineFilter != null
                      ? kAccent.withValues(alpha: 0.1)
                      : Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            SizedBox(height: getPercentageHeight(1.5, context)),
            // Use fridgeIngredients count in fridge mode
            if (fridgeIngredients.length >= 3) ...[
              SizedBox(
                width: double.infinity,
                child: AppButton(
                  text: isAnalyzingFridge
                      ? 'Generating Recipes...'
                      : 'Generate Recipes',
                  onPressed: isAnalyzingFridge
                      ? () {}
                      : () {
                          _generateFridgeRecipes();
                        },
                  type: AppButtonType.primary,
                  color: kAccent,
                ),
              ),
            ] else ...[
              Container(
                padding: EdgeInsets.all(getPercentageWidth(3, context)),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange),
                    SizedBox(width: getPercentageWidth(2, context)),
                    Expanded(
                      child: Text(
                        'Add at least 3 ingredients to generate recipes',
                        style: textTheme.bodySmall?.copyWith(
                          color: Colors.orange,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],

        // Clear fridge button
        if (fridgeIngredients.isNotEmpty) ...[
          SizedBox(height: getPercentageHeight(1, context)),
          Center(
            child: TextButton.icon(
              onPressed: () => _clearFridge(),
              icon: Icon(Icons.clear_all, color: kAccentLight),
              label: Text(
                'Clear All',
                style: textTheme.bodySmall?.copyWith(color: kAccentLight),
              ),
            ),
          ),
        ],

        // Display generated recipes - only in fridge mode, not pantry mode
        if (!isPantryMode &&
            _showFridgeRecipes &&
            _fridgeRecipes.isNotEmpty) ...[
          SizedBox(height: getPercentageHeight(2, context)),
          Row(
            children: [
              Text(
                'Recipes Using Your Ingredients',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: kAccent,
                ),
              ),
              SizedBox(width: 8),
              Icon(
                Icons.save,
                size: 16,
                color: kAccentLight,
              ),
              Text(
                'Saved',
                style: textTheme.bodySmall?.copyWith(
                  color: kAccentLight,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          SizedBox(height: getPercentageHeight(1, context)),
          ...(_fridgeRecipes.map(
              (recipe) => _buildRecipeCard(recipe, isDarkMode, textTheme))),
        ],
      ],
    );
  }

  Widget _buildRecipeCard(
      Map<String, dynamic> recipe, bool isDarkMode, TextTheme textTheme) {
    return GestureDetector(
      onTap: () => _navigateToRecipeDetail(recipe),
      child: Container(
        margin: EdgeInsets.only(bottom: getPercentageHeight(1, context)),
        padding: EdgeInsets.all(getPercentageWidth(3, context)),
        decoration: BoxDecoration(
          color: kAccent.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kAccent.withValues(alpha: 0.3)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(
            children: [
              Icon(Icons.restaurant, color: kAccent),
              SizedBox(width: getPercentageWidth(2, context)),
              Expanded(
                child: Text(
                  recipe['title'] ?? 'Untitled Recipe',
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: kAccent,
                  ),
                ),
              ),
              // Save button
              // IconButton(
              //   onPressed: () => _saveRecipeToDatabase(recipe),
              //   icon: Icon(
              //     Icons.bookmark_add,
              //     color: kAccent,
              //     size: getIconScale(5, context),
              //   ),
              //   tooltip: 'Save Recipe',
              // ),
            ],
          ),
          SizedBox(height: getPercentageHeight(1, context)),

          // Description
          if (recipe['calories'] != null && recipe['calories'] != 0) ...[
            Text(
              '${recipe['calories']} calories',
              style: textTheme.bodySmall?.copyWith(
                color: isDarkMode ? kLightGrey : kDarkGrey,
              ),
            ),
            SizedBox(height: getPercentageHeight(0.5, context)),
          ],

          // Cooking info
          Row(
            children: [
              if (recipe['cookingTime'] != null &&
                  recipe['cookingTime'] != 'Unknown') ...[
                Icon(Icons.timer,
                    size: getIconScale(4, context), color: kAccent),
                SizedBox(width: getPercentageWidth(1, context)),
                Text(
                  recipe['cookingTime'],
                  style: textTheme.bodySmall?.copyWith(
                    color: isDarkMode ? kWhite : kBlack,
                  ),
                ),
                SizedBox(width: getPercentageWidth(4, context)),
              ],
              if (recipe['difficulty'] != null) ...[
                Icon(Icons.speed,
                    size: getIconScale(4, context), color: kAccent),
                SizedBox(width: getPercentageWidth(1, context)),
                Text(
                  '${recipe['difficulty']} difficulty',
                  style: textTheme.bodySmall?.copyWith(
                    color: isDarkMode ? kWhite : kBlack,
                  ),
                ),
              ],
            ],
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    final textTheme = Theme.of(context).textTheme;

    final result = Scaffold(
      appBar: AppBar(
        centerTitle: true,
        toolbarHeight: getPercentageHeight(10, context),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Dine-In',
              textAlign: TextAlign.center,
              style: textTheme.displaySmall?.copyWith(
                fontSize: getTextScale(7, context),
              ),
            ),
            SizedBox(width: getPercentageWidth(2, context)),
            InfoIconWidget(
              title: 'Dine In',
              description: isPantryMode
                  ? 'Cook with what\'s in your pantry, Chef'
                  : 'Cook with what\'s in your fridge, Chef',
              details: [
                {
                  'icon': Icons.emoji_events,
                  'title': 'Fridge Mode',
                  'description':
                      'Add ingredients from your fridge or take a photo!',
                  'color': kBlue,
                },
                {
                  'icon': Icons.auto_awesome,
                  'title': 'AI Recipe Generation',
                  'description':
                      'Get personalized recipes using your ingredients',
                  'color': kBlue,
                },
                {
                  'icon': Icons.emoji_events,
                  'title': 'Pantry Mode',
                  'description':
                      'Add ingredients to your pantry and use in meal planning!',
                  'color': kBlue,
                },
              ],
              iconColor: kBlue,
              tooltip: 'Dine In Information',
            ),
          ],
        ),
        backgroundColor: isDarkMode ? kDarkGrey : kWhite,
        elevation: 2,
      ),
      body: Container(
       decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage(
              isDarkMode
                  ? 'assets/images/background/imagedark.jpeg'
                  : 'assets/images/background/imagelight.jpeg',
            ),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              isDarkMode
                  ? Colors.black.withOpacity(0.5)   
                  : Colors.white.withOpacity(0.5),
              isDarkMode ? BlendMode.darken : BlendMode.lighten,
            ),
          ),
        ),
        child: isLoading
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(color: kAccent),
                    SizedBox(height: getPercentageHeight(2, context)),
                    Text(
                      'Finding perfect ingredient pair...',
                      style: textTheme.bodyMedium?.copyWith(
                        color: isDarkMode ? kWhite : kBlack,
                      ),
                    ),
                  ],
                ),
              )
            : GestureDetector(
                onTap: () {
                  _fridgeFocusNode.unfocus();
                },
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(getPercentageWidth(2, context)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: getPercentageHeight(2, context)),
                      // Header text
                      Center(
                        child: Text(
                          isPantryMode
                              ? 'What\'s in Your Pantry?'
                              : 'What\'s in Your Fridge?',
                          textAlign: TextAlign.center,
                          style: textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: getPercentageWidth(5, context),
                            color: kAccent,
                          ),
                        ),
                      ),
                      SizedBox(height: getPercentageHeight(1, context)),
                      Center(
                        child: Text(
                          isPantryMode
                              ? 'Add ingredients to your pantry and use in meal planning!'
                              : 'Add ingredients from your fridge and get personalized recipes!',
                          textAlign: TextAlign.center,
                          style: textTheme.bodyMedium?.copyWith(
                            color: isDarkMode ? kLightGrey : kDarkGrey,
                            fontSize: getPercentageWidth(3.5, context),
                          ),
                        ),
                      ),
                      SizedBox(height: getPercentageHeight(1.5, context)),

                      // Fridge interface
                      _buildFridgeInterface(isDarkMode, textTheme),
                      SizedBox(height: getPercentageHeight(2, context)),

                      SizedBox(height: getPercentageHeight(10, context)),
                    ],
                  ),
                ),
              ),
      ),
    );
    return result;
  }
}
