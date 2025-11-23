import 'dart:io';
import 'package:flutter/material.dart';

import '../constants.dart';
import '../helper/helper_functions.dart';
import '../helper/notifications_helper.dart';
import '../helper/utils.dart';
import '../helper/ingredient_utils.dart';
import '../widgets/primary_button.dart';
import '../data_models/post_model.dart';
import '../service/battle_service.dart';

class FoodAnalysisResultsScreen extends StatefulWidget {
  final File imageFile;
  final Map<String, dynamic> analysisResult;
  final String? postId;
  final String? battleId;
  final String? battleCategory;
  final bool? isMainPost;
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
    this.battleId,
    this.battleCategory,
    this.isMainPost,
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

  /// Calculate health score from confidence level
  int _calculateHealthScoreFromConfidence(String confidence) {
    switch (confidence.toLowerCase()) {
      case 'high':
        return 8; // High confidence = good health score
      case 'medium':
        return 6; // Medium confidence = moderate health score
      case 'low':
        return 4; // Low confidence = lower health score
      default:
        return 6; // Default to medium
    }
  }

  /// Normalize and validate analysis data to prevent duplicates and handle errors
  void _normalizeAnalysisData() {
    try {
      debugPrint('=== NORMALIZING ANALYSIS DATA ===');
      debugPrint('Analysis data type: ${_editableAnalysis.runtimeType}');
      debugPrint('Analysis data keys: ${_editableAnalysis.keys.toList()}');
      debugPrint(
        'Food items type: ${_editableAnalysis['foodItems'].runtimeType}',
      );
      debugPrint(
        'Food items count: ${(_editableAnalysis['foodItems'] as List).length}',
      );

      if ((_editableAnalysis['foodItems'] as List).isNotEmpty) {
        final firstItem = (_editableAnalysis['foodItems'] as List).first;
        debugPrint('First food item type: ${firstItem.runtimeType}');
        debugPrint('First food item: $firstItem');

        if (firstItem is Map) {
          final nutritionalInfo = firstItem['nutritionalInfo'];
          debugPrint('Nutritional info type: ${nutritionalInfo.runtimeType}');
          debugPrint('Nutritional info: $nutritionalInfo');
        }
      }
      debugPrint('=== END ANALYSIS DATA LOGGING ===');

      // Normalize ingredients if they exist
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

  /// Normalize and deduplicate ingredients to prevent variations like "sesameseed" vs "sesame seed"
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

    // Group ingredients by normalized name
    stringIngredients.forEach((originalName, amount) {
      final normalizedName = normalizeIngredientName(originalName);

      if (!groupedIngredients.containsKey(normalizedName)) {
        groupedIngredients[normalizedName] = [];
      }
      groupedIngredients[normalizedName]!.add(MapEntry(originalName, amount));
    });

    // Process grouped ingredients
    groupedIngredients.forEach((normalizedName, ingredientList) {
      if (ingredientList.length == 1) {
        // Single ingredient, use as-is
        final ingredient = ingredientList.first;
        normalizedIngredients[ingredient.key] = ingredient.value;
      } else {
        // Multiple ingredients with same normalized name - combine them
        final combinedResult = combineIngredients(ingredientList);
        normalizedIngredients[combinedResult.key] = combinedResult.value;
      }
    });

    return normalizedIngredients;
  }

  Color _getHealthScoreColor(int? score, String? confidence) {
    if (score != null) {
      if (score >= 8) return Colors.green;
      if (score >= 6) return Colors.orange;
      return Colors.red;
    }

    // Use confidence level when health score is not available
    switch (confidence?.toLowerCase()) {
      case 'high':
        return Colors.green;
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  String _getHealthScoreDescription(int? score, String? confidence) {
    if (score != null) {
      if (score >= 8) return 'Excellent nutritional choice!';
      if (score >= 6)
        return 'Good with room for improvement, check AI suggestions';
      return 'Consider healthier alternatives, check AI suggestions';
    }

    // Use confidence level when health score is not available
    switch (confidence?.toLowerCase()) {
      case 'high':
        return 'High confidence analysis - reliable nutritional data';
      case 'medium':
        return 'Moderate confidence - review suggestions for improvements';
      case 'low':
        return 'Low confidence - consider retaking photo or manual entry';
      default:
        return 'Analysis completed - review suggestions for improvements';
    }
  }

  String _getHealthScoreLabel(int? score, String? confidence) {
    if (score != null) {
      return 'Health Score';
    }
    return 'Analysis Confidence';
  }

  String _getHealthScoreValue(int? score, String? confidence) {
    if (score != null) {
      return '$score';
    }

    // Use confidence level when health score is not available
    switch (confidence?.toLowerCase()) {
      case 'high':
        return 'High';
      case 'medium':
        return 'Med';
      case 'low':
        return 'Low';
      default:
        return 'Med';
    }
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

      setState(() {
        _hasCreatedMeal = true;
      });
    } catch (e) {
      debugPrint('Failed to save analysis: $e');
      // Don't show error dialog on back navigation, just fail silently
    }
  }

  Future<void> _saveAnalysis() async {
    setState(() {
      _isSaving = true;
    });

    try {
      // Show immediate success message
      showTastySnackbar(
        'Success!',
        'Meal added to your daily meals!',
        context,
        backgroundColor: kAccent,
      );

      // Navigate back immediately
      Navigator.of(context).pop(true);

      // Save to daily meals and create meal in background (non-blocking)
      _saveToDailyMealsInBackground();
    } catch (e) {
      debugPrint('Failed to save analysis: $e');
      showTastySnackbar(
        'Failed to save analysis',
        'Please try again',
        context,
        backgroundColor: kAccent,
      );
    } finally {
      setState(() {
        _isSaving = false;
      });
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
        debugPrint('Meal IDs: $mealIds');
        actualMealId = mealIds.first.toString();
      } else {
        // Create a new meal in the meals collection if no meal IDs exist
        debugPrint('No meal IDs, creating new meal');
        try {
          actualMealId = await geminiService.createMealFromAnalysis(
            analysisResult: _editableAnalysis,
            userId: userService.userId ?? '',
            imagePath: 'cloud_function_generated',
            mealType: mealType,
          );
          debugPrint(
              'Successfully created new meal $actualMealId in meals collection');
        } catch (e) {
          debugPrint('Failed to create meal in meals collection: $e');
          // Fallback to temporary ID
          actualMealId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
        }
      }

      // Skip daily meals addition for challenge detail screen
      if (widget.skipAnalysisSave != true &&
          widget.screen != 'challenge_detail') {
        await geminiService.addAnalyzedMealToDaily(
          mealId: actualMealId,
          userId: userService.userId ?? '',
          mealType: mealType,
          analysisResult: _editableAnalysis,
          date: widget.date ?? DateTime.now(),
        );

        debugPrint(
          'Successfully added meal $actualMealId to daily meals in background',
        );
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
          debugPrint(
              'Successfully updated post ${widget.postId} with mealId: $actualMealId');
        } catch (e) {
          debugPrint('Failed to update post with mealId: $e');
        }
      }

      // Handle post creation for analyze & upload flow in background
      if (widget.isAnalyzeAndUpload == true) {
        await _handlePostCreationInBackground();
      }
    } catch (e) {
      debugPrint('Background save to daily meals failed: $e');
      // Don't show error to user since UI already showed success
    }
  }

