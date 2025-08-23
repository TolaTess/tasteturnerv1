import 'dart:convert';
import 'dart:math';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';
import '../data_models/macro_data.dart';
import '../helper/helper_files.dart';
import '../helper/helper_functions.dart';
import '../helper/utils.dart';
import '../pages/upload_battle.dart';
import '../screens/recipes_list_category_screen.dart';
import '../service/macro_manager.dart';
import '../widgets/ingredient_battle_widget.dart';
import '../widgets/optimized_image.dart';
import '../widgets/primary_button.dart';
import '../widgets/info_icon_widget.dart';

class DineInScreen extends StatefulWidget {
  const DineInScreen({super.key});

  @override
  State<DineInScreen> createState() => _DineInScreenState();
}

class _DineInScreenState extends State<DineInScreen> {
  final MacroManager _macroManager = Get.find<MacroManager>();

  MacroData? selectedCarb;
  MacroData? selectedProtein;
  bool isLoading = false;
  bool isAccepted = false;
  Map<String, dynamic>? selectedMeal;
  final Random _random = Random();

  // Challenge related variables
  List<MacroData> challengeIngredients = [];
  List<MacroData> selectedChallengeIngredients = [];
  bool isChallengeMode = false;
  bool isLoadingChallenge = false;
  String? challengeDate;
  String? savedChallengeDate; // Store the user's saved challenge date

