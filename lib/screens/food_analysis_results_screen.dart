import 'dart:io';
import 'package:flutter/material.dart';

import '../constants.dart';
import '../helper/helper_functions.dart';
import '../helper/notifications_helper.dart';
import '../helper/utils.dart';
import '../helper/ingredient_utils.dart';
import '../widgets/primary_button.dart';
import '../data_models/post_model.dart';
import '../service/calorie_adjustment_service.dart';
import 'package:get/get.dart';

// QC State enum for Service Quality Check
enum QCState {
  onSpec, // Within ±10% of target
  underPrep, // >10% under target
  heavyPour, // >10% over target
  macroMiss, // Calories on point but macro ratios wrong
}

class FoodAnalysisResultsScreen extends StatefulWidget {
  final File imageFile;
  final Map<String, dynamic> analysisResult;
  final String? postId;
  final String? selectedCategory;
  final bool? isAnalyzeAndUpload;
  final DateTime? date;
  final String? mealType;
  final String? screen;
  final bool? skipAnalysisSave;
  final bool? isFeedPage;

  const FoodAnalysisResultsScreen({
    super.key,
    required this.imageFile,
    required this.analysisResult,
    this.postId = '',
    this.selectedCategory,
    this.isAnalyzeAndUpload,
    this.date,
    this.mealType,
    this.screen,
    this.skipAnalysisSave,
    this.isFeedPage,
  });

  @override
  State<FoodAnalysisResultsScreen> createState() =>
      _FoodAnalysisResultsScreenState();
}

class _FoodAnalysisResultsScreenState extends State<FoodAnalysisResultsScreen> {
  late Map<String, dynamic> _editableAnalysis;
  bool _isSaving = false;
  bool _hasCreatedMeal = false;
  late String mealType;

  // Constants for health score thresholds
  static const int _highHealthScoreThreshold = 8;
  static const int _mediumHealthScoreThreshold = 6;

  @override
  void initState() {
    super.initState();
    mealType = widget.mealType ?? getMealTimeOfDay();
    _editableAnalysis = Map<String, dynamic>.from(widget.analysisResult);

    // Apply ingredient deduplication and validation on initial load
    _normalizeAnalysisData();

    // Recalculate totals on initial load to ensure consistency
    _recalculateTotalNutrition();
  }

  /// Handle errors with consistent snackbar display
  void _handleError(String message, {String? details}) {
    if (!mounted || !context.mounted) return;
    debugPrint('Error: $message${details != null ? ' - $details' : ''}');
    showTastySnackbar(
      'Error',
      message,
      context,
      backgroundColor: Colors.red,
    );
  }

  /// Show success message with consistent styling
  void _showSuccessMessage(String message) {
    if (!mounted || !context.mounted) return;
    showTastySnackbar(
      'Success',
      message,
      context,
      backgroundColor: kAccent,
    );
  }

  /// Calculate health score from confidence level
  int _calculateHealthScoreFromConfidence(String confidence) {
    switch (confidence.toLowerCase()) {
      case 'high':
        return _highHealthScoreThreshold; // High confidence = good health score
      case 'medium':
        return _mediumHealthScoreThreshold; // Medium confidence = moderate health score
      case 'low':
        return 4; // Low confidence = lower health score
      default:
        return _mediumHealthScoreThreshold; // Default to medium
    }
  }

  /// Normalize and validate analysis data to prevent duplicates and handle errors
  void _normalizeAnalysisData() {
    try {
      // Normalize ingredients if they exist using shared helpers
      if (_editableAnalysis.containsKey('ingredients') &&
          _editableAnalysis['ingredients'] is Map) {
        _editableAnalysis['ingredients'] = _normalizeAndDeduplicateIngredients(
          Map<String, dynamic>.from(_editableAnalysis['ingredients'] as Map),
        );
      }

      // Ensure required fields exist with fallback values
      _editableAnalysis['foodItems'] = _editableAnalysis['foodItems'] ?? [];
      // Ensure totalNutrition is properly typed
      if (_editableAnalysis['totalNutrition'] is Map) {
        _editableAnalysis['totalNutrition'] = Map<String, dynamic>.from(
          _editableAnalysis['totalNutrition'] as Map,
        );
      } else {
        _editableAnalysis['totalNutrition'] = {
          'calories': 0,
          'protein': 0,
          'carbs': 0,
          'fat': 0,
          'fiber': 0,
          'sugar': 0,
          'sodium': 0,
        };
      }
      // Calculate health score from confidence if healthScore doesn't exist
      if (!_editableAnalysis.containsKey('healthScore') ||
          _editableAnalysis['healthScore'] == null) {
        final confidence =
            _editableAnalysis['confidence'] as String? ?? 'medium';
        _editableAnalysis['healthScore'] =
            _calculateHealthScoreFromConfidence(confidence);
      }
      _editableAnalysis['estimatedPortionSize'] =
          _editableAnalysis['estimatedPortionSize'] ?? 'medium';
      _editableAnalysis['confidence'] =
          _editableAnalysis['confidence'] ?? 'medium';
      _editableAnalysis['source'] = _editableAnalysis['source'] ?? false;

      // Validate and fix food items
      final foodItems = _editableAnalysis['foodItems'] as List<dynamic>;
      for (int i = 0; i < foodItems.length; i++) {
        final item = Map<String, dynamic>.from(foodItems[i] as Map);

        // Ensure required fields exist
        item['name'] = item['name'] ?? 'Unknown Food ${i + 1}';
        item['estimatedWeight'] = item['estimatedWeight'] ?? '100g';
        item['confidence'] = item['confidence'] ?? 'medium';

        // Ensure nutritional info exists
        item['nutritionalInfo'] = item['nutritionalInfo'] ??
            {
              'calories': 100,
              'protein': 5,
              'carbs': 10,
              'fat': 4,
              'fiber': 1,
              'sugar': 2,
              'sodium': 100,
            };

        // Validate nutritional values are numbers
        final nutritionData = item['nutritionalInfo'];
        if (nutritionData is Map) {
          final nutrition = Map<String, dynamic>.from(nutritionData);
          nutrition.forEach((key, value) {
            if (value == null ||
                (value is String && double.tryParse(value) == null)) {
              nutrition[key] = 0;
            }
          });
          item['nutritionalInfo'] = nutrition;
        }
      }
    } catch (e) {
      debugPrint('Error normalizing analysis data: $e');
      // Set minimal fallback data if normalization fails
      _editableAnalysis = {
        'foodItems': [
          {
            'name': 'Unknown Food',
            'estimatedWeight': '0',
            'confidence': 'low',
            'nutritionalInfo': {
              'calories': 0,
              'protein': 0,
              'carbs': 0,
              'fat': 0,
              'fiber': 0,
              'sugar': 0,
              'sodium': 0,
            },
          },
        ],
        'totalNutrition': {
          'calories': 0,
          'protein': 0,
          'carbs': 0,
          'fat': 0,
          'fiber': 0,
          'sugar': 0,
          'sodium': 0,
        },
        'healthScore': 0,
        'estimatedPortionSize': '0',
        'ingredients': {'unknown ingredient': '0'},
        'confidence': 'low',
        'source': true,
        'notes':
            'Analysis data was malformed and has been reset to safe defaults.',
      };
    }
  }

