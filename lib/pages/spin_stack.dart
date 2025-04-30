import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../constants.dart';
import '../data_models/macro_data.dart';
import '../data_models/meal_model.dart';
import '../helper/utils.dart';
import '../screens/shopping_list.dart';
import '../widgets/ingredient_features.dart';
import '../widgets/secondary_button.dart';
import '../widgets/spinning_math.dart';

class SpinWheelWidget extends StatefulWidget {
  final List<MacroData> labels;
  final List<Meal>? mealList;
  final List<String>? customLabels; // Custom ingredient list
  final StreamController<int>? spinController;
  final bool isMealSpin;
  final VoidCallback playSound;
  final VoidCallback stopSound;

  SpinWheelWidget({
    super.key,
    required this.labels,
    this.customLabels,
    this.spinController,
    this.mealList,
    this.isMealSpin = false,
    required this.playSound,
    required this.stopSound,
  });

  @override
  _SpinWheelWidgetState createState() => _SpinWheelWidgetState();
}

class _SpinWheelWidgetState extends State<SpinWheelWidget> {
  int proteinCounter = 0;
  int carbsCounter = 0;
  int fatCounter = 0;
  String? selectedLabel;
  bool isMacroEmpty = false;
  List<String> acceptedItems = [];
  List<String> availableLabels = [];
  List<MacroData> fullLabelsList = [];
  List<Meal> fullMealList = [];
  Key _spinningWheelKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    _updateLabels();
  }

  @override
  void dispose() {
    if (acceptedItems.isNotEmpty) {
      // Save the context before disposal
      final BuildContext currentContext = context;

      Future.microtask(() async {
        try {
          final List<MacroData> ingredientList =
              await macroManager.fetchAndEnsureIngredientsExist(acceptedItems);

          await macroManager.saveShoppingList(
            userService.userId ?? '',
            ingredientList,
          );

          // Check if widget is still mounted before showing SnackBar
          if (mounted) {
            showTastySnackbar(
              'Success',
              'Shopping list saved',
              currentContext,
            );
          }
        } catch (e) {
          debugPrint("Error saving shopping list: $e");
        }
      });
    }

    super.dispose();
  }

  @override
  void didUpdateWidget(covariant SpinWheelWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.customLabels != widget.customLabels ||
        oldWidget.mealList != widget.mealList ||
        oldWidget.labels != widget.labels) {
      _updateLabels();
      setState(() {
        _spinningWheelKey = UniqueKey();
      });
    }
  }

  void _updateLabels() {
    setState(() {
      availableLabels = []; // Clear existing labels first

      if (widget.isMealSpin) {
        if (widget.customLabels != null) {
          availableLabels = widget.customLabels!.toSet().toList();
        } else if (widget.mealList != null && widget.mealList!.isNotEmpty) {
          fullMealList = widget.mealList!.toList();
          isMacroEmpty = fullMealList.isEmpty;
          availableLabels =
              fullMealList.map((meal) => meal.title).take(10).toList();
        }
      } else if (widget.customLabels != null &&
          widget.customLabels!.isNotEmpty) {
        availableLabels = widget.customLabels!.toSet().toList();
      } else {
        fullLabelsList = widget.labels;
        isMacroEmpty = fullLabelsList.isEmpty;
        availableLabels = fullLabelsList
            .map((macroData) => macroData.title)
            .take(10)
            .toList();
      }

      // Ensure we don't have empty labels
      availableLabels.removeWhere((label) => label.trim().isEmpty);
    });
  }

  void _acceptSelectedLabel(String label) {
    setState(() {
      if (!acceptedItems.contains(label)) {
        acceptedItems.add(label);
      }
      availableLabels.remove(label);
      selectedLabel = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = getThemeProvider(context).isDarkMode;

    // If no labels available, show a message instead of empty wheel
    if (availableLabels.isEmpty) {
      return Center(
        child: Text(
          'No items available',
          style: TextStyle(
            color: isDarkMode ? kWhite : kBlack,
            fontSize: 16,
          ),
        ),
      );
    }

    return SizedBox(
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              WidgetSpinningWheel(
                key: _spinningWheelKey,
                playSound: widget.playSound,
                stopSound: widget.stopSound,
                labels: availableLabels,
                defaultSpeed: 0.05,
                textStyle: TextStyle(
                  color: isDarkMode ? kWhite : kBlack,
                ),
                colours: [
                  isDarkMode ? kWhite : kBlack,
                ],
                onSpinComplete: (String label) {
                  setState(() {
                    selectedLabel = label;
                  });

                  showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        backgroundColor:
                            isDarkMode ? kDarkGrey : kBackgroundColor,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(30),
                            topRight: Radius.circular(30),
                          ),
                        ),
                        title: Text(
                          "Selected Option",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: isDarkMode ? kWhite : kBlack,
                          ),
                        ),
                        content: Text(
                          capitalizeFirstLetter(label),
                          style: TextStyle(
                            fontSize: 18,
                            color: isDarkMode ? kBlue : kAccent,
                          ),
                        ),
                        actions: [
                          SecondaryButton(
                            press: () {
                              Navigator.of(context).pop();
                            },
                            text: "Try Again",
                          ),
                          SecondaryButton(
                            press: () {
                              Navigator.of(context).pop();
                              _acceptSelectedLabel(label);
                            },
                            text: "Accept",
                          ),
                        ],
                      );
                    },
                  );
                },
                size: 300,
              ),
              Positioned(
                top: -5,
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: Image.asset(
                    "assets/images/pointer.png",
                    width: 83,
                    height: 93,
                    cacheWidth: 83,
                    cacheHeight: 93,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: getPercentageHeight(3, context)),
          AcceptedItemsList(
            acceptedItems: acceptedItems,
            isMealSpin: widget.isMealSpin,
          ),
        ],
      ),
    );
  }
}

