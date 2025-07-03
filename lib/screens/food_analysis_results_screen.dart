import 'dart:io';
import 'package:flutter/material.dart';

import '../constants.dart';
import '../helper/helper_functions.dart';
import '../helper/utils.dart';
import '../widgets/primary_button.dart';

class FoodAnalysisResultsScreen extends StatefulWidget {
  final File imageFile;
  final Map<String, dynamic> analysisResult;
  final String? postId;

  const FoodAnalysisResultsScreen({
    super.key,
    required this.imageFile,
    required this.analysisResult,
    this.postId = '',
  });

  @override
  State<FoodAnalysisResultsScreen> createState() =>
      _FoodAnalysisResultsScreenState();
}

class _FoodAnalysisResultsScreenState extends State<FoodAnalysisResultsScreen> {
  late Map<String, dynamic> _editableAnalysis;
  bool _isSaving = false;
  bool _hasCreatedMeal = false;

  @override
  void initState() {
    super.initState();
    _editableAnalysis = Map<String, dynamic>.from(widget.analysisResult);
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

      // Create meal from analysis only
      await geminiService.createMealFromAnalysis(
        analysisResult: _editableAnalysis,
        userId: tastyId,
        mealType: mealType,
        imagePath: downloadUrl,
        mealId: widget.postId?.isNotEmpty == true ? widget.postId : null,
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

      // Create meal from analysis
      final mealId = await geminiService.createMealFromAnalysis(
        analysisResult: _editableAnalysis,
        userId: tastyId,
        mealType: mealType,
        imagePath: downloadUrl,
        mealId: widget.postId?.isNotEmpty == true ? widget.postId : null,
      );

      // Add to daily meals
      await geminiService.addAnalyzedMealToDaily(
        mealId: mealId,
        userId: userService.userId ?? '',
        mealType: mealType,
        analysisResult: _editableAnalysis,
      );

      setState(() {
        _hasCreatedMeal = true;
      });

      // Show success message
      showTastySnackbar(
        'Success!',
        'Food analyzed and added to your ${mealType.toLowerCase()} meals.',
        context,
        backgroundColor: kAccent,
      );

      // Navigate back to the previous screen
      Navigator.of(context).pop();
    } catch (e) {
      _showErrorDialog('Failed to save analysis: $e');
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

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
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
      'calories': 0,
      'protein': 0,
      'carbs': 0,
      'fat': 0,
      'fiber': 0,
      'sugar': 0,
      'sodium': 0,
    };

    for (final item in foodItems) {
      final nutrition = item['nutritionalInfo'] as Map<String, dynamic>;
      totalNutrition['calories'] = (totalNutrition['calories'] as int) +
          (nutrition['calories'] as int? ?? 0);
      totalNutrition['protein'] = (totalNutrition['protein'] as int) +
          (nutrition['protein'] as int? ?? 0);
      totalNutrition['carbs'] =
          (totalNutrition['carbs'] as int) + (nutrition['carbs'] as int? ?? 0);
      totalNutrition['fat'] =
          (totalNutrition['fat'] as int) + (nutrition['fat'] as int? ?? 0);
      totalNutrition['fiber'] =
          (totalNutrition['fiber'] as int) + (nutrition['fiber'] as int? ?? 0);
      totalNutrition['sugar'] =
          (totalNutrition['sugar'] as int) + (nutrition['sugar'] as int? ?? 0);
      totalNutrition['sodium'] = (totalNutrition['sodium'] as int) +
          (nutrition['sodium'] as int? ?? 0);
    }

    _editableAnalysis['totalNutrition'] = totalNutrition;
  }

  Widget _buildNutritionCard({
    required String title,
    required String value,
    required String unit,
    required Color color,
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
          Text(
            value,
            style: TextStyle(
              fontSize: getTextScale(4, context),
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
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
                        ),
                        _buildNutritionCard(
                          title: 'Protein',
                          value: '${totalNutrition['protein'] ?? 0}',
                          unit: 'grams',
                          color: Colors.blue,
                        ),
                        _buildNutritionCard(
                          title: 'Carbs',
                          value: '${totalNutrition['carbs'] ?? 0}',
                          unit: 'grams',
                          color: Colors.green,
                        ),
                        _buildNutritionCard(
                          title: 'Fat',
                          value: '${totalNutrition['fat'] ?? 0}',
                          unit: 'grams',
                          color: Colors.purple,
                        ),
                      ],
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
                                  'Weight: ${foodItem['estimatedWeight'] ?? 'Unknown'}g',
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
    nutrition['calories'] = int.tryParse(_caloriesController.text) ?? 0;
    nutrition['protein'] = int.tryParse(_proteinController.text) ?? 0;
    nutrition['carbs'] = int.tryParse(_carbsController.text) ?? 0;
    nutrition['fat'] = int.tryParse(_fatController.text) ?? 0;

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
