import 'dart:async';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:tasteturner/widgets/bottom_nav.dart';
import '../constants.dart';
import '../helper/helper_functions.dart';
import '../helper/utils.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tasteturner/data_models/macro_data.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../service/macro_manager.dart';
import '../widgets/ingredient_features.dart';
import '../widgets/info_icon_widget.dart';
import '../widgets/shopping_list_generate_button.dart';
import '../screens/premium_screen.dart';

class ShoppingTab extends StatefulWidget {
  final bool is54321View;
  const ShoppingTab({super.key, this.is54321View = false});

  @override
  State<ShoppingTab> createState() => _ShoppingTabState();
}

class _ShoppingTabState extends State<ShoppingTab>
    with SingleTickerProviderStateMixin {
  String? _selectedDay;
  bool _is54321View = false;
  bool _isLoading54321 = false;
  bool _isGenerating = false;
  Map<String, dynamic>? _shoppingList54321;
  final RxInt _newItemsCount = 0.obs;
  StreamSubscription? _mealPlansSubscription;
  late TabController _tabController;

  final List<String> _daysOfWeek = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday'
  ];

  final MacroManager _macroManager = Get.find<MacroManager>();

  /// Handle errors with consistent snackbar display
  void _handleError(String message, {String? details}) {
    if (!mounted || !context.mounted) return;
    debugPrint('Error: $message${details != null ? ' - $details' : ''}');
    showTastySnackbar(
      'Error',
      message,
      context,
      backgroundColor: Colors.red,
    );
  }

  /// Show success message with consistent styling
  void _showSuccessMessage(String message) {
    if (!mounted || !context.mounted) return;
    showTastySnackbar(
      'Success',
      message,
      context,
      backgroundColor: kGreen,
    );
  }

  /// Switch to the "From This Week's Menu" tab after generating ingredients
  void _switchToGeneratedSection() {
    if (!mounted) return;
    try {
      if (_tabController.index != 1) {
        _tabController.animateTo(1);
      }
    } catch (e) {
      debugPrint('Error switching to generated section: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadSelectedDay();
    _loadViewPreference();
    _macroManager.fetchIngredients();
    _load54321ShoppingList();
    _checkForNewItems();
    _setupMealPlansListener();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh shopping list when tab becomes visible to ensure latest items are displayed
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final userId = userService.userId;
        if (userId != null) {
          final currentWeek = getCurrentWeek();
          _macroManager.refreshShoppingLists(userId, currentWeek);
        }
      }
    });
  }

  @override
  void dispose() {
    _mealPlansSubscription?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  void _setupMealPlansListener() {
    try {
      final userId = userService.userId;
      if (userId == null) return;

      _mealPlansSubscription?.cancel();

      // Get current week's start and end dates
      final now = DateTime.now();
      final weekStart = getWeekStart(now);
      final weekEnd = weekStart.add(const Duration(days: 6));

      // Format dates as YYYY-MM-DD
      final formatDate = (DateTime date) {
        final y = date.year;
        final m = date.month.toString().padLeft(2, '0');
        final d = date.day.toString().padLeft(2, '0');
        return '$y-$m-$d';
      };

      final startDateStr = formatDate(weekStart);
      final endDateStr = formatDate(weekEnd);

      // Listen to meal plans for the current week
      _mealPlansSubscription = firestore
          .collection('mealPlans')
          .doc(userId)
          .collection('date')
          .where(FieldPath.documentId, isGreaterThanOrEqualTo: startDateStr)
          .where(FieldPath.documentId, isLessThanOrEqualTo: endDateStr)
          .snapshots()
          .listen((snapshot) {
        // When meal plans change, update the count
        if (mounted) {
          _checkForNewItems();
        }
      }, onError: (e) {
        debugPrint('Error listening to meal plans: $e');
        // Non-critical error, don't show to user
      });
    } catch (e) {
      debugPrint('Error setting up meal plans listener: $e');
      // Non-critical error, don't show to user
    }
  }

  Future<void> _loadSelectedDay() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() {
          _selectedDay = prefs.getString('shopping_day');
        });
      }
    } catch (e) {
      debugPrint('Error loading selected day: $e');
      // Non-critical error, don't show to user
    }
  }

  Future<void> _loadViewPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() {
          // If widget.is54321View is true, it should override shared preferences
          _is54321View = widget.is54321View ||
              (prefs.getBool('shopping_54321_view') ?? false);
        });
      }
    } catch (e) {
      debugPrint('Error loading view preference: $e');
      // Non-critical error, don't show to user
    }
  }

  Future<void> _saveViewPreference(bool is54321View) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('shopping_54321_view', is54321View);
      if (mounted) {
        setState(() {
          _is54321View = is54321View;
        });
      }
    } catch (e) {
      debugPrint('Error saving view preference: $e');
      if (mounted && context.mounted) {
        _handleError('Failed to save view preference. Please try again.',
            details: e.toString());
      }
    }
  }

  Future<void> _saveSelectedDay(String day) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('shopping_day', day);
      if (mounted) {
        setState(() {
          _selectedDay = day;
        });
      }

      try {
        await notificationService.cancelScheduledNotification(1001);
      } catch (e) {
        debugPrint('Error canceling notification: $e');
        // Continue even if cancel fails
      }

      int dayIndex = _daysOfWeek.indexOf(day);
      if (dayIndex == -1) {
        throw Exception('Invalid day: $day');
      }
      int weekday = dayIndex + 1;

      try {
        FirebaseAnalytics.instance.logEvent(
          name: 'shopping_day_selected',
          parameters: {'day': day},
        );
      } catch (e) {
        debugPrint('Error logging analytics: $e');
        // Continue even if analytics fails
      }

      try {
        await notificationService.scheduleWeeklyReminder(
          id: 1001,
          title: 'Shopping Reminder',
          body:
              'Today is your shopping day! Don\'t forget to buy your groceries for a healthy week!',
          weekday: weekday,
          hour: 10,
          minute: 0,
        );
      } catch (e) {
        debugPrint('Error scheduling notification: $e');
        if (mounted && context.mounted) {
          _handleError('Failed to schedule reminder. Please try again.',
              details: e.toString());
        }
      }
    } catch (e) {
      debugPrint('Error saving selected day: $e');
      if (mounted && context.mounted) {
        _handleError('Failed to save shopping day. Please try again.',
            details: e.toString());
      }
    }
  }

  Future<void> _load54321ShoppingList() async {
    final userId = userService.userId;
    if (userId == null) {
      debugPrint('54321 Load: No user ID found');
      return;
    }

    try {
      // Use MacroManager instead of GeminiService
      final savedListData = await _macroManager.getLatest54321ShoppingList();
      if (mounted) {
        setState(() {
          _shoppingList54321 = savedListData;
        });
        debugPrint(
            '54321 Load: _shoppingList54321 set to: ${_shoppingList54321 != null ? 'NOT NULL' : 'NULL'}');
        debugPrint(
            '54321 Load: State updated, should show empty: ${_shouldShow54321EmptyState()}');
      }
    } catch (e) {
      debugPrint('Error loading 54321 shopping list: $e');
      if (mounted) {
        setState(() {
          _shoppingList54321 = null;
        });
        if (context.mounted) {
          _handleError('Failed to load 54321 shopping list. Please try again.',
              details: e.toString());
        }
      }
    }
  }

  Future<void> _checkForNewItems() async {
    final userId = userService.userId;
    if (userId == null) return;

    try {
      final weekId = getCurrentWeek();
      final newItemsCount =
          await _macroManager.checkForNewMealPlanItems(userId, weekId);
      // Only update if mounted to prevent disappearing count
      if (mounted) {
        _newItemsCount.value = newItemsCount;
        debugPrint('New meals count: $newItemsCount');
      }
    } catch (e) {
      debugPrint('Error checking for new items: $e');
      if (mounted) {
        _newItemsCount.value = 0;
      }
    }
  }

  void _showRemoveAllDialog(
      BuildContext context, bool isDarkMode, bool isManual, bool isGenerated) {
    final sectionTitle = isManual ? 'Added Manually' : 'From Your Meal Plan';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: isDarkMode ? kDarkGrey : kWhite,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: Text(
            'Clear All Items',
            style: TextStyle(
              color: isDarkMode ? kWhite : kBlack,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Text(
            'Are you sure you want to clear all items from "$sectionTitle", Chef?\n\nThis action cannot be undone.',
            style: TextStyle(
              color: isDarkMode ? kWhite : kBlack,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _removeAllItems(isManual, isGenerated);
              },
              child: Text(
                'Clear All',
                style: TextStyle(color: kRed, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );
  }

  void _removeAllItems(bool isManual, bool isGenerated) async {
    final userId = userService.userId;
    if (userId == null) return;

    final currentWeek = getCurrentWeek();

    try {
      // Remove all items from the appropriate list in Firestore
      final userMealsRef = firestore
          .collection('userMeals')
          .doc(userId)
          .collection('shoppingList')
          .doc(currentWeek);

      final fieldToClear = isManual ? 'manualItems' : 'generatedItems';

      await userMealsRef.set({
        fieldToClear: {},
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Refresh the shopping lists after bulk deletion
      await _macroManager.refreshShoppingLists(userId, currentWeek);

      // Show success message
      if (mounted && context.mounted) {
        _showSuccessMessage(
            'All items cleared from ${isManual ? 'Chef\'s Selection' : 'Menu'} list');
      }
    } catch (e) {
      debugPrint('Error removing all items: $e');
      if (mounted && context.mounted) {
        _handleError('Failed to remove items. Please try again.',
            details: e.toString());
      }
    }
  }

  Future<void> generate54321ShoppingList() async {
    if (_isLoading54321) return;

    // Check premium access
    if (!canUseAI()) {
      final isDarkMode = getThemeProvider(context).isDarkMode;
      showPremiumRequiredDialog(context, isDarkMode);
      return;
    }

    if (mounted) {
      setState(() {
        _isLoading54321 = true;
      });
    }

    try {
      debugPrint(
          'Generating new 54321 shopping list using ingredients collection...');

      // Generate and save the new shopping list using MacroManager
      final shoppingListData =
          await _macroManager.generateAndSave54321ShoppingList();
      FirebaseAnalytics.instance.logEvent(name: '54321_shopping');

      if (shoppingListData != null) {
        debugPrint('Successfully generated 54321 shopping list');

        if (mounted) {
          setState(() {
            _shoppingList54321 = shoppingListData;
            _isLoading54321 = false;
          });

          // Show success message
          if (context.mounted) {
            _showSuccessMessage(
                'New 54321 shopping list generated with diet preferences');
          }
        }
      } else {
        throw Exception('Failed to generate shopping list');
      }
    } catch (e) {
      debugPrint('Error generating 54321 shopping list: $e');
      if (mounted) {
        setState(() {
          _isLoading54321 = false;
        });
        if (context.mounted) {
          _handleError('Failed to generate 54321 list. Please try again.',
              details: e.toString());
        }
      }
    }
  }

  void _showDayPicker(BuildContext context, bool isDarkMode) async {
    final textTheme = Theme.of(context).textTheme;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: isDarkMode ? kDarkGrey : kWhite,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(30),
              topRight: Radius.circular(30),
            ),
            boxShadow: [
              BoxShadow(
                color: isDarkMode
                    ? kWhite.withValues(alpha: 0.1)
                    : kBlack.withValues(alpha: 0.2),
                blurRadius: 20,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle
                Container(
                  margin: EdgeInsets.only(
                    top: getPercentageHeight(1, context),
                    bottom: getPercentageHeight(1, context),
                  ),
                  width: getPercentageWidth(10, context),
                  height: getPercentageHeight(0.3, context),
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? kLightGrey.withValues(alpha: 0.5)
                        : kDarkGrey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),

                // Title
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: getPercentageWidth(5, context),
                    vertical: getPercentageHeight(1, context),
                  ),
                  child: Text(
                    'Select Shopping Day',
                    style: textTheme.displaySmall?.copyWith(
                      fontSize: getTextScale(6, context),
                      fontWeight: FontWeight.w600,
                      color: isDarkMode ? kWhite : kBlack,
                    ),
                  ),
                ),

                SizedBox(height: getPercentageHeight(1, context)),

                // Days list
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: getPercentageWidth(4, context),
                    vertical: getPercentageHeight(1, context),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: _daysOfWeek.map((day) {
                      final isSelected = _selectedDay == day;
                      final dayIcon = _getDayIcon(day);

                      return GestureDetector(
                        onTap: () {
                          Navigator.pop(ctx);
                          _saveSelectedDay(day);
                        },
                        child: Container(
                          margin: EdgeInsets.only(
                            bottom: getPercentageHeight(1, context),
                          ),
                          padding: EdgeInsets.symmetric(
                            horizontal: getPercentageWidth(4, context),
                            vertical: getPercentageHeight(2, context),
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? kAccent.withValues(alpha: 0.15)
                                : isDarkMode
                                    ? kDarkGrey.withValues(alpha: 0.5)
                                    : kAccentLight.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected
                                  ? kAccent
                                  : isDarkMode
                                      ? kLightGrey.withValues(alpha: 0.2)
                                      : kAccent.withValues(alpha: 0.2),
                              width: isSelected ? 2 : 1,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: kAccent.withValues(alpha: 0.2),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Row(
                            children: [
                              // Day icon
                              Container(
                                padding: EdgeInsets.all(
                                  getPercentageWidth(2.5, context),
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? kAccent.withValues(alpha: 0.2)
                                      : isDarkMode
                                          ? kLightGrey.withValues(alpha: 0.1)
                                          : kAccent.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  dayIcon,
                                  color: isSelected
                                      ? kAccent
                                      : isDarkMode
                                          ? kLightGrey
                                          : kAccent.withValues(alpha: 0.7),
                                  size: getIconScale(5, context),
                                ),
                              ),

                              SizedBox(width: getPercentageWidth(3, context)),

                              // Day name
                              Expanded(
                                child: Text(
                                  day,
                                  style: textTheme.titleLarge?.copyWith(
                                    fontSize: getTextScale(4.5, context),
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                                    color: isSelected
                                        ? kAccent
                                        : isDarkMode
                                            ? kWhite
                                            : kBlack,
                                  ),
                                ),
                              ),

                              // Check icon
                              if (isSelected)
                                Container(
                                  padding: EdgeInsets.all(
                                    getPercentageWidth(1.5, context),
                                  ),
                                  decoration: BoxDecoration(
                                    color: kAccent,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.check,
                                    color: kWhite,
                                    size: getIconScale(4, context),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),

                SizedBox(height: getPercentageHeight(2, context)),
              ],
            ),
          ),
        );
      },
    );
  }

  IconData _getDayIcon(String day) {
    switch (day.toLowerCase()) {
      case 'monday':
        return Icons.calendar_today;
      case 'tuesday':
        return Icons.event;
      case 'wednesday':
        return Icons.calendar_month;
      case 'thursday':
        return Icons.date_range;
      case 'friday':
        return Icons.today;
      case 'saturday':
        return Icons.weekend;
      case 'sunday':
        return Icons.wb_sunny;
      default:
        return Icons.calendar_today;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        automaticallyImplyLeading: true,
        toolbarHeight: getPercentageHeight(10, context),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Market List',
              style: textTheme.displaySmall?.copyWith(
                fontSize: getTextScale(7, context),
              ),
            ),
            SizedBox(width: getPercentageWidth(2, context)),
            const InfoIconWidget(
              title: 'Market List',
              description: 'Create and manage your market inventory',
              details: [
                {
                  'icon': Icons.shopping_cart,
                  'title': 'Smart Lists',
                  'description': 'Generated lists based on your meal plans',
                  'color': kAccentLight,
                },
                {
                  'icon': Icons.add_shopping_cart,
                  'title': 'Add Items',
                  'description': 'Manually add items to your market list',
                  'color': kAccentLight,
                },
                {
                  'icon': Icons.add_shopping_cart,
                  'title': 'Market Day',
                  'description': 'Set your market day and get reminders',
                  'color': kAccentLight,
                },
                {
                  'icon': Icons.check_circle,
                  'title': 'Track Purchases',
                  'description': 'Check off items as you shop',
                  'color': kAccentLight,
                },
                {
                  'icon': Icons.grid_view,
                  'title': '54321 Method',
                  'description': 'Balanced market lists',
                  'color': kAccentLight,
                },
              ],
              iconColor: kAccentLight,
              tooltip: 'Market List Information',
            ),
          ],
        ),
        actions: [
          // View toggle button
          Padding(
            padding: EdgeInsets.only(right: getPercentageWidth(2, context)),
            child: IconButton(
              onPressed: () => _saveViewPreference(!_is54321View),
              icon: Icon(
                _is54321View ? Icons.list : Icons.grid_view,
                color: kAccent,
                size: getPercentageWidth(6, context),
              ),
              tooltip: _is54321View
                  ? 'Switch to Standard View'
                  : 'Switch to 54321 View',
            ),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage(
              isDarkMode
                  ? 'assets/images/background/imagedark.jpeg'
                  : 'assets/images/background/imagelight.jpeg',
            ),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              isDarkMode
                  ? Colors.black.withOpacity(0.5)
                  : Colors.white.withOpacity(0.5),
              isDarkMode ? BlendMode.darken : BlendMode.lighten,
            ),
          ),
        ),
        child: Column(
          children: [
            // Header card with shopping day and view info
            Padding(
              padding: EdgeInsets.symmetric(
                vertical: getPercentageHeight(1, context),
                horizontal: getPercentageWidth(2.5, context),
              ),
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                color: isDarkMode ? kDarkGrey : kWhite,
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: () => _showDayPicker(context, isDarkMode),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          vertical: getPercentageHeight(1, context),
                          horizontal: getPercentageWidth(3.5, context),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildInfoColumn(
                              context,
                              title: 'Market Day',
                              icon: Icons.edit_calendar,
                              text: _selectedDay ?? 'Select Day',
                              textTheme: textTheme,
                            ),
                            Obx(() => _buildInfoColumn(
                                  context,
                                  title: _is54321View ? 'View' : 'Stock',
                                  icon: _is54321View
                                      ? Icons.grid_view
                                      : Icons.shopping_basket,
                                  text: _is54321View
                                      ? '54321'
                                      : _getItemCountText(),
                                  textTheme: textTheme,
                                )),
                          ],
                        ),
                      ),
                    ),
                    if (!_is54321View) ...[
                      Column(
                        children: [
                          GestureDetector(
                            onTap: () => Get.to(() => IngredientFeatures(
                                  items: macroManager.ingredient,
                                )),
                            child: Text(
                              'View Walk-In Pantry',
                              style: textTheme.displayMedium?.copyWith(
                                fontSize: getTextScale(4, context),
                                fontWeight: FontWeight.normal,
                                color: kAccentLight,
                              ),
                            ),
                          ),
                          SizedBox(height: getPercentageHeight(1, context)),
                          GestureDetector(
                            onTap: () => _saveViewPreference(!_is54321View),
                            child: Text(
                              'Click to view 54321 list',
                              style: textTheme.bodyMedium?.copyWith(
                                color: kAccent,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: getPercentageHeight(1, context)),
                    ],
                  ],
                ),
              ),
            ),

            // 54321 View
            if (_is54321View) ...[
              _build54321View(context, isDarkMode, textTheme),
            ] else ...[
              // Regular shopping list view
              Expanded(
                child: Obx(() {
                  final generatedItems = _macroManager.generatedShoppingList;
                  final manualItems = _macroManager.manualShoppingList;
                  final hasItems =
                      generatedItems.isNotEmpty || manualItems.isNotEmpty;
                  final bothSectionsHaveItems =
                      generatedItems.isNotEmpty && manualItems.isNotEmpty;

                  // If both sections have items, show tabs
                  if (hasItems && bothSectionsHaveItems) {
                    return Column(
                      children: [
                        // Add Generate Button at the top only if there are new meals
                        if (_newItemsCount.value > 0)
                          ShoppingListGenerateButton(
                            isGenerating: _isGenerating,
                            newItemsCount: _newItemsCount,
                            macroManager: _macroManager,
                            onGeneratingStateChanged: (isGenerating) {
                              if (mounted) {
                                setState(() {
                                  _isGenerating = isGenerating;
                                });
                              }
                            },
                            onSuccess: () async {
                              if (mounted) {
                                await _checkForNewItems();
                                // Wait a bit for UI to update, then switch tab
                                await Future.delayed(
                                    const Duration(milliseconds: 500));
                                _switchToGeneratedSection();
                              }
                            },
                          ),
                        // TabBar positioned below the button
                        Container(
                          color: isDarkMode ? kDarkGrey : kWhite,
                          child: TabBar(
                            controller: _tabController,
                            labelColor: kAccent,
                            unselectedLabelColor:
                                isDarkMode ? kLightGrey : kDarkGrey,
                            indicatorColor: kAccent,
                            indicatorWeight: 3,
                            tabs: const [
                              Tab(text: "Selection"),
                              Tab(text: "Menu"),
                            ],
                          ),
                        ),
                        // TabBarView with both sections
                        Expanded(
                          child: TabBarView(
                            controller: _tabController,
                            children: [
                              // Tab 0: Chef's Selection
                              ListView(
                                children: [
                                  _buildSectionHeader(
                                      'Chef\'s Selection', textTheme, context,
                                      isManual: true),
                                  ..._buildConsolidatedList(
                                      manualItems.toList(),
                                      isManual: true),
                                ],
                              ),
                              // Tab 1: From This Week's Menu
                              ListView(
                                children: [
                                  _buildSectionHeader('From This Week\'s Menu',
                                      textTheme, context,
                                      isGenerated: true),
                                  ..._buildConsolidatedList(
                                      generatedItems.toList(),
                                      isManual: false),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }

                  // Single section or empty state - show without tabs (backward compatible)
                  List<Widget> listWidgets = [];

                  if (hasItems) {
                    // Add Generate Button at the top only if there are new meals
                    if (_newItemsCount.value > 0) {
                      listWidgets.add(
                        ShoppingListGenerateButton(
                          isGenerating: _isGenerating,
                          newItemsCount: _newItemsCount,
                          macroManager: _macroManager,
                          onGeneratingStateChanged: (isGenerating) {
                            if (mounted) {
                              setState(() {
                                _isGenerating = isGenerating;
                              });
                            }
                          },
                          onSuccess: () async {
                            if (mounted) {
                              await _checkForNewItems();
                              // If generatedItems becomes available, switch to tab view
                              await Future.delayed(
                                  const Duration(milliseconds: 500));
                              if (_macroManager
                                      .generatedShoppingList.isNotEmpty &&
                                  _macroManager.manualShoppingList.isNotEmpty) {
                                _switchToGeneratedSection();
                              }
                            }
                          },
                        ),
                      );
                    }

                    if (manualItems.isNotEmpty) {
                      listWidgets.add(_buildSectionHeader(
                          'Chef\'s Selection', textTheme, context,
                          isManual: true));
                      listWidgets.addAll(_buildConsolidatedList(
                          manualItems.toList(),
                          isManual: true));
                    }

                    if (generatedItems.isNotEmpty) {
                      listWidgets.add(_buildSectionHeader(
                          'From This Week\'s Menu', textTheme, context,
                          isGenerated: true));
                      listWidgets.addAll(_buildConsolidatedList(
                          generatedItems.toList(),
                          isManual: false));
                    }
                  } else {
                    // Show empty state with manual generation button
                    listWidgets.add(
                      Padding(
                        padding: EdgeInsets.only(
                            top: getPercentageHeight(10, context)),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.shopping_cart_outlined,
                                size: getPercentageWidth(20, context),
                                color: isDarkMode
                                    ? kWhite.withOpacity(0.5)
                                    : kBlack.withOpacity(0.5),
                              ),
                              SizedBox(height: getPercentageHeight(2, context)),
                              Text(
                                'Your market list is empty, Chef!',
                                style: textTheme.titleMedium,
                              ),
                              SizedBox(height: getPercentageHeight(1, context)),
                              GestureDetector(
                                onTap: () => Get.to(
                                    () => BottomNavSec(selectedIndex: 3)),
                                child: Text(
                                  'Chef, how about a spin of the wheel?',
                                  style: textTheme.bodyMedium?.copyWith(
                                      color: kBlue,
                                      decoration: TextDecoration.underline),
                                ),
                              ),
                              SizedBox(height: getPercentageHeight(3, context)),
                              // Only show button if there are new meals
                              if (_newItemsCount.value > 0)
                                ShoppingListGenerateButton(
                                  isGenerating: _isGenerating,
                                  newItemsCount: _newItemsCount,
                                  macroManager: _macroManager,
                                  showInEmptyState: true,
                                  onGeneratingStateChanged: (isGenerating) {
                                    if (mounted) {
                                      setState(() {
                                        _isGenerating = isGenerating;
                                      });
                                    }
                                  },
                                  onSuccess: () async {
                                    if (mounted) {
                                      await _checkForNewItems();
                                    }
                                  },
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }

                  return ListView(
                    children: listWidgets,
                  );
                }),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String isLessThanCategory(String category, int count) {
    final dietPreference =
        userService.currentUser.value?.settings['dietPreference'];
    if (category == 'fruits') {
      return count < 4 ? 'less fruits on ${dietPreference}' : '';
    } else if (category == 'proteins') {
      return count < 3
          ? 'less protein on ${dietPreference}'
          : count > 3
              ? 'more protein on ${dietPreference}'
              : '';
    } else if (category == 'vegetables') {
      return count < 5 ? 'less vegetable on ${dietPreference}' : '';
    } else if (category == 'sauces') {
      return count < 2 ? 'less sauce on ${dietPreference}' : '';
    } else if (category == 'grains') {
      return count < 1 ? 'less grain on ${dietPreference}' : '';
    } else if (category == 'treats') {
      return count < 1 ? 'less treat on ${dietPreference}' : '';
    }
    return '';
  }

  String _getItemCountText() {
    final consolidatedCounts = _getConsolidatedCounts();
    final purchasedCount = consolidatedCounts['purchased'] ?? 0;
    final totalCount = consolidatedCounts['total'] ?? 0;
    return '$purchasedCount / $totalCount';
  }

  bool _shouldShow54321EmptyState() {
    debugPrint(
        '54321 Empty State: Called with _shoppingList54321 = ${_shoppingList54321 != null ? 'NOT NULL' : 'NULL'}');

    // Show empty state if:
    // 1. No shopping list data at all
    if (_shoppingList54321 == null) {
      debugPrint('54321 Empty State: No shopping list data');
      return true;
    }

    // 2. Shopping list data exists but has no actual shopping list content
    final shoppingListData =
        _shoppingList54321!['shoppingList'] as Map<String, dynamic>?;

    // Handle nested shoppingList structure
    Map<String, dynamic>? shoppingList;
    if (shoppingListData != null &&
        shoppingListData.containsKey('shoppingList')) {
      // Nested structure: {shoppingList: {shoppingList: {...}}}
      shoppingList = shoppingListData['shoppingList'] as Map<String, dynamic>?;
    } else {
      // Direct structure: {shoppingList: {...}}
      shoppingList = shoppingListData;
    }

    if (shoppingList == null || shoppingList.isEmpty) {
      return true;
    }

    // 3. Shopping list exists but all categories are empty
    final categories = [
      'vegetables',
      'fruits',
      'proteins',
      'sauces',
      'grains',
      'treats'
    ];
    bool hasAnyItems = false;

    for (final category in categories) {
      final items = shoppingList[category] as List<dynamic>?;
      if (items != null && items.isNotEmpty) {
        hasAnyItems = true;
        break;
      }
    }

    final shouldShowEmpty = !hasAnyItems;
    return shouldShowEmpty;
  }

  Widget _build54321View(
      BuildContext context, bool isDarkMode, TextTheme textTheme) {
    return Expanded(
      child: Column(
        children: [
          // Generate button
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: getPercentageWidth(4, context),
              vertical: getPercentageHeight(1, context),
            ),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading54321
                    ? null
                    : (canUseAI()
                        ? generate54321ShoppingList
                        : () {
                            final isDarkMode =
                                getThemeProvider(context).isDarkMode;
                            showPremiumRequiredDialog(context, isDarkMode);
                          }),
                icon: _isLoading54321
                    ? SizedBox(
                        width: getPercentageWidth(4, context),
                        height: getPercentageWidth(4, context),
                        child: const CircularProgressIndicator(
                          strokeWidth: 2,
                          color: kWhite,
                        ),
                      )
                    : Icon(
                        canUseAI() ? Icons.refresh : Icons.lock,
                        color: kWhite,
                      ),
                label: Text(
                  _isLoading54321
                      ? 'Generating...'
                      : (canUseAI()
                          ? 'Generate 54321 List'
                          : 'Premium Required'),
                  style: textTheme.bodyLarge?.copyWith(
                    color: kWhite,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: canUseAI() ? kAccent : Colors.grey,
                  padding: EdgeInsets.symmetric(
                    vertical: getPercentageHeight(2, context),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),

          // 54321 Shopping List
          Expanded(
            child: _shouldShow54321EmptyState()
                ? _build54321EmptyState(context, isDarkMode, textTheme)
                : _build54321ShoppingList(context, isDarkMode, textTheme),
          ),
        ],
      ),
    );
  }

  Widget _build54321EmptyState(
      BuildContext context, bool isDarkMode, TextTheme textTheme) {
    final hasPremiumAccess = canUseAI();

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            hasPremiumAccess
                ? Icons.shopping_basket_outlined
                : Icons.lock_outline,
            size: getPercentageWidth(15, context),
            color: hasPremiumAccess ? kAccentLight : Colors.grey,
          ),
          SizedBox(height: getPercentageHeight(2, context)),
          Text(
            '54321 Market List',
            style: textTheme.headlineMedium?.copyWith(
              color: hasPremiumAccess ? kAccent : Colors.grey,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: getPercentageHeight(1, context)),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: getPercentageWidth(8, context),
            ),
            child: Text(
              hasPremiumAccess
                  ? 'Generate a balanced market list with:\n• 5 Vegetables\n• 4 Fruits\n• 3 Proteins\n• 2 Sauces/Spreads\n• 1 Grain\n• 1 Fun Treat'
                  : 'Upgrade to Premium to unlock AI-powered 54321 market lists!\n\nGet personalized, balanced market lists tailored to your dietary preferences and family needs.',
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: isDarkMode ? kLightGrey : kDarkGrey,
                height: 1.5,
              ),
            ),
          ),
          if (!hasPremiumAccess) ...[
            SizedBox(height: getPercentageHeight(3, context)),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const PremiumScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: kAccent,
                padding: EdgeInsets.symmetric(
                  horizontal: getPercentageWidth(6, context),
                  vertical: getPercentageHeight(1.5, context),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Upgrade to Premium',
                style: textTheme.bodyLarge?.copyWith(
                  color: kWhite,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _build54321ShoppingList(
      BuildContext context, bool isDarkMode, TextTheme textTheme) {
    final shoppingListData =
        _shoppingList54321!['shoppingList'] as Map<String, dynamic>;

    // Handle nested shoppingList structure
    Map<String, dynamic> shoppingList;
    if (shoppingListData.containsKey('shoppingList')) {
      // Nested structure: {shoppingList: {shoppingList: {...}}}
      shoppingList = shoppingListData['shoppingList'] as Map<String, dynamic>;
    } else {
      // Direct structure: {shoppingList: {...}}
      shoppingList = shoppingListData;
    }

    final tips = _shoppingList54321!['tips'] as List<dynamic>? ?? [];
    final mealIdeas = _shoppingList54321!['mealIdeas'] as List<dynamic>? ?? [];
    final estimatedCost = _shoppingList54321!['estimatedCost'] as String? ?? '';
    final generatedAt = _shoppingList54321!['generatedAt'] as String?;

    // Format the generation date
    String formattedDate = '';
    if (generatedAt != null) {
      try {
        final date = DateTime.parse(generatedAt);
        formattedDate = DateFormat('MMM dd, yyyy \'at\' h:mm a').format(date);
      } catch (e) {
        formattedDate = 'Recently generated';
      }
    }

    return ListView(
      padding: EdgeInsets.symmetric(
        horizontal: getPercentageWidth(2, context),
      ),
      children: [
        // Generation date card
        if (formattedDate.isNotEmpty)
          Card(
            color: isDarkMode
                ? kLightGrey.withValues(alpha: 0.2)
                : kWhite.withValues(alpha: 0.9),
            child: Padding(
              padding: EdgeInsets.all(getPercentageWidth(3, context)),
              child: Row(
                children: [
                  Icon(Icons.schedule,
                      color: kAccent, size: getPercentageWidth(5, context)),
                  SizedBox(width: getPercentageWidth(2, context)),
                  Expanded(
                    child: Text(
                      'Generated: $formattedDate',
                      style: textTheme.bodyMedium?.copyWith(
                        color: isDarkMode ? kWhite : kBlack,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        // Cost estimate card
        if (estimatedCost.isNotEmpty)
          Card(
            color: isDarkMode
                ? kLightGrey.withValues(alpha: 0.2)
                : kWhite.withValues(alpha: 0.9),
            child: Padding(
              padding: EdgeInsets.all(getPercentageWidth(3, context)),
              child: Row(
                children: [
                  Icon(Icons.money,
                      color: kAccent, size: getPercentageWidth(5, context)),
                  SizedBox(width: getPercentageWidth(2, context)),
                  Text(
                    'Estimated Cost: ${estimatedCost.replaceAll('\$', '')}',
                    style: textTheme.bodyLarge?.copyWith(
                      color: kAccent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Shopping categories
        ..._build54321Categories(context, isDarkMode, textTheme, shoppingList),

        // Tips section
        if (tips.isNotEmpty) ...[
          SizedBox(height: getPercentageHeight(2, context)),
          _buildSectionHeader('Market Tips', textTheme, context),
          ...tips.map((tip) =>
              _buildTipCard(context, isDarkMode, textTheme, tip.toString())),
        ],

        // Meal ideas section
        if (mealIdeas.isNotEmpty) ...[
          SizedBox(height: getPercentageHeight(2, context)),
          _buildSectionHeader('Menu Ideas', textTheme, context),
          ...mealIdeas.map((idea) => _buildMealIdeaCard(
              context, isDarkMode, textTheme, idea.toString())),
        ],

        SizedBox(height: getPercentageHeight(7, context)),
      ],
    );
  }

  List<Widget> _build54321Categories(BuildContext context, bool isDarkMode,
      TextTheme textTheme, Map<String, dynamic> shoppingList) {
    final categories = [
      {
        'key': 'vegetables',
        'title': '🥬 Vegetables (5)',
        'color': kAccentLight.withValues(alpha: kMidOpacity)
      },
      {
        'key': 'fruits',
        'title': '🍎 Fruits (4)',
        'color': kPurple.withValues(alpha: kMidOpacity)
      },
      {
        'key': 'proteins',
        'title': '🥩 Proteins (3)',
        'color': kAccent.withValues(alpha: kMidOpacity)
      },
      {
        'key': 'sauces',
        'title': '🧂 Sauces & Spreads (2)',
        'color': kLightGrey.withValues(alpha: kMidOpacity)
      },
      {
        'key': 'grains',
        'title': '🌾 Grains (1)',
        'color': kBlue.withValues(alpha: kMidOpacity)
      },
      {
        'key': 'treats',
        'title': '🍫 Fun Treat (1)',
        'color': kPink.withValues(alpha: kMidOpacity)
      },
    ];

    return categories.map((category) {
      final items = shoppingList[category['key']] as List<dynamic>? ?? [];
      if (items.isEmpty) return const SizedBox.shrink();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: getPercentageHeight(1, context)),
          Row(
            children: [
              _buildSectionHeader(
                  category['title'] as String, textTheme, context),
              if (isLessThanCategory(category['key'] as String, items.length) !=
                  '') ...[
                Text(
                  '- (${isLessThanCategory(category['key'] as String, items.length) != '' ? isLessThanCategory(category['key'] as String, items.length) : ''})',
                  style: textTheme.labelMedium?.copyWith(
                    color: kAccentLight,
                  ),
                ),
              ]
            ],
          ),
          ...items.map((item) => _build54321ItemCard(
                context,
                isDarkMode,
                textTheme,
                item as Map<String, dynamic>,
                category['color'] as Color,
              )),
        ],
      );
    }).toList();
  }

  Widget _build54321ItemCard(
    BuildContext context,
    bool isDarkMode,
    TextTheme textTheme,
    Map<String, dynamic> item,
    Color categoryColor,
  ) {
    final name = item['name'] as String? ?? '';
    final amount = item['amount'] as String? ?? '';
    final notes = item['notes'] as String? ?? '';

    return Card(
      margin: EdgeInsets.symmetric(
        horizontal: getPercentageWidth(2, context),
        vertical: getPercentageHeight(0.5, context),
      ),
      elevation: 1.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: categoryColor.withValues(alpha: 0.3), width: 1),
      ),
      color: isDarkMode ? kDarkGrey : kWhite,
      child: Padding(
        padding: EdgeInsets.all(getPercentageWidth(3, context)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    capitalizeFirstLetter(name),
                    style: textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isDarkMode ? kWhite : kBlack,
                    ),
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: getPercentageWidth(2, context),
                    vertical: getPercentageHeight(0.5, context),
                  ),
                  decoration: BoxDecoration(
                    color: categoryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    amount,
                    style: textTheme.bodyMedium?.copyWith(
                      color: categoryColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            if (notes.isNotEmpty) ...[
              SizedBox(height: getPercentageHeight(0.5, context)),
              Text(
                notes,
                style: textTheme.bodySmall?.copyWith(
                  color: isDarkMode ? kLightGrey : kDarkGrey,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTipCard(
      BuildContext context, bool isDarkMode, TextTheme textTheme, String tip) {
    return Card(
      margin: EdgeInsets.symmetric(
        horizontal: getPercentageWidth(2, context),
        vertical: getPercentageHeight(0.5, context),
      ),
      color: isDarkMode
          ? kLightGrey.withValues(alpha: 0.2)
          : kWhite.withValues(alpha: 0.9),
      child: Padding(
        padding: EdgeInsets.all(getPercentageWidth(3, context)),
        child: Row(
          children: [
            Icon(Icons.lightbulb_outline,
                color: kAccent, size: getPercentageWidth(5, context)),
            SizedBox(width: getPercentageWidth(2, context)),
            Expanded(
              child: Text(
                tip,
                style: textTheme.bodyMedium?.copyWith(
                  color: isDarkMode ? kWhite : kBlack,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMealIdeaCard(
      BuildContext context, bool isDarkMode, TextTheme textTheme, String idea) {
    return Card(
      margin: EdgeInsets.symmetric(
        horizontal: getPercentageWidth(2, context),
        vertical: getPercentageHeight(0.5, context),
      ),
      color: isDarkMode
          ? kLightGrey.withValues(alpha: 0.2)
          : kWhite.withValues(alpha: 0.9),
      child: Padding(
        padding: EdgeInsets.all(getPercentageWidth(3, context)),
        child: Row(
          children: [
            Icon(Icons.restaurant_outlined,
                color: kPrimaryColor, size: getPercentageWidth(5, context)),
            SizedBox(width: getPercentageWidth(2, context)),
            Expanded(
              child: Text(
                idea,
                style: textTheme.bodyMedium?.copyWith(
                  color: isDarkMode ? kWhite : kBlack,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoColumn(BuildContext context,
      {required String title,
      required IconData icon,
      required String text,
      required TextTheme textTheme}) {
    return Column(
      children: [
        Text(
          title,
          style: textTheme.titleLarge?.copyWith(
            fontSize: getTextScale(4.5, context),
            fontWeight: FontWeight.w600,
            color: kAccent,
          ),
        ),
        SizedBox(height: getPercentageHeight(1, context)),
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: getPercentageWidth(3, context),
            vertical: getPercentageHeight(1, context),
          ),
          decoration: BoxDecoration(
            color: kAccent.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: kAccent,
                size: getPercentageWidth(5, context),
              ),
              SizedBox(width: getPercentageWidth(1, context)),
              Text(
                textAlign: TextAlign.center,
                text,
                style: textTheme.bodyMedium?.copyWith(
                  fontSize: getTextScale(4, context),
                  fontWeight: FontWeight.w400,
                  color: kAccent,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(
    String title,
    TextTheme textTheme,
    BuildContext context, {
    bool isManual = false,
    bool isGenerated = false,
  }) {
    final isDarkMode = getThemeProvider(context).isDarkMode;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: getPercentageWidth(4, context),
        vertical: getPercentageHeight(1.5, context),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: textTheme.titleLarge?.copyWith(
              fontSize: getTextScale(4.5, context),
              fontWeight: FontWeight.w400,
              color: kAccent,
            ),
          ),
          if (isManual || isGenerated)
            IconButton(
              onPressed: () => _showRemoveAllDialog(
                  context, isDarkMode, isManual, isGenerated),
              icon: Icon(
                Icons.delete_sweep,
                color: kRed,
                size: getPercentageWidth(5, context),
              ),
              tooltip: 'Remove all items',
            ),
        ],
      ),
    );
  }

  List<Widget> _buildConsolidatedList(List<MacroData> items,
      {required bool isManual}) {
    if (items.isEmpty) {
      return [];
    }

    // Group items by title (case-insensitive)
    final Map<String, List<MacroData>> groupedByTitle = {};
    for (final item in items) {
      final title = item.title.toLowerCase();
      (groupedByTitle[title] ??= []).add(item);
    }

    final List<Widget> widgets = [];

    groupedByTitle.forEach((title, groupedItems) {
      final MacroData displayItem;
      VoidCallback onToggle;

      if (groupedItems.length > 1) {
        // Consolidate item
        final itemsToConsolidate = groupedItems.map((item) {
          return {
            'name': item.title,
            'amount': item.macros['amount'] as String? ?? '',
          };
        }).toList();

        final consolidatedAmounts =
            consolidateGroceryAmounts(itemsToConsolidate);
        final newAmount = consolidatedAmounts[title];

        final templateItem = groupedItems.first;
        // The consolidated item is 'selected' only if all its parts are selected
        final bool isSelected = groupedItems.every((item) => item.isSelected);

        displayItem = templateItem.copyWith(
          macros: {'amount': newAmount ?? ''},
          isSelected: isSelected,
        );

        onToggle = () {
          final newSelectedState = !displayItem.isSelected;
          for (final itemToToggle in groupedItems) {
            // Only update if state is different to avoid redundant writes
            if (itemToToggle.isSelected != newSelectedState) {
              _macroManager.markItemPurchased(
                itemToToggle.id!,
                newSelectedState,
                isManual: isManual,
              );
            }
          }
        };
      } else {
        // Single item, no consolidation needed
        displayItem = groupedItems.first;
        onToggle = () => _macroManager.markItemPurchased(
              displayItem.id!,
              !displayItem.isSelected,
              isManual: isManual,
            );
      }

      // Create the shopping list item
      final shoppingListItem = ShoppingListItem(
        item: displayItem,
        onToggle: onToggle,
      );

      // Wrap in Dismissible for swipe-to-delete functionality
      widgets.add(
        Dismissible(
          key: Key('shopping_item_${displayItem.id ?? displayItem.title}'),
          direction: DismissDirection.endToStart, // Swipe from right to left
          background: Container(
            margin: EdgeInsets.symmetric(
              horizontal: getPercentageWidth(2, context),
              vertical: getPercentageHeight(1, context),
            ),
            decoration: BoxDecoration(
              color: kRed,
              borderRadius: BorderRadius.circular(20.0),
            ),
            alignment: Alignment.centerRight,
            padding: EdgeInsets.only(right: getPercentageWidth(4, context)),
            child: const Icon(
              Icons.delete,
              color: kWhite,
              size: 24,
            ),
          ),
          confirmDismiss: (direction) async {
            // Show confirmation dialog
            return await showDialog<bool>(
                  context: context,
                  builder: (BuildContext context) {
                    final isDarkMode = getThemeProvider(context).isDarkMode;
                    return AlertDialog(
                      backgroundColor: isDarkMode ? kDarkGrey : kWhite,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      title: Text(
                        'Remove Item',
                        style: TextStyle(
                          color: isDarkMode ? kWhite : kBlack,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      content: Text(
                        'Are you sure you want to remove "${displayItem.title}" from your market list, Chef?',
                        style: TextStyle(
                          color: isDarkMode ? kWhite : kBlack,
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: Text(
                            'Cancel',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          child: Text(
                            'Remove',
                            style: TextStyle(color: kRed),
                          ),
                        ),
                      ],
                    );
                  },
                ) ??
                false;
          },
          onDismissed: (direction) {
            _deleteItem(displayItem, groupedItems, isManual);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content:
                    Text('Removed "${displayItem.title}" from market list'),
                backgroundColor: kRed,
                duration: const Duration(seconds: 2),
              ),
            );
          },
          child: shoppingListItem,
        ),
      );
    });

    // Sort widgets alphabetically by item title
    widgets.sort((a, b) {
      String titleA = '';
      String titleB = '';

      // Extract titles from Dismissible widgets
      if (a is Dismissible && a.child is ShoppingListItem) {
        titleA = (a.child as ShoppingListItem).item.title;
      }
      if (b is Dismissible && b.child is ShoppingListItem) {
        titleB = (b.child as ShoppingListItem).item.title;
      }

      return titleA.toLowerCase().compareTo(titleB.toLowerCase());
    });

    return widgets;
  }

  void _deleteItem(
      MacroData displayItem, List<MacroData> groupedItems, bool isManual) {
    try {
      final userId = userService.userId;
      if (userId == null) {
        _handleError('User not found. Please try again.');
        return;
      }

      // Delete all items in the group (for consolidated items)
      for (final itemToDelete in groupedItems) {
        if (itemToDelete.id != null) {
          try {
            _macroManager.removeFromShoppingList(userId, itemToDelete,
                isManual: isManual);
          } catch (e) {
            debugPrint('Error removing item ${itemToDelete.id}: $e');
            // Continue with other items even if one fails
          }
        }
      }
    } catch (e) {
      debugPrint('Error deleting item: $e');
      if (mounted && context.mounted) {
        _handleError('Failed to delete item. Please try again.',
            details: e.toString());
      }
    }
  }

  Map<String, int> _getConsolidatedCounts() {
    final generatedItems = _macroManager.generatedShoppingList;
    final manualItems = _macroManager.manualShoppingList;

    int totalCount = 0;
    int purchasedCount = 0;

    void processList(List<MacroData> items) {
      if (items.isEmpty) return;

      final Map<String, List<MacroData>> groupedByTitle = {};
      for (final item in items) {
        final title = item.title.toLowerCase();
        (groupedByTitle[title] ??= []).add(item);
      }

      totalCount += groupedByTitle.length;

      for (final group in groupedByTitle.values) {
        if (group.every((item) => item.isSelected)) {
          purchasedCount++;
        }
      }
    }

    processList(generatedItems.toList());
    processList(manualItems.toList());

    return {'purchased': purchasedCount, 'total': totalCount};
  }
}

class ShoppingListItem extends StatelessWidget {
  final MacroData item;
  final VoidCallback onToggle;

  const ShoppingListItem({
    super.key,
    required this.item,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isDarkMode = getThemeProvider(context).isDarkMode;
    final String title = capitalizeFirstLetter(item.title);
    final String? amount = item.macros['amount'] as String?;

    final textStyle = textTheme.displayMedium?.copyWith(
      fontWeight: FontWeight.w200,
      fontSize: getTextScale(4, context),
      decoration:
          item.isSelected ? TextDecoration.lineThrough : TextDecoration.none,
      color:
          item.isSelected ? Colors.grey[500] : (isDarkMode ? kWhite : kBlack),
    );

    final amountTextStyle = textTheme.bodyMedium?.copyWith(
      fontSize: getTextScale(3.5, context),
      decoration:
          item.isSelected ? TextDecoration.lineThrough : TextDecoration.none,
      color:
          item.isSelected ? Colors.grey[500] : (isDarkMode ? kWhite : kBlack),
    );

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: getPercentageWidth(2, context),
      ),
      child: Card(
        elevation: 1.5,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.0),
        ),
        color: isDarkMode ? kDarkGrey : kWhite,
        child: InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(20.0),
          child: Padding(
            padding: EdgeInsets.all(getPercentageWidth(2, context)),
            child: Row(
              children: [
                SizedBox(width: getPercentageWidth(2, context)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: textStyle),
                      if (amount != null && amount.isNotEmpty) ...[
                        SizedBox(height: getPercentageHeight(0.5, context)),
                        Text(amount, style: amountTextStyle),
                      ]
                    ],
                  ),
                ),
                Theme(
                  data: Theme.of(context).copyWith(
                    unselectedWidgetColor:
                        isDarkMode ? kPrimaryColor : kDarkGrey,
                  ),
                  child: Checkbox(
                    value: item.isSelected,
                    onChanged: (_) => onToggle(),
                    activeColor: kAccent,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
