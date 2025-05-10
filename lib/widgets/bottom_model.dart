import 'package:flutter/material.dart';

import '../data_models/macro_data.dart';
import '../data_models/meal_model.dart';
import '../pages/spinwheelpop.dart';

void showSpinWheel(
  BuildContext context,
  String type,
  List<MacroData> ingredientList,
  List<Meal> mealList,
  List<String> macroList,
  String selectedCategory,
  bool bool,
) {
  showModalBottomSheet(
    context: context,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.only(
        topLeft: Radius.circular(30),
        topRight: Radius.circular(30),
      ),
    ),
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext context) {
      return ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(30),
            topRight: Radius.circular(30),
          ),
          child: Container(
              height: MediaQuery.of(context).size.height * 0.90,
              color: Colors.white,
              child: SpinWheelPop(
                // macro: type,
                ingredientList: ingredientList,
                mealList: mealList,
                macroList: macroList,
                selectedCategory: selectedCategory,
              )));
    },
  );
}
