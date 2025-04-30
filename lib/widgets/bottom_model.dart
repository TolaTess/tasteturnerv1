import 'package:flutter/material.dart';

import '../data_models/macro_data.dart';
import '../data_models/meal_model.dart';
import '../pages/daily_info_page.dart';
import '../pages/spinwheelpop.dart';
import '../pages/update_steps.dart';

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

void showModel(BuildContext context, String title, double total, double current,
    bool isWaterorSteps, ValueNotifier<double> currentValue) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    useSafeArea: true,
    builder: (BuildContext context) {
      return Container(
        decoration: const BoxDecoration(
          color: Colors.transparent, // Ensure transparency
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(30),
            topRight: Radius.circular(30),
          ),
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(30),
            topRight: Radius.circular(30),
          ),
          child: SizedBox(
            child: isWaterorSteps
                ? DailyFoodPage(
                    total: total,
                    current: current,
                    currentNotifier: currentValue,
                    title: 'Update $title',
                  )
                : UpdateStepsModal(
                    total: total,
                    current: current,
                    title: title,
                    isHealthSynced: isWaterorSteps,
                    currentNotifier: currentValue,
                  ),
          ),
        ),
      );
    },
  );
}
