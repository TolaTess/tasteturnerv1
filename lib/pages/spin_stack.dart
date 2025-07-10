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
import '../widgets/loading_screen.dart';
import '../widgets/primary_button.dart';
import '../widgets/spinning_math.dart';

class SpinWheelWidget extends StatefulWidget {
  final List<MacroData> labels;
  final List<Meal>? mealList;
  final List<String>? customLabels; // Custom ingredient list
  final StreamController<int>? spinController;
  final bool isMealSpin;
  final VoidCallback playSound;
  final VoidCallback stopSound;
  final bool funMode;

  SpinWheelWidget({
    super.key,
    required this.labels,
    this.customLabels,
    this.spinController,
    this.mealList,
    this.isMealSpin = false,
    required this.playSound,
    required this.stopSound,
    this.funMode = false,
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
      final BuildContext currentContext = context;

      Future.microtask(() async {
        try {
          // If customLabel is not empty, show a different snackbar and skip saving
          if (widget.customLabels != null &&
              widget.customLabels!.isNotEmpty &&
              widget.funMode) {
            if (!widget.isMealSpin) {
              showTastySnackbar(
                'Not Saved',
                'Hope it was a fun spin.',
                currentContext,
              );
            }
            return;
          }

          final List<MacroData> ingredientList =
              await macroManager.fetchAndEnsureIngredientsExist(acceptedItems);

          await macroManager.saveShoppingList(ingredientList);

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

  Future<void> removeFromShoppingList(String userId, MacroData item) async {
    try {
      if (item.id == null) {
        print("Cannot remove item with null ID");
        return;
      }

      final currentWeek = getCurrentWeek();
      final userMealsRef = firestore
          .collection('userMeals')
          .doc(userId)
          .collection('shoppingList')
          .doc('week_$currentWeek');

      // Remove the ingredient id from the map
      await userMealsRef.set({
        'items': {item.id!: FieldValue.delete()},
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print("Error removing item from shopping list: $e");
      throw Exception("Failed to remove item from shopping list");
    }
  }

  // Add method to fetch shopping list for a specific week
  Future<Map<String, bool>> fetchShoppingListForWeekWithStatus(
      String userId, int week,
      [int? year]) async {
    try {
      year ??= DateTime.now().year;
      final userMealsRef = firestore
          .collection('userMeals')
          .doc(userId)
          .collection('shoppingList')
          .doc('week_$week');

      final docSnapshot = await userMealsRef.get();

      if (!docSnapshot.exists) {
        print("No shopping list found for week $week of year $year.");
        return {};
      }

      final data = docSnapshot.data();
      if (data != null && data['items'] != null && data['year'] == year) {
        final Map<String, dynamic> itemsMap =
            Map<String, dynamic>.from(data['items']);
        final Map<String, bool> statusMap =
            itemsMap.map((key, value) => MapEntry(key, value == true));
        return statusMap;
      }

      return {};
    } catch (e) {
      print("Error fetching shopping list for week $week: $e");
      return {};
    }
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
      if (widget.customLabels == null || widget.customLabels!.isEmpty) {
        _maintainAvailableLabels();
      }
      selectedLabel = null;
    });
  }

  void _acceptSelectedLabel(String label) {
    setState(() {
      if (!acceptedItems.contains(label)) {
        acceptedItems.add(label);
      }
      availableLabels.remove(label);
      if (widget.customLabels == null || widget.customLabels!.isEmpty) {
        _maintainAvailableLabels();
      }
      selectedLabel = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    final textTheme = Theme.of(context).textTheme;

    // If no labels available, show a message instead of empty wheel
    if (availableLabels.isEmpty) {
      return Center(
        child: Text(
          'No items available',
          style: textTheme.bodyMedium?.copyWith(
              color: isDarkMode ? kWhite : kBlack, fontWeight: FontWeight.w600),
        ),
      );
    }

    return SizedBox(
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width >= 800
                      ? getPercentageWidth(55, context)
                      : getPercentageWidth(65, context),
                  minWidth: getPercentageWidth(45, context),
                ),
                child: WidgetSpinningWheel(
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
                            style: textTheme.displayMedium?.copyWith(
                                color: isDarkMode ? kWhite : kBlack,
                                fontWeight: FontWeight.w500),
                          ),
                          content: Text(
                            capitalizeFirstLetter(label),
                            style: textTheme.bodyMedium?.copyWith(
                                color: isDarkMode ? kBlue : kAccent,
                                fontSize: 25),
                          ),
                          actionsAlignment: MainAxisAlignment.spaceBetween,
                          actions: [
                            AppButton(
                              type: AppButtonType.follow,
                              width: 30,
                              onPressed: () {
                                Navigator.of(context).pop();
                                _tryAgainLabel();
                              },
                              text: "Skip",
                            ),
                            AppButton(
                              type: AppButtonType.follow,
                              width: 30,
                              onPressed: () {
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
              ),
              Positioned(
                top: MediaQuery.of(context).size.width >= 800 ? 58 : 7,
                child: SizedBox(
                  width: getPercentageWidth(6.5, context),
                  height: getPercentageWidth(6.5, context),
                  child: Image.asset(
                    "assets/images/pointer.png",
                    width: getPercentageWidth(10, context),
                    height: getPercentageWidth(10, context),
                    cacheWidth: getPercentageWidth(10, context).toInt(),
                    cacheHeight: getPercentageWidth(10, context).toInt(),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: getProportionalHeight(2, context)),
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

  bool canUseAI() {
    final freeTrialDate = userService.currentUser.value?.freeTrialDate;
    final isFreeTrial =
        freeTrialDate != null && DateTime.now().isBefore(freeTrialDate);
    final isPremium = userService.currentUser.value?.isPremium ?? false;
    return isPremium || isFreeTrial;
  }

  Future<void> _generateMealFromIngredients(displayedItems) async {
    try {
      showDialog(
        context: context,
        builder: (context) => const LoadingScreen(
          loadingText: 'Generating Meal Plan, Please Wait...',
        ),
      );

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
        barrierDismissible: false, // Prevent dismissing during loading
        builder: (context) {
          final isDarkMode = getThemeProvider(context).isDarkMode;
          final textTheme = Theme.of(context).textTheme;
          return StatefulBuilder(
            builder: (context, setState) {
              int? loadingIndex; // Track which item is loading
              bool isProcessing = false; // Global processing state

              return AlertDialog(
                backgroundColor: isDarkMode ? kDarkGrey : kWhite,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                ),
                title: Text(
                  'Select a Meal',
                  style: textTheme.displaySmall?.copyWith(
                      fontSize: getPercentageWidth(7, context),
                      color: kAccent,
                      fontWeight: FontWeight.w500),
                ),
                content: SizedBox(
                  width: double.maxFinite,
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: meals.length,
                    itemBuilder: (context, index) {
                      final meal = meals[index];
                      final title = meal['title'] ?? 'Untitled';
                      final isThisItemLoading = loadingIndex == index;
                      final isDisabled = isProcessing && !isThisItemLoading;

                      String cookingTime = meal['cookingTime'] ?? '';
                      String cookingMethod = meal['cookingMethod'] ?? '';

                      return Card(
                        color: colors[index % colors.length],
                        child: ListTile(
                          enabled: !isProcessing,
                          title: Text(
                            title,
                            style: textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: isDarkMode ? kWhite : kDarkGrey,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (cookingTime.isNotEmpty)
                                Text(
                                  'Cooking Time: $cookingTime',
                                  style: textTheme.bodyMedium?.copyWith(
                                    color: isDarkMode ? kWhite : kDarkGrey,
                                  ),
                                ),
                              if (cookingMethod.isNotEmpty)
                                Text(
                                  'Method: $cookingMethod',
                                  style: textTheme.bodyMedium?.copyWith(
                                    color: isDarkMode ? kWhite : kDarkGrey,
                                  ),
                                ),
                            ],
                          ),
                          onTap: isProcessing
                              ? null
                              : () async {
                                  // Set loading state and show SnackBar
                                  setState(() {
                                    isProcessing = true;
                                    loadingIndex = index;
                                  });

                                  // Show SnackBar with loading message
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Row(
                                        children: [
                                          const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: kWhite,
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: Text(
                                              'Saving "$title" to your calendar...',
                                              style: const TextStyle(
                                                color: kWhite,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      backgroundColor: kAccent,
                                      duration: const Duration(seconds: 10),
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                  );

                                  try {
                                    final userId = userService.userId;
                                    if (userId == null)
                                      throw Exception('User ID not found');
                                    final date = DateFormat('yyyy-MM-dd')
                                        .format(DateTime.now());
                                    // Save all meals first
                                    final List<String> allMealIds =
                                        await saveMealsToFirestore(
                                            userId, mealPlan, '');
                                    final int selectedIndex = meals.indexWhere(
                                        (m) => m['title'] == meal['title']);
                                    final String? selectedMealId =
                                        (selectedIndex != -1 &&
                                                selectedIndex <
                                                    allMealIds.length)
                                            ? allMealIds[selectedIndex]
                                            : null;
                                    // Get existing meals first
                                    final docRef = firestore
                                        .collection('mealPlans')
                                        .doc(userId)
                                        .collection('date')
                                        .doc(date);
                                    // Add new meal ID if not null
                                    if (selectedMealId != null) {
                                      await docRef.set({
                                        'userId': userId,
                                        'dayType': 'chef_tasty',
                                        'isSpecial': true,
                                        'date': date,
                                        'meals': FieldValue.arrayUnion(
                                            [selectedMealId]),
                                      }, SetOptions(merge: true));
                                    }

                                    if (mounted) {
                                      // Hide the SnackBar
                                      ScaffoldMessenger.of(context)
                                          .hideCurrentSnackBar();

                                      // Show success SnackBar
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Successfully saved "$title" to your calendar!',
                                            style: const TextStyle(
                                              color: kWhite,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          backgroundColor: kAccent,
                                          duration: const Duration(seconds: 2),
                                          behavior: SnackBarBehavior.floating,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                        ),
                                      );

                                      Navigator.of(context)
                                          .pop(meal); // Close selection dialog
                                    }
                                  } catch (e) {
                                    // Reset loading state on error
                                    if (mounted) {
                                      // Hide the loading SnackBar
                                      ScaffoldMessenger.of(context)
                                          .hideCurrentSnackBar();

                                      setState(() {
                                        isProcessing = false;
                                        loadingIndex = null;
                                      });

                                      // Show error SnackBar
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Failed to save meal. Please try again.',
                                            style: const TextStyle(
                                              color: kWhite,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          backgroundColor: kRed,
                                          duration: const Duration(seconds: 3),
                                          behavior: SnackBarBehavior.floating,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                        ),
                                      );

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
                    onPressed:
                        isProcessing ? null : () => Navigator.of(context).pop(),
                    child: Text(
                      'Cancel',
                      style: textTheme.bodyLarge?.copyWith(
                        color: isProcessing
                            ? kLightGrey
                            : (isDarkMode ? kWhite : kBlack),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              );
            },
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
    final isDarkMode = getThemeProvider(context).isDarkMode;
    final textTheme = Theme.of(context).textTheme;
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
                return Text('No meals selected',
                    style: textTheme.bodyMedium
                        ?.copyWith(color: isDarkMode ? kWhite : kBlack));
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
                return Text(
                  'No ingredients selected',
                  style: textTheme.bodyMedium
                      ?.copyWith(color: isDarkMode ? kWhite : kBlack),
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
    final textTheme = Theme.of(context).textTheme;
    final freeTrialDate = userService.currentUser.value?.freeTrialDate;
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
                            style: textTheme.displaySmall?.copyWith(
                                color: isDarkMode ? kWhite : kBlack,
                                fontSize: 25),
                          ),
                          Text(
                            'Accepted ${widget.acceptedItems.length == 1 ? 'item' : 'items'}: ',
                            style: textTheme.bodyLarge
                                ?.copyWith(color: isDarkMode ? kWhite : kBlack),
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
                                  horizontal: 4, vertical: 2),
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
                                    style: textTheme.bodyMedium
                                        ?.copyWith(color: kAccentLight),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.close,
                                    size: getIconScale(4, context),
                                    color: kAccentLight,
                                  ),
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
                  style: textTheme.displaySmall?.copyWith(
                      color: isDarkMode ? kWhite : kBlack, fontSize: 25),
                ),
              FloatingActionButton.extended(
                onPressed: () {
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
                      if (canUseAI()) {
                        _generateMealFromIngredients(displayedItems);
                        return;
                      } else {
                        showPremiumRequiredDialog(context, isDarkMode);
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
                backgroundColor:
                    isDarkMode ? kLightGrey : kAccent.withOpacity(0.60),
                foregroundColor: isDarkMode ? kWhite : kBlack,
                elevation: 6,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(5),
                ),
                label: Padding(
                  padding: EdgeInsets.symmetric(
                    vertical: getPercentageHeight(0.5, context),
                    horizontal: getPercentageWidth(1, context),
                  ),
                  child: Text(
                    isMealSpin
                        ? 'Save to Meal Plan'
                        : (userService.currentUser.value?.isPremium ?? false) ||
                                isInFreeTrial
                            ? 'Generate Meal with ingredients!'
                            : 'Go Premium to generate a meal!',
                    style: textTheme.labelLarge?.copyWith(
                        color: isDarkMode ? kWhite : kBlack,
                        fontWeight: FontWeight.w500),
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