  /// Handle post creation in background for analyze & upload flow
  Future<void> _handlePostCreationInBackground() async {
    try {
      final bool isExistingPostAnalysis =
          widget.postId != null && widget.postId!.isNotEmpty;

      if (isExistingPostAnalysis) return; // Skip for existing posts

      String postImageUrl;

      // Determine if this is a battle post, main post, or regular post
      final bool isBattlePost =
          widget.battleId != null && widget.isMainPost != true;
      final bool isMainPost = widget.isMainPost == true;
      final bool isRegularPost =
          widget.battleId == null && widget.isMainPost == null;

      if (isMainPost || isRegularPost) {
        // Upload image to Firebase Storage for main/regular posts
        String imagePath =
            'tastyanalysis/${userService.userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final uploadTask =
            await firebaseStorage.ref(imagePath).putFile(widget.imageFile);
        postImageUrl = await uploadTask.ref.getDownloadURL();
      } else {
        // For battle posts, upload to battle storage
        postImageUrl = await BattleService.instance.uploadBattleImage(
          battleId: widget.battleId!,
          userId: userService.userId ?? '',
          imageFile: widget.imageFile,
        );
      }

      // Get the actual meal ID from the analysis result (generated by cloud function)
      final mealIds = _editableAnalysis['mealIds'] as List<dynamic>? ?? [];
      final String actualMealId = mealIds.isNotEmpty
          ? mealIds.first.toString()
          : 'post_${DateTime.now().millisecondsSinceEpoch}'; // Fallback if no meal ID

      // Generate a temporary post ID
      final String tempPostId = 'post_${DateTime.now().millisecondsSinceEpoch}';

      // Create the post with the actual meal ID
      final post = Post(
        id: isBattlePost ? '' : tempPostId,
        mealId: actualMealId, // Use the actual meal ID from cloud function
        userId: userService.userId ?? '',
        mediaPaths: [postImageUrl],
        name: userService.currentUser.value?.displayName ?? '',
        category: widget.selectedCategory ?? 'general',
        isBattle: isBattlePost,
        battleId: isBattlePost ? widget.battleId! : '',
        isVideo: false,
      );

      // Upload the post
      await postController.uploadPost(post, userService.userId ?? '', [
        postImageUrl,
      ]);

      debugPrint(
          'Successfully created post in background with mealId: $actualMealId');
    } catch (e) {
      debugPrint('Background post creation failed: $e');
      // Don't show error to user since UI already showed success
    }
  }