  @override
  void initState() {
    super.initState();
    _loadSavedMeal();
    _loadChallengeData();
    _generateIngredientPair();
    _checkChallengeNotification();
  }

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
      print('Error saving meal to storage: $e');
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
      print('Error loading meal from storage: $e');
    }
  }

  // Clear saved meal data
  Future<void> _clearSavedMeal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_selectedMealKey);
      await prefs.remove(_selectedCarbKey);
      await prefs.remove(_selectedProteinKey);
      await prefs.remove(_mealTimestampKey);
    } catch (e) {
      print('Error clearing saved meal: $e');
    }
  }

  // Load challenge data from Firebase and local storage
  Future<void> _loadChallengeData() async {
    setState(() {
      isLoadingChallenge = true;
    });

    try {
      // Fetch general data from Firebase
      await firebaseService.fetchGeneralData();

      // Get challenge details from general data
      final challengeDetails = firebaseService.generalData['challenge_details'];

      if (challengeDetails != null && challengeDetails is String) {
        // Parse challenge details: "07-08-2025,carrot,shrimp,pork,aubergine"
        final parts = challengeDetails.split(',');
        if (parts.length >= 5) {
          challengeDate = parts[0];

          // Get ingredient names (skip the date)
          final ingredientNames = parts.skip(1).toList();

          // Fetch all ingredients to find the challenge ingredients
          if (_macroManager.ingredient.isEmpty) {
            await _macroManager.fetchIngredients();
          }

          // Find ingredients by name (case-insensitive)
          challengeIngredients = [];
          for (String name in ingredientNames) {
            final found = _macroManager.ingredient
                .where((ingredient) =>
                    ingredient.title.toLowerCase() == name.toLowerCase())
                .toList();
            if (found.isNotEmpty) {
              challengeIngredients.add(found.first);
            } else {
              // Try partial matching as fallback
              final partialMatches = _macroManager.ingredient
                  .where((ingredient) =>
                      ingredient.title
                          .toLowerCase()
                          .contains(name.toLowerCase()) ||
                      name
                          .toLowerCase()
                          .contains(ingredient.title.toLowerCase()))
                  .toList();
              if (partialMatches.isNotEmpty) {
                challengeIngredients.add(partialMatches.first);
              }
            }
          }

          // If no ingredients found, create mock ingredients for testing
          if (challengeIngredients.isEmpty) {
            challengeIngredients = [
              MacroData(
                id: 'mock_carrot',
                title: 'Carrot',
                type: 'vegetable',
                mediaPaths: [],
                calories: 41,
                macros: {'protein': '0.9', 'carbs': '9.6', 'fat': '0.2'},
                categories: ['vegetable'],
                features: {},
                image: 'assets/images/vegetable.jpg',
              ),
              MacroData(
                id: 'mock_shrimp',
                title: 'Shrimp',
                type: 'protein',
                mediaPaths: [],
                calories: 85,
                macros: {'protein': '20.1', 'carbs': '0.2', 'fat': '0.5'},
                categories: ['protein'],
                features: {},
                image: 'assets/images/fish.jpg',
              ),
              MacroData(
                id: 'mock_pork',
                title: 'Pork',
                type: 'protein',
                mediaPaths: [],
                calories: 242,
                macros: {'protein': '27.3', 'carbs': '0.0', 'fat': '14.0'},
                categories: ['protein'],
                features: {},
                image: 'assets/images/meat.jpg',
              ),
              MacroData(
                id: 'mock_aubergine',
                title: 'Aubergine',
                type: 'vegetable',
                mediaPaths: [],
                calories: 25,
                macros: {'protein': '1.0', 'carbs': '6.0', 'fat': '0.2'},
                categories: ['vegetable'],
                features: {},
                image: 'assets/images/vegetable.jpg',
              ),
            ];
          }

          // Load saved challenge data
          await _loadSavedChallengeData();

          // Check for challenge notification after loading data
          await _checkChallengeNotification();
        }
      }
    } catch (e) {
      print('Error loading challenge data: $e');
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

      // Check if saved challenge is for the same week
      if (savedChallengeDateFromStorage == challengeDate &&
          isChallengeModeSaved) {
        final savedIngredients = prefs.getString(_challengeIngredientsKey);
        if (savedIngredients != null) {
          final ingredientIds = jsonDecode(savedIngredients) as List<dynamic>;

          selectedChallengeIngredients = [];
          for (String id in ingredientIds) {
            final found = challengeIngredients
                .where((ingredient) => ingredient.id == id)
                .toList();
            if (found.isNotEmpty) {
              selectedChallengeIngredients.add(found.first);
            }
          }

          setState(() {
            isChallengeMode = true;
          });
        }
      }
    } catch (e) {
      print('Error loading saved challenge data: $e');
    }
  }

  // Save challenge data to local storage
  Future<void> _saveChallengeData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      if (selectedChallengeIngredients.isNotEmpty) {
        final ingredientIds = selectedChallengeIngredients
            .map((ingredient) => ingredient.id)
            .toList();
        await prefs.setString(
            _challengeIngredientsKey, jsonEncode(ingredientIds));
        await prefs.setString(_challengeDateKey, challengeDate ?? '');
        await prefs.setBool(_isChallengeModeKey, true);
      }
    } catch (e) {
      print('Error saving challenge data: $e');
    }
  }

  // Clear challenge data from local storage
  Future<void> _clearChallengeData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_challengeIngredientsKey);
      await prefs.remove(_challengeDateKey);
      await prefs.remove(_isChallengeModeKey);
    } catch (e) {
      print('Error clearing challenge data: $e');
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
      print('Error parsing challenge date: $e');
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
      print('Error parsing challenge date: $e');
    }

    return false;
  }

  // Check if challenge notification should be sent
  Future<void> _checkChallengeNotification() async {
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
          print('Error parsing challenge date: $e');
        }
      }
    } catch (e) {
      print('Error checking challenge notification: $e');
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
      print('Challenge notification sent successfully');
    } catch (e) {
      print('Error sending challenge notification: $e');
    }
  }

  // Get notification status
  Future<bool> _getNotificationStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_challengeNotificationEnabledKey) ?? true;
    } catch (e) {
      print('Error getting notification status: $e');
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
      print('Error toggling challenge notifications: $e');
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
                                        child: ingredient.mediaPaths.isNotEmpty
                                            ? ingredient.mediaPaths.first
                                                    .contains('https')
                                                ? OptimizedImage(
                                                    imageUrl: ingredient
                                                        .mediaPaths.first,
                                                    fit: BoxFit.cover,
                                                    width: double.infinity,
                                                    height: double.infinity,
                                                  )
                                                : Image.asset(
                                                    getAssetImageForItem(
                                                        ingredient
                                                            .mediaPaths.first),
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (context,
                                                            error,
                                                            stackTrace) =>
                                                        Icon(Icons.food_bank,
                                                            size: getIconScale(
                                                                8, context)),
                                                  )
                                            : ingredient.image.isNotEmpty
                                                ? Image.asset(
                                                    getAssetImageForItem(
                                                        ingredient.image),
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (context,
                                                            error,
                                                            stackTrace) =>
                                                        Icon(Icons.food_bank,
                                                            size: getIconScale(
                                                                8, context)),
                                                  )
                                                : Icon(
                                                    Icons.food_bank,
                                                    size: getIconScale(
                                                        8, context),
                                                    color: kAccent,
                                                  ),
                                      ),
                                    ),
                                    SizedBox(
                                        height:
                                            getPercentageHeight(1, context)),
                                    Text(
                                      ingredient.title,
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
                                        child: ingredient.mediaPaths.isNotEmpty
                                            ? ingredient.mediaPaths.first
                                                    .contains('https')
                                                ? OptimizedImage(
                                                    imageUrl: ingredient
                                                        .mediaPaths.first,
                                                    fit: BoxFit.cover,
                                                    width: double.infinity,
                                                    height: double.infinity,
                                                  )
                                                : Image.asset(
                                                    getAssetImageForItem(
                                                        ingredient
                                                            .mediaPaths.first),
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (context,
                                                            error,
                                                            stackTrace) =>
                                                        Icon(Icons.food_bank,
                                                            size: getIconScale(
                                                                8, context)),
                                                  )
                                            : ingredient.image.isNotEmpty
                                                ? Image.asset(
                                                    getAssetImageForItem(
                                                        ingredient.image),
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (context,
                                                            error,
                                                            stackTrace) =>
                                                        Icon(Icons.food_bank,
                                                            size: getIconScale(
                                                                8, context)),
                                                  )
                                                : Icon(
                                                    Icons.food_bank,
                                                    size: getIconScale(
                                                        8, context),
                                                    color: kAccent,
                                                  ),
                                      ),
                                    ),
                                    SizedBox(
                                        height:
                                            getPercentageHeight(1, context)),
                                    Text(
                                      ingredient.title,
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

  // Switch to random ingredient mode
  void _switchToRandomMode() async {
    final shouldSwitch = await showDialog<bool>(
      context: context,
      builder: (context) {
        final isDarkMode = getThemeProvider(context).isDarkMode;
        final textTheme = Theme.of(context).textTheme;
        return AlertDialog(
          backgroundColor: isDarkMode ? kDarkGrey : kWhite,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: Text(
            'Switch to Random Mode?',
            style: textTheme.titleLarge?.copyWith(color: kAccent),
          ),
          content: Text(
            'This will clear your current challenge. Continue?',
            style: textTheme.bodyMedium?.copyWith(
              color: isDarkMode ? kWhite : kBlack,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                'Keep Challenge',
                style: textTheme.bodyMedium?.copyWith(color: kAccent),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                'Switch Mode',
                style: textTheme.bodyMedium?.copyWith(color: kAccent),
              ),
            ),
          ],
        );
      },
    );

    if (shouldSwitch == true) {
      await _clearChallengeData();
      setState(() {
        isChallengeMode = false;
        selectedChallengeIngredients.clear();
      });
    }
  }

  Future<void> _generateIngredientPair({bool forceRefresh = false}) async {
    // Only generate new ingredients if none exist or if forced refresh
    if (!forceRefresh && selectedCarb != null && selectedProtein != null) {
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      // Ensure ingredients are fetched
      if (_macroManager.ingredient.isEmpty) {
        await _macroManager.fetchIngredients();
      }

      final ingredients = _macroManager.ingredient;

      // Get carbs (grains, vegetables, carbs) and shuffle properly
      final allCarbs = ingredients
          .where((ingredient) =>
              (ingredient.type.toLowerCase() == 'grain' ||
                  ingredient.type.toLowerCase() == 'vegetable' ||
                  ingredient.type.toLowerCase() == 'carb') &&
              !excludedIngredients.contains(ingredient.title.toLowerCase()))
          .toList();
      allCarbs.shuffle(_random);
      final carbs = allCarbs.take(10).toList();

      // Get proteins and shuffle properly
      final allProteins = ingredients
          .where((ingredient) =>
              ingredient.type.toLowerCase() == 'protein' &&
              !excludedIngredients.contains(ingredient.title.toLowerCase()))
          .toList();
      allProteins.shuffle(_random);
      final proteins = allProteins.take(10).toList();

      // Randomly select one of each
      if (carbs.isNotEmpty && proteins.isNotEmpty) {
        selectedCarb = carbs[_random.nextInt(carbs.length)];
        selectedProtein = proteins[_random.nextInt(proteins.length)];

        // Clear meal when ingredients change
        if (forceRefresh) {
          selectedMeal = null;
          isAccepted = false;
        }
      }
    } catch (e) {
      print('Error generating ingredient pair: $e');
    }

    setState(() {
      isLoading = false;
    });

    // Save the new ingredients to storage
    _saveMealToStorage();
  }

  // Method to refresh ingredients
  Future<void> _refreshIngredients() async {
    await _generateIngredientPair(forceRefresh: true);
  }

  void _refreshPair() async {
    // If there's a saved meal, show confirmation dialog
    if (selectedMeal != null) {
      final shouldClear = await _showClearMealDialog();
      if (!shouldClear) return;
    }

    // Clear from storage when user explicitly generates new ingredients
    _clearSavedMeal();
    // Use the new refresh method which forces new ingredient generation
    await _refreshIngredients();
  }

  // Show dialog to confirm clearing existing meal
  Future<bool> _showClearMealDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        final isDarkMode = getThemeProvider(context).isDarkMode;
        final textTheme = Theme.of(context).textTheme;
        return AlertDialog(
          backgroundColor: isDarkMode ? kDarkGrey : kWhite,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: Text(
            'Generate New Pair?',
            style: textTheme.titleLarge?.copyWith(color: kAccent),
          ),
          content: Text(
            'You have a saved recipe. Generating new ingredients will clear your current recipe. Continue?',
            style: textTheme.bodyMedium?.copyWith(
              color: isDarkMode ? kWhite : kBlack,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                'Keep Current',
                style: textTheme.bodyMedium?.copyWith(color: kAccent),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                'Generate New',
                style: textTheme.bodyMedium?.copyWith(color: kAccent),
              ),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  void _acceptPair() {
    setState(() {
      isAccepted = true;
    });
  }

  void _showDetails(bool isDarkMode, TextTheme textTheme) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor:
            getThemeProvider(context).isDarkMode ? kDarkGrey : kWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Text(
          'Ingredient Details',
          style: textTheme.titleLarge?.copyWith(
            color: kAccent,
          ),
        ),
        content: Text(
          '• Use only the listed ingredients plus:\n'
          '  - Onions\n'
          '  - Herbs\n'
          '  - Spices\n\n'
          '• Create a visually stunning dish\n'
          '• Take a high-quality photo\n\n'
          '🏆 Remember: Presentation is key! \n\n Enjoy your meal!',
          style: textTheme.bodyMedium?.copyWith(
            color: isDarkMode ? kWhite : kBlack,
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Close',
                style: textTheme.bodyMedium?.copyWith(
                  color: kAccentLight,
                ),
              )),
        ],
      ),
    );
  }

  void _navigateToUploadBattle({bool isChallenge = false}) {
    if (isChallenge && selectedChallengeIngredients.length == 2) {
      // Create battle ID from challenge ingredient names + random number
      final battleId =
          '${selectedChallengeIngredients[0].title.toLowerCase().replaceAll(' ', '_')}_'
          '${selectedChallengeIngredients[1].title.toLowerCase().replaceAll(' ', '_')}_'
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

  @override
  Widget build(BuildContext context) {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
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
              description: 'Get inspired to cook with simple ingredients',
              details: [
                {
                  'icon': Icons.casino,
                  'title': 'Random Ingredients',
                  'description': 'Get two random ingredients to cook with',
                  'color': kBlue,
                },
                {
                  'icon': Icons.emoji_events,
                  'title': 'Weekly Challenge',
                  'description': 'Join challenges to win points and rewards',
                  'color': kBlue,
                },
                {
                  'icon': Icons.restaurant,
                  'title': 'Simple Cooking',
                  'description':
                      'Create delicious meals with just 2 ingredients',
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
          : SingleChildScrollView(
              padding: EdgeInsets.all(getPercentageWidth(4, context)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: getPercentageHeight(2, context)),
                  // Header text
                  Center(
                    child: Text(
                      isChallengeMode
                          ? 'Weekly Challenge Ingredients'
                          : 'Your Random Ingredient Pair',
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
                          : 'Create something amazing with these two ingredients!',
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

                  // Ingredient cards
                  if (isChallengeMode &&
                      selectedChallengeIngredients.isNotEmpty) ...[
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
                            Expanded(
                              child: _buildIngredientCard(
                                selectedChallengeIngredients[0],
                                'Challenge',
                                isDarkMode,
                                textTheme,
                                kAccent,
                              ),
                            ),
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
                                    final meal = await geminiService
                                        .generateMealsFromIngredients(
                                            selectedChallengeIngredients,
                                            context,
                                            true);
                                    if (meal != null) {
                                      setState(() {
                                        selectedMeal = meal;
                                      });
                                      // Save the meal to storage
                                      _saveMealToStorage();
                                    }
                                  } catch (e) {
                                    // Handle error
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content:
                                            Text('Failed to generate meal: $e'),
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
                                    color: kAccentLight.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    'Use Tasty AI',
                                    textAlign: TextAlign.center,
                                    style: textTheme.bodyMedium?.copyWith(
                                      color: kAccentLight,
                                      fontWeight: FontWeight.w600,
                                      fontSize: getPercentageWidth(4, context),
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
                                  'Switch Mode',
                                  style: textTheme.bodyMedium?.copyWith(
                                    color: kAccent,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: kAccent),
                                  padding: EdgeInsets.symmetric(
                                    vertical: getPercentageHeight(1.5, context),
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
                                text: 'Upload Challenge Creation!',
                                onPressed: () =>
                                    _navigateToUploadBattle(isChallenge: true),
                                type: AppButtonType.primary,
                                color: kAccent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ] else if (selectedCarb != null &&
                      selectedProtein != null) ...[
                    Row(
                      children: [
                        // Carb card
                        Expanded(
                          child: _buildIngredientCard(
                            selectedCarb!,
                            'Grain',
                            isDarkMode,
                            textTheme,
                            getMealTypeColor('grain'),
                          ),
                        ),
                        SizedBox(width: getPercentageWidth(4, context)),
                        // Plus icon
                        Container(
                          padding:
                              EdgeInsets.all(getPercentageWidth(3, context)),
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
                        // Protein card
                        Expanded(
                          child: _buildIngredientCard(
                            selectedProtein!,
                            'Protein',
                            isDarkMode,
                            textTheme,
                            getMealTypeColor('protein'),
                          ),
                        ),
                      ],
                    ),
                  ],
                  SizedBox(height: getPercentageHeight(2, context)),
                  // Dine in Challenge section
                  GestureDetector(
                    onTap: isLoadingChallenge
                        ? null
                        : () {
                            // For testing: if no challenge ingredients loaded, create mock ones
                            if (challengeIngredients.isEmpty) {
                              setState(() {
                                challengeIngredients = [
                                  MacroData(
                                    id: 'mock_carrot',
                                    title: 'Carrot',
                                    type: 'vegetable',
                                    mediaPaths: [],
                                    calories: 41,
                                    macros: {
                                      'protein': '0.9',
                                      'carbs': '9.6',
                                      'fat': '0.2'
                                    },
                                    categories: ['vegetable'],
                                    features: {},
                                    image: 'assets/images/vegetable.jpg',
                                  ),
                                  MacroData(
                                    id: 'mock_shrimp',
                                    title: 'Shrimp',
                                    type: 'protein',
                                    mediaPaths: [],
                                    calories: 85,
                                    macros: {
                                      'protein': '20.1',
                                      'carbs': '0.2',
                                      'fat': '0.5'
                                    },
                                    categories: ['protein'],
                                    features: {},
                                    image: 'assets/images/fish.jpg',
                                  ),
                                  MacroData(
                                    id: 'mock_pork',
                                    title: 'Pork',
                                    type: 'protein',
                                    mediaPaths: [],
                                    calories: 242,
                                    macros: {
                                      'protein': '27.3',
                                      'carbs': '0.0',
                                      'fat': '14.0'
                                    },
                                    categories: ['protein'],
                                    features: {},
                                    image: 'assets/images/meat.jpg',
                                  ),
                                  MacroData(
                                    id: 'mock_aubergine',
                                    title: 'Aubergine',
                                    type: 'vegetable',
                                    mediaPaths: [],
                                    calories: 25,
                                    macros: {
                                      'protein': '1.0',
                                      'carbs': '6.0',
                                      'fat': '0.2'
                                    },
                                    categories: ['vegetable'],
                                    features: {},
                                    image: 'assets/images/vegetable.jpg',
                                  ),
                                ];
                              });
                            }
                            if (_isChallengeDateInPast()) {
                              showTastySnackbar(
                                  'Dine-In Challenge',
                                  'New challenge coming soon!',
                                  context,
                                  backgroundColor: kAccent);
                            } else {
                              _showChallengeSelectionDialog();
                            }
                          },
                    child: Container(
                      padding: EdgeInsets.all(getPercentageWidth(3, context)),
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
                                    fontSize: getPercentageWidth(4, context),
                                  ),
                                ),
                                if (isChallengeMode && _isChallengeEnded()) ...[
                                  SizedBox(
                                      height:
                                          getPercentageHeight(0.5, context)),
                                  Text(
                                    _isOldChallenge()
                                        ? 'Old challenge from: ${savedChallengeDate ?? 'Unknown'}'
                                        : 'Challenge ended: ${challengeDate ?? 'Unknown'}',
                                    textAlign: TextAlign.center,
                                    style: textTheme.bodySmall?.copyWith(
                                      color: kDarkGrey,
                                      fontSize: getPercentageWidth(3, context),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (isLoadingChallenge)
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
                              isChallengeMode
                                  ? (_isChallengeEnded()
                                      ? Icons.schedule
                                      : Icons.check_circle)
                                  : _isChallengeDateInPast()
                                      ? Icons.schedule
                                      : Icons.lightbulb_outline,
                              color: isChallengeMode
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

                  SizedBox(height: getPercentageHeight(2.5, context)),

                  // Action buttons
                  if (isChallengeMode &&
                      selectedChallengeIngredients.isNotEmpty) ...[
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
                  ] else if (!isAccepted) ...[
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _refreshPair,
                            icon: Icon(Icons.refresh, color: kAccent),
                            label: Text(
                              'Refresh Pair',
                              style: textTheme.bodyMedium?.copyWith(
                                color: kAccent,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: kAccent),
                              padding: EdgeInsets.symmetric(
                                vertical: getPercentageHeight(1.5, context),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: getPercentageWidth(4, context)),
                        Expanded(
                          child: AppButton(
                            text: 'Accept Pair',
                            onPressed: _acceptPair,
                            type: AppButtonType.primary,
                            width: 100,
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    // Creation submission section
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
                              Icon(Icons.check_circle, color: kAccent),
                              SizedBox(width: getPercentageWidth(2, context)),
                              Text(
                                'Perfect! Ready to create?',
                                style: textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: kAccent,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: getPercentageHeight(2, context)),
                          Text(
                            'Time to show your culinary creativity! Upload your creation using these ingredients and share it with the community.',
                            style: textTheme.bodyMedium?.copyWith(
                              color: isDarkMode ? kWhite : kBlack,
                              fontSize: getPercentageWidth(3.5, context),
                            ),
                          ),
                          SizedBox(height: getPercentageHeight(2, context)),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    setState(() {
                                      isAccepted = false;
                                    });
                                  },
                                  icon: Icon(Icons.arrow_back, color: kAccent),
                                  label: Text(
                                    'Go Back',
                                    style: textTheme.bodyMedium?.copyWith(
                                      color: kAccent,
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(color: kAccent),
                                  ),
                                ),
                              ),
                              SizedBox(width: getPercentageWidth(4, context)),
                              Expanded(
                                child: AppButton(
                                  text: 'See Details',
                                  onPressed: () =>
                                      _showDetails(isDarkMode, textTheme),
                                  type: AppButtonType.follow,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: getPercentageHeight(2, context)),
                    Center(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kPink,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          Get.to(() => RecipeListCategory(
                                index: 1,
                                searchIngredient:
                                    selectedProtein!.title.toLowerCase(),
                                screen: 'categories',
                                isNoTechnique: true,
                              ));
                        },
                        icon: const Icon(Icons.restaurant, color: kWhite),
                        label: Text('See Recipes for ${selectedProtein!.title}',
                            style:
                                textTheme.labelLarge?.copyWith(color: kWhite)),
                      ),
                    ),

                    if (selectedMeal == null && !isChallengeMode) ...[
                      SizedBox(height: getPercentageHeight(2, context)),
                      Row(
                        children: [
                          SizedBox(width: getPercentageWidth(2, context)),
                          Expanded(
                            flex: 1,
                            child: GestureDetector(
                              onTap: () async {
                                if (!canUseAI()) {
                                  showPremiumRequiredDialog(
                                      context, isDarkMode);
                                  return;
                                }

                                try {
                                  final meal = await geminiService
                                      .generateMealsFromIngredients(
                                          [selectedCarb!, selectedProtein!],
                                          context,
                                          true);
                                  if (meal != null) {
                                    setState(() {
                                      selectedMeal = meal;
                                    });
                                    // Save the meal to storage
                                    _saveMealToStorage();
                                  }
                                } catch (e) {
                                  // Handle error
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content:
                                          Text('Failed to generate meal: $e'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              },
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: getPercentageWidth(2, context),
                                    vertical: getPercentageHeight(1, context)),
                                decoration: BoxDecoration(
                                  color: kAccentLight.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'Use Tasty AI',
                                  textAlign: TextAlign.center,
                                  style: textTheme.bodyMedium?.copyWith(
                                    color: kAccentLight,
                                    fontWeight: FontWeight.w600,
                                    fontSize: getPercentageWidth(4, context),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: getPercentageWidth(4, context)),
                          Expanded(
                            flex: 3,
                            child: AppButton(
                              text: 'Upload Creation',
                              onPressed: () => _navigateToUploadBattle(),
                              type: AppButtonType.primary,
                              width: 100,
                              color: kAccent,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],

                  // Display selected meal if available
                  if (selectedMeal != null && !isChallengeMode) ...[
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
                                SizedBox(width: getPercentageWidth(1, context)),
                                Text(
                                  selectedMeal!['cookingTime'],
                                  style: textTheme.bodySmall?.copyWith(
                                    color: isDarkMode ? kWhite : kBlack,
                                  ),
                                ),
                                SizedBox(width: getPercentageWidth(4, context)),
                              ],
                              if (selectedMeal!['cookingMethod'] != null) ...[
                                Icon(Icons.restaurant_menu,
                                    size: getIconScale(4, context),
                                    color: kAccent),
                                SizedBox(width: getPercentageWidth(1, context)),
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
                                        bottom:
                                            getPercentageHeight(0.3, context)),
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
                          SizedBox(height: getPercentageHeight(0.5, context)),
                          if (selectedMeal!['instructions'] != null) ...[
                            ...((selectedMeal!['instructions'] as List<dynamic>)
                                .asMap()
                                .entries
                                .map(
                                  (entry) => Padding(
                                    padding: EdgeInsets.only(
                                        bottom:
                                            getPercentageHeight(0.5, context)),
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
    );
  }

  Widget _buildIngredientCard(
    MacroData ingredient,
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
              child: ingredient.mediaPaths.isNotEmpty
                  ? ingredient.mediaPaths.first.contains('https')
                      ? OptimizedImage(
                          imageUrl: ingredient.mediaPaths.first,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                        )
                      : Image.asset(
                          getAssetImageForItem(ingredient.mediaPaths.first),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Icon(
                              Icons.food_bank,
                              size: getIconScale(10, context)),
                        )
                  : ingredient.image.isNotEmpty
                      ? Image.asset(
                          getAssetImageForItem(ingredient.image),
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
            capitalizeFirstLetter(ingredient.title),
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: getPercentageWidth(3.5, context),
              color: isDarkMode ? kWhite : kBlack,
            ),
          ),
          SizedBox(height: getPercentageHeight(0.5, context)),

          // Calories
          Text(
            '${ingredient.calories} cal',
            style: textTheme.bodySmall?.copyWith(
              color: isDarkMode ? kAccent : kLightGrey,
              fontSize: getPercentageWidth(3, context),
            ),
          ),
        ],
      ),
    );
  }
}
