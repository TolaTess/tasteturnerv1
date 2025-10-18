import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:firebase_analytics/firebase_analytics.dart';
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
import '../pages/upload_battle.dart';
import '../service/macro_manager.dart';
import '../service/gemini_service.dart' as gemini;
import '../widgets/ingredient_battle_widget.dart';
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

  // Legacy variables (keeping for challenge mode)
  MacroData? selectedCarb;
  MacroData? selectedProtein;
  bool isLoading = false;
  bool isAccepted = false;
  Map<String, dynamic>? selectedMeal;
  final Random _random = Random();

  // Challenge related variables
  List<Map<String, String>> challengeIngredients = [];
  List<Map<String, String>> selectedChallengeIngredients = [];
  bool isChallengeMode = false;
  bool isLoadingChallenge = false;
  String? challengeDate;
  String? savedChallengeDate; // Store the user's saved challenge date
  bool isChallengeEnabled = false;
  List<String> excludedIngredients = [];

  @override
  void initState() {
    super.initState();
    _loadSavedMeal();
    _loadFridgeData();
    _loadFridgeRecipesFromSharedPreferences(); // Load persisted fridge recipes
    loadExcludedIngredients();
    debugPrint('Excluded ingredients: ${excludedIngredients.length}');

    // Load excluded ingredients lazily after UI is built
    // _loadExcludedIngredientsLazily();
    _checkChallengeNotification();
    _loadChallengeData();
  }

  @override
  void dispose() {
    _fridgeController.dispose();
    _fridgeFocusNode.dispose();
    super.dispose();
  }

  loadExcludedIngredients() async {
    excludedIngredients = excludeIngredients.toList();
  }

  // /// Load excluded ingredients lazily after UI is built
  // void _loadExcludedIngredientsLazily() {
  //   // Use addPostFrameCallback to ensure this runs after the first frame is rendered
  //   WidgetsBinding.instance.addPostFrameCallback((_) async {
  //     try {
  //       debugPrint('Loading excluded ingredients from Firebase...');

  //       // Only fetch if we don't already have the data
  //       if (firebaseService.generalData.isEmpty) {
  //         await firebaseService.fetchGeneralData();
  //       }

  //       if (mounted && firebaseService.generalData.isNotEmpty) {
  //         setState(() {
  //           excludedIngredients = firebaseService
  //               .generalData['excludeIngredients']
  //               .toString()
  //               .split(',');
  //         });
  //         debugPrint(
  //             'Excluded ingredients loaded: ${excludedIngredients.length}');
  //       }
  //     } catch (e) {
  //       debugPrint('Error loading excluded ingredients: $e');
  //       // Fallback to local data if Firebase fails
  //       if (mounted) {
  //         setState(() {
  //           excludedIngredients = excludeIngredients.toList();
  //         });
  //       }
  //     }
  //   });
  // }

  // Local storage keys
  static const String _selectedMealKey = 'dine_in_selected_meal';
  static const String _selectedCarbKey = 'dine_in_selected_carb';
  static const String _selectedProteinKey = 'dine_in_selected_protein';
  static const String _mealTimestampKey = 'dine_in_meal_timestamp';

  // Challenge storage keys
  static const String _challengeIngredientsKey =
      'dine_in_challenge_ingredients';
  static const String _challengeDateKey = 'dine_in_challenge_date';
  static const String _isChallengeModeKey = 'dine_in_is_challenge_mode';

  // Notification storage keys
  static const String _lastChallengeNotificationKey =
      'dine_in_last_challenge_notification';
  static const String _challengeNotificationEnabledKey =
      'dine_in_challenge_notification_enabled';

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

  // Load challenge data from Firebase and local storage
  Future<void> _loadChallengeData() async {
    debugPrint('Loading challenge data');

    setState(() {
      isLoadingChallenge = true;
    });

    try {
      // Get challenge details from general data
      final challengeDetails = firebaseService.generalData['challenge_details'];

      if (challengeDetails != null && challengeDetails is String) {
        // Parse challenge details: "07-08-2025,carrot-v,shrimp-p,pork-p,aubergine-v"
        final parts = challengeDetails.split(',');
        if (parts.length >= 6) {
          challengeDate = parts[0];
          isChallengeEnabled = parts[5] == 'true';
          debugPrint('Challenge enabled: $isChallengeEnabled');

          // Get ingredient names (skip the date)
          final ingredientNames = parts.skip(1).take(4).toList();

          // Fetch all ingredients to find the challenge ingredients
          if (_macroManager.ingredient.isEmpty) {
            await _macroManager.fetchIngredients();
          }

          // Parse ingredients with new format: "carrot-v,shrimp-p,pork-p,aubergine-v"
          challengeIngredients = [];
          for (String ingredientString in ingredientNames) {
            // Extract clean name and type from format like "carrot-v" or "shrimp-p"
            final cleanName =
                ingredientString.replaceAll(RegExp(r'-[vp]$'), '');
            final type = ingredientString.endsWith('-v')
                ? 'vegetable'
                : ingredientString.endsWith('-p')
                    ? 'protein'
                    : 'unknown';

            // Create simple ingredient map
            challengeIngredients.add({
              'name': cleanName,
              'type': type,
              'image': type == 'vegetable'
                  ? 'assets/images/vegetable.jpg'
                  : 'assets/images/meat.jpg',
            });
          }

          // If no ingredients found, create mock ingredients for testing
          if (challengeIngredients.isEmpty) {
            challengeIngredients = [
              {
                'name': 'Carrot',
                'type': 'vegetable',
                'image': 'assets/images/vegetable.jpg'
              },
              {
                'name': 'Shrimp',
                'type': 'protein',
                'image': 'assets/images/fish.jpg'
              },
              {
                'name': 'Pork',
                'type': 'protein',
                'image': 'assets/images/meat.jpg'
              },
              {
                'name': 'Aubergine',
                'type': 'vegetable',
                'image': 'assets/images/vegetable.jpg'
              },
            ];
          }

          // Load saved challenge data
          await _loadSavedChallengeData();

          // Check for challenge notification after loading data
          await _checkChallengeNotification();
        }
      }
    } catch (e) {
      debugPrint('Error loading challenge data: $e');
    }

    setState(() {
      isLoadingChallenge = false;
    });
  }

  // Load saved challenge data from local storage
  Future<void> _loadSavedChallengeData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final savedChallengeDateFromStorage = prefs.getString(_challengeDateKey);
      final isChallengeModeSaved = prefs.getBool(_isChallengeModeKey) ?? false;

      // Store the saved challenge date for comparison
      savedChallengeDate = savedChallengeDateFromStorage;

      // Set the mode preference
      setState(() {
        isChallengeMode = isChallengeModeSaved;
      });

      // Check if saved challenge is for the same week
      if (savedChallengeDateFromStorage == challengeDate &&
          isChallengeModeSaved) {
        final savedIngredients = prefs.getString(_challengeIngredientsKey);
        if (savedIngredients != null) {
          final ingredientIds = jsonDecode(savedIngredients) as List<dynamic>;

          selectedChallengeIngredients = [];
          for (String id in ingredientIds) {
            final found = challengeIngredients
                .where((ingredient) =>
                    ingredient['name']?.toLowerCase() == id.toLowerCase())
                .toList();
            if (found.isNotEmpty) {
              selectedChallengeIngredients.add(found.first);
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading saved challenge data: $e');
    } 
  }

  // Save challenge data to local storage
  Future<void> _saveChallengeData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      if (selectedChallengeIngredients.isNotEmpty) {
        final ingredientIds = selectedChallengeIngredients
            .map((ingredient) => ingredient['name'] ?? '')
            .toList();
        await prefs.setString(
            _challengeIngredientsKey, jsonEncode(ingredientIds));
        await prefs.setString(_challengeDateKey, challengeDate ?? '');
        await prefs.setBool(_isChallengeModeKey, true);
      }
    } catch (e) {
      showTastySnackbar(
          'Something went wrong', 'Please try again later', Get.context!,
          backgroundColor: kRed);
    }
  }

  // Check if challenge has ended
  bool _isChallengeEnded() {
    // Check if user is enrolled in an old challenge
    if (_isOldChallenge()) return true;

    if (challengeDate == null) return false;

    try {
      // Parse challenge date (format: "DD-MM-YYYY")
      final challengeParts = challengeDate!.split('-');
      if (challengeParts.length == 3) {
        final challengeDay = int.parse(challengeParts[0]);
        final challengeMonth = int.parse(challengeParts[1]);
        final challengeYear = int.parse(challengeParts[2]);

        final challengeDateTime =
            DateTime(challengeYear, challengeMonth, challengeDay);

        // Check if challenge has ended (after Sunday of that week)
        final challengeEndDate = _getWeekEndDate(challengeDateTime);
        final now = DateTime.now();

        return now.isAfter(challengeEndDate);
      }
    } catch (e) {
      showTastySnackbar(
          'Something went wrong', 'Please try again later', Get.context!,
          backgroundColor: kRed);
    }

    return false;
  }

  // Check if user is enrolled in an old challenge
  bool _isOldChallenge() {
    // If user is not in challenge mode, they can't have an old challenge
    if (!isChallengeMode) return false;

    // If there's no current challenge date, but user is enrolled, it's an old challenge
    if (challengeDate == null) return true;

    // If user's saved challenge date is different from current challenge date, it's an old challenge
    if (savedChallengeDate != null && savedChallengeDate != challengeDate) {
      return true;
    }

    return false;
  }

  // Get the end date of the week for a given date
  DateTime _getWeekEndDate(DateTime date) {
    final daysUntilSunday = DateTime.sunday - date.weekday;
    return date.add(Duration(days: daysUntilSunday));
  }

  // Check if challenge date is in the past
  bool _isChallengeDateInPast() {
    if (challengeDate == null) return false;

    try {
      // Parse challenge date (format: "DD-MM-YYYY")
      final challengeParts = challengeDate!.split('-');
      if (challengeParts.length == 3) {
        final challengeDay = int.parse(challengeParts[0]);
        final challengeMonth = int.parse(challengeParts[1]);
        final challengeYear = int.parse(challengeParts[2]);

        final challengeDateTime =
            DateTime(challengeYear, challengeMonth, challengeDay);

        // Check if challenge date is in the past (before today)
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);

        return challengeDateTime.isBefore(today);
      }
    } catch (e) {
      showTastySnackbar(
          'Something went wrong', 'Please try again later', Get.context!,
          backgroundColor: kRed);
    }

    return false;
  }

  // Check if challenge notification should be sent
  Future<void> _checkChallengeNotification() async {
    debugPrint('Checking challenge notification');
    try {
      final prefs = await SharedPreferences.getInstance();

      // Check if notifications are enabled (default to true)
      final notificationsEnabled =
          prefs.getBool(_challengeNotificationEnabledKey) ?? true;
      if (!notificationsEnabled) return;

      // Get current date
      final now = DateTime.now();

      // Check if today is Monday
      if (now.weekday != DateTime.monday) return;

      // Get the last notification date
      final lastNotificationDate =
          prefs.getString(_lastChallengeNotificationKey);
      if (lastNotificationDate != null) {
        final lastDate = DateTime.parse(lastNotificationDate);
        // If we already sent a notification this week, don't send another
        if (now.difference(lastDate).inDays < 7) return;
      }

      // Check if there's a challenge date this week
      if (challengeDate != null) {
        try {
          // Parse challenge date (format: "DD-MM-YYYY")
          final challengeParts = challengeDate!.split('-');
          if (challengeParts.length == 3) {
            final challengeDay = int.parse(challengeParts[0]);
            final challengeMonth = int.parse(challengeParts[1]);
            final challengeYear = int.parse(challengeParts[2]);

            final challengeDateTime =
                DateTime(challengeYear, challengeMonth, challengeDay);

            // Check if challenge ends this Sunday
            final thisSunday = _getThisWeekSunday();

            if (challengeDateTime.isAtSameMomentAs(thisSunday)) {
              // Send notification
              await _sendChallengeNotification();

              // Save notification date
              await prefs.setString(
                  _lastChallengeNotificationKey, now.toIso8601String());
            }
          }
        } catch (e) {
          showTastySnackbar(
              'Something went wrong', 'Please try again later', Get.context!,
              backgroundColor: kRed);
        }
      }
    } catch (e) {
      showTastySnackbar(
          'Something went wrong', 'Please try again later', Get.context!,
          backgroundColor: kRed);
    }
  }

  // Get this week's Sunday
  DateTime _getThisWeekSunday() {
    final now = DateTime.now();
    final daysUntilSunday = DateTime.sunday - now.weekday;
    return now.add(Duration(days: daysUntilSunday));
  }

  // Send challenge notification
  Future<void> _sendChallengeNotification() async {
    try {
      await notificationService.showNotification(
        id: 1001, // Unique ID for challenge notifications
        title: 'Weekly Challenge Reminder! 🏆',
        body:
            'Your Dine-In challenge ends this Sunday! Don\'t forget to upload your creation.',
      );
    } catch (e) {
      showTastySnackbar(
          'Something went wrong', 'Please try again later', Get.context!,
          backgroundColor: kRed);
    }
  }

  // Get notification status
  Future<bool> _getNotificationStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_challengeNotificationEnabledKey) ?? true;
    } catch (e) {
      debugPrint('Error getting notification status: $e');
      return true;
    }
  }

  // Toggle challenge notifications
  Future<void> _toggleChallengeNotifications(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_challengeNotificationEnabledKey, enabled);

      if (enabled) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Challenge notifications enabled'),
            backgroundColor: kAccent,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Challenge notifications disabled'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error toggling challenge notifications: $e');
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
          'Please wait while the camera initializes...',
          context,
          backgroundColor: kAccent,
        );
      }

      debugPrint('Starting image picker with source: $source');

      // Add timeout to prevent hanging
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
        const Duration(seconds: 30),
        onTimeout: () {
          debugPrint('Image picker timed out');
          throw TimeoutException(
              'Camera operation timed out', const Duration(seconds: 30));
        },
      );
      debugPrint('Image picker completed, result: ${image?.path}');

      if (image != null) {
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
        final ingredients = analysisResult['ingredients'] as List<dynamic>;
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
          final suggestedMeals =
              analysisResult['suggestedMeals'] as List<dynamic>;
          debugPrint('Suggested meals: $suggestedMeals');

          setState(() {
            // Convert each meal properly to preserve all fields
            _fridgeRecipes = suggestedMeals.map((meal) {
              if (meal is Map<String, dynamic>) {
                debugPrint('Processing meal: $meal');
                return {
                  'title': meal['title'] ?? 'Untitled Recipe',
                  'description': meal['description'] ?? 'No description',
                  'cookingTime': meal['cookingTime'] ?? 'Unknown',
                  'difficulty': meal['difficulty'] ?? 'medium',
                  'calories': meal['calories'] ?? 0,
                  'ingredients': meal['ingredients'] ?? {},
                };
              }
              return {
                'title': 'Untitled Recipe',
                'description': 'No description',
                'cookingTime': 'Unknown',
                'difficulty': 'medium',
                'calories': 0,
                'ingredients': {},
              };
            }).toList();
            _showFridgeRecipes = true;
          });

          debugPrint('Updated _fridgeRecipes: $_fridgeRecipes');
          debugPrint('_showFridgeRecipes: $_showFridgeRecipes');

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
            _fridgeRecipes[recipeIndex]['mealId'] = mealId;
            debugPrint(
                'Updated recipe with mealId: $mealId for title: $recipeTitle');

            // Save the updated recipe to SharedPreferences for persistence
            await _saveFridgeRecipesToSharedPreferences();
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
      final recipesJson =
          _fridgeRecipes.map((recipe) => jsonEncode(recipe)).toList();
      await prefs.setStringList('fridge_recipes', recipesJson);
      debugPrint(
          'Saved ${_fridgeRecipes.length} fridge recipes to SharedPreferences');
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
                return Map<String, dynamic>.from(jsonDecode(recipeJson));
              } catch (e) {
                debugPrint('Error parsing recipe from SharedPreferences: $e');
                return null;
              }
            })
            .where((recipe) => recipe != null)
            .cast<Map<String, dynamic>>()
            .toList();

        if (loadedRecipes.isNotEmpty) {
          setState(() {
            _fridgeRecipes = loadedRecipes;
            _showFridgeRecipes = true;
          });
          debugPrint(
              'Loaded ${loadedRecipes.length} fridge recipes from SharedPreferences');
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

  // Show challenge ingredient selection dialog
  void _showChallengeSelectionDialog() {
    if (challengeIngredients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No challenge ingredients available'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final isDarkMode = getThemeProvider(context).isDarkMode;
          final textTheme = Theme.of(context).textTheme;

          return AlertDialog(
            backgroundColor: isDarkMode ? kDarkGrey : kWhite,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            title: Text(
              'Select Ingredients',
              style: textTheme.titleLarge?.copyWith(color: kAccent),
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Choose 2 ingredients from this week\'s challenge:',
                    style: textTheme.bodyMedium?.copyWith(
                      color: isDarkMode ? kWhite : kBlack,
                    ),
                  ),
                  SizedBox(height: getPercentageHeight(2, context)),
                  // 2x2 Grid layout for challenge ingredients
                  Column(
                    children: [
                      // First row
                      Row(
                        children:
                            challengeIngredients.take(2).map((ingredient) {
                          final isSelected =
                              selectedChallengeIngredients.contains(ingredient);
                          final colorIndex =
                              challengeIngredients.indexOf(ingredient) %
                                  colors.length;
                          return Expanded(
                            child: GestureDetector(
                              onTap: () {
                                setDialogState(() {
                                  if (isSelected) {
                                    selectedChallengeIngredients
                                        .remove(ingredient);
                                  } else if (selectedChallengeIngredients
                                          .length <
                                      2) {
                                    selectedChallengeIngredients
                                        .add(ingredient);
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                            'You can only select 2 ingredients'),
                                        backgroundColor: Colors.orange,
                                      ),
                                    );
                                  }
                                });
                              },
                              child: Container(
                                margin: EdgeInsets.all(
                                    getPercentageWidth(1, context)),
                                padding: EdgeInsets.all(
                                    getPercentageWidth(2, context)),
                                decoration: BoxDecoration(
                                  color:
                                      isSelected ? kAccent : colors[colorIndex],
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected
                                        ? kAccent
                                        : kAccent.withValues(alpha: 0.3),
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          Colors.black.withValues(alpha: 0.1),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    Container(
                                      height: getPercentageWidth(15, context),
                                      width: getPercentageWidth(15, context),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color:
                                            kLightGrey.withValues(alpha: 0.3),
                                      ),
                                      child: ClipOval(
                                        child: ingredient['image'] != null
                                            ? Image.asset(
                                                ingredient['image']!,
                                                fit: BoxFit.cover,
                                                errorBuilder: (context, error,
                                                        stackTrace) =>
                                                    Icon(Icons.food_bank,
                                                        size: getIconScale(
                                                            8, context)),
                                              )
                                            : Icon(
                                                Icons.food_bank,
                                                size: getIconScale(8, context),
                                                color: kAccent,
                                              ),
                                      ),
                                    ),
                                    SizedBox(
                                        height:
                                            getPercentageHeight(1, context)),
                                    Text(
                                      capitalizeFirstLetter(
                                          ingredient['name'] ?? ''),
                                      textAlign: TextAlign.center,
                                      style: textTheme.bodySmall?.copyWith(
                                        color: isSelected
                                            ? kWhite
                                            : (isDarkMode ? kWhite : kBlack),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      // Second row
                      SizedBox(height: getPercentageHeight(1, context)),
                      Row(
                        children:
                            challengeIngredients.skip(2).map((ingredient) {
                          final isSelected =
                              selectedChallengeIngredients.contains(ingredient);
                          final colorIndex =
                              challengeIngredients.indexOf(ingredient) %
                                  colors.length;
                          return Expanded(
                            child: GestureDetector(
                              onTap: () {
                                setDialogState(() {
                                  if (isSelected) {
                                    selectedChallengeIngredients
                                        .remove(ingredient);
                                  } else if (selectedChallengeIngredients
                                          .length <
                                      2) {
                                    selectedChallengeIngredients
                                        .add(ingredient);
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                            'You can only select 2 ingredients'),
                                        backgroundColor: Colors.orange,
                                      ),
                                    );
                                  }
                                });
                              },
                              child: Container(
                                margin: EdgeInsets.all(
                                    getPercentageWidth(1, context)),
                                padding: EdgeInsets.all(
                                    getPercentageWidth(2, context)),
                                decoration: BoxDecoration(
                                  color:
                                      isSelected ? kAccent : colors[colorIndex],
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected
                                        ? kAccent
                                        : kAccent.withValues(alpha: 0.3),
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          Colors.black.withValues(alpha: 0.1),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    Container(
                                      height: getPercentageWidth(15, context),
                                      width: getPercentageWidth(15, context),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color:
                                            kLightGrey.withValues(alpha: 0.3),
                                      ),
                                      child: ClipOval(
                                        child: ingredient['image'] != null
                                            ? Image.asset(
                                                ingredient['image']!,
                                                fit: BoxFit.cover,
                                                errorBuilder: (context, error,
                                                        stackTrace) =>
                                                    Icon(Icons.food_bank,
                                                        size: getIconScale(
                                                            8, context)),
                                              )
                                            : Icon(
                                                Icons.food_bank,
                                                size: getIconScale(8, context),
                                                color: kAccent,
                                              ),
                                      ),
                                    ),
                                    SizedBox(
                                        height:
                                            getPercentageHeight(1, context)),
                                    Text(
                                      capitalizeFirstLetter(
                                          ingredient['name'] ?? ''),
                                      textAlign: TextAlign.center,
                                      style: textTheme.bodySmall?.copyWith(
                                        color: isSelected
                                            ? kWhite
                                            : (isDarkMode ? kWhite : kBlack),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancel',
                  style: textTheme.bodyMedium?.copyWith(color: kAccentLight),
                ),
              ),
              TextButton(
                onPressed: selectedChallengeIngredients.length == 2
                    ? () {
                        Navigator.pop(context);
                        _showChallengeDetailsDialog();
                      }
                    : null,
                child: Text(
                  'Continue',
                  style: textTheme.bodyMedium?.copyWith(
                    color: selectedChallengeIngredients.length == 2
                        ? kAccent
                        : kAccentLight,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // Show challenge details dialog
  void _showChallengeDetailsDialog() {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    final textTheme = Theme.of(context).textTheme;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: isDarkMode ? kDarkGrey : kWhite,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            title: Text(
              'Weekly Challenge Details',
              style: textTheme.titleLarge?.copyWith(color: kAccent),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '• Use only the selected ingredients plus:\n'
                  '  - Onions\n'
                  '  - Herbs\n'
                  '  - Spices\n\n'
                  '• Create a visually stunning dish\n'
                  '• Take a high-quality photo\n'
                  '• Submit before the end of the week\n\n'
                  '• Upload a photo of your meal to earn 30 points\n\n'
                  '🏆 Challenge ends: ${challengeDate ?? 'This week'} \n\n'
                  'Good luck!',
                  style: textTheme.bodyMedium?.copyWith(
                    color: isDarkMode ? kWhite : kBlack,
                  ),
                ),
                SizedBox(height: getPercentageHeight(2, context)),
                // Notification toggle
                FutureBuilder<bool>(
                  future: _getNotificationStatus(),
                  builder: (context, snapshot) {
                    final notificationsEnabled = snapshot.data ?? true;
                    return Row(
                      children: [
                        Icon(
                          Icons.notifications,
                          color: notificationsEnabled ? kAccent : kLightGrey,
                          size: getIconScale(6, context),
                        ),
                        SizedBox(width: getPercentageWidth(2, context)),
                        Expanded(
                          child: Text(
                            'Monday reminders',
                            style: textTheme.bodyMedium?.copyWith(
                              color: isDarkMode ? kWhite : kBlack,
                            ),
                          ),
                        ),
                        Switch(
                          value: notificationsEnabled,
                          onChanged: (value) {
                            setDialogState(() {});
                            _toggleChallengeNotifications(value);
                          },
                          activeColor: kAccent,
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancel',
                  style: textTheme.bodyMedium?.copyWith(color: kAccentLight),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  FirebaseAnalytics.instance
                      .logEvent(name: 'dine_in_challenge_accepted');
                  _acceptChallenge();
                },
                child: Text(
                  'Join Challenge',
                  style: textTheme.bodyMedium?.copyWith(color: kAccent),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // Accept the challenge
  void _acceptChallenge() async {
    await _saveChallengeData();
    setState(() {
      isChallengeMode = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Challenge accepted! Good luck!'),
        backgroundColor: kAccent,
      ),
    );
  }

  // Switch between fridge and challenge mode
  void _switchToRandomMode() async {
    print('Switching mode from $isChallengeMode to ${!isChallengeMode}');
    print(
        'Current selectedChallengeIngredients: $selectedChallengeIngredients');

    setState(() {
      isChallengeMode = !isChallengeMode;
    });

    // Save the mode preference
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_isChallengeModeKey, isChallengeMode);
    } catch (e) {
      debugPrint('Error saving mode preference: $e');
    }

    print('After switch - isChallengeMode: $isChallengeMode');
    print(
        'After switch - selectedChallengeIngredients: $selectedChallengeIngredients');

    // Show feedback to user
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isChallengeMode
              ? 'Switched to Weekly Challenge mode'
              : 'Switched to Fridge mode',
        ),
        backgroundColor: kAccent,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _navigateToUploadBattle({bool isChallenge = false}) {
    if (isChallenge && selectedChallengeIngredients.length >= 2) {
      // Create battle ID from challenge ingredient names + random number
      final battleId =
          '${selectedChallengeIngredients[0]['name']?.toLowerCase().replaceAll(' ', '_')}_'
          '${selectedChallengeIngredients[1]['name']?.toLowerCase().replaceAll(' ', '_')}_'
          'challenge_${_random.nextInt(9999).toString().padLeft(4, '0')}';

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => UploadBattleImageScreen(
            battleId: battleId,
            battleCategory: 'Weekly Challenge',
            isMainPost: false,
          ),
        ),
      );
    } else if (selectedCarb != null && selectedProtein != null) {
      // Create battle ID from ingredient names + random number
      final battleId =
          '${selectedCarb!.title.toLowerCase().replaceAll(' ', '_')}_'
          '${selectedProtein!.title.toLowerCase().replaceAll(' ', '_')}_'
          '${_random.nextInt(9999).toString().padLeft(4, '0')}';

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => UploadBattleImageScreen(
            battleId: battleId,
            battleCategory: 'Dine-In Challenge',
            isMainPost: false,
          ),
        ),
      );
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
          if (recipe['calories'] != null) ...[
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
              if (recipe['cookingTime'] != null) ...[
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
                {
                  'icon': Icons.emoji_events,
                  'title': 'Weekly Challenge',
                  'description': 'Join challenges to win points and rewards',
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
                        isChallengeMode
                            ? 'Weekly Challenge Ingredients'
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
                        isChallengeMode
                            ? 'Create something amazing with your selected challenge ingredients!'
                            : 'Add ingredients from your fridge and get personalized recipes!',
                        textAlign: TextAlign.center,
                        style: textTheme.bodyMedium?.copyWith(
                          color: isDarkMode ? kLightGrey : kDarkGrey,
                          fontSize: getPercentageWidth(3.5, context),
                        ),
                      ),
                    ),
                    SizedBox(height: getPercentageHeight(1.5, context)),

                    // Weekly Ingredients Battle Widget
                    const WeeklyIngredientBattle(),

                    SizedBox(height: getPercentageHeight(2, context)),

                    // Fridge or Challenge ingredients
                    if (isChallengeMode &&
                        selectedChallengeIngredients.length >= 2) ...[
                      // Challenge ingredients display
                      Column(
                        children: [
                          Text(
                            'Your Challenge Ingredients',
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: kAccent,
                              fontSize: getPercentageWidth(4, context),
                            ),
                          ),
                          SizedBox(height: getPercentageHeight(1, context)),
                          Row(
                            children: [
                              // First challenge ingredient
                              if (selectedChallengeIngredients.isNotEmpty)
                                Expanded(
                                  child: _buildIngredientCard(
                                    selectedChallengeIngredients[0],
                                    'Challenge',
                                    isDarkMode,
                                    textTheme,
                                    kAccent,
                                  ),
                                ),
                              if (selectedChallengeIngredients.length > 1) ...[
                                SizedBox(width: getPercentageWidth(4, context)),
                                // Plus icon
                                Container(
                                  padding: EdgeInsets.all(
                                      getPercentageWidth(3, context)),
                                  decoration: BoxDecoration(
                                    color: kAccent.withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.add,
                                    size: getIconScale(8, context),
                                    color: kAccent,
                                  ),
                                ),
                                SizedBox(width: getPercentageWidth(4, context)),
                                // Second challenge ingredient
                                Expanded(
                                  child: _buildIngredientCard(
                                    selectedChallengeIngredients[1],
                                    'Challenge',
                                    isDarkMode,
                                    textTheme,
                                    kAccent,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          SizedBox(height: getPercentageHeight(2, context)),
                          // Challenge AI generation and switch mode buttons
                          Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () async {
                                    if (!canUseAI()) {
                                      showPremiumRequiredDialog(
                                          context, isDarkMode);
                                      return;
                                    }

                                    try {
                                      // Convert to simple format for AI
                                      final simpleIngredients =
                                          selectedChallengeIngredients
                                              .map((ingredient) =>
                                                  ingredient['name'] ?? '')
                                              .toList();

                                      final meal = await gemini.geminiService
                                          .generateMealsFromIngredients(
                                              simpleIngredients, context, true);

                                      // Check if meal generation failed
                                      if (meal['source'] == 'failed' ||
                                          meal['error'] == true) {
                                        showMealGenerationErrorDialog(
                                          context,
                                          meal['message'] ??
                                              'Failed to generate meals. Please try again.',
                                          onRetry: () async {
                                            try {
                                              final retryMeal = await gemini
                                                  .geminiService
                                                  .generateMealsFromIngredients(
                                                      simpleIngredients,
                                                      context,
                                                      true);
                                              if (retryMeal['source'] !=
                                                      'failed' &&
                                                  retryMeal['error'] != true) {
                                                setState(() {
                                                  selectedMeal = retryMeal;
                                                });
                                                _saveMealToStorage();
                                              }
                                            } catch (e) {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                      'Failed to generate meal: $e'),
                                                  backgroundColor: Colors.red,
                                                ),
                                              );
                                            }
                                          },
                                        );
                                        return;
                                      }

                                      setState(() {
                                        selectedMeal = meal;
                                      });
                                      // Save the meal to storage
                                      _saveMealToStorage();
                                    } catch (e) {
                                      // Handle error
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                              'Failed to generate meal: $e'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  },
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                        horizontal:
                                            getPercentageWidth(2, context),
                                        vertical:
                                            getPercentageHeight(1, context)),
                                    decoration: BoxDecoration(
                                      color:
                                          kAccentLight.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      'Use Tasty AI',
                                      textAlign: TextAlign.center,
                                      style: textTheme.bodyMedium?.copyWith(
                                        color: kAccentLight,
                                        fontWeight: FontWeight.w600,
                                        fontSize:
                                            getPercentageWidth(4, context),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(width: getPercentageWidth(2, context)),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _switchToRandomMode,
                                  icon: Icon(Icons.swap_horiz, color: kAccent),
                                  label: Text(
                                    isChallengeMode
                                        ? 'Switch to Fridge'
                                        : 'Switch to Challenge',
                                    style: textTheme.bodyMedium?.copyWith(
                                      color: kAccent,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(color: kAccent),
                                    padding: EdgeInsets.symmetric(
                                      vertical:
                                          getPercentageHeight(1.5, context),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      // Display challenge meal if available
                      if (selectedMeal != null && isChallengeMode) ...[
                        SizedBox(height: getPercentageHeight(2, context)),
                        Container(
                          padding:
                              EdgeInsets.all(getPercentageWidth(4, context)),
                          decoration: BoxDecoration(
                            color: kAccent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: kAccent.withValues(alpha: 0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.auto_awesome, color: kAccent),
                                  SizedBox(
                                      width: getPercentageWidth(2, context)),
                                  Expanded(
                                    child: Text(
                                      'Challenge Recipe',
                                      style: textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: kAccent,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.close, color: kAccent),
                                    onPressed: () {
                                      setState(() {
                                        selectedMeal = null;
                                      });
                                    },
                                  ),
                                ],
                              ),
                              SizedBox(height: getPercentageHeight(1, context)),

                              // Meal title
                              Text(
                                selectedMeal!['title'] ?? 'Untitled Recipe',
                                style: textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: isDarkMode ? kWhite : kBlack,
                                ),
                              ),
                              SizedBox(height: getPercentageHeight(1, context)),

                              // Description
                              if (selectedMeal!['description'] != null) ...[
                                Text(
                                  selectedMeal!['description'],
                                  style: textTheme.bodyMedium?.copyWith(
                                    color: isDarkMode ? kLightGrey : kDarkGrey,
                                  ),
                                ),
                                SizedBox(
                                    height: getPercentageHeight(1, context)),
                              ],

                              // Cooking info
                              Row(
                                children: [
                                  if (selectedMeal!['cookingTime'] != null) ...[
                                    Icon(Icons.timer,
                                        size: getIconScale(4, context),
                                        color: kAccent),
                                    SizedBox(
                                        width: getPercentageWidth(1, context)),
                                    Text(
                                      selectedMeal!['cookingTime'],
                                      style: textTheme.bodySmall?.copyWith(
                                        color: isDarkMode ? kWhite : kBlack,
                                      ),
                                    ),
                                    SizedBox(
                                        width: getPercentageWidth(4, context)),
                                  ],
                                  if (selectedMeal!['cookingMethod'] !=
                                      null) ...[
                                    Icon(Icons.restaurant_menu,
                                        size: getIconScale(4, context),
                                        color: kAccent),
                                    SizedBox(
                                        width: getPercentageWidth(1, context)),
                                    Text(
                                      selectedMeal!['cookingMethod'],
                                      style: textTheme.bodySmall?.copyWith(
                                        color: isDarkMode ? kWhite : kBlack,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              SizedBox(height: getPercentageHeight(2, context)),

                              // Ingredients
                              Text(
                                'Ingredients:',
                                style: textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: kAccent,
                                ),
                              ),
                              SizedBox(
                                  height: getPercentageHeight(0.5, context)),
                              if (selectedMeal!['ingredients'] != null) ...[
                                ...((selectedMeal!['ingredients']
                                        as Map<String, dynamic>)
                                    .entries
                                    .map(
                                      (entry) => Padding(
                                        padding: EdgeInsets.only(
                                            bottom: getPercentageHeight(
                                                0.3, context)),
                                        child: Text(
                                          '• ${entry.key}: ${entry.value}',
                                          style: textTheme.bodySmall?.copyWith(
                                            color: isDarkMode ? kWhite : kBlack,
                                          ),
                                        ),
                                      ),
                                    )),
                              ],
                              SizedBox(height: getPercentageHeight(2, context)),

                              // Instructions
                              Text(
                                'Instructions:',
                                style: textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: kAccent,
                                ),
                              ),
                              SizedBox(
                                  height: getPercentageHeight(0.5, context)),
                              if (selectedMeal!['instructions'] != null) ...[
                                ...((selectedMeal!['instructions']
                                        as List<dynamic>)
                                    .asMap()
                                    .entries
                                    .map(
                                      (entry) => Padding(
                                        padding: EdgeInsets.only(
                                            bottom: getPercentageHeight(
                                                0.5, context)),
                                        child: Text(
                                          '${entry.key + 1}. ${entry.value}',
                                          style: textTheme.bodySmall?.copyWith(
                                            color: isDarkMode ? kWhite : kBlack,
                                          ),
                                        ),
                                      ),
                                    )),
                              ],

                              SizedBox(height: getPercentageHeight(2, context)),

                              // Action button
                              SizedBox(
                                width: double.infinity,
                                child: AppButton(
                                  text: 'Upload Challenge Creation!',
                                  onPressed: () => _navigateToUploadBattle(
                                      isChallenge: true),
                                  type: AppButtonType.primary,
                                  color: kAccent,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ] else ...[
                      // Fridge interface
                      _buildFridgeInterface(isDarkMode, textTheme),
                    ],
                    SizedBox(height: getPercentageHeight(2, context)),
                    // Dine in Challenge section - only show if not in challenge mode AND no challenge ingredients selected
                    if (!isChallengeMode &&
                        isChallengeEnabled &&
                        selectedChallengeIngredients.isEmpty) ...[
                      GestureDetector(
                        onTap: isLoadingChallenge
                            ? null
                            : () {
                                // For testing: if no challenge ingredients loaded, create mock ones
                                if (challengeIngredients.isEmpty) {
                                  setState(() {
                                    challengeIngredients = [
                                      {
                                        'name': 'Carrot',
                                        'type': 'vegetable',
                                        'image': 'assets/images/vegetable.jpg'
                                      },
                                      {
                                        'name': 'Shrimp',
                                        'type': 'protein',
                                        'image': 'assets/images/fish.jpg'
                                      },
                                      {
                                        'name': 'Pork',
                                        'type': 'protein',
                                        'image': 'assets/images/meat.jpg'
                                      },
                                      {
                                        'name': 'Aubergine',
                                        'type': 'vegetable',
                                        'image': 'assets/images/vegetable.jpg'
                                      },
                                    ];
                                  });
                                }
                                if (_isChallengeDateInPast() &&
                                    isChallengeEnabled) {
                                  showTastySnackbar('Dine-In Challenge',
                                      'New challenge coming soon!', context,
                                      backgroundColor: kAccent);
                                } else {
                                  _showChallengeSelectionDialog();
                                }
                              },
                        child: Container(
                          padding:
                              EdgeInsets.all(getPercentageWidth(3, context)),
                          decoration: BoxDecoration(
                            color: kAccentLight.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: kAccent.withValues(alpha: 0.3),
                                blurRadius: 5,
                                offset: Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.lightbulb_outline,
                                color: kAccentLight,
                                size: getIconScale(5, context),
                              ),
                              SizedBox(width: getPercentageWidth(2, context)),
                              Expanded(
                                child: Column(
                                  children: [
                                    Text(
                                      isLoadingChallenge
                                          ? 'Loading challenge...'
                                          : isChallengeMode
                                              ? _isChallengeEnded()
                                                  ? 'Weekly Challenge Ended!'
                                                  : 'Weekly Challenge Active!'
                                              : _isChallengeDateInPast()
                                                  ? 'New Challenge Coming Soon!'
                                                  : 'Join this week\'s Dine-In Challenge!',
                                      textAlign: TextAlign.center,
                                      style: textTheme.bodyLarge?.copyWith(
                                        color: isDarkMode ? kDarkGrey : kWhite,
                                        fontWeight: FontWeight.w600,
                                        fontSize:
                                            getPercentageWidth(4, context),
                                      ),
                                    ),
                                    if (isChallengeMode &&
                                        isChallengeEnabled &&
                                        _isChallengeEnded()) ...[
                                      SizedBox(
                                          height: getPercentageHeight(
                                              0.5, context)),
                                      Text(
                                        _isOldChallenge() && isChallengeEnabled
                                            ? 'Old challenge from: ${savedChallengeDate ?? 'Unknown'}'
                                            : 'Challenge ended: ${challengeDate ?? 'Unknown'}',
                                        textAlign: TextAlign.center,
                                        style: textTheme.bodySmall?.copyWith(
                                          color: kDarkGrey,
                                          fontSize:
                                              getPercentageWidth(3, context),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              if (isLoadingChallenge && isChallengeEnabled)
                                SizedBox(
                                  width: getIconScale(5, context),
                                  height: getIconScale(5, context),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: kAccentLight,
                                  ),
                                )
                              else
                                Icon(
                                  isChallengeMode && isChallengeEnabled
                                      ? (_isChallengeEnded()
                                          ? Icons.schedule
                                          : Icons.check_circle)
                                      : _isChallengeDateInPast()
                                          ? Icons.schedule
                                          : Icons.lightbulb_outline,
                                  color: isChallengeMode && isChallengeEnabled
                                      ? (_isChallengeEnded()
                                          ? Colors.orange
                                          : kAccent)
                                      : _isChallengeDateInPast()
                                          ? Colors.orange
                                          : kAccentLight,
                                  size: getIconScale(5, context),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],

                    // Show "Switch to Weekly Challenge" button when in fridge mode but has challenge ingredients
                    if (!isChallengeMode &&
                        selectedChallengeIngredients.isNotEmpty &&
                        isChallengeEnabled) ...[
                      SizedBox(height: getPercentageHeight(2, context)),
                      GestureDetector(
                        onTap: () => _switchToRandomMode(),
                        child: Container(
                          padding:
                              EdgeInsets.all(getPercentageWidth(3, context)),
                          decoration: BoxDecoration(
                            color: kAccent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: kAccent.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.emoji_events,
                                color: kAccent,
                                size: getIconScale(5, context),
                              ),
                              SizedBox(width: getPercentageWidth(2, context)),
                              Expanded(
                                child: Column(
                                  children: [
                                    Text(
                                      'You have enrolled in this week\'s challenge!',
                                      textAlign: TextAlign.center,
                                      style: textTheme.bodyLarge?.copyWith(
                                        color: isDarkMode ? kWhite : kBlack,
                                        fontWeight: FontWeight.w600,
                                        fontSize:
                                            getPercentageWidth(4, context),
                                      ),
                                    ),
                                    SizedBox(
                                        height:
                                            getPercentageHeight(0.5, context)),
                                    Text(
                                      'Tap to switch to Weekly Challenge mode',
                                      textAlign: TextAlign.center,
                                      style: textTheme.bodySmall?.copyWith(
                                        color:
                                            isDarkMode ? kLightGrey : kDarkGrey,
                                        fontSize:
                                            getPercentageWidth(3, context),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.arrow_forward_ios,
                                color: kAccent,
                                size: getIconScale(4, context),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],

                    SizedBox(height: getPercentageHeight(2.5, context)),

                    // Action buttons
                    if (isChallengeMode &&
                        isChallengeEnabled &&
                        selectedChallengeIngredients.length >= 2) ...[
                      // Challenge mode - show upload button directly
                      if (selectedMeal == null) ...[
                        SizedBox(
                          width: double.infinity,
                          child: AppButton(
                            text: 'Upload Challenge Creation',
                            onPressed: () =>
                                _navigateToUploadBattle(isChallenge: true),
                            type: AppButtonType.primary,
                            color: kAccent,
                          ),
                        ),
                      ],
                    ] else if (!isChallengeMode && isChallengeEnabled) ...[
                      // Fridge mode - show upload button if recipes are generated
                      if (_showFridgeRecipes && _fridgeRecipes.isNotEmpty) ...[
                        SizedBox(
                          width: double.infinity,
                          child: AppButton(
                            text: 'Upload Your Creation',
                            onPressed: () => _navigateToUploadBattle(),
                            type: AppButtonType.primary,
                            color: kAccent,
                          ),
                        ),
                      ],
                    ] else
                      ...[],

                    // Display selected meal if available
                    if (selectedMeal != null &&
                        !isChallengeMode &&
                        isChallengeEnabled) ...[
                      SizedBox(height: getPercentageHeight(2, context)),
                      Container(
                        padding: EdgeInsets.all(getPercentageWidth(4, context)),
                        decoration: BoxDecoration(
                          color: kAccent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border:
                              Border.all(color: kAccent.withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.auto_awesome, color: kAccent),
                                SizedBox(width: getPercentageWidth(2, context)),
                                Expanded(
                                  child: Text(
                                    'AI Generated Recipe',
                                    style: textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: kAccent,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(Icons.close, color: kAccent),
                                  onPressed: () {
                                    setState(() {
                                      selectedMeal = null;
                                    });
                                    // Note: Keep meal in storage so it can be restored
                                  },
                                ),
                              ],
                            ),
                            SizedBox(height: getPercentageHeight(1, context)),

                            // Meal title
                            Text(
                              selectedMeal!['title'] ?? 'Untitled Recipe',
                              style: textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: isDarkMode ? kWhite : kBlack,
                              ),
                            ),
                            SizedBox(height: getPercentageHeight(1, context)),

                            // Description
                            if (selectedMeal!['description'] != null) ...[
                              Text(
                                selectedMeal!['description'],
                                style: textTheme.bodyMedium?.copyWith(
                                  color: isDarkMode ? kLightGrey : kDarkGrey,
                                ),
                              ),
                              SizedBox(height: getPercentageHeight(1, context)),
                            ],

                            // Cooking info
                            Row(
                              children: [
                                if (selectedMeal!['cookingTime'] != null) ...[
                                  Icon(Icons.timer,
                                      size: getIconScale(4, context),
                                      color: kAccent),
                                  SizedBox(
                                      width: getPercentageWidth(1, context)),
                                  Text(
                                    selectedMeal!['cookingTime'],
                                    style: textTheme.bodySmall?.copyWith(
                                      color: isDarkMode ? kWhite : kBlack,
                                    ),
                                  ),
                                  SizedBox(
                                      width: getPercentageWidth(4, context)),
                                ],
                                if (selectedMeal!['cookingMethod'] != null) ...[
                                  Icon(Icons.restaurant_menu,
                                      size: getIconScale(4, context),
                                      color: kAccent),
                                  SizedBox(
                                      width: getPercentageWidth(1, context)),
                                  Text(
                                    selectedMeal!['cookingMethod'],
                                    style: textTheme.bodySmall?.copyWith(
                                      color: isDarkMode ? kWhite : kBlack,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            SizedBox(height: getPercentageHeight(2, context)),

                            // Ingredients
                            Text(
                              'Ingredients:',
                              style: textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: kAccent,
                              ),
                            ),
                            SizedBox(height: getPercentageHeight(0.5, context)),
                            if (selectedMeal!['ingredients'] != null) ...[
                              ...((selectedMeal!['ingredients']
                                      as Map<String, dynamic>)
                                  .entries
                                  .map(
                                    (entry) => Padding(
                                      padding: EdgeInsets.only(
                                          bottom: getPercentageHeight(
                                              0.3, context)),
                                      child: Text(
                                        '• ${entry.key}: ${entry.value}',
                                        style: textTheme.bodySmall?.copyWith(
                                          color: isDarkMode ? kWhite : kBlack,
                                        ),
                                      ),
                                    ),
                                  )),
                            ],
                            SizedBox(height: getPercentageHeight(2, context)),

                            // Instructions
                            if (selectedMeal!['instructions'] != null)
                              Text(
                                'Instructions:',
                                style: textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: kAccent,
                                ),
                              ),
                            SizedBox(height: getPercentageHeight(0.5, context)),
                            if (selectedMeal!['instructions'] != null) ...[
                              ...((selectedMeal!['instructions']
                                      as List<dynamic>)
                                  .asMap()
                                  .entries
                                  .map(
                                    (entry) => Padding(
                                      padding: EdgeInsets.only(
                                          bottom: getPercentageHeight(
                                              0.5, context)),
                                      child: Text(
                                        '${entry.key + 1}. ${entry.value}',
                                        style: textTheme.bodySmall?.copyWith(
                                          color: isDarkMode ? kWhite : kBlack,
                                        ),
                                      ),
                                    ),
                                  )),
                            ],

                            SizedBox(height: getPercentageHeight(2, context)),

                            // Action button
                            SizedBox(
                              width: double.infinity,
                              child: AppButton(
                                text: 'Upload Creation!',
                                onPressed: () => _navigateToUploadBattle(),
                                type: AppButtonType.primary,
                                color: kAccent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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