  Future<bool> _onWillPop() async {
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
            aiFailed ? 'Analysis Failed' : 'Food Analysis Results',
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
                    onPressed: _isSaving ? null : _saveAnalysis,
                    child: Text(
                      'Save',
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
                  'AI Analysis Failed',
                  style: textTheme.titleLarge?.copyWith(
                    fontSize: getTextScale(5, context),
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
                SizedBox(height: getPercentageHeight(1, context)),
                Text(
                  'We couldn\'t analyze your food image. This might be due to:\n\n• Poor image quality\n• Network issues\n• AI service temporarily unavailable\n\nPlease try again with a clearer image.',
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
              text: 'Try Again',
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

          // Health Score / Analysis Confidence
          if (source == false) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDarkMode ? kDarkGrey : kWhite,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _getHealthScoreColor(
                        healthScore,
                        confidence,
                      ).withValues(alpha: 0.2),
                    ),
                    child: Center(
                      child: Text(
                        _getHealthScoreValue(healthScore, confidence),
                        style: TextStyle(
                          fontSize: getTextScale(6, context),
                          fontWeight: FontWeight.bold,
                          color: _getHealthScoreColor(healthScore, confidence),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getHealthScoreLabel(healthScore, confidence),
                          style: textTheme.titleMedium?.copyWith(
                            fontSize: getTextScale(4, context),
                            fontWeight: FontWeight.w600,
                            color: isDarkMode ? kWhite : kDarkGrey,
                          ),
                        ),
                        Text(
                          _getHealthScoreDescription(healthScore, confidence),
                          style: textTheme.bodyMedium?.copyWith(
                            fontSize: getTextScale(3, context),
                            color: isDarkMode
                                ? kWhite.withValues(alpha: 0.7)
                                : kDarkGrey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),

          // Suggestions Section
          if (_editableAnalysis.containsKey('suggestions') &&
              (_editableAnalysis['suggestions'] as Map).isNotEmpty) ...[
            buildSuggestionsSection(context, _editableAnalysis, false),
          ],

          const SizedBox(height: 20),

          // Nutrition Summary
          Text(
            'Nutrition Summary',
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
                  'Calculated from macros:',
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
                'Detected Food Items',
                style: textTheme.titleMedium?.copyWith(
                  fontSize: getTextScale(5, context),
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? kWhite : kDarkGrey,
                ),
              ),
              Text(
                'Tap to edit',
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
                    text: 'Add Meal',
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
    if (_isUpdatingFromWeight) return;

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

  @override
  void dispose() {
    _weightController.removeListener(_onWeightChanged);
    _caloriesController.removeListener(_onCaloriesChanged);
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
    final calories = double.tryParse(_caloriesController.text) ?? 0.0;
    final protein = double.tryParse(_proteinController.text) ?? 0.0;
    final carbs = double.tryParse(_carbsController.text) ?? 0.0;
    final fat = double.tryParse(_fatController.text) ?? 0.0;

    // Calculate calories from macros
    final calculatedCalories = (protein * 4) + (carbs * 4) + (fat * 9);

    // Use macro-based calories if they don't equal the provided calories
    final finalCalories =
        calculatedCalories != calories ? calculatedCalories : calories;

    nutrition['calories'] = finalCalories.round();
    nutrition['protein'] = protein.round();
    nutrition['carbs'] = carbs.round();
    nutrition['fat'] = fat.round();

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
        'Edit Food Item',
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
          child: const Text('Add', style: TextStyle(color: kAccent)),
        ),
      ],
    );
  }
}