  /// Normalize and deduplicate ingredients using shared helpers from ingredient_utils.dart
  /// This method uses normalizeIngredientName and combineIngredients from the shared utility
  Map<String, String> _normalizeAndDeduplicateIngredients(
    Map<String, dynamic> ingredients,
  ) {
    final Map<String, String> normalizedIngredients = {};
    final Map<String, List<MapEntry<String, String>>> groupedIngredients = {};

    // Convert all ingredients to Map<String, String> and normalize keys
    final stringIngredients = <String, String>{};
    ingredients.forEach((key, value) {
      stringIngredients[key] = value.toString();
    });

    // Group ingredients by normalized name using shared helper
    stringIngredients.forEach((originalName, amount) {
      final normalizedName = normalizeIngredientName(originalName);

      if (!groupedIngredients.containsKey(normalizedName)) {
        groupedIngredients[normalizedName] = [];
      }
      groupedIngredients[normalizedName]!.add(MapEntry(originalName, amount));
    });

    // Process grouped ingredients using shared combineIngredients helper
    groupedIngredients.forEach((normalizedName, ingredientList) {
      if (ingredientList.length == 1) {
        // Single ingredient, use as-is
        final ingredient = ingredientList.first;
        normalizedIngredients[ingredient.key] = ingredient.value;
      } else {
        // Multiple ingredients with same normalized name - combine them using shared helper
        final combinedResult = combineIngredients(ingredientList);
        normalizedIngredients[combinedResult.key] = combinedResult.value;
      }
    });

    return normalizedIngredients;
  }

  Future<void> _createMealOnly() async {
    if (_hasCreatedMeal) return; // Don't create meal twice

    try {
      // Skip if coming from buddy chat (already saved)
      if (widget.skipAnalysisSave == true) {
        setState(() {
          _hasCreatedMeal = true;
        });
        return;
      }

      // Save analysis to tastyanalysis collection only (no image upload needed)
      // Meals are now created by cloud functions, not here
      await geminiService.saveAnalysisToFirestore(
        analysisResult: _editableAnalysis,
        userId: userService.userId ?? '',
        imagePath:
            'cloud_function_generated', // Placeholder since cloud function handles image
      );

      if (mounted) {
        setState(() {
          _hasCreatedMeal = true;
        });
      }
    } catch (e) {
      debugPrint('Failed to save analysis: $e');
      // Don't show error dialog on back navigation, just fail silently
      // But log the error for debugging
      if (mounted && context.mounted) {
        // Only show error if it's a critical failure
        _handleError('Failed to save analysis. Please try again.',
            details: e.toString());
      }
    }
  }

