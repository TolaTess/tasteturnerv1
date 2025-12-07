import 'package:flutter/material.dart';

import '../constants.dart';
import '../data_models/meal_model.dart';
import '../helper/utils.dart';
import '../widgets/circle_image.dart';
import '../widgets/icon_widget.dart';

class MealSpinList extends StatefulWidget {
  const MealSpinList({
    super.key,
    required this.mealList,
    this.isMealSpin = false,
  });

  final List<dynamic> mealList;
  final bool isMealSpin;
  @override
  State<MealSpinList> createState() => _MealSpinListState();
}

class _MealSpinListState extends State<MealSpinList> {
  final Set<int> _selectedItems = {}; // Track selected items by index

  void _toggleSelection(int index) {
    setState(() {
      if (_selectedItems.contains(index)) {
        _selectedItems.remove(index);
      } else {
        _selectedItems.add(index);
      }
    });
  }

  Future<void> _saveToMealPlan() async {
    try {
      // Use the indices from `_selectedItems` to get the selected items
      final selectedItems =
          _selectedItems.map((index) => widget.mealList[index]).toList();
      if (selectedItems.isEmpty) {
        if (mounted) {
          showTastySnackbar(
            'Please try again.',
            'No items selected to save!',
            context,
          );
        }
        return;
      }

      // Save the selected items to meal plan
      await mealManager.addMealPlan(
        DateTime.now(),
        selectedItems
            .map(
                (item) => item is Meal ? item.mealId : item['mealId'] as String)
            .toList(),
      );

      // Show snackbar before navigating back to ensure context is still mounted
      if (mounted) {
        showTastySnackbar(
          'Success',
          'Added to meal plan successfully!',
          context,
        );
      }
    } catch (e) {
      if (mounted) {
        showTastySnackbar(
          'Please try again.',
          'Error adding to meal plan: $e',
          context,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: true,
        title: Text('Select items',
            style: textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.w500,
                fontSize: getTextScale(7, context))),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 15.0),
            child: GestureDetector(
              onTap: () async {
                await _saveToMealPlan();
                if (mounted) {
                  Navigator.pop(context);
                }
              },
              child: Padding(
                padding: EdgeInsets.all(getPercentageWidth(1, context)),
                child: IconCircleButton(
                  icon: Icons.save_alt,
                  isColorChange: _selectedItems.isNotEmpty ? true : false,
                  size: kIconSizeMedium,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 15),
              // Shopping list grid
              if (widget.mealList.isEmpty)
                const Center(
                  child: Text('No items available'),
                )
              else
                SizedBox(
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(8.0),
                    itemCount: widget.mealList.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 4,
                      mainAxisSpacing: 4,
                    ),
                    itemBuilder: (context, index) {
                      final item = widget.mealList[index];
                      return IngredientItem(
                        dataSrc: item,
                        isSelected: _selectedItems.contains(index),
                        press: () {
                          _toggleSelection(index);
                        },
                      );
                    },
                  ),
                ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
