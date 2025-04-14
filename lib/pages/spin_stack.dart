import 'dart:async';

import 'package:flutter/material.dart';

import '../constants.dart';
import '../data_models/macro_data.dart';
import '../data_models/meal_model.dart';
import '../helper/utils.dart';
import '../screens/shopping_list.dart';
import '../widgets/circle_image.dart';
import '../widgets/search_button.dart';
import '../widgets/secondary_button.dart';
import '../widgets/spinning_math.dart';

class SpinWheelWidget extends StatefulWidget {
  final List<MacroData> labels;
  final List<Meal>? mealList;
  final List<String>? customLabels; // Custom ingredient list
  final String macro;
  final StreamController<int>? spinController;
  final bool isMealSpin;
  final VoidCallback playSound;

  const SpinWheelWidget({
    super.key,
    required this.labels,
    required this.macro,
    this.customLabels,
    this.spinController,
    this.mealList,
    this.isMealSpin = false,
    required this.playSound,
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

  @override
  void initState() {
    super.initState();
    _updateLabelsBasedOnMacro(widget.macro);
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
            ScaffoldMessenger.of(currentContext).showSnackBar(
              const SnackBar(content: Text('Shopping list saved')),
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
    if (oldWidget.macro != widget.macro ||
        oldWidget.customLabels != widget.customLabels) {
      _updateLabelsBasedOnMacro(widget.macro);
    }
  }

  void _updateLabelsBasedOnMacro(String macro) {
    setState(() {
      if (widget.isMealSpin) {
        availableLabels = widget.customLabels!.toSet().toList();
      } else if (widget.mealList != null && widget.mealList!.isNotEmpty) {
        fullMealList = widget.mealList!.toList();
        isMacroEmpty = fullMealList.isEmpty;
        availableLabels =
            fullMealList.map((meal) => meal.title).take(8).toList();
      } else if (widget.customLabels != null &&
          widget.customLabels!.isNotEmpty) {
        availableLabels = widget.customLabels!.toSet().toList();
      } else {
        fullLabelsList = widget.labels
            .where((item) => item.type.toLowerCase() == macro.toLowerCase())
            .toList();

        isMacroEmpty = fullLabelsList.isEmpty;

        availableLabels =
            fullLabelsList.map((macroData) => macroData.title).take(8).toList();
      }

      _maintainAvailableLabels();
    });
  }

  void _maintainAvailableLabels() {
    // Remove accepted items from available labels
    availableLabels.removeWhere((label) => acceptedItems.contains(label));

    // Try to fill up to 8 labels from fullLabelsList first
    while (availableLabels.length < 8 && fullLabelsList.isNotEmpty) {
      // Find a label that isn't already in availableLabels or acceptedItems
      MacroData? newLabel;
      for (var label in fullLabelsList) {
        if (!acceptedItems.contains(label.title) &&
            !availableLabels.contains(label.title)) {
          newLabel = label;
          break;
        }
      }

      if (newLabel != null && newLabel.title.isNotEmpty) {
        availableLabels.add(newLabel.title);
      } else {
        break;
      }
    }

    // If we still need more labels and have meals available, add from mealList
    if (availableLabels.length < 8 &&
        widget.mealList != null &&
        widget.mealList!.isNotEmpty) {
      for (var meal in widget.mealList!) {
        if (availableLabels.length >= 8) break;

        if (!acceptedItems.contains(meal.title) &&
            !availableLabels.contains(meal.title) &&
            meal.title.isNotEmpty) {
          availableLabels.add(meal.title);
        }
      }
    }
  }

  void _acceptSelectedLabel(String label) {
    setState(() {
      if (!acceptedItems.contains(label)) {
        acceptedItems.add(label);
      }
      availableLabels.remove(label);
      _maintainAvailableLabels();
      selectedLabel = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = getThemeProvider(context).isDarkMode;

    return SizedBox(
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              WidgetSpinningWheel(
                playSound: widget.playSound,
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

  void checkCounter() {
    switch (widget.macro.toLowerCase()) {
      case 'protein':
        proteinCounter++;
        break;
      case 'carbs':
        carbsCounter++;
        break;
      case 'fat':
        fatCounter++;
        break;
      default:
        break;
    }
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
  bool isEdit = false;

  void _toggleEdit() {
    setState(() {
      isEdit = !isEdit;
    });
  }

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
                  // Convert the items to the appropriate type before passing to ShoppingListScreen
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ShoppingListScreen(
                        shoppingList: processedItems,
                        isMealSpin: isMealSpin,
                      ),
                    ),
                  );
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
