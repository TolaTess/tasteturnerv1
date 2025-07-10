import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../constants.dart';
import '../helper/helper_functions.dart';
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

  const FoodAnalysisResultsScreen({
    super.key,
    required this.imageFile,
    required this.analysisResult,
    this.postId = '',
    this.battleId,
    this.battleCategory,
    this.isMainPost,
    this.selectedCategory,
  });

  @override
  State<FoodAnalysisResultsScreen> createState() =>
      _FoodAnalysisResultsScreenState();
}

class _FoodAnalysisResultsScreenState extends State<FoodAnalysisResultsScreen> {
  late Map<String, dynamic> _editableAnalysis;
  bool _isSaving = false;
  bool _hasCreatedMeal = false;
  bool _showNutritionWarning = false;
  String _nutritionWarningMessage = '';

  @override
  void initState() {
    super.initState();
    _editableAnalysis = Map<String, dynamic>.from(widget.analysisResult);

    // Recalculate totals on initial load to ensure consistency
    _recalculateTotalNutrition();
    _validateNutrition();
  }

  Color _getHealthScoreColor(int score) {
    if (score >= 8) return Colors.green;
    if (score >= 6) return Colors.orange;
    return Colors.red;
  }

  String _getHealthScoreDescription(int score) {
    if (score >= 8) return 'Excellent nutritional choice!';
    if (score >= 6) return 'Good with room for improvement';
    return 'Consider healthier alternatives';
  }

