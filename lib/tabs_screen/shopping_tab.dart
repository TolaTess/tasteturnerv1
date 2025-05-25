import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../constants.dart';
import '../data_models/macro_data.dart';
import '../helper/utils.dart';
import '../widgets/icon_widget.dart';
import '../widgets/ingredient_features.dart';
import '../widgets/premium_widget.dart';
import '../widgets/shopping_list_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ShoppingTab extends StatefulWidget {
  const ShoppingTab({super.key});

  @override
  State<ShoppingTab> createState() => _ShoppingTabState();
}

class _ShoppingTabState extends State<ShoppingTab> {
  List<MacroData> shoppingList = [];
  List<MacroData> myShoppingList = [];
  Set<String> selectedShoppingItems = {};
  String? _selectedDay;
  final List<String> _daysOfWeek = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday'
  ];

  @override
  void initState() {
    super.initState();
    _loadSelectedDay();
    _setupDataListeners();
  }

  Future<void> _loadSelectedDay() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedDay = prefs.getString('shopping_day');
    });
  }

  Future<void> _saveSelectedDay(String day) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('shopping_day', day);
    setState(() {
      _selectedDay = day;
    });
    // Cancel previous scheduled notification
    await notificationService.cancelScheduledNotification(1001);
    // Schedule weekly notification for the selected day at 10:00 AM
    int dayIndex = _daysOfWeek.indexOf(day); // 0 = Monday
    int weekday = dayIndex + 1; // DateTime weekday: Monday=1, ..., Sunday=7
    await notificationService.scheduleWeeklyReminder(
      id: 1001, // Unique ID for shopping reminder
      title: 'Shopping Reminder',
      body:
          'Today is your shopping day! Don\'t forget to buy your groceries for a healthy week!',
      weekday: weekday,
      hour: 10,
      minute: 0,
      // Optionally, pass timezone if needed
    );
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
                            fontSize: getPercentageWidth(3.5, context),
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

  void _setupDataListeners() {
    _onRefresh();
  }

  Future<void> _onRefresh() async {
    setState(() {
      shoppingList = macroManager.ingredient;
    });
    final currentWeek = getCurrentWeek();
    macroManager.fetchShoppingList(
        userService.userId ?? '', currentWeek, false);
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    return RefreshIndicator(
      onRefresh: _onRefresh,
      child: Column(
        children: [
          // Action buttons row
          const SizedBox(height: 15),

          if (macroManager.shoppingList.isEmpty &&
              macroManager.previousShoppingList.isNotEmpty)
            const SizedBox(height: 30),
          if (macroManager.shoppingList.isEmpty &&
              macroManager.previousShoppingList.isNotEmpty)
            const Center(
              child: Text(
                'Last week\'s list:',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: kAccent,
                ),
              ),
            ),

          // Shopping schedule selector
          Padding(
            padding: EdgeInsets.symmetric(
              vertical: getPercentageHeight(1, context),
              horizontal: getPercentageWidth(4, context),
            ),
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              color: isDarkMode ? kDarkGrey : kWhite,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  vertical: getPercentageHeight(2, context),
                  horizontal: getPercentageWidth(5, context),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              color: kAccent,
                              size: getPercentageWidth(7, context),
                            ),
                            SizedBox(width: getPercentageWidth(2, context)),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Shopping Day',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: getPercentageWidth(4.5, context),
                                    color: kAccent,
                                  ),
                                ),
                                SizedBox(
                                    height: getPercentageHeight(1, context)),
                                GestureDetector(
                                  onTap: () =>
                                      _showDayPicker(context, isDarkMode),
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal:
                                          getPercentageWidth(2.5, context),
                                      vertical: getPercentageHeight(1, context),
                                    ),
                                    decoration: BoxDecoration(
                                      color: kAccent.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        Text(
                                          _selectedDay == null ||
                                                  _selectedDay == ''
                                              ? 'Select Day'
                                              : _selectedDay!,
                                          style: TextStyle(
                                            color: kAccent,
                                            fontWeight: FontWeight.w600,
                                            fontSize: getPercentageWidth(
                                                3.5, context),
                                          ),
                                        ),
                                        SizedBox(
                                            width: getPercentageWidth(
                                                1.5, context)),
                                        Icon(
                                          Icons.edit_calendar,
                                          color: kAccent,
                                          size:
                                              getPercentageWidth(4.5, context),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                SizedBox(
                                    height: getPercentageHeight(2, context)),
                              ],
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Items',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: getPercentageWidth(4.5, context),
                                color: kAccent,
                              ),
                            ),
                            SizedBox(height: getPercentageHeight(1, context)),
                            Row(
                              children: [
                                Icon(
                                  Icons.shopping_basket,
                                  color: kAccent,
                                  size: getPercentageWidth(5, context),
                                ),
                                SizedBox(width: getPercentageWidth(1, context)),
                                Obx(
                                  () => Text(
                                    '${macroManager.shoppingList.length}',
                                    style: TextStyle(
                                      fontSize:
                                          getPercentageWidth(4.5, context),
                                      fontWeight: FontWeight.bold,
                                      color: kAccent,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                    SizedBox(height: getPercentageHeight(1, context)),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => IngredientFeatures(
                              items: macroManager.ingredient,
                            ),
                          ),
                        );
                      },
                      child: Center(
                        child: Text(
                          textAlign: TextAlign.center,
                          'SEE MORE INGREDIENTS',
                          style: TextStyle(
                            fontSize: getPercentageWidth(3.5, context),
                            fontWeight: FontWeight.w600,
                            color: kAccentLight,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          //Shopping list
          Expanded(
            child: Obx(() {
              if (macroManager.shoppingList.isEmpty &&
                  macroManager.previousShoppingList.isEmpty) {
                macroManager.fetchShoppingList(
                    userService.userId ?? '', getCurrentWeek() - 1, true);
                return noItemTastyWidget(
                  'No items in shopping list',
                  'Add items using Tasty Spin!',
                  context,
                  true,
                  'spin',
                );
              }

              // Use the ingredient id as the selection key
              final statusMap = macroManager.shoppingList.isNotEmpty
                  ? macroManager.shoppingList
                  : macroManager.previousShoppingList;
              final itemIds = statusMap.keys.toList();
              return ShoppingListView(
                items: itemIds,
                statusMap: statusMap,
                onToggle: (itemId) {}, // No-op, handled in ShoppingListView
                isCurrentWeek: macroManager.shoppingList.isNotEmpty,
              );
            }),
          ),
          // ------------------------------------Premium / Ads------------------------------------
          userService.currentUser?.isPremium ?? false
              ? const SizedBox.shrink()
              : const SizedBox(height: 15),
          userService.currentUser?.isPremium ?? false
              ? const SizedBox.shrink()
              : PremiumSection(
                  isPremium: userService.currentUser?.isPremium ?? false,
                  titleOne: joinChallenges,
                  titleTwo: premium,
                  isDiv: false,
                ),

          userService.currentUser?.isPremium ?? false
              ? const SizedBox.shrink()
              : const SizedBox(height: 10),
          userService.currentUser?.isPremium ?? false
              ? const SizedBox.shrink()
              : Divider(
                  color: getThemeProvider(context).isDarkMode
                      ? kWhite
                      : kDarkGrey),
          // ------------------------------------Premium / Ads-------------------------------------
        ],
      ),
    );
  }
}
