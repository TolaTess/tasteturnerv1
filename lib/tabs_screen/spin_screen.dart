import 'package:flutter/material.dart';

import '../constants.dart';
import '../data_models/macro_data.dart';
import '../data_models/meal_model.dart';
import '../pages/spinwheelpop.dart';

class SpinScreen extends StatefulWidget {
  SpinScreen({
    super.key,
  });

  @override
  State<SpinScreen> createState() => _SpinScreenState();
}

class _SpinScreenState extends State<SpinScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  List<MacroData> ingredientList = [];
  List<Meal> mealList = [];
  List<String> macroList = [];
  String selectedCategory = 'all';

  @override
  void initState() {
    super.initState();
    _fetchData();
    _controller = AnimationController(vsync: this);
  }

  Future<void> _fetchData() async {
    final ingredients = await macroManager.getIngredientsByCategory('all');
    final uniqueTypes = await macroManager.getUniqueTypes(ingredients);
    final mealListData = await mealManager.fetchMealsByCategory('all');
    if (mounted) {
      setState(() {
        ingredientList = ingredients;
        macroList = uniqueTypes;
        mealList = mealListData;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SpinWheelPop(
      ingredientList: ingredientList,
      mealList: mealList,
      macroList: macroList,
      selectedCategory: selectedCategory,
    );
  }
}