class AcceptedItemsList extends StatefulWidget {
  final List<String> acceptedItems;
  final bool isMealSpin;
  const AcceptedItemsList({
    super.key,
    required this.acceptedItems,
    required this.isMealSpin,
  });

  @override
  State<AcceptedItemsList> createState() => _AcceptedItemsListState();
}

class _AcceptedItemsListState extends State<AcceptedItemsList> {
  void removeItem(int index) {
    setState(() {
      widget.acceptedItems.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return widget.isMealSpin
        ? FutureBuilder<List<Meal>>(
            future: mealManager.fetchAndEnsureMealsExist(widget.acceptedItems),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const CircularProgressIndicator(
                  color: kAccent,
                );
              } else if (snapshot.hasError) {
                return Text('Error: ${snapshot.error}');
              } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Text('No items selected');
              } else {
                final displayedItems = snapshot.data!;
                return _buildContent(context, displayedItems, true);
              }
            },
          )
        : FutureBuilder<List<MacroData>>(
            future: macroManager
                .fetchAndEnsureIngredientsExist(widget.acceptedItems),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const CircularProgressIndicator(
                  color: kAccent,
                );
              } else if (snapshot.hasError) {
                return Text('Error: ${snapshot.error}');
              } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Text('No items selected');
              } else {
                final displayedItems = snapshot.data!;
                return _buildContent(context, displayedItems, false);
              }
            },
          );
  }

  Widget _buildContent(
      BuildContext context, dynamic displayedItems, bool isMealSpin) {
    final isDarkMode = getThemeProvider(context).isDarkMode;

    final processedItems = isMealSpin
        ? (displayedItems as List<Meal>)
            .map((meal) => {'mealId': meal.mealId, 'title': meal.title})
            .toList()
        : (displayedItems as List<MacroData>)
            .map((macro) => {'title': macro.title})
            .toList();

    return Padding(
      padding: const EdgeInsets.only(top: 10, left: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              GestureDetector(
                onTap: () {
                  if (widget.isMealSpin) {
                    // Convert the items to the appropriate type before passing to ShoppingListScreen
                    Get.to(
                      () => MealSpinList(
                        mealList: processedItems,
                        isMealSpin: isMealSpin,
                      ),
                    );
                  } else {
                    Get.to(
                      () => IngredientFeatures(
                        items: displayedItems,
                      ),
                    );
                  }
                },
                child: Center(
                  child: Container(
                    padding: EdgeInsets.all(getPercentageHeight(2, context)),
                    decoration: BoxDecoration(
                      color:
                          isDarkMode ? kLightGrey : kAccent.withOpacity(0.60),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      isMealSpin
                          ? 'Save to Meal Plan'
                          : 'Go to Saved ${widget.acceptedItems.length == 1 ? 'item' : 'items'}:',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: isDarkMode ? kWhite : kBlack,
                      ),
                    ),
                  ),
                ),
              ),
              Text(
                '${widget.acceptedItems.length}',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
