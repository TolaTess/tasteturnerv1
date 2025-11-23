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
    _loadSavedMeal();
    _loadFridgeData();
    _loadFridgeRecipesFromSharedPreferences();
    loadExcludedIngredients();
    debugPrint('Excluded ingredients: ${excludedIngredients.length}');
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
    super.dispose();
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

      String errorMessage = 'Failed to pick image';
      if (e is TimeoutException) {
        errorMessage = 'Camera operation timed out. Please try again.';
      } else if (e.toString().contains('permission')) {
        errorMessage =
            'Camera permission denied. Please enable camera access in settings.';
      } else if (e.toString().contains('camera')) {
        errorMessage =
            'Camera not available. Please try using gallery instead.';
      }

      showTastySnackbar(
        'Error',
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
          'Analysis Failed',
          'Failed to analyze image: ${analysisResult['message']}',
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

        setState(() {
          fridgeIngredients = ingredientNames;
        });

        debugPrint('Updated fridgeIngredients: $fridgeIngredients');

        await _saveFridgeData();

        // If we have suggested meals from the analysis, use them directly
        if (analysisResult['suggestedMeals'] != null) {
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
        'Analysis Failed',
        'Failed to analyze fridge image: $e',
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

    setState(() {
      fridgeIngredients.addAll(ingredients);
      _fridgeController.clear();
    });

    await _saveFridgeData();
    // await _generateFridgeRecipes();
  }

  Future<void> _generateFridgeRecipes() async {
    if (fridgeIngredients.length < 3) {
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
      final mockIngredients = fridgeIngredients
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
      final recipes = await gemini.geminiService.generateMealsFromIngredients(
        mockIngredients,
        context,
        true, // isDineIn
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
                'Generation Failed',
                'Failed to generate meals: $e',
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
        'Recipe Generation Failed',
        'Failed to generate recipes: $e',
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
        'Save Failed',
        'Failed to save recipe: $e',
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
        'Navigation Failed',
        'Failed to open recipe details',
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
                  Text(
                    'Add Ingredients',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: kAccent,
                    ),
                  ),
                ],
              ),
              SizedBox(height: getPercentageHeight(1, context)),

              // Text input for manual entry
              TextField(
                controller: _fridgeController,
                focusNode: _fridgeFocusNode,
                onSubmitted: (value) {
                  _fridgeFocusNode.unfocus();
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
            ],
          ),
        ),

        SizedBox(height: getPercentageHeight(1, context)),

        // Current ingredients list
        if (fridgeIngredients.isNotEmpty) ...[
          Text(
            'Your Fridge Ingredients (${fridgeIngredients.length})',
            style: textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: kAccent,
            ),
          ),
          SizedBox(height: getPercentageHeight(0.5, context)),
          Wrap(
            spacing: getPercentageWidth(1, context),
            runSpacing: getPercentageHeight(0.5, context),
            children: fridgeIngredients.map((ingredient) {
              return Container(
                padding: EdgeInsets.symmetric(
                  horizontal: getPercentageWidth(2, context),
                  vertical: getPercentageHeight(0.5, context),
                ),
                decoration: BoxDecoration(
                  color: kAccent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: kAccent.withValues(alpha: 0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      capitalizeFirstLetter(ingredient),
                      style: textTheme.bodySmall?.copyWith(
                        color: kAccent,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(width: getPercentageWidth(1, context)),
                    GestureDetector(
                      onTap: () => _removeFridgeIngredient(ingredient),
                      child: Icon(
                        Icons.close,
                        size: getIconScale(4, context),
                        color: kAccent,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          SizedBox(height: getPercentageHeight(2, context)),

          // Generate recipes button
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
                border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
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

        // Display generated recipes
        if (_showFridgeRecipes && _fridgeRecipes.isNotEmpty) ...[
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
            const InfoIconWidget(
              title: 'Dine In',
              description: 'Cook with what you have in your fridge',
              details: [
                {
                  'icon': Icons.kitchen,
                  'title': 'Fridge Ingredients',
                  'description':
                      'Add ingredients from your fridge or take a photo',
                  'color': kBlue,
                },
                {
                  'icon': Icons.auto_awesome,
                  'title': 'AI Recipe Generation',
                  'description':
                      'Get personalized recipes using your ingredients',
                  'color': kBlue,
                },
                // {
                //   'icon': Icons.emoji_events,
                //   'title': 'Weekly Challenge',
                //   'description': 'Join challenges to win points and rewards',
                //   'color': kBlue,
                // },
              ],
              iconColor: kBlue,
              tooltip: 'Dine In Information',
            ),
          ],
        ),
        backgroundColor: isDarkMode ? kDarkGrey : kWhite,
        elevation: 2,
      ),
      body: isLoading
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
                        'What\'s in Your Fridge?',
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
                        'Add ingredients from your fridge and get personalized recipes!',
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
    );
    return result;
  }

  Widget _buildIngredientCard(
    Map<String, String> ingredient,
    String typeLabel,
    bool isDarkMode,
    TextTheme textTheme,
    Color color,
  ) {
    return Container(
      padding: EdgeInsets.all(getPercentageWidth(3, context)),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Type label
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: getPercentageWidth(2, context),
              vertical: getPercentageHeight(0.5, context),
            ),
            decoration: BoxDecoration(
              color: isDarkMode
                  ? kAccent.withValues(alpha: 0.2)
                  : kLightGrey.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              typeLabel == 'Grain'
                  ? 'Carb'
                  : typeLabel == 'Protein'
                      ? 'Protein'
                      : typeLabel,
              style: textTheme.bodySmall?.copyWith(
                color: isDarkMode ? kWhite : kBlack,
                fontWeight: FontWeight.w600,
                fontSize: getPercentageWidth(3, context),
              ),
            ),
          ),
          SizedBox(height: getPercentageHeight(1, context)),

          // Ingredient image
          Container(
            height: getPercentageWidth(20, context),
            width: getPercentageWidth(20, context),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: kLightGrey.withValues(alpha: 0.3),
            ),
            child: ClipOval(
              child: ingredient['image'] != null
                  ? Image.asset(
                      ingredient['image']!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Icon(
                          Icons.food_bank,
                          size: getIconScale(10, context)),
                    )
                  : Icon(
                      Icons.food_bank,
                      size: getIconScale(10, context),
                      color: kAccent,
                    ),
            ),
          ),
          SizedBox(height: getPercentageHeight(1, context)),

          // Ingredient name
          Text(
            capitalizeFirstLetter(ingredient['name'] ?? ''),
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: getPercentageWidth(3.5, context),
              color: isDarkMode ? kWhite : kBlack,
            ),
          ),
        ],
      ),
    );
  }
}
