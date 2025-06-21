import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../constants.dart';
import '../helper/utils.dart';
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
  // Removed unused shoppingList and myShoppingList assignments to avoid void assignment errors
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

  bool showGroceryList = true; // NEW: toggle for grocery/general
  bool _shoppingCardExpanded = false;
  bool _isLoadingGrocery = false;
  bool _isLoadingShopping = false;

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

  void _setupDataListeners() {
    _onRefresh();
  }

  Future<void> _onRefresh() async {
    // Only generate grocery list if the grocery list is empty
    if (macroManager.groceryList.isEmpty) {
      await macroManager.generateGroceryList();
    }
    if (showGroceryList) {
      await _fetchGroceryList();
    } else {
      await _fetchShoppingList();
    }
    await macroManager.fetchIngredients();
  }

  Future<void> _fetchGroceryList() async {
    setState(() {
      _isLoadingGrocery = true;
    });
    macroManager.fetchShoppingList(
        userService.userId ?? '', getCurrentWeek(), false,
        collectionName: 'groceryList');
    setState(() {
      _isLoadingGrocery = false;
    });
  }

  Future<void> _fetchShoppingList() async {
    setState(() {
      _isLoadingShopping = true;
    });
    macroManager.fetchShoppingList(
        userService.userId ?? '', getCurrentWeek(), false);
    setState(() {
      _isLoadingShopping = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shopping List'),
      ),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: Column(
          children: [
            // Action buttons row
            SizedBox(height: getPercentageHeight(1, context)),

            // NEW: Toggle for grocery/general list

            Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: getPercentageWidth(2, context),
                  vertical: getPercentageHeight(1, context)),
              child: Material(
                color: kAccent.withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: getPercentageWidth(2, context),
                    vertical: getPercentageHeight(1, context),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          showGroceryList
                              ? IconButton(
                                  onPressed: () async {
                                    showDialog(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        backgroundColor:
                                            isDarkMode ? kDarkGrey : kWhite,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(16),
                                        ),
                                        title: Text('Update Meal Plan List',
                                            style: TextStyle(
                                                color: kAccent,
                                                fontWeight: FontWeight.w600,
                                                fontSize: getPercentageHeight(
                                                    2.2, context))),
                                        content: Text(
                                            'Shopping List based on your meal plan for this week. \nDo you want to update?',
                                            style: TextStyle(
                                                color: isDarkMode
                                                    ? kWhite
                                                    : kBlack,
                                                fontSize: getPercentageHeight(
                                                    2, context))),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context),
                                            child: Text('Cancel',
                                                style: TextStyle(
                                                    color: isDarkMode
                                                        ? kWhite
                                                        : kBlack,
                                                    fontSize:
                                                        getPercentageHeight(
                                                            1.8, context))),
                                          ),
                                          TextButton(
                                            onPressed: () async {
                                              Navigator.pop(context);
                                              await macroManager
                                                  .generateGroceryList();
                                              showTastySnackbar(
                                                  'Meal Plan List',
                                                  'Meal Plan List updated for this week',
                                                  context);
                                            },
                                            child: Text('Update',
                                                style: TextStyle(
                                                    color: kAccent,
                                                    fontSize:
                                                        getPercentageHeight(
                                                            1.8, context))),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                  icon: Icon(
                                    Icons.refresh,
                                    color: kAccent,
                                    size: getPercentageWidth(5, context),
                                  ),
                                )
                              : const SizedBox.shrink(),
                          SizedBox(width: getPercentageWidth(2, context)),
                          Text('Meal Plan List',
                              style: TextStyle(
                                  color: showGroceryList
                                      ? kAccent
                                      : (isDarkMode ? kWhite : kBlack),
                                  fontWeight: FontWeight.bold,
                                  fontSize: getPercentageHeight(
                                      showGroceryList ? 2.2 : 1.8, context))),
                          Switch(
                            value: showGroceryList,
                            onChanged: (val) async {
                              setState(() {
                                showGroceryList = val;
                              });
                              if (val) {
                                await _fetchGroceryList();
                              } else {
                                await _fetchShoppingList();
                              }
                            },
                            activeColor: kAccent,
                          ),
                          Text('Shopping List',
                              style: TextStyle(
                                  color: !showGroceryList
                                      ? kAccent
                                      : (isDarkMode ? kWhite : kBlack),
                                  fontWeight: FontWeight.bold,
                                  fontSize: getPercentageHeight(
                                      showGroceryList ? 1.8 : 2.2, context))),
                        ],
                      ),
                      if (macroManager.shoppingList.isEmpty &&
                          macroManager.previousShoppingList.isNotEmpty)
                        Center(
                          child: Text(
                            'Last week\'s list:',
                            style: TextStyle(
                              fontSize: getPercentageHeight(2, context),
                              fontWeight: FontWeight.w600,
                              color: kAccent,
                            ),
                          ),
                        ),
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
                              fontSize: getPercentageHeight(2, context),
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

            // Shopping schedule selector
            Padding(
              padding: EdgeInsets.symmetric(
                vertical: getPercentageHeight(1, context),
                horizontal: getPercentageWidth(2.5, context),
              ),
              child: Builder(
                builder: (context) {
                  final groceryNotEmpty = macroManager.groceryList.isNotEmpty;
                  final shoppingNotEmpty = macroManager.shoppingList.isNotEmpty;
                  final prevNotEmpty =
                      macroManager.previousShoppingList.isNotEmpty;
                  final shouldShow = (showGroceryList && groceryNotEmpty) ||
                      (!showGroceryList && (shoppingNotEmpty || prevNotEmpty));
                  if (!shouldShow) return const SizedBox.shrink();
                  return Card(
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
                                Column(
                                  children: [
                                    Text(
                                      'Shopping Day',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize:
                                            getPercentageHeight(2.2, context),
                                        color: kAccent,
                                      ),
                                    ),
                                    SizedBox(
                                        height:
                                            getPercentageHeight(1, context)),
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal:
                                            getPercentageWidth(3, context),
                                        vertical:
                                            getPercentageHeight(1, context),
                                      ),
                                      decoration: BoxDecoration(
                                        color: kAccent.withOpacity(0.08),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.edit_calendar,
                                            color: kAccent,
                                            size:
                                                getPercentageWidth(5, context),
                                          ),
                                          SizedBox(
                                              width: getPercentageWidth(
                                                  1, context)),
                                          Text(
                                            textAlign: TextAlign.center,
                                            _selectedDay == null ||
                                                    _selectedDay == ''
                                                ? 'Select Day'
                                                : _selectedDay!,
                                            style: TextStyle(
                                              color: kAccent,
                                              fontWeight: FontWeight.bold,
                                              fontSize: getPercentageHeight(
                                                  1.8, context),
                                            ),
                                          ),
                                        ],
                                      ),
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
                                        fontSize:
                                            getPercentageHeight(2.2, context),
                                        color: kAccent,
                                      ),
                                    ),
                                    SizedBox(
                                        height:
                                            getPercentageHeight(1, context)),
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal:
                                            getPercentageWidth(3, context),
                                        vertical:
                                            getPercentageHeight(1, context),
                                      ),
                                      decoration: BoxDecoration(
                                        color: kAccent.withOpacity(0.08),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.shopping_basket,
                                            color: kAccent,
                                            size:
                                                getPercentageWidth(5, context),
                                          ),
                                          SizedBox(
                                              width: getPercentageWidth(
                                                  1, context)),
                                          Obx(() {
                                            final statusMap = showGroceryList
                                                ? macroManager.groceryList
                                                : macroManager
                                                        .shoppingList.isNotEmpty
                                                    ? macroManager.shoppingList
                                                    : macroManager
                                                        .previousShoppingList;
                                            final total = statusMap.length;
                                            final purchased = statusMap.values
                                                .where((v) => v == true)
                                                .length;
                                            return Text(
                                              '$purchased / $total',
                                              style: TextStyle(
                                                fontSize: getPercentageHeight(
                                                    1.8, context),
                                                fontWeight: FontWeight.bold,
                                                color: kAccent,
                                              ),
                                            );
                                          }),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            showGroceryList
                ? macroManager.groceryList.isNotEmpty
                    ? Center(
                        child: Text(
                            'Your generated shopping list from this week\'s Meal Plan',
                            style: TextStyle(
                                fontSize: getTextScale(3.2, context),
                                overflow: TextOverflow.ellipsis,
                                fontWeight: FontWeight.w400,
                                color: kAccent)),
                      )
                    : const SizedBox.shrink()
                : macroManager.shoppingList.isNotEmpty
                    ? Center(
                        child: Text('Your selected and spin list',
                            style: TextStyle(
                                fontSize: getTextScale(3.2, context),
                                fontWeight: FontWeight.w400,
                                color: kAccent)),
                      )
                    : const SizedBox.shrink(),

            SizedBox(height: getPercentageHeight(1, context)),

            //Shopping list
            Expanded(
              child: Obx(() {
                if (showGroceryList) {
                  if (_isLoadingGrocery) {
                    return const Center(
                        child: CircularProgressIndicator(color: kAccent));
                  }
                  if (macroManager.groceryList.isEmpty) {
                    return noItemTastyWidget(
                      'No items in Meal Plan List',
                      'Add meal plan to your Calendar!',
                      context,
                      true,
                      'calendar',
                    );
                  }
                  final statusMap = macroManager.groceryList;
                  final itemIds = statusMap.keys.toList();
                  return ShoppingListView(
                    items: itemIds,
                    statusMap: statusMap,
                    onToggle: (itemId) {},
                    isCurrentWeek: macroManager.groceryList.isNotEmpty,
                    isGroceryList: true,
                  );
                } else {
                  if (_isLoadingShopping) {
                    return const Center(
                        child: CircularProgressIndicator(color: kAccent));
                  }
                  // Show general shopping list (existing logic)
                  if (macroManager.shoppingList.isEmpty &&
                      macroManager.previousShoppingList.isEmpty) {
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
                }
              }),
            ),
            // ------------------------------------Premium / Ads------------------------------------
            if (!(userService.currentUser?.isPremium ?? false)) ...[
              const SizedBox(height: 15),
              PremiumSection(
                isPremium: userService.currentUser?.isPremium ?? false,
                titleOne: joinChallenges,
                titleTwo: premium,
                isDiv: false,
              ),
              const SizedBox(height: 10),
              Divider(
                color:
                    getThemeProvider(context).isDarkMode ? kWhite : kDarkGrey,
              ),
            ]
            // ------------------------------------Premium / Ads-------------------------------------
          ],
        ),
      ),
    );
  }
}
