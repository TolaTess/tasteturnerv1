import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../constants.dart';
import '../helper/helper_functions.dart';
import '../helper/utils.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tasteturner/data_models/macro_data.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../service/macro_manager.dart';
import '../widgets/ingredient_features.dart';
import '../screens/premium_screen.dart';

class ShoppingTab extends StatefulWidget {
  const ShoppingTab({super.key});

  @override
  State<ShoppingTab> createState() => _ShoppingTabState();
}

class _ShoppingTabState extends State<ShoppingTab> {
  String? _selectedDay;
  bool _is54321View = false;
  bool _isLoading54321 = false;
  Map<String, dynamic>? _shoppingList54321;

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

  @override
  void initState() {
    super.initState();
    _loadSelectedDay();
    _loadViewPreference();
    _macroManager.fetchIngredients();
    _load54321ShoppingList();
  }

  Future<void> _loadSelectedDay() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _selectedDay = prefs.getString('shopping_day');
      });
    }
  }

  Future<void> _loadViewPreference() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _is54321View = prefs.getBool('shopping_54321_view') ?? false;
      });
    }
  }

  Future<void> _saveViewPreference(bool is54321View) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('shopping_54321_view', is54321View);
    if (mounted) {
      setState(() {
        _is54321View = is54321View;
      });
    }
  }

  Future<void> _saveSelectedDay(String day) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('shopping_day', day);
    if (mounted) {
      setState(() {
        _selectedDay = day;
      });
    }
    await notificationService.cancelScheduledNotification(1001);
    int dayIndex = _daysOfWeek.indexOf(day);
    int weekday = dayIndex + 1;
    FirebaseAnalytics.instance.logEvent(name: 'shopping_day_selected', parameters: {
      'day': day,
    });
    await notificationService.scheduleWeeklyReminder(
      id: 1001,
      title: 'Shopping Reminder',
      body:
          'Today is your shopping day! Don\'t forget to buy your groceries for a healthy week!',
      weekday: weekday,
      hour: 10,
      minute: 0,
    );
  }

  Future<void> _load54321ShoppingList() async {
    final userId = userService.userId;
    if (userId == null) return;

    try {
      final savedList = await geminiService.get54321ShoppingList(userId);
      if (mounted && savedList != null) {
        setState(() {
          _shoppingList54321 = savedList;
        });
      }
    } catch (e) {
      print('Error loading 54321 shopping list: $e');
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
            'Remove All Items',
            style: TextStyle(
              color: isDarkMode ? kWhite : kBlack,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Text(
            'Are you sure you want to remove all items from "$sectionTitle"?\n\nThis action cannot be undone.',
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
                'Remove All',
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'All items removed from ${isManual ? 'manual' : 'generated'} list'),
            backgroundColor: kAccent,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to remove items: $e'),
            backgroundColor: kRed,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _generate54321ShoppingList() async {
    if (_isLoading54321) return;

    // Check premium access
    if (!canUseAI()) {
      final isDarkMode = getThemeProvider(context).isDarkMode;
      showPremiumRequiredDialog(context, isDarkMode);
      return;
    }

    setState(() {
      _isLoading54321 = true;
    });

    try {
      // Get user context from userService instead of private method
      final currentUser = userService.currentUser.value;
      final dietaryRestrictions =
          currentUser?.settings['dietPreference'] != 'balanced'
              ? currentUser?.settings['dietPreference']
              : null;
      final familyMode = currentUser?.familyMode ?? false;

      final result = await geminiService.generateAndSave54321ShoppingList(
        dietaryRestrictions: dietaryRestrictions,
        additionalContext: 'Family mode: ${familyMode ? 'Yes' : 'No'}',
      );

      if (mounted) {
        setState(() {
          _shoppingList54321 = result;
          _isLoading54321 = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading54321 = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate 54321 list: $e'),
            backgroundColor: kRed,
          ),
        );
      }
    }
  }

  void _showDayPicker(BuildContext context, bool isDarkMode) async {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDarkMode ? kDarkGrey : kWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
      ),
      builder: (ctx) {
        return SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: _daysOfWeek.map((day) {
                return GestureDetector(
                  onTap: () {
                    Navigator.pop(ctx);
                    _saveSelectedDay(day);
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          day,
                          style: TextStyle(
                            color: isDarkMode ? kWhite : kBlack,
                            fontSize: getTextScale(3.5, context),
                          ),
                        ),
                        if (_selectedDay == day)
                          const Icon(Icons.check, color: kAccent, size: 18)
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        );
      },
    );
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
        title: Text(
          'Shopping List',
          style: textTheme.displaySmall?.copyWith(
            fontSize: getTextScale(7, context),
          ),
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
                  ? 'Switch to Regular View'
                  : 'Switch to 54321 View',
            ),
          ),
        ],
      ),
      body: Column(
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
                            title: 'Shopping Day',
                            icon: Icons.edit_calendar,
                            text: _selectedDay ?? 'Select Day',
                            textTheme: textTheme,
                          ),
                          _buildInfoColumn(
                            context,
                            title: _is54321View ? 'View' : 'Items',
                            icon: _is54321View
                                ? Icons.grid_view
                                : Icons.shopping_basket,
                            text: _is54321View ? '54321' : _getItemCountText(),
                            textTheme: textTheme,
                          ),
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
                            'SEE MORE INGREDIENTS',
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

                List<Widget> listWidgets = [];

                if (hasItems) {
                  if (manualItems.isNotEmpty) {
                    listWidgets.add(_buildSectionHeader(
                        'Added Manually', textTheme, context,
                        isManual: true));
                    listWidgets.addAll(_buildConsolidatedList(
                        manualItems.toList(),
                        isManual: true));
                  }

                  if (generatedItems.isNotEmpty) {
                    listWidgets.add(_buildSectionHeader(
                        'From Your Meal Plan', textTheme, context,
                        isGenerated: true));
                    listWidgets.addAll(_buildConsolidatedList(
                        generatedItems.toList(),
                        isManual: false));
                  }
                } else {
                  // Show empty state in the list
                  listWidgets.add(
                    noItemTastyWidget(
                      'Your shopping list is empty!',
                      'Click to spin the wheel and generate a list.',
                      context,
                      true,
                      'spin',
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
    );
  }

  String _getItemCountText() {
    final consolidatedCounts = _getConsolidatedCounts();
    final purchasedCount = consolidatedCounts['purchased'] ?? 0;
    final totalCount = consolidatedCounts['total'] ?? 0;
    return '$purchasedCount / $totalCount';
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
                        ? _generate54321ShoppingList
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
            child: _shoppingList54321 == null
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
            '54321 Shopping List',
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
                  ? 'Generate a balanced shopping list with:\n• 5 Vegetables\n• 4 Fruits\n• 3 Proteins\n• 2 Sauces/Spreads\n• 1 Grain\n• 1 Fun Treat'
                  : 'Upgrade to Premium to unlock AI-powered 54321 shopping lists!\n\nGet personalized, balanced shopping lists tailored to your dietary preferences and family needs.',
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
    final shoppingList =
        _shoppingList54321!['shoppingList'] as Map<String, dynamic>;
    final tips = _shoppingList54321!['tips'] as List<dynamic>? ?? [];
    final mealIdeas = _shoppingList54321!['mealIdeas'] as List<dynamic>? ?? [];
    final estimatedCost = _shoppingList54321!['estimatedCost'] as String? ?? '';

    return ListView(
      padding: EdgeInsets.symmetric(
        horizontal: getPercentageWidth(2, context),
      ),
      children: [
        // Cost estimate card
        if (estimatedCost.isNotEmpty)
          Card(
            color: isDarkMode
                ? kLightGrey.withOpacity(0.2)
                : kWhite.withOpacity(0.9),
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
          _buildSectionHeader('Shopping Tips', textTheme, context),
          ...tips.map((tip) =>
              _buildTipCard(context, isDarkMode, textTheme, tip.toString())),
        ],

        // Meal ideas section
        if (mealIdeas.isNotEmpty) ...[
          SizedBox(height: getPercentageHeight(2, context)),
          _buildSectionHeader('Meal Ideas', textTheme, context),
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
          _buildSectionHeader(category['title'] as String, textTheme, context),
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
        side: BorderSide(color: categoryColor.withOpacity(0.3), width: 1),
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
                    name,
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
                    color: categoryColor.withOpacity(0.1),
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
      color: isDarkMode ? kLightGrey.withOpacity(0.2) : kWhite.withOpacity(0.9),
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
      color: isDarkMode ? kLightGrey.withOpacity(0.2) : kWhite.withOpacity(0.9),
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
            fontWeight: FontWeight.w200,
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
            color: kAccent.withOpacity(0.08),
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
                  fontWeight: FontWeight.w200,
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
              fontWeight: FontWeight.w200,
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
                        'Are you sure you want to remove "${displayItem.title}" from your shopping list?',
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
                    Text('Removed "${displayItem.title}" from shopping list'),
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
    final userId = userService.userId;
    if (userId == null) return;

    // Delete all items in the group (for consolidated items)
    for (final itemToDelete in groupedItems) {
      if (itemToDelete.id != null) {
        _macroManager.removeFromShoppingList(userId, itemToDelete,
            isManual: isManual);
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
