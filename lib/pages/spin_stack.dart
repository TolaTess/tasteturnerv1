import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:tasteturner/widgets/ingredient_features.dart';

import '../constants.dart';
import '../data_models/macro_data.dart';
import '../data_models/meal_model.dart';
import '../helper/helper_functions.dart';
import '../helper/utils.dart';
import '../screens/shopping_list.dart';
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

          // removed mounted check so it can show even if widget is disposed
          if (!widget.isMealSpin) {
            showTastySnackbar(
              'Success',
              'Items added to your shopping list',
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
      final random = Random();
      if (widget.isMealSpin) {
        if (widget.customLabels != null) {
          final customList = widget.customLabels!.toSet().toList();
          customList.shuffle(random);
          availableLabels = customList.take(10).toList();
        } else if (widget.mealList != null && widget.mealList!.isNotEmpty) {
          fullMealList = widget.mealList!.toList();
          isMacroEmpty = fullMealList.isEmpty;
          final mealTitles = fullMealList.map((meal) => meal.title).toList();
          mealTitles.shuffle(random);
          availableLabels = mealTitles.take(10).toList();
        }
      } else if (widget.customLabels != null &&
          widget.customLabels!.isNotEmpty) {
        final customList = widget.customLabels!.toSet().toList();
        customList.shuffle(random);
        availableLabels = customList.take(10).toList();
      } else {
        fullLabelsList = widget.labels;
        isMacroEmpty = fullLabelsList.isEmpty;
        final macroTitles =
            fullLabelsList.map((macroData) => macroData.title).toList();
        macroTitles.shuffle(random);
        availableLabels = macroTitles.take(10).toList();
      }

      // Ensure we don't have empty labels
      availableLabels.removeWhere((label) => label.trim().isEmpty);
    });
  }

  void _maintainAvailableLabels() {
    availableLabels.removeWhere((label) => acceptedItems.contains(label));

    while (availableLabels.length < 10 && fullLabelsList.isNotEmpty) {
      MacroData? newLabel = fullLabelsList.firstWhere(
        (item) =>
            !acceptedItems.contains(item.title) &&
            !availableLabels.contains(item.title),
      );

      if (newLabel.title.isNotEmpty) {
        availableLabels.add(newLabel.title);
      } else {
        break;
      }
    }
  }

  void _tryAgainLabel() {
    setState(() {
      availableLabels.remove(selectedLabel);
      _maintainAvailableLabels();
      selectedLabel = null;
    });
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
                              _tryAgainLabel();
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
                size: getPercentageWidth(70, context),
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

  // Helper method to show loading dialog
  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => noItemTastyWidget(
          'Generating Meal Plan, Please Wait...', '', context, false, ''),
    );
  }

  // Prepare the prompt for Gemini
  Future<void> _generateMealFromIngredients(displayedItems) async {
    try {
      // Show loading indicator
      _showLoadingDialog();

      // Prepare prompt and generate meal plan
      final mealPlan = await geminiService.generateMealFromIngredients(
        displayedItems.map((item) => item.title).join(', '),
      );

      // Hide loading dialog before showing selection
      if (mounted) Navigator.of(context).pop();

      final meals = mealPlan['meals'] as List<dynamic>? ?? [];
      if (meals.isEmpty) throw Exception('No meals generated');

      // Show dialog to let user pick one meal
      final selectedMeal = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (context) {
          final isDarkMode = getThemeProvider(context).isDarkMode;
          return AlertDialog(
            backgroundColor: isDarkMode ? kDarkGrey : kWhite,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(30),
                topRight: Radius.circular(30),
              ),
            ),
            title: Text('Select a Meal',
                style: TextStyle(color: isDarkMode ? kWhite : kBlack)),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: meals.length,
                itemBuilder: (context, index) {
                  final meal = meals[index];
                  final title = meal['title'] ?? 'Untitled';

                  String cookingTime = meal['cookingTime'] ?? '';
                  String cookingMethod = meal['cookingMethod'] ?? '';

                  return Card(
                    color: kAccent,
                    child: ListTile(
                      title: Text(title,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (cookingTime.isNotEmpty)
                            Text('Cooking Time: $cookingTime'),
                          if (cookingMethod.isNotEmpty)
                            Text('Method: $cookingMethod'),
                        ],
                      ),
                      onTap: () async {
                        // Show a loading indicator while saving
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (context) => noItemTastyWidget(
                              'Saving your meal in your calendar...',
                              '',
                              context,
                              false,
                              ''),
                        );
                        await Future.delayed(const Duration(seconds: 5));
                        try {
                          final userId = userService.userId;
                          if (userId == null)
                            throw Exception('User ID not found');
                          final date =
                              DateFormat('yyyy-MM-dd').format(DateTime.now());
                          // Save all meals first
                          final List<String> allMealIds =
                              await saveMealsToFirestore(userId, mealPlan, '');
                          final int selectedIndex = meals
                              .indexWhere((m) => m['title'] == meal['title']);
                          final String? selectedMealId = (selectedIndex != -1 &&
                                  selectedIndex < allMealIds.length)
                              ? allMealIds[selectedIndex]
                              : null;
                          // Get existing meals first
                          final docRef = firestore
                              .collection('mealPlans')
                              .doc(userId)
                              .collection('date')
                              .doc(date);

                          final docSnapshot = await docRef.get();
                          List<String> existingMealIds = [];
                          if (docSnapshot.exists) {
                            final data = docSnapshot.data();
                            if (data != null && data['meals'] != null) {
                              existingMealIds =
                                  List<String>.from(data['meals']);
                            }
                          }
                          // Add new meal ID if not null
                          if (selectedMealId != null) {
                            existingMealIds.add(selectedMealId);
                          }

                          await docRef.set({
                            'userId': userId,
                            'dayType': 'tasty_spin',
                            'isSpecial': true,
                            'date': date,
                            'meals': existingMealIds,
                          }, SetOptions(merge: true));

                          if (mounted) {
                            Navigator.of(context).pop();
                            Navigator.of(context)
                                .pop(meal); // Close selection dialog
                          }
                        } catch (e) {
                          if (mounted) {
                            Navigator.of(context).pop(); // Hide loading
                            handleError(e, context);
                          }
                        }
                      },
                    ),
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: isDarkMode ? kWhite : kBlack),
                ),
              ),
            ],
          );
        },
      );
      if (selectedMeal == null) return; // User cancelled
    } catch (e) {
      if (mounted) {
        handleError(e, context);
      }
    }
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
                return const Text('No items selected',
                    style: TextStyle(fontSize: 12));
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
                return const Text(
                  'No items selected',
                  style: TextStyle(fontSize: 12),
                );
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
    final freeTrialDate = userService.currentUser?.freeTrialDate;
    final isInFreeTrial =
        freeTrialDate != null && DateTime.now().isBefore(freeTrialDate);

    return Padding(
      padding: EdgeInsets.only(
        left: getPercentageWidth(5, context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          isMealSpin
              ? SizedBox(height: getPercentageHeight(1, context))
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () {
                        if (!isMealSpin && displayedItems is List<MacroData>) {
                          Get.to(
                            () => IngredientFeatures(
                              items: displayedItems,
                            ),
                          );
                        }
                      },
                      child: Row(
                        children: [
                          Text(
                            '${widget.acceptedItems.length} ',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDarkMode ? kWhite : kBlack,
                            ),
                          ),
                          Text(
                            'Accepted ${widget.acceptedItems.length == 1 ? 'item' : 'items'}: ',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w400,
                              color: isDarkMode ? kWhite : kBlack,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: getPercentageHeight(1, context)),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (int i = 0; i < widget.acceptedItems.length; i++)
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                widget.acceptedItems.removeAt(i);
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: kAccentLight.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: kAccentLight),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    capitalizeFirstLetter(
                                        widget.acceptedItems[i]),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.normal,
                                      color: kAccentLight,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.close,
                                      size: 16, color: kAccentLight),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
          SizedBox(height: getPercentageHeight(2, context)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              if (widget.isMealSpin)
                Text(
                  '${widget.acceptedItems.length} ${widget.acceptedItems.length == 1 ? 'meal' : 'meals'} accepted',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: isDarkMode ? kWhite : kBlack,
                  ),
                ),
              GestureDetector(
                onTap: () {
                  if (widget.isMealSpin) {
                    // Convert the items to the appropriate type before passing to ShoppingListScreen
                    Get.to(
                      () => MealSpinList(
                        mealList: displayedItems,
                        isMealSpin: isMealSpin,
                      ),
                    );
                  } else {
                    if (displayedItems.isNotEmpty &&
                        widget.acceptedItems.length > 1) {
                      if ((userService.currentUser?.isPremium ?? false) ||
                          isInFreeTrial) {
                        _generateMealFromIngredients(displayedItems);
                        return;
                      } else {
                        showDialog(
                          context: context,
                          builder: (context) => showPremiumDialog(
                              context,
                              isDarkMode,
                              'Premium Feature',
                              'Upgrade to premium to generate a meal with selected ingredients!'),
                        );
                      }
                    } else {
                      showTastySnackbar(
                        'Try Again',
                        'Please select at least 2 ingredients',
                        context,
                      );
                    }
                  }
                },
                child: Center(
                  child: Container(
                    padding: EdgeInsets.symmetric(
                        vertical: getPercentageHeight(1.2, context),
                        horizontal: getPercentageWidth(3, context)),
                    decoration: BoxDecoration(
                      color:
                          isDarkMode ? kLightGrey : kAccent.withOpacity(0.60),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      isMealSpin
                          ? 'Save to Meal Plan'
                          : 'Generate Meal with Ingredients!',
                      style: TextStyle(
                        fontSize: isMealSpin ? 14 : 12,
                        fontWeight: FontWeight.w500,
                        color: isDarkMode ? kWhite : kBlack,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
