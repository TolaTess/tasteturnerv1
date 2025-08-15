import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../constants.dart';
import '../helper/helper_functions.dart';
import '../helper/notifications_helper.dart';
import '../helper/utils.dart';
import '../widgets/primary_button.dart';
import '../data_models/post_model.dart';
import '../service/battle_service.dart';
import '../widgets/bottom_nav.dart';

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

  /// Normalize and validate analysis data to prevent duplicates and handle errors
  void _normalizeAnalysisData() {
    try {
      // Normalize ingredients if they exist
      if (_editableAnalysis.containsKey('ingredients') &&
          _editableAnalysis['ingredients'] is Map) {
        _editableAnalysis['ingredients'] = _normalizeAndDeduplicateIngredients(
            _editableAnalysis['ingredients'] as Map<String, dynamic>);
      }

      // Ensure required fields exist with fallback values
      _editableAnalysis['foodItems'] = _editableAnalysis['foodItems'] ?? [];
      _editableAnalysis['totalNutrition'] =
          _editableAnalysis['totalNutrition'] ??
              {
                'calories': 0,
                'protein': 0,
                'carbs': 0,
                'fat': 0,
                'fiber': 0,
                'sugar': 0,
                'sodium': 0,
              };
      _editableAnalysis['healthScore'] = _editableAnalysis['healthScore'] ?? 5;
      _editableAnalysis['estimatedPortionSize'] =
          _editableAnalysis['estimatedPortionSize'] ?? 'medium';
      _editableAnalysis['confidence'] =
          _editableAnalysis['confidence'] ?? 'medium';

      // Validate and fix food items
      final foodItems = _editableAnalysis['foodItems'] as List<dynamic>;
      for (int i = 0; i < foodItems.length; i++) {
        final item = foodItems[i] as Map<String, dynamic>;

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
              'sodium': 100
            };

        // Validate nutritional values are numbers
        final nutrition = item['nutritionalInfo'] as Map<String, dynamic>;
        nutrition.forEach((key, value) {
          if (value == null ||
              (value is String && double.tryParse(value) == null)) {
            nutrition[key] = 0;
          }
        });
      }
    } catch (e) {
      print('Error normalizing analysis data: $e');
      // Set minimal fallback data if normalization fails
      _editableAnalysis = {
        'foodItems': [
          {
            'name': 'Unknown Food',
            'estimatedWeight': '100g',
            'confidence': 'low',
            'nutritionalInfo': {
              'calories': 200,
              'protein': 10,
              'carbs': 20,
              'fat': 8,
              'fiber': 2,
              'sugar': 5,
              'sodium': 200
            }
          }
        ],
        'totalNutrition': {
          'calories': 200,
          'protein': 10,
          'carbs': 20,
          'fat': 8,
          'fiber': 2,
          'sugar': 5,
          'sodium': 200
        },
        'healthScore': 5,
        'estimatedPortionSize': 'medium',
        'ingredients': {'unknown ingredient': '1 portion'},
        'confidence': 'low',
        'notes':
            'Analysis data was malformed and has been reset to safe defaults.'
      };
    }
  }

  /// Normalize and deduplicate ingredients to prevent variations like "sesameseed" vs "sesame seed"
  Map<String, String> _normalizeAndDeduplicateIngredients(
      Map<String, dynamic> ingredients) {
    final Map<String, String> normalizedIngredients = {};
    final Map<String, List<MapEntry<String, String>>> groupedIngredients = {};

    // Convert all ingredients to Map<String, String> and normalize keys
    final stringIngredients = <String, String>{};
    ingredients.forEach((key, value) {
      stringIngredients[key] = value.toString();
    });

    // Group ingredients by normalized name
    stringIngredients.forEach((originalName, amount) {
      final normalizedName = _normalizeIngredientName(originalName);

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
        final combinedResult = _combineIngredients(ingredientList);
        normalizedIngredients[combinedResult.key] = combinedResult.value;
      }
    });

    return normalizedIngredients;
  }

  /// Normalize ingredient name for comparison (lowercase, no spaces, common substitutions)
  String _normalizeIngredientName(String name) {
    return name
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), '') // Remove all whitespace
        .replaceAll(RegExp(r'[^\w]'), '') // Remove non-word characters
        .replaceAll('oilolive', 'oliveoil') // Handle oil variations
        .replaceAll('saltpink', 'pinksalt')
        .replaceAll('saltrock', 'rocksalt')
        .replaceAll('saltsea', 'seasalt');
  }

  /// Combine multiple ingredients with the same normalized name
  MapEntry<String, String> _combineIngredients(
      List<MapEntry<String, String>> ingredients) {
    // Use the most descriptive name (longest with spaces)
    String bestName = ingredients.first.key;
    for (final ingredient in ingredients) {
      if (ingredient.key.contains(' ') &&
          ingredient.key.length > bestName.length) {
        bestName = ingredient.key;
      }
    }

    // Try to combine quantities if they have the same unit
    final quantities = <double>[];
    String? commonUnit;
    bool canCombine = true;

    for (final ingredient in ingredients) {
      final amount = ingredient.value.toLowerCase().trim();
      final match = RegExp(r'(\d+(?:\.\d+)?)\s*([a-zA-Z]*)').firstMatch(amount);

      if (match != null) {
        final quantity = double.tryParse(match.group(1) ?? '0') ?? 0;
        final unit = match.group(2) ?? '';

        if (commonUnit == null) {
          commonUnit = unit;
        } else if (commonUnit != unit && unit.isNotEmpty) {
          // Different units, can't combine
          canCombine = false;
          break;
        }
        quantities.add(quantity);
      } else {
        // Can't parse quantity, can't combine
        canCombine = false;
        break;
      }
    }

    if (canCombine && quantities.isNotEmpty) {
      final totalQuantity = quantities.reduce((a, b) => a + b);
      final combinedAmount = commonUnit != null && commonUnit.isNotEmpty
          ? '$totalQuantity$commonUnit'
          : totalQuantity.toString();
      return MapEntry(bestName, combinedAmount);
    } else {
      // Can't combine, use the first one and add a note
      final firstAmount = ingredients.first.value;
      final additionalCount = ingredients.length - 1;
      final combinedAmount = additionalCount > 0
          ? '$firstAmount (+$additionalCount more)'
          : firstAmount;
      return MapEntry(bestName, combinedAmount);
    }
  }

  Color _getHealthScoreColor(int score) {
    if (score >= 8) return Colors.green;
    if (score >= 6) return Colors.orange;
    return Colors.red;
  }

  String _getHealthScoreDescription(int score) {
    if (score >= 8) return 'Excellent nutritional choice!';
    if (score >= 6)
      return 'Good with room for improvement, check AI suggestions';
    return 'Consider healthier alternatives, check AI Alternatives';
  }

  Future<void> _createMealOnly() async {
    if (_hasCreatedMeal) return; // Don't create meal twice

    try {
      // Upload image to Firebase Storage
      String imagePath =
          'tastyanalysis/${userService.userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final uploadTask =
          await firebaseStorage.ref(imagePath).putFile(widget.imageFile);
      final downloadUrl = await uploadTask.ref.getDownloadURL();

      // Save analysis to tastyanalysis collection
      await geminiService.saveAnalysisToFirestore(
        analysisResult: _editableAnalysis,
        userId: userService.userId ?? '',
        imagePath: downloadUrl,
      );

      // Determine mealId based on the flow type
      final bool isExistingPostAnalysis =
          widget.postId != null && widget.postId!.isNotEmpty;
      final String? mealIdToUse = isExistingPostAnalysis ? widget.postId : null;

      // Create meal from analysis only
      await geminiService.createMealFromAnalysis(
        analysisResult: _editableAnalysis,
        userId: tastyId,
        mealType: mealType,
        imagePath: downloadUrl,
        mealId: mealIdToUse,
      );

      setState(() {
        _hasCreatedMeal = true;
      });
    } catch (e) {
      print('Failed to create meal: $e');
      // Don't show error dialog on back navigation, just fail silently
    }
  }

  Future<void> _saveAnalysis() async {
    setState(() {
      _isSaving = true;
    });

    try {
      String downloadUrl;

      // Skip image upload and analysis saving if coming from buddy chat (already saved)
      if (widget.skipAnalysisSave == true) {
        // For buddy chat, we don't need to upload the image again or save analysis
        // The analysis is already saved and we have the image URL
        downloadUrl =
            'buddy_chat_temp_url'; // Placeholder since we won't use it for post creation
      } else {
        // Upload image to Firebase Storage
        String imagePath =
            'tastyanalysis/${userService.userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final uploadTask =
            await firebaseStorage.ref(imagePath).putFile(widget.imageFile);
        downloadUrl = await uploadTask.ref.getDownloadURL();

        // Save analysis to tastyanalysis collection
        await geminiService.saveAnalysisToFirestore(
          analysisResult: _editableAnalysis,
          userId: userService.userId ?? '',
          imagePath: downloadUrl,
        );
      }

      // Determine if this is for an existing post or a new analyze & upload flow
      final bool isExistingPostAnalysis =
          widget.postId != null && widget.postId!.isNotEmpty;

      String finalMealId;

      if (isExistingPostAnalysis) {
        // Path 2: Existing post analysis - use existing postId as mealId for linking
        finalMealId = await geminiService.createMealFromAnalysis(
          analysisResult: _editableAnalysis,
          userId: tastyId,
          mealType: mealType,
          imagePath: downloadUrl,
          mealId: widget.postId!, // Use existing postId as mealId for linking
        );
      } else {
        // Path 1: New analyze & upload - create meal first, then use mealId as postId
        finalMealId = await geminiService.createMealFromAnalysis(
          analysisResult: _editableAnalysis,
          userId: tastyId,
          mealType: mealType,
          imagePath: downloadUrl,
          mealId: null, // Let it generate a new ID
        );
      }

      // Add to daily meals
      if (widget.screen != 'challenge_detail') {
        await geminiService.addAnalyzedMealToDaily(
          mealId: finalMealId,
          userId: userService.userId ?? '',
          mealType: mealType,
          analysisResult: _editableAnalysis,
          date: widget.date ?? DateTime.now(),
        );
      }

      // CRITICAL FIX: Update original post with mealId for existing post analysis
      if (isExistingPostAnalysis) {
        try {
          await postController.updatePost(
            postId: widget.postId!,
            updateData: {'mealId': finalMealId},
          );
        } catch (e) {
          print('Error updating post with mealId: $e');
          // Don't fail the whole operation, just log the error
        }
      }

      setState(() {
        _hasCreatedMeal = true;
      });

      // Handle post creation for analyze & upload flow (both regular and battle posts)
      if (widget.isAnalyzeAndUpload == true && !isExistingPostAnalysis) {
        try {
          String postImageUrl;

          // Determine if this is a battle post, main post, or regular post
          final bool isBattlePost =
              widget.battleId != null && widget.isMainPost != true;
          final bool isMainPost = widget.isMainPost == true;
          final bool isRegularPost =
              widget.battleId == null && widget.isMainPost == null;

          if (isMainPost || isRegularPost) {
            // For main posts and regular posts, use the already uploaded image
            postImageUrl = downloadUrl;
          } else {
            // For battle posts, upload to battle storage
            postImageUrl = await BattleService.instance.uploadBattleImage(
              battleId: widget.battleId!,
              userId: userService.userId ?? '',
              imageFile: widget.imageFile,
            );
          }

          // Create the post using the mealId as the postId for proper linking
          final post = Post(
            id: isBattlePost
                ? ''
                : finalMealId, // Battle posts get unique ID, main posts use mealId for linking
            mealId:
                finalMealId, // Always link the post to the meal via mealId field
            userId: userService.userId ?? '',
            mediaPaths: [postImageUrl],
            name: userService.currentUser.value?.displayName ?? '',
            category: widget.selectedCategory ??
                'general', // Use actual selected category for all posts
            isBattle: isBattlePost,
            battleId: isBattlePost ? widget.battleId! : '',
            isVideo: false,
          );

          // Upload the post
          await postController
              .uploadPost(post, userService.userId ?? '', [postImageUrl]);

          // Show success message
          showTastySnackbar(
            'Success!',
            'Food analyzed, meal added to your ${mealType.toLowerCase()}, and post uploaded!',
            context,
            backgroundColor: kAccent,
          );

          // Navigate to appropriate screen
          if (isMainPost) {
            Get.to(() => const BottomNavSec(selectedIndex: 2));
          } else if (isBattlePost) {
            // Go back to the previous screen for battle posts
            Navigator.of(context).pop();
            Navigator.of(context).pop(); // Go back to battle screen
          } else {
            // For regular posts, just go back to the previous screen
            Navigator.of(context).pop();
          }
        } catch (e) {
          print('Failed to create post: $e');
          showTastySnackbar(
            'Warning',
            'Meal saved successfully, but failed to upload post. Please try uploading manually.',
            context,
            backgroundColor: Colors.orange,
          );
          Navigator.of(context).pop();
        }
      } else {
        // Regular analysis save without post creation
        showTastySnackbar(
          'Success!',
          'Food analyzed and added to your ${mealType.toLowerCase()} meals.',
          context,
          backgroundColor: kAccent,
        );

        // Navigate back to the previous screen with success result
        Navigator.of(context).pop(true); // Return true to indicate success
      }
    } catch (e) {
      print('Failed to save analysis: $e');
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

  Future<bool> _onWillPop() async {
    // Create meal only when user goes back without saving
    if (!_hasCreatedMeal && !_isSaving) {
      await _createMealOnly();
    }
    return true; // Allow navigation back
  }

  void _editFoodItem(int index) {
    final foodItems = _editableAnalysis['foodItems'] as List<dynamic>;
    final foodItem = foodItems[index] as Map<String, dynamic>;

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
      final nutrition = item['nutritionalInfo'] as Map<String, dynamic>;

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
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
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

  @override
  Widget build(BuildContext context) {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    final textTheme = Theme.of(context).textTheme;
    final totalNutrition =
        _editableAnalysis['totalNutrition'] as Map<String, dynamic>;
    final foodItems = _editableAnalysis['foodItems'] as List<dynamic>;
    final healthScore = _editableAnalysis['healthScore'] as int? ?? 5;

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: isDarkMode ? kBlack : kWhite,
        appBar: AppBar(
          backgroundColor: isDarkMode ? kBlack : kWhite,
          elevation: 0,
          automaticallyImplyLeading: true,
          title: Text(
            'Food Analysis Results',
            style: textTheme.displaySmall?.copyWith(
              color: isDarkMode ? kWhite : kBlack,
              fontSize: getTextScale(6, context),
              fontWeight: FontWeight.w600,
            ),
          ),
          actions: [
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
            ? const Center(
                child: CircularProgressIndicator(color: kAccent),
              )
            : SingleChildScrollView(
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

                    // Health Score
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
                              color: _getHealthScoreColor(healthScore)
                                  .withValues(alpha: 0.2),
                            ),
                            child: Center(
                              child: Text(
                                '$healthScore',
                                style: TextStyle(
                                  fontSize: getTextScale(6, context),
                                  fontWeight: FontWeight.bold,
                                  color: _getHealthScoreColor(healthScore),
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
                                  'Health Score',
                                  style: textTheme.titleMedium?.copyWith(
                                    fontSize: getTextScale(4, context),
                                    fontWeight: FontWeight.w600,
                                    color: isDarkMode ? kWhite : kDarkGrey,
                                  ),
                                ),
                                Text(
                                  _getHealthScoreDescription(healthScore),
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

                    const SizedBox(height: 20),

                    // Suggestions Section
                    if (_editableAnalysis.containsKey('suggestions'))
                      buildSuggestionsSection(
                          context, _editableAnalysis, false),

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
                              color: isDarkMode
                                  ? kWhite.withValues(alpha: 0.7)
                                  : kDarkGrey,
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
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final foodItem =
                            foodItems[index] as Map<String, dynamic>;
                        final nutrition =
                            foodItem['nutritionalInfo'] as Map<String, dynamic>;

                        final weight = foodItem['estimatedWeight'] ?? 'Unknown';
                        final weightValue =
                            weight.contains('g') ? weight : '${weight}g';

                        return GestureDetector(
                          onTap: () => _editFoodItem(index),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isDarkMode ? kDarkGrey : Colors.grey[100],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color:
                                    isDarkMode ? kDarkGrey : Colors.grey[300]!,
                                width: 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        foodItem['name'] ?? 'Unknown Food',
                                        style: textTheme.titleMedium?.copyWith(
                                          fontSize: getTextScale(4, context),
                                          fontWeight: FontWeight.w600,
                                          color:
                                              isDarkMode ? kWhite : kDarkGrey,
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
                          ? const Center(
                              child: CircularProgressIndicator(color: kAccent),
                            )
                          : AppButton(
                              text: widget.screen == 'challenge_detail'
                                  ? 'Save Meal'
                                  : 'Add to ${capitalizeFirstLetter(mealType)}',
                              onPressed: () => _saveAnalysis(),
                              type: AppButtonType.primary,
                              width: 100,
                            ),
                    ),
                    SizedBox(height: getPercentageHeight(3, context)),
                  ],
                ),
              ),
      ),
    );
  }
}

class _FoodItemEditDialog extends StatefulWidget {
  final Map<String, dynamic> foodItem;
  final Function(Map<String, dynamic>) onSave;

  const _FoodItemEditDialog({
    required this.foodItem,
    required this.onSave,
  });

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
    final nutrition =
        widget.foodItem['nutritionalInfo'] as Map<String, dynamic>;

    _nameController =
        TextEditingController(text: widget.foodItem['name'] ?? '');

    // Parse and store original values
    _originalWeight = double.tryParse(widget.foodItem['estimatedWeight']
                ?.toString()
                .replaceAll('g', '') ??
            '0') ??
        0.0;
    _originalCalories =
        double.tryParse(nutrition['calories']?.toString() ?? '0') ?? 0.0;
    _originalProtein =
        double.tryParse(nutrition['protein']?.toString() ?? '0') ?? 0.0;
    _originalCarbs =
        double.tryParse(nutrition['carbs']?.toString() ?? '0') ?? 0.0;
    _originalFat = double.tryParse(nutrition['fat']?.toString() ?? '0') ?? 0.0;

    _weightController = TextEditingController(text: _originalWeight.toString());
    _caloriesController =
        TextEditingController(text: _originalCalories.toString());
    _proteinController =
        TextEditingController(text: _originalProtein.toString());
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

    final nutrition = updatedItem['nutritionalInfo'] as Map<String, dynamic>;

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
          style: TextStyle(
            color: isDarkMode ? kWhite : kBlack,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: isDarkMode ? kDarkGrey : Colors.grey[100],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = getThemeProvider(context).isDarkMode;

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
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
            _buildTextField(
              label: 'Food Name',
              controller: _nameController,
            ),
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
          child: const Text(
            'Save',
            style: TextStyle(color: kAccent),
          ),
        ),
      ],
    );
  }
}