  /// Save for challenge detail screen - saves to meals and tastyanalysis but NOT daily meals
  Future<void> _saveForChallengeDetail() async {
    if (_hasCreatedMeal) return; // Don't save twice

    setState(() {
      _isSaving = true;
    });

    try {
      // Get suggested meal IDs from the analysis result
      final mealIds = _editableAnalysis['mealIds'] as List<dynamic>? ?? [];

      String actualMealId = '';

      // Check if meal already exists
      if (mealIds.isNotEmpty) {
        // Meal already exists, use existing ID
        actualMealId = mealIds.first.toString();
        debugPrint('Using existing meal ID: $actualMealId');
      } else {
        // Create a new meal in the meals collection if no meal IDs exist
        try {
          actualMealId = await geminiService.createMealFromAnalysis(
            analysisResult: _editableAnalysis,
            userId: userService.userId ?? '',
            imagePath: 'cloud_function_generated',
            mealType: mealType,
          );
          debugPrint('Created new meal ID: $actualMealId');
        } catch (e) {
          debugPrint('Failed to create meal in meals collection: $e');
          // Continue to save analysis even if meal creation fails
        }
      }

      // Save analysis to tastyanalysis collection
      try {
        await geminiService.saveAnalysisToFirestore(
          analysisResult: _editableAnalysis,
          userId: userService.userId ?? '',
          imagePath: 'cloud_function_generated',
        );
        debugPrint('Saved analysis to tastyanalysis collection');
      } catch (e) {
        debugPrint('Failed to save analysis to tastyanalysis: $e');
        // Log error but continue
      }

      // Update existing post with meal ID if we have one
      if (widget.postId != null &&
          widget.postId!.isNotEmpty &&
          actualMealId.isNotEmpty) {
        try {
          await postController.updatePost(
            postId: widget.postId!,
            updateData: {'mealId': actualMealId},
          );
          debugPrint('Updated post with mealId: $actualMealId');
        } catch (e) {
          debugPrint('Failed to update post with mealId: $e');
          // Log error but don't show to user
        }
      }

      if (mounted) {
        setState(() {
          _hasCreatedMeal = true;
          _isSaving = false;
        });
        // Navigate back
        Navigator.of(context).pop();
      }
    } catch (e) {
      debugPrint('Failed to save for challenge detail: $e');
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        if (context.mounted) {
          _handleError('Failed to save. Please try again.',
              details: e.toString());
        }
      }
    }
  }

  Future<void> _saveAnalysis() async {
    setState(() {
      _isSaving = true;
    });

    try {
      // Show immediate success message
      if (mounted && context.mounted) {
        _showSuccessMessage('Plate added to your menu, Chef!');
      }

      // Navigate back immediately
      if (mounted && context.mounted) {
        Navigator.of(context).pop(true);
      }

      // Save to daily meals and create meal in background (non-blocking)
      _saveToDailyMealsInBackground();
    } catch (e) {
      debugPrint('Failed to save analysis: $e');
      if (mounted && context.mounted) {
        _handleError('Couldn\'t save to menu, Chef. Please try again.',
            details: e.toString());
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  /// Save to daily meals and create meal in background without blocking UI
  Future<void> _saveToDailyMealsInBackground() async {
    try {
      // Get suggested meal IDs from the analysis result
      final mealIds = _editableAnalysis['mealIds'] as List<dynamic>? ?? [];

      String actualMealId = '';

      if (mealIds.isNotEmpty) {
        // Use the first meal ID as the primary meal ID
        actualMealId = mealIds.first.toString();
      } else {
        // Create a new meal in the meals collection if no meal IDs exist
        try {
          actualMealId = await geminiService.createMealFromAnalysis(
            analysisResult: _editableAnalysis,
            userId: userService.userId ?? '',
            imagePath: 'cloud_function_generated',
            mealType: mealType,
          );
        } catch (e) {
          debugPrint('Failed to create meal in meals collection: $e');
          // Fallback to temporary ID
          actualMealId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
          // Log error for monitoring but don't show to user (background operation)
        }
      }

      // Skip daily meals addition for challenge detail screen
      if (widget.skipAnalysisSave != true) {
        try {
          await geminiService.addAnalyzedMealToDaily(
            mealId: actualMealId,
            userId: userService.userId ?? '',
            mealType: mealType,
            analysisResult: _editableAnalysis,
            date: widget.date ?? DateTime.now(),
          );

          // Check for Heavy Pour QC state and apply adjustment to next meal
          await _applyQCAdjustmentIfNeeded();
        } catch (e) {
          debugPrint('Failed to add meal to daily meals: $e');
          // Log error but don't show to user (background operation)
        }
      }

      // Update existing post with meal ID if we have one and it's from challenge detail
      if (widget.postId != null &&
          widget.postId!.isNotEmpty &&
          actualMealId.isNotEmpty) {
        try {
          await postController.updatePost(
            postId: widget.postId!,
            updateData: {'mealId': actualMealId},
          );
        } catch (e) {
          debugPrint('Failed to update post with mealId: $e');
          // Log error but don't show to user (background operation)
        }
      }

      // Handle post creation for analyze & upload flow in background
      if (widget.isAnalyzeAndUpload == true) {
        await _handlePostCreationInBackground(actualMealId: actualMealId);
      }
    } catch (e) {
      debugPrint('Background save to daily meals failed: $e');
      // Log error for monitoring but don't show to user since UI already showed success
      // This is a background operation and failures are non-critical
    }
  }

  /// Handle post creation in background for analyze & upload flow
  Future<void> _handlePostCreationInBackground(
      {required String actualMealId}) async {
    try {
      final bool isExistingPostAnalysis =
          widget.postId != null && widget.postId!.isNotEmpty;

      if (isExistingPostAnalysis) return; // Skip for existing posts

      // Ensure we have a valid meal ID (not a temp or post_ prefixed ID)
      String validMealId = actualMealId;
      if (validMealId.isEmpty ||
          validMealId.startsWith('temp_') ||
          validMealId.startsWith('post_')) {
        debugPrint('Invalid meal ID for post creation: $validMealId');
        // Try to get meal ID from analysis result as fallback
        final mealIds = _editableAnalysis['mealIds'] as List<dynamic>? ?? [];
        if (mealIds.isNotEmpty) {
          final mealIdFromAnalysis = mealIds.first.toString();
          if (mealIdFromAnalysis.isNotEmpty &&
              !mealIdFromAnalysis.startsWith('temp_') &&
              !mealIdFromAnalysis.startsWith('post_')) {
            validMealId = mealIdFromAnalysis;
          } else {
            debugPrint('No valid meal ID available for post creation');
            return; // Don't create post without valid meal ID
          }
        } else {
          debugPrint('No meal ID available for post creation');
          return; // Don't create post without valid meal ID
        }
      }

      // Upload image to Firebase Storage
      try {
        String imagePath =
            'tastyanalysis/${userService.userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final uploadTask =
            await firebaseStorage.ref(imagePath).putFile(widget.imageFile);
        final String postImageUrl = await uploadTask.ref.getDownloadURL();

        // Generate a temporary post ID
        final String tempPostId =
            'post_${DateTime.now().millisecondsSinceEpoch}';

        // Create the post with the actual meal ID (passed from _saveToDailyMealsInBackground)
        final post = Post(
          id: tempPostId,
          mealId: validMealId, // Use the validated meal ID that was created
          userId: userService.userId ?? '',
          mediaPaths: [postImageUrl],
          name: userService.currentUser.value?.displayName ?? '',
          category: widget.selectedCategory ?? 'general',
          isVideo: false,
        );

        // Upload the post
        await postController.uploadPost(post, userService.userId ?? '', [
          postImageUrl,
        ]);

        debugPrint('Post created successfully with mealId: $validMealId');
      } catch (e) {
        debugPrint('Background post creation failed: $e');
        // Log error but don't show to user (background operation)
        // This is non-critical as the meal was already saved
      }
    } catch (e) {
      debugPrint('Background post creation error: $e');
      // Log error but don't show to user since UI already showed success
    }
  }

  Future<bool> _onWillPop() async {
    // For challenge detail screen, save to meals/tastyanalysis but not daily meals
    if (widget.screen == 'challenge_detail') {
      if (!_hasCreatedMeal && !_isSaving) {
        await _saveForChallengeDetail();
      }
      return true; // Allow navigation back
    }

    // Create meal only when user goes back without saving
    if (!_hasCreatedMeal && !_isSaving) {
      await _createMealOnly();
    }

    // If coming from feed page, navigate to explore page instead of going back
    if (widget.isFeedPage == true) {
      Navigator.of(context).pushReplacementNamed('/explore');
      return false; // Prevent default back navigation
    }

    return true; // Allow navigation back
  }

  void _editFoodItem(int index) {
    final foodItems = _editableAnalysis['foodItems'] as List<dynamic>;
    final foodItem = Map<String, dynamic>.from(foodItems[index] as Map);

    showDialog(
      context: context,
      builder: (context) => _FoodItemEditDialog(
        foodItem: foodItem,
        onSave: (updatedItem) {
          setState(() {
            foodItems[index] = updatedItem;
            _recalculateTotalNutrition();
          });
        },
      ),
    );
  }

  void _recalculateTotalNutrition() {
    final foodItems = _editableAnalysis['foodItems'] as List<dynamic>;
    final totalNutrition = <String, dynamic>{
      'calories': 0.0,
      'protein': 0.0,
      'carbs': 0.0,
      'fat': 0.0,
      'fiber': 0.0,
      'sugar': 0.0,
      'sodium': 0.0,
    };

    for (final item in foodItems) {
      final nutrition = Map<String, dynamic>.from(
        item['nutritionalInfo'] as Map,
      );

      // Handle both int and double values safely
      final itemCalories = _parseNumeric(nutrition['calories']);
      final itemProtein = _parseNumeric(nutrition['protein']);
      final itemCarbs = _parseNumeric(nutrition['carbs']);
      final itemFat = _parseNumeric(nutrition['fat']);

      // Calculate calories from macros for this item
      final calculatedCalories =
          (itemProtein * 4) + (itemCarbs * 4) + (itemFat * 9);

      // Use macro-based calories if they don't equal the provided calories
      final finalCalories = calculatedCalories != itemCalories
          ? calculatedCalories
          : itemCalories;

      totalNutrition['calories'] =
          (totalNutrition['calories'] as double) + finalCalories;
      totalNutrition['protein'] =
          (totalNutrition['protein'] as double) + itemProtein;
      totalNutrition['carbs'] = (totalNutrition['carbs'] as double) + itemCarbs;
      totalNutrition['fat'] = (totalNutrition['fat'] as double) + itemFat;
      totalNutrition['fiber'] = (totalNutrition['fiber'] as double) +
          _parseNumeric(nutrition['fiber']);
      totalNutrition['sugar'] = (totalNutrition['sugar'] as double) +
          _parseNumeric(nutrition['sugar']);
      totalNutrition['sodium'] = (totalNutrition['sodium'] as double) +
          _parseNumeric(nutrition['sodium']);
    }

    // Convert back to integers for consistency with UI display
    totalNutrition.forEach((key, value) {
      totalNutrition[key] = (value as double).round();
    });

    _editableAnalysis['totalNutrition'] = totalNutrition;
  }

  /// Safely parse numeric values that could be int, double, or string
  double _parseNumeric(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  // Build Turner's Notes section
  Widget _buildTurnersNotes(
    BuildContext context,
    bool isDarkMode,
    Map<String, dynamic> totalNutrition,
    int? healthScore,
    String confidence,
  ) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _buildTurnersNotesAsync(
        totalNutrition,
        healthScore,
        confidence,
      ),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final notes = snapshot.data!['notes'] as List<String>;
        final qcState = snapshot.data!['qcState'] as QCState?;
        final mealType = snapshot.data!['mealType'] as String? ?? '';

        if (notes.isEmpty) return const SizedBox.shrink();

        // Return styled container similar to ingredient details
        return Container(
          margin:
              EdgeInsets.symmetric(horizontal: getPercentageWidth(2, context)),
          padding: EdgeInsets.all(getPercentageWidth(3, context)),
          decoration: BoxDecoration(
            color: kAccent.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: kAccent.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Turner\'s Notes',
                    style: TextStyle(
                      fontSize: getTextScale(4.5, context),
                      fontWeight: FontWeight.w700,
                      color: kAccent,
                    ),
                  ),
                  if (qcState != null)
                    _buildQCBadge(context, isDarkMode, qcState, mealType),
                ],
              ),
              SizedBox(height: getPercentageHeight(1, context)),
              ...notes.map((note) => Padding(
                    padding: EdgeInsets.only(
                        bottom: getPercentageHeight(0.5, context)),
                    child: RichText(
                      text: TextSpan(
                        style: TextStyle(
                          fontSize: getTextScale(3.5, context),
                          fontStyle: FontStyle.italic,
                          color: isDarkMode ? kWhite : kBlack,
                          height: 1.5,
                        ),
                        children: _parseTurnerNote(note),
                      ),
                    ),
                  )),
            ],
          ),
        );
      },
    );
  }

  // Async method to build Turner's Notes
  Future<Map<String, dynamic>> _buildTurnersNotesAsync(
    Map<String, dynamic> totalNutrition,
    int? healthScore,
    String confidence,
  ) async {
    List<String> notes = [];
    QCState? qcState;

    // Health Score / Quality notes
    if (healthScore != null) {
      if (healthScore >= _highHealthScoreThreshold) {
        notes.add('Excellent **Plate Quality** - well balanced macros, Chef.');
      } else if (healthScore >= _mediumHealthScoreThreshold) {
        notes.add(
            'Good **Plate Quality** - solid foundation with room for refinement.');
      } else {
        notes.add(
            '**Plate Quality** needs work - check suggestions for improvements.');
      }
    } else {
      // Confidence-based notes
      switch (confidence.toLowerCase()) {
        case 'high':
          notes.add('High **Tasting Confidence** - reliable analysis, Chef.');
          break;
        case 'medium':
          notes.add(
              'Moderate **Tasting Confidence** - review and adjust as needed.');
          break;
        case 'low':
          notes.add(
              'Low **Tasting Confidence** - consider retaking photo for better accuracy.');
          break;
      }
    }

    // Macro balance notes
    final calories = (totalNutrition['calories'] ?? 0) as int;
    final protein = (totalNutrition['protein'] ?? 0) as int;
    final carbs = (totalNutrition['carbs'] ?? 0) as int;
    final fat = (totalNutrition['fat'] ?? 0) as int;

    // High protein note
    if (protein > 30 && calories > 0) {
      final proteinPercent = (protein * 4 / calories * 100).round();
      if (proteinPercent > 30) {
        notes.add(
            'High **Protein** content (${proteinPercent}%) - great for muscle maintenance.');
      }
    }

    // Low carb note
    if (carbs < 20 && calories > 0) {
      notes.add('**Low Carb** profile - suitable for low-carb protocols.');
    }

    // Balanced macros note
    if (calories > 0) {
      final proteinPercent = (protein * 4 / calories * 100).round();
      final carbPercent = (carbs * 4 / calories * 100).round();
      final fatPercent = (fat * 9 / calories * 100).round();

      if (proteinPercent >= 25 &&
          proteinPercent <= 35 &&
          carbPercent >= 30 &&
          carbPercent <= 45 &&
          fatPercent >= 20 &&
          fatPercent <= 35) {
        notes.add('Well **Balanced Macros** - excellent macro distribution.');
      }
    }

    // Portion size note (if available)
    final portionSize =
        _editableAnalysis['estimatedPortionSize']?.toString() ?? '';
    if (portionSize.isNotEmpty && portionSize != 'medium') {
      notes.add(
          '**${capitalizeFirstLetter(portionSize)}** portion size detected.');
    }

    // Replace daily macro notes with QC notes
    final mealType = widget.mealType ?? getMealTimeOfDay();

    // Calculate QC state for badge display
    final mealTargets = _calculateMealTargets(mealType);
    final analyzed = {
      'calories': (totalNutrition['calories'] ?? 0) as int,
      'protein': (totalNutrition['protein'] ?? 0) as int,
      'carbs': (totalNutrition['carbs'] ?? 0) as int,
      'fat': (totalNutrition['fat'] ?? 0) as int,
    };
    qcState = _determineQCState(analyzed, mealTargets);

    await _addQCNotes(notes, totalNutrition, mealType);

    // Add Chef's Eye observations
    _addChefsEyeNotes(notes, _editableAnalysis);

    return {
      'notes': notes,
      'qcState': qcState,
      'mealType': mealType,
    };
  }

  // Build QC Badge (Digital Pass Ticket)
  Widget _buildQCBadge(
    BuildContext context,
    bool isDarkMode,
    QCState state,
    String mealType,
  ) {
    Color badgeColor;
    String badgeText;
    IconData badgeIcon;

    switch (state) {
      case QCState.onSpec:
        badgeColor = Colors.green;
        badgeText = 'Service Approved';
        badgeIcon = Icons.check_circle;
        break;
      case QCState.heavyPour:
        badgeColor = Colors.orange;
        badgeText = 'Adjustment Required';
        badgeIcon = Icons.warning;
        break;
      case QCState.underPrep:
        badgeColor = Colors.yellow;
        badgeText = 'Fuel Warning';
        badgeIcon = Icons.info;
        break;
      case QCState.macroMiss:
        badgeColor = Colors.blue;
        badgeText = 'Composition Check';
        badgeIcon = Icons.tune;
        break;
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: getPercentageWidth(2.5, context),
        vertical: getPercentageHeight(0.6, context),
      ),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: badgeColor, width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(badgeIcon, color: badgeColor, size: getIconScale(4, context)),
          SizedBox(width: getPercentageWidth(1, context)),
          Text(
            badgeText,
            style: TextStyle(
              color: badgeColor,
              fontWeight: FontWeight.bold,
              fontSize: getTextScale(3, context),
            ),
          ),
        ],
      ),
    );
  }

  // Parse Turner's note to highlight key terms
  List<TextSpan> _parseTurnerNote(String note) {
    final parts = note.split('**');
    List<TextSpan> spans = [];

    for (int i = 0; i < parts.length; i++) {
      if (i % 2 == 0) {
        // Regular text
        spans.add(TextSpan(text: parts[i]));
      } else {
        // Bold text (highlighted terms)
        spans.add(TextSpan(
          text: parts[i],
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: kAccent,
          ),
        ));
      }
    }

    return spans;
  }

  // Calculate meal slot targets
  Map<String, int> _calculateMealTargets(String mealType) {
    // Get user settings
    final user = userService.currentUser.value;
    final settings = user?.settings ?? {};
    final fitnessGoal = settings['fitnessGoal']?.toString().toLowerCase() ?? '';

    // Base calorie goal
    final baseCalories = _parseMacroGoal(settings['foodGoal'] ?? 2000);

    // Adjust for fitness goal
    double adjustedCalories = baseCalories.toDouble();
    switch (fitnessGoal) {
      case 'lose weight':
      case 'weight loss':
        adjustedCalories = baseCalories * 0.8;
        break;
      case 'gain muscle':
      case 'muscle gain':
      case 'build muscle':
        adjustedCalories = baseCalories * 1.0;
        break;
      default:
        adjustedCalories = baseCalories.toDouble();
    }

    // Meal percentage distribution
    double mealPercentage = 0.0;
    switch (mealType.toLowerCase()) {
      case 'breakfast':
        mealPercentage = 0.25; // 25%
        break;
      case 'lunch':
        mealPercentage = 0.375; // 37.5%
        break;
      case 'dinner':
        mealPercentage = 0.375; // 37.5%
        break;
      default:
        mealPercentage = 0.25;
    }

    final mealCalorieTarget = (adjustedCalories * mealPercentage).round();

    // Calculate macro targets based on meal calories
    final dailyProteinGoal = _parseMacroGoal(settings['proteinGoal'] ?? 150);
    final dailyCarbsGoal = _parseMacroGoal(settings['carbsGoal'] ?? 200);
    final dailyFatGoal = _parseMacroGoal(settings['fatGoal'] ?? 65);

    // Distribute macros proportionally to meal percentage
    final mealProteinTarget = (dailyProteinGoal * mealPercentage).round();
    final mealCarbsTarget = (dailyCarbsGoal * mealPercentage).round();
    final mealFatTarget = (dailyFatGoal * mealPercentage).round();

    return {
      'calories': mealCalorieTarget,
      'protein': mealProteinTarget,
      'carbs': mealCarbsTarget,
      'fat': mealFatTarget,
    };
  }

  // Determine QC state by comparing analyzed food against meal targets
  QCState _determineQCState(
    Map<String, int> analyzed,
    Map<String, int> targets,
  ) {
    if (targets['calories'] == null || targets['calories']! == 0) {
      return QCState.onSpec; // Default if no target
    }

    final calorieDelta = analyzed['calories']! - targets['calories']!;
    final caloriePercent = (calorieDelta / targets['calories']!) * 100;

    // Check if calories are within ±10%
    final caloriesOnSpec = caloriePercent.abs() <= 10;

    // Check macro ratios
    if (analyzed['calories']! > 0 && targets['calories']! > 0) {
      final proteinPercent =
          (analyzed['protein']! * 4 / analyzed['calories']!) * 100;
      final targetProteinPercent =
          (targets['protein']! * 4 / targets['calories']!) * 100;
      final proteinRatioOff =
          (proteinPercent - targetProteinPercent).abs() > 10;

      final carbsPercent =
          (analyzed['carbs']! * 4 / analyzed['calories']!) * 100;
      final targetCarbsPercent =
          (targets['carbs']! * 4 / targets['calories']!) * 100;
      final carbsRatioOff = (carbsPercent - targetCarbsPercent).abs() > 10;

      // Macro Miss: Calories correct but ratios wrong
      if (caloriesOnSpec && (proteinRatioOff || carbsRatioOff)) {
        return QCState.macroMiss;
      }
    }

    // Heavy Pour: Over target
    if (caloriePercent > 10) {
      return QCState.heavyPour;
    }

    // Under Prep: Under target
    if (caloriePercent < -10) {
      return QCState.underPrep;
    }

    // On Spec: Within range
    return QCState.onSpec;
  }

  // Add QC notes based on meal slot comparison
  Future<void> _addQCNotes(
    List<String> notes,
    Map<String, dynamic> totalNutrition,
    String mealType,
  ) async {
    try {
      // Calculate meal targets
      final mealTargets = _calculateMealTargets(mealType);

      // Get analyzed macros
      final analyzed = {
        'calories': (totalNutrition['calories'] ?? 0) as int,
        'protein': (totalNutrition['protein'] ?? 0) as int,
        'carbs': (totalNutrition['carbs'] ?? 0) as int,
        'fat': (totalNutrition['fat'] ?? 0) as int,
      };

      // Determine QC state
      final qcState = _determineQCState(analyzed, mealTargets);

      // Generate Turner's Notes based on QC state
      switch (qcState) {
        case QCState.onSpec:
          notes.add(
              '**Service Approved.** Plating looks tight, Chef. You hit the macro specs for ${capitalizeFirstLetter(mealType)} perfectly. The kitchen is running smooth—keep this pace for the next service.');
          break;

        case QCState.heavyPour:
          final overBy = analyzed['calories']! - mealTargets['calories']!;
          notes.add(
              '**Adjustment Required.** This is a hearty plate, Chef, about ${overBy}kcal over the ${capitalizeFirstLetter(mealType)} spec. It looks delicious, so enjoy it. I\'ve automatically lightened the prep list for the next meal to balance the inventory.');
          break;

        case QCState.underPrep:
          final underBy = mealTargets['calories']! - analyzed['calories']!;
          final proteinUnder = mealTargets['protein']! - analyzed['protein']!;
          if (proteinUnder > 5) {
            notes.add(
                '**Fuel Warning.** Light service today? You\'re under the protein spec for this meal. You might crash during the shift. I recommend firing a protein snack (boiled egg or shake) around 3 PM.');
          } else {
            notes.add(
                '**Fuel Warning.** You\'re about ${underBy}kcal under the ${capitalizeFirstLetter(mealType)} spec, Chef. Consider adding a side to keep energy steady.');
          }
          break;

        case QCState.macroMiss:
          if (analyzed['calories']! > 0 && mealTargets['calories']! > 0) {
            final proteinPercent =
                (analyzed['protein']! * 4 / analyzed['calories']!) * 100;
            final targetProteinPercent =
                (mealTargets['protein']! * 4 / mealTargets['calories']!) * 100;
            final carbsPercent =
                (analyzed['carbs']! * 4 / analyzed['calories']!) * 100;
            final targetCarbsPercent =
                (mealTargets['carbs']! * 4 / mealTargets['calories']!) * 100;

            if (proteinPercent < targetProteinPercent - 10) {
              notes.add(
                  '**Composition Check.** Calories are on point, but the protein ratio is low. To keep the engine running, let\'s prioritize lean meat or fish for the next meal. I\'ve updated the next meal suggestion.');
            } else if (carbsPercent > targetCarbsPercent + 10) {
              notes.add(
                  '**Composition Check.** Calories match the spec, but carbs are high relative to protein. Consider balancing with more protein in the next meal, Chef.');
            } else {
              notes.add(
                  '**Composition Check.** Calories match the spec, but the macro balance needs adjustment. Check the next meal for better macro distribution, Chef.');
            }
          }
          break;
      }

      // Add specific macro deltas for context
      final proteinDelta = analyzed['protein']! - mealTargets['protein']!;
      final carbsDelta = analyzed['carbs']! - mealTargets['carbs']!;
      final fatDelta = analyzed['fat']! - mealTargets['fat']!;

      if (proteinDelta.abs() > 5) {
        if (proteinDelta > 0) {
          notes.add(
              'Protein is **${proteinDelta}g over** the ${capitalizeFirstLetter(mealType)} target.');
        } else {
          notes.add(
              'Protein is **${proteinDelta.abs()}g under** the ${capitalizeFirstLetter(mealType)} target.');
        }
      }

      if (carbsDelta.abs() > 10) {
        if (carbsDelta > 0) {
          notes.add(
              'Carbs are **${carbsDelta}g over** the ${capitalizeFirstLetter(mealType)} target.');
        } else {
          notes.add(
              'Carbs are **${carbsDelta.abs()}g under** the ${capitalizeFirstLetter(mealType)} target.');
        }
      }

      if (fatDelta.abs() > 5) {
        if (fatDelta > 0) {
          notes.add(
              'Fat is **${fatDelta}g over** the ${capitalizeFirstLetter(mealType)} target.');
        } else {
          notes.add(
              'Fat is **${fatDelta.abs()}g under** the ${capitalizeFirstLetter(mealType)} target.');
        }
      }
    } catch (e) {
      debugPrint('Error in QC check: $e');
      // Silently fail - don't show error to user
    }
  }

  // Add Chef's Eye observations
  void _addChefsEyeNotes(
    List<String> notes,
    Map<String, dynamic> analysis,
  ) {
    try {
      // Rainbow Check (Micronutrients)
      final ingredients =
          analysis['ingredients'] as Map<String, dynamic>? ?? {};
      final rainbowValues = <String>{};

      ingredients.forEach((key, value) {
        final color = value.toString().toLowerCase().trim();
        if ([
          'red',
          'orange',
          'yellow',
          'green',
          'blue',
          'purple',
          'white',
          'brown',
          'beige'
        ].contains(color)) {
          rainbowValues.add(color);
        }
      });

      final isMonochrome = rainbowValues.length <= 1 &&
          (rainbowValues.contains('brown') || rainbowValues.contains('beige'));

      if (isMonochrome && rainbowValues.isNotEmpty) {
        notes.add(
            'The macros are good, but the presentation is a bit monochrome. We need more color on the station for vitamins. Try adding a side of greens or fruit to the next service, Chef.');
      }

      // Satiety Prediction (Fiber/Volume)
      final foodItems = analysis['foodItems'] as List<dynamic>? ?? [];
      double totalFiber = 0;
      int totalCalories = 0;

      for (var item in foodItems) {
        final nutrition =
            item['nutritionalInfo'] as Map<String, dynamic>? ?? {};
        totalFiber += (nutrition['fiber'] ?? 0).toDouble();
        totalCalories += (nutrition['calories'] ?? 0) as int;
      }

      final fiberPerCalorie =
          totalCalories > 0 ? (totalFiber / totalCalories * 100) : 0;

      if (fiberPerCalorie < 2 && totalCalories > 400) {
        notes.add(
            'This is high-density fuel, Chef. Since fiber is low here, you might feel hungry before the next service. Drink extra water to help with satiety.');
      }

      // Flavor/Texture Compliment
      final itemNames = foodItems
          .map((item) => (item['name'] ?? '').toString().toLowerCase())
          .toList();

      final highQualityIngredients = [
        'avocado',
        'salmon',
        'quinoa',
        'kale',
        'blueberries'
      ];
      String? foundQuality;

      for (var quality in highQualityIngredients) {
        if (itemNames.any((name) => name.contains(quality))) {
          foundQuality = quality;
          break;
        }
      }

      if (foundQuality != null) {
        if (foundQuality == 'avocado') {
          notes.add(
              'Great use of healthy fats with that avocado, Chef. That\'s going to provide excellent slow-burn energy for the afternoon.');
        } else if (foundQuality == 'salmon') {
          notes.add(
              'Excellent protein choice with that salmon, Chef. High-quality omega-3s for sustained energy.');
        } else if (foundQuality == 'quinoa') {
          notes.add(
              'Smart choice with quinoa, Chef. Complete protein and high fiber for steady energy.');
        } else if (foundQuality == 'kale') {
          notes.add(
              'Great addition of kale, Chef. Packed with micronutrients and fiber for optimal nutrition.');
        } else if (foundQuality == 'blueberries') {
          notes.add(
              'Excellent antioxidant boost with those blueberries, Chef. Great for recovery and energy.');
        }
      }
    } catch (e) {
      debugPrint('Error in Chef\'s Eye notes: $e');
      // Silently fail
    }
  }

  // Parse macro goal value (handles both int and string)
  int _parseMacroGoal(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) {
      // Remove 'g' or other units and parse
      final cleaned = value.replaceAll(RegExp(r'[^0-9]'), '');
      return int.tryParse(cleaned) ?? 0;
    }
    if (value is num) return value.toInt();
    return 0;
  }

  // Apply QC adjustment if Heavy Pour state detected
  Future<void> _applyQCAdjustmentIfNeeded() async {
    try {
      // Get total nutrition from the analysis
      final totalNutrition = Map<String, dynamic>.from(
        _editableAnalysis['totalNutrition'] as Map,
      );

      // Calculate meal targets
      final mealTargets = _calculateMealTargets(mealType);

      // Get analyzed macros
      final analyzed = {
        'calories': (totalNutrition['calories'] ?? 0) as int,
        'protein': (totalNutrition['protein'] ?? 0) as int,
        'carbs': (totalNutrition['carbs'] ?? 0) as int,
        'fat': (totalNutrition['fat'] ?? 0) as int,
      };

      // Determine QC state
      final qcState = _determineQCState(analyzed, mealTargets);

      // Only apply adjustment for Heavy Pour state
      if (qcState == QCState.heavyPour) {
        final overage = analyzed['calories']! - mealTargets['calories']!;

        if (overage > 0) {
          // Determine next meal type to adjust (use lowercase to match service)
          String nextMealType = '';
          switch (mealType.toLowerCase()) {
            case 'breakfast':
              nextMealType = 'lunch';
              break;
            case 'lunch':
              nextMealType = 'dinner';
              break;
            case 'dinner':
              // Default to snacks, but could check for notAllowedMealType if available
              nextMealType = 'snacks';
              break;
            default:
              nextMealType = 'lunch'; // Default fallback
          }

          // Get CalorieAdjustmentService and apply adjustment
          try {
            final adjustmentService = Get.find<CalorieAdjustmentService>();
            await adjustmentService.setAdjustmentForMeal(nextMealType, overage);

            debugPrint(
                'QC Adjustment applied: $nextMealType reduced by $overage kcal');
          } catch (e) {
            debugPrint('Error applying QC adjustment: $e');
            // Silently fail - adjustment is non-critical
          }
        }
      }
    } catch (e) {
      debugPrint('Error checking QC adjustment: $e');
      // Silently fail - adjustment is non-critical
    }
  }

  Widget _buildNutritionCard({
    required String title,
    required String value,
    required String unit,
    required Color color,
    TextTheme? textTheme,
  }) {
    final isDarkMode = getThemeProvider(context).isDarkMode;

    return Container(
      padding: EdgeInsets.all(getPercentageWidth(3, context)),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: getTextScale(2.5, context),
              fontWeight: FontWeight.w500,
              color: isDarkMode ? kWhite : kDarkGrey,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                value,
                style: textTheme?.titleMedium?.copyWith(
                  fontSize: getTextScale(4, context),
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              SizedBox(width: getPercentageWidth(1, context)),
              Text(
                unit,
                style: TextStyle(
                  fontSize: getTextScale(2, context),
                  color: isDarkMode
                      ? kWhite.withValues(alpha: 0.7)
                      : kDarkGrey.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Check if AI generation failed and returned fallback/empty data
  bool _isAIGenerationFailed() {
    final foodItems = _editableAnalysis['foodItems'] as List<dynamic>;
    final totalNutrition = Map<String, dynamic>.from(
      _editableAnalysis['totalNutrition'] as Map,
    );
    final source = _editableAnalysis['source'] is bool
        ? _editableAnalysis['source'] as bool
        : _editableAnalysis['source'] == 'cloud_function'
            ? false
            : true;

    // Check if we have fallback data (source = true) or empty/zero nutrition
    if (source == true) return true;

    // Check if all nutrition values are zero
    final hasZeroNutrition = totalNutrition.values.every(
      (value) =>
          value == null || value == 0 || (value is String && value == '0'),
    );

    // Check if food items are empty or contain only fallback items
    final hasEmptyFoodItems = foodItems.isEmpty ||
        (foodItems.length == 1 &&
            foodItems.first['name']?.toString().toLowerCase().contains(
                      'unknown',
                    ) ==
                true);

    return hasZeroNutrition || hasEmptyFoodItems;
  }

  /// Retry AI analysis
  Future<void> _retryAIAnalysis() async {
    setState(() {
      _isSaving = true;
    });

    try {
      // Navigate back to trigger re-analysis
      Navigator.of(context).pop('retry');
    } catch (e) {
      debugPrint('Error during retry: $e');
      showTastySnackbar(
        'Error',
        'Failed to retry analysis. Please try again.',
        context,
        backgroundColor: Colors.red,
      );
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    final textTheme = Theme.of(context).textTheme;
    final totalNutrition = Map<String, dynamic>.from(
      _editableAnalysis['totalNutrition'] as Map,
    );
    final foodItems = _editableAnalysis['foodItems'] as List<dynamic>;
    final healthScore = _editableAnalysis['healthScore'] as int?;
    final confidence = _editableAnalysis['confidence'] as String? ?? 'medium';
    final source = _editableAnalysis['source'] is bool
        ? _editableAnalysis['source'] as bool
        : _editableAnalysis['source'] == 'cloud_function'
            ? false
            : true;

    // Check if AI generation failed
    final bool aiFailed = _isAIGenerationFailed();

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: isDarkMode ? kBlack : kWhite,
        appBar: AppBar(
          backgroundColor: isDarkMode ? kBlack : kWhite,
          elevation: 0,
          automaticallyImplyLeading: false,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back,
              color: isDarkMode ? kWhite : kBlack,
            ),
            onPressed: () {
              if (widget.isFeedPage == true) {
                Navigator.of(context).pushReplacementNamed('/explore');
              } else {
                Navigator.of(context).pop();
              }
            },
          ),
          title: Text(
            aiFailed ? 'Tasting Failed' : 'Plate Analysis',
            style: textTheme.displaySmall?.copyWith(
              color: isDarkMode ? kWhite : kBlack,
              fontSize: getTextScale(6, context),
              fontWeight: FontWeight.w600,
            ),
          ),
          actions: aiFailed
              ? null
              : [
                  TextButton(
                    onPressed: _isSaving
                        ? null
                        : widget.screen == 'challenge_detail'
                            ? _saveForChallengeDetail
                            : _saveAnalysis,
                    child: Text(
                      widget.screen == 'challenge_detail' ? 'Close' : 'Save',
                      style: textTheme.displayMedium?.copyWith(
                        color: kAccent,
                        fontSize: getTextScale(4, context),
                        fontWeight: FontWeight.w200,
                      ),
                    ),
                  ),
                ],
        ),
        body: _isSaving
            ? const Center(child: CircularProgressIndicator(color: kAccent))
            : aiFailed
                ? _buildAIFailedUI(context, isDarkMode, textTheme)
                : _buildNormalAnalysisUI(
                    context,
                    isDarkMode,
                    textTheme,
                    totalNutrition,
                    foodItems,
                    healthScore,
                    confidence,
                    source,
                  ),
      ),
    );
  }

  /// Build UI for when AI analysis fails
  Widget _buildAIFailedUI(
    BuildContext context,
    bool isDarkMode,
    TextTheme textTheme,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Image preview
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(
              widget.imageFile,
              height: getPercentageHeight(30, context),
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),

          SizedBox(height: getPercentageHeight(4, context)),

          // Error message
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDarkMode ? kDarkGrey : Colors.red[50],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.red.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.error_outline,
                  size: getIconScale(12, context),
                  color: Colors.red,
                ),
                SizedBox(height: getPercentageHeight(2, context)),
                Text(
                  'Tasting Failed',
                  style: textTheme.titleLarge?.copyWith(
                    fontSize: getTextScale(5, context),
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
                SizedBox(height: getPercentageHeight(1, context)),
                Text(
                  'Chef, I couldn\'t taste that dish properly. This might be due to:\n\n• Image quality needs improvement\n• Network hiccup at the station\n• Service temporarily unavailable\n\nPlease try again with a clearer image.',
                  textAlign: TextAlign.center,
                  style: textTheme.bodyMedium?.copyWith(
                    fontSize: getTextScale(3.5, context),
                    color:
                        isDarkMode ? kWhite.withValues(alpha: 0.8) : kDarkGrey,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: getPercentageHeight(4, context)),

          // Retry button
          SizedBox(
            width: double.infinity,
            child: AppButton(
              text: 'Retry Tasting',
              onPressed: _retryAIAnalysis,
              type: AppButtonType.primary,
              width: 100,
            ),
          ),

          SizedBox(height: getPercentageHeight(2, context)),

          // Alternative action
          TextButton(
            onPressed: () {
              if (widget.isFeedPage == true) {
                Navigator.of(context).pushReplacementNamed('/explore');
              } else {
                Navigator.of(context).pop();
              }
            },
            child: Text(
              'Go Back',
              style: textTheme.bodyMedium?.copyWith(
                fontSize: getTextScale(3.5, context),
                color: isDarkMode ? kWhite.withValues(alpha: 0.7) : kDarkGrey,
              ),
            ),
          ),

          SizedBox(height: getPercentageHeight(3, context)),
        ],
      ),
    );
  }

  /// Build normal analysis UI when AI succeeds
  Widget _buildNormalAnalysisUI(
    BuildContext context,
    bool isDarkMode,
    TextTheme textTheme,
    Map<String, dynamic> totalNutrition,
    List<dynamic> foodItems,
    int? healthScore,
    String confidence,
    bool source,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image preview
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(
              widget.imageFile,
              height: getPercentageHeight(25, context),
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),

          const SizedBox(height: 20),

          // Turner's Notes Section
          _buildTurnersNotes(
            context,
            isDarkMode,
            totalNutrition,
            healthScore,
            confidence,
          ),

          const SizedBox(height: 20),

          // Suggestions Section
          if (_editableAnalysis.containsKey('suggestions') &&
              (_editableAnalysis['suggestions'] as Map).isNotEmpty) ...[
            buildSuggestionsSection(context, _editableAnalysis, false),
          ],

          const SizedBox(height: 20),

          // Nutrition Summary
          Text(
            'Macro Breakdown',
            style: textTheme.titleMedium?.copyWith(
              fontSize: getTextScale(5, context),
              fontWeight: FontWeight.bold,
              color: isDarkMode ? kWhite : kDarkGrey,
            ),
          ),
          SizedBox(height: getPercentageHeight(1, context)),

          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 2.5,
            children: [
              _buildNutritionCard(
                title: 'Calories',
                value: '${totalNutrition['calories'] ?? 0}',
                unit: 'kcal',
                color: Colors.orange,
                textTheme: textTheme,
              ),
              _buildNutritionCard(
                title: 'Protein',
                value: '${totalNutrition['protein'] ?? 0}',
                unit: 'grams',
                color: Colors.blue,
                textTheme: textTheme,
              ),
              _buildNutritionCard(
                title: 'Carbs',
                value: '${totalNutrition['carbs'] ?? 0}',
                unit: 'grams',
                color: Colors.green,
                textTheme: textTheme,
              ),
              _buildNutritionCard(
                title: 'Fat',
                value: '${totalNutrition['fat'] ?? 0}',
                unit: 'grams',
                color: Colors.purple,
                textTheme: textTheme,
              ),
            ],
          ),

          // Macro-based calories calculation for transparency
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDarkMode
                  ? kDarkGrey.withValues(alpha: 0.3)
                  : Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Calculated from macros, Chef:',
                  style: TextStyle(
                    fontSize: getTextScale(3, context),
                    color:
                        isDarkMode ? kWhite.withValues(alpha: 0.7) : kDarkGrey,
                  ),
                ),
                Text(
                  '${((totalNutrition['protein'] ?? 0) * 4 + (totalNutrition['carbs'] ?? 0) * 4 + (totalNutrition['fat'] ?? 0) * 9).round()} kcal',
                  style: TextStyle(
                    fontSize: getTextScale(3, context),
                    color: isDarkMode ? kWhite : kBlack,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // Detected Food Items
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'What I Tasted',
                style: textTheme.titleMedium?.copyWith(
                  fontSize: getTextScale(5, context),
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? kWhite : kDarkGrey,
                ),
              ),
              Text(
                'Tap to adjust',
                style: textTheme.bodyMedium?.copyWith(
                  fontSize: getTextScale(3, context),
                  color: kAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: foodItems.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final foodItem = Map<String, dynamic>.from(
                foodItems[index] as Map,
              );
              final nutrition = Map<String, dynamic>.from(
                foodItem['nutritionalInfo'] as Map,
              );

              final weight = foodItem['estimatedWeight'] ?? 'Unknown';
              final weightValue = weight.contains('g') ? weight : '${weight}g';

              return GestureDetector(
                onTap: () => _editFoodItem(index),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDarkMode ? kDarkGrey : Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDarkMode ? kDarkGrey : Colors.grey[300]!,
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              foodItem['name'] ?? 'Unknown Food',
                              style: textTheme.titleMedium?.copyWith(
                                fontSize: getTextScale(4, context),
                                fontWeight: FontWeight.w600,
                                color: isDarkMode ? kWhite : kDarkGrey,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.edit,
                            color: kAccent,
                            size: getIconScale(5, context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Weight: $weightValue',
                        style: textTheme.bodyMedium?.copyWith(
                          fontSize: getTextScale(3, context),
                          color: isDarkMode
                              ? kWhite.withValues(alpha: 0.7)
                              : kDarkGrey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${nutrition['calories'] ?? 0} cal',
                              style: textTheme.bodyMedium?.copyWith(
                                fontSize: getTextScale(3, context),
                                color: Colors.orange,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              '${nutrition['protein'] ?? 0}g protein',
                              style: textTheme.bodyMedium?.copyWith(
                                fontSize: getTextScale(3, context),
                                color: Colors.blue,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          SizedBox(height: getPercentageHeight(2, context)),

          // Save Button
          SizedBox(
            width: double.infinity,
            child: _isSaving
                ? const Center(child: CircularProgressIndicator(color: kAccent))
                : AppButton(
                    text: 'Add to Menu',
                    onPressed: () => _saveAnalysis(),
                    type: AppButtonType.primary,
                    width: 100,
                  ),
          ),
          SizedBox(height: getPercentageHeight(3, context)),
        ],
      ),
    );
  }
}

class _FoodItemEditDialog extends StatefulWidget {
  final Map<String, dynamic> foodItem;
  final Function(Map<String, dynamic>) onSave;

  const _FoodItemEditDialog({required this.foodItem, required this.onSave});

  @override
  State<_FoodItemEditDialog> createState() => _FoodItemEditDialogState();
}

class _FoodItemEditDialogState extends State<_FoodItemEditDialog> {
  late TextEditingController _nameController;
  late TextEditingController _weightController;
  late TextEditingController _caloriesController;
  late TextEditingController _proteinController;
  late TextEditingController _carbsController;
  late TextEditingController _fatController;

  // Store original values for ratio calculations
  late double _originalWeight;
  late double _originalCalories;
  late double _originalProtein;
  late double _originalCarbs;
  late double _originalFat;

  bool _isUpdatingFromWeight = false;
  bool _isUpdatingFromCalories = false;
  bool _isUpdatingFromMacros = false;

  @override
  void initState() {
    super.initState();
    final nutrition = Map<String, dynamic>.from(
      widget.foodItem['nutritionalInfo'] as Map,
    );

    _nameController = TextEditingController(
      text: widget.foodItem['name'] ?? '',
    );

    // Parse and store original values
    _originalWeight = double.tryParse(
          widget.foodItem['estimatedWeight']?.toString().replaceAll('g', '') ??
              '0',
        ) ??
        0.0;
    _originalCalories =
        double.tryParse(nutrition['calories']?.toString() ?? '0') ?? 0.0;
    _originalProtein =
        double.tryParse(nutrition['protein']?.toString() ?? '0') ?? 0.0;
    _originalCarbs =
        double.tryParse(nutrition['carbs']?.toString() ?? '0') ?? 0.0;
    _originalFat = double.tryParse(nutrition['fat']?.toString() ?? '0') ?? 0.0;

    _weightController = TextEditingController(text: _originalWeight.toString());
    _caloriesController = TextEditingController(
      text: _originalCalories.toString(),
    );
    _proteinController = TextEditingController(
      text: _originalProtein.toString(),
    );
    _carbsController = TextEditingController(text: _originalCarbs.toString());
    _fatController = TextEditingController(text: _originalFat.toString());

    // Add listeners for automatic conversion
    _weightController.addListener(_onWeightChanged);
    _caloriesController.addListener(_onCaloriesChanged);
    _proteinController.addListener(_onMacrosChanged);
    _carbsController.addListener(_onMacrosChanged);
    _fatController.addListener(_onMacrosChanged);
  }

  void _onWeightChanged() {
    if (_isUpdatingFromCalories) return;

    final newWeight = double.tryParse(_weightController.text) ?? 0.0;
    if (newWeight > 0 && _originalWeight > 0) {
      final ratio = newWeight / _originalWeight;

      _isUpdatingFromWeight = true;
      _caloriesController.text = (_originalCalories * ratio).round().toString();
      _proteinController.text = (_originalProtein * ratio).round().toString();
      _carbsController.text = (_originalCarbs * ratio).round().toString();
      _fatController.text = (_originalFat * ratio).round().toString();
      _isUpdatingFromWeight = false;
    }
  }

  void _onCaloriesChanged() {
    if (_isUpdatingFromWeight || _isUpdatingFromMacros) return;

    final newCalories = double.tryParse(_caloriesController.text) ?? 0.0;
    if (newCalories > 0 && _originalCalories > 0) {
      final ratio = newCalories / _originalCalories;

      _isUpdatingFromCalories = true;
      _weightController.text = (_originalWeight * ratio).round().toString();
      _proteinController.text = (_originalProtein * ratio).round().toString();
      _carbsController.text = (_originalCarbs * ratio).round().toString();
      _fatController.text = (_originalFat * ratio).round().toString();
      _isUpdatingFromCalories = false;
    }
  }

  void _onMacrosChanged() {
    if (_isUpdatingFromWeight || _isUpdatingFromCalories) return;

    // Recalculate calories from macros when protein, carbs, or fat changes
    final protein = double.tryParse(_proteinController.text) ?? 0.0;
    final carbs = double.tryParse(_carbsController.text) ?? 0.0;
    final fat = double.tryParse(_fatController.text) ?? 0.0;

    final calculatedCalories = (protein * 4) + (carbs * 4) + (fat * 9);

    _isUpdatingFromMacros = true;
    _caloriesController.text = calculatedCalories.round().toString();
    _isUpdatingFromMacros = false;
  }

  @override
  void dispose() {
    _weightController.removeListener(_onWeightChanged);
    _caloriesController.removeListener(_onCaloriesChanged);
    _proteinController.removeListener(_onMacrosChanged);
    _carbsController.removeListener(_onMacrosChanged);
    _fatController.removeListener(_onMacrosChanged);
    _nameController.dispose();
    _weightController.dispose();
    _caloriesController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatController.dispose();
    super.dispose();
  }

  void _save() {
    final updatedItem = Map<String, dynamic>.from(widget.foodItem);
    updatedItem['name'] = _nameController.text;
    updatedItem['estimatedWeight'] = '${_weightController.text}g';

    final nutrition = Map<String, dynamic>.from(
      updatedItem['nutritionalInfo'] as Map,
    );

    // Use double parsing for better precision, then convert to int for storage
    final protein = double.tryParse(_proteinController.text) ?? 0.0;
    final carbs = double.tryParse(_carbsController.text) ?? 0.0;
    final fat = double.tryParse(_fatController.text) ?? 0.0;

    // Always calculate calories from macros for consistency
    final calculatedCalories = (protein * 4) + (carbs * 4) + (fat * 9);

    // Update nutrition values
    nutrition['calories'] = calculatedCalories.round();
    nutrition['protein'] = protein.round();
    nutrition['carbs'] = carbs.round();
    nutrition['fat'] = fat.round();

    // Ensure nutritionalInfo is updated in the item
    updatedItem['nutritionalInfo'] = nutrition;

    widget.onSave(updatedItem);
    Navigator.of(context).pop();
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    TextInputType? keyboardType,
  }) {
    final isDarkMode = getThemeProvider(context).isDarkMode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: getTextScale(3.5, context),
            fontWeight: FontWeight.w500,
            color: isDarkMode ? kWhite : kDarkGrey,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          style: TextStyle(color: isDarkMode ? kWhite : kBlack),
          decoration: InputDecoration(
            filled: true,
            fillColor: isDarkMode ? kDarkGrey : Colors.grey[100],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = getThemeProvider(context).isDarkMode;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      backgroundColor: isDarkMode ? kDarkGrey : kWhite,
      title: Text(
        'Adjust Portion',
        style: TextStyle(
          color: isDarkMode ? kWhite : kBlack,
          fontSize: getTextScale(5, context),
          fontWeight: FontWeight.w600,
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildTextField(label: 'Food Name', controller: _nameController),
            const SizedBox(height: 16),
            _buildTextField(
              label: 'Weight (g)',
              controller: _weightController,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              label: 'Calories',
              controller: _caloriesController,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              label: 'Protein (g)',
              controller: _proteinController,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              label: 'Carbs (g)',
              controller: _carbsController,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              label: 'Fat (g)',
              controller: _fatController,
              keyboardType: TextInputType.number,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Cancel',
            style: TextStyle(
              color: isDarkMode ? kWhite.withValues(alpha: 0.7) : kDarkGrey,
            ),
          ),
        ),
        TextButton(
          onPressed: _save,
          child: const Text('Update', style: TextStyle(color: kAccent)),
        ),
      ],
    );
  }
}