  Future<void> _createMealOnly() async {
    if (_hasCreatedMeal) return; // Don't create meal twice

    try {
      // Upload image to Firebase Storage
      String imagePath =
          'food_analysis/${userService.userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final uploadTask =
          await firebaseStorage.ref(imagePath).putFile(widget.imageFile);
      final downloadUrl = await uploadTask.ref.getDownloadURL();

      final mealType = getMealTimeOfDay();

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
      // Upload image to Firebase Storage
      String imagePath =
          'food_analysis/${userService.userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final uploadTask =
          await firebaseStorage.ref(imagePath).putFile(widget.imageFile);
      final downloadUrl = await uploadTask.ref.getDownloadURL();

      // Save analysis to tastyanalysis collection
      await geminiService.saveAnalysisToFirestore(
        analysisResult: _editableAnalysis,
        userId: userService.userId ?? '',
        imagePath: downloadUrl,
      );

      final mealType = getMealTimeOfDay();

      // Determine if this is for an existing post or a new analyze & upload flow
      final bool isExistingPostAnalysis =
          widget.postId != null && widget.postId!.isNotEmpty;
      final bool isNewAnalyzeAndUpload =
          widget.battleId != null && !isExistingPostAnalysis;

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
      await geminiService.addAnalyzedMealToDaily(
        mealId: finalMealId,
        userId: userService.userId ?? '',
        mealType: mealType,
        analysisResult: _editableAnalysis,
      );

      setState(() {
        _hasCreatedMeal = true;
      });

      // Handle post creation for new analyze & upload flow
      if (isNewAnalyzeAndUpload) {
        try {
          // Upload image to battle storage
          String battleImageUrl;
          if (widget.isMainPost == true) {
            // For main posts, upload normally
            battleImageUrl = downloadUrl; // Use the same uploaded image
          } else {
            // For battle posts, upload to battle storage
            battleImageUrl = await BattleService.instance.uploadBattleImage(
              battleId: widget.battleId!,
              userId: userService.userId ?? '',
              imageFile: widget.imageFile,
            );
          }

          // Create the post using the mealId as the postId for proper linking
          final post = Post(
            id: finalMealId, // Use mealId as postId for proper linking
            mealId: finalMealId, // Link the post to the meal
            userId: userService.userId ?? '',
            mediaPaths: [battleImageUrl],
            name: userService.currentUser.value?.displayName ?? '',
            category: widget.selectedCategory ?? 'general',
            isBattle: widget.isMainPost == true ? false : true,
            battleId: widget.isMainPost == true ? '' : widget.battleId!,
            isVideo: false,
          );

          // Upload the post
          if (widget.isMainPost == true) {
            await postController
                .uploadPost(post, userService.userId ?? '', [battleImageUrl]);
          } else {
            await BattleService.instance.uploadBattleImages(post: post);
          }

          // Show success message
          showTastySnackbar(
            'Success!',
            'Food analyzed, meal added to your ${mealType.toLowerCase()}, and post uploaded!',
            context,
            backgroundColor: kAccent,
          );

          // Navigate to appropriate screen
          if (widget.isMainPost == true) {
            Get.to(() => const BottomNavSec(selectedIndex: 2));
          } else {
            // Go back to the previous screen
            Navigator.of(context).pop();
            Navigator.of(context).pop(); // Go back to battle screen
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

        // Navigate back to the previous screen
        Navigator.of(context).pop();
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
            _validateNutrition();
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
      totalNutrition['calories'] = (totalNutrition['calories'] as double) +
          _parseNumeric(nutrition['calories']);
      totalNutrition['protein'] = (totalNutrition['protein'] as double) +
          _parseNumeric(nutrition['protein']);
      totalNutrition['carbs'] = (totalNutrition['carbs'] as double) +
          _parseNumeric(nutrition['carbs']);
      totalNutrition['fat'] =
          (totalNutrition['fat'] as double) + _parseNumeric(nutrition['fat']);
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

  /// Validate nutrition consistency and macro calculations
  void _validateNutrition() {
    final totalNutrition =
        _editableAnalysis['totalNutrition'] as Map<String, dynamic>;
    final calories = _parseNumeric(totalNutrition['calories']);
    final protein = _parseNumeric(totalNutrition['protein']);
    final carbs = _parseNumeric(totalNutrition['carbs']);
    final fat = _parseNumeric(totalNutrition['fat']);

    // Calculate calories from macros (protein: 4 cal/g, carbs: 4 cal/g, fat: 9 cal/g)
    final calculatedCalories = (protein * 4) + (carbs * 4) + (fat * 9);
    final caloriesDifference = (calories - calculatedCalories).abs();

    // Allow 10% tolerance for rounding and estimation errors
    final tolerance = calories * 0.1;

    setState(() {
      if (caloriesDifference > tolerance && caloriesDifference > 50) {
        _showNutritionWarning = true;
        _nutritionWarningMessage =
            'Calories (${calories.round()}) don\'t match macros (${calculatedCalories.round()}). This may affect accuracy.';
      } else {
        _showNutritionWarning = false;
        _nutritionWarningMessage = '';
      }
    });
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

                    // Nutrition Warning (if any)
                    if (_showNutritionWarning)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.orange.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              color: Colors.orange,
                              size: getIconScale(5, context),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _nutritionWarningMessage,
                                style: TextStyle(
                                  color: Colors.orange,
                                  fontSize: getTextScale(3, context),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

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

                    SizedBox(height: getPercentageHeight(1, context)),

                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      child: _isSaving
                          ? const Center(
                              child: CircularProgressIndicator(color: kAccent),
                            )
                          : AppButton(
                              text: 'Add to ${getMealTimeOfDay()}',
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

  @override
  void initState() {
    super.initState();
    final nutrition =
        widget.foodItem['nutritionalInfo'] as Map<String, dynamic>;

    _nameController =
        TextEditingController(text: widget.foodItem['name'] ?? '');
    _weightController = TextEditingController(
        text: widget.foodItem['estimatedWeight']?.toString() ?? '');
    _caloriesController =
        TextEditingController(text: nutrition['calories']?.toString() ?? '0');
    _proteinController =
        TextEditingController(text: nutrition['protein']?.toString() ?? '0');
    _carbsController =
        TextEditingController(text: nutrition['carbs']?.toString() ?? '0');
    _fatController =
        TextEditingController(text: nutrition['fat']?.toString() ?? '0');
  }

  @override
  void dispose() {
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
    updatedItem['estimatedWeight'] = _weightController.text;

    final nutrition = updatedItem['nutritionalInfo'] as Map<String, dynamic>;

    // Use double parsing for better precision, then convert to int for storage
    final calories = double.tryParse(_caloriesController.text) ?? 0.0;
    final protein = double.tryParse(_proteinController.text) ?? 0.0;
    final carbs = double.tryParse(_carbsController.text) ?? 0.0;
    final fat = double.tryParse(_fatController.text) ?? 0.0;

    // Validate macros vs calories
    final calculatedCalories = (protein * 4) + (carbs * 4) + (fat * 9);
    final difference = (calories - calculatedCalories).abs();

    if (difference > calories * 0.15 && difference > 30) {
      // Show warning dialog for significant discrepancies
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          backgroundColor:
              getThemeProvider(context).isDarkMode ? kDarkGrey : kWhite,
          title: const Text('Nutrition Warning'),
          content: Text(
              'The calories (${calories.round()}) don\'t match the calculated calories from macros (${calculatedCalories.round()}). This may affect nutrition accuracy. Do you want to continue?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Edit Again'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _saveValues(
                    updatedItem, nutrition, calories, protein, carbs, fat);
              },
              child: const Text('Save Anyway'),
            ),
          ],
        ),
      );
    } else {
      _saveValues(updatedItem, nutrition, calories, protein, carbs, fat);
    }
  }

  void _saveValues(
      Map<String, dynamic> updatedItem,
      Map<String, dynamic> nutrition,
      double calories,
      double protein,
      double carbs,
      double fat) {
    nutrition['calories'] = calories.round();
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
