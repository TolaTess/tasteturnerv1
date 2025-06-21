import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../constants.dart';
import '../helper/utils.dart';
import '../widgets/premium_widget.dart';
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

  bool _isLoading = false;
  bool _hasError = false;

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

  Future<void> _onRefresh({bool isPullToRefresh = false}) async {
    // If this is an initial load and we already have a list, do nothing.
    // This prevents the list from being cleared on tab switch.
    if (!isPullToRefresh && macroManager.groceryList.isNotEmpty) {
      return;
    }

    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    try {
      // Fetch any existing lists from the backend first.
      await _fetchGroceryList();
      await _fetchShoppingList();

      // If both lists are empty after fetching, then generate a new one.
      if (macroManager.groceryList.isEmpty &&
          macroManager.shoppingList.isEmpty) {
        await macroManager.generateGroceryList();
      }

      await macroManager.fetchIngredients();
    } catch (e) {
      print('Error loading shopping list: $e');
      if (mounted) {
        setState(() => _hasError = true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _fetchGroceryList() async {
    macroManager.fetchShoppingList(
        userService.userId ?? '', getCurrentWeek(), false,
        collectionName: 'groceryList');
  }

  Future<void> _fetchShoppingList() async {
    macroManager.fetchShoppingList(
        userService.userId ?? '', getCurrentWeek(), false);
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shopping List'),
      ),
      body: RefreshIndicator(
        onRefresh: () => _onRefresh(isPullToRefresh: true),
        child: Column(
          children: [
            // Action buttons row
            SizedBox(height: getPercentageHeight(1, context)),

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

                  final shouldShow = groceryNotEmpty || shoppingNotEmpty;
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
                                            final groceryStatusMap =
                                                macroManager.groceryList;
                                            final shoppingStatusMap =
                                                macroManager.shoppingList;

                                            final total =
                                                groceryStatusMap.length +
                                                    shoppingStatusMap.length;
                                            final purchased = groceryStatusMap
                                                    .values
                                                    .where((v) => v == true)
                                                    .length +
                                                shoppingStatusMap.values
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

            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: kAccent))
                  : _hasError
                      ? Center(
                          child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('Failed to load shopping list.'),
                            const SizedBox(height: 8),
                            ElevatedButton(
                              onPressed: _onRefresh,
                              child: const Text('Try Again'),
                            )
                          ],
                        ))
                      : Obx(() {
                          // By accessing the ingredient list here, we ensure this Obx rebuilds
                          // when the ingredients are loaded, which in turn rebuilds the list.
                          final _ = macroManager.ingredient.length;

                          if (macroManager.groceryList.isEmpty &&
                              macroManager.shoppingList.isEmpty) {
                            return noItemTastyWidget(
                              'No items in shopping list',
                              'Add meal plan or use Tasty Spin!',
                              context,
                              true,
                              'spin',
                            );
                          }

                          final groceryItems = macroManager.groceryList.keys;
                          final shoppingItems = macroManager.shoppingList.keys;

                          return ListView.builder(
                            itemCount: (shoppingItems.isNotEmpty ? 1 : 0) +
                                shoppingItems.length +
                                (groceryItems.isNotEmpty ? 1 : 0) +
                                groceryItems.length,
                            itemBuilder: (context, index) {
                              if (shoppingItems.isNotEmpty) {
                                if (index == 0) {
                                  return _buildSectionHeader('Spin/Selected');
                                }
                                if (index <= shoppingItems.length) {
                                  final itemId =
                                      shoppingItems.elementAt(index - 1);
                                  return ShoppingListItem(
                                    itemId: itemId,
                                    status: macroManager.shoppingList[itemId] ??
                                        false,
                                    onToggle: () {
                                      macroManager.markItemPurchased(
                                          userService.userId!, itemId,
                                          collectionName: 'shoppingList');
                                    },
                                  );
                                }
                              }

                              int groceryStartIndex =
                                  (shoppingItems.isNotEmpty ? 1 : 0) +
                                      shoppingItems.length;

                              if (groceryItems.isNotEmpty) {
                                if (index == groceryStartIndex) {
                                  return _buildSectionHeader('Generated List');
                                }
                                if (index > groceryStartIndex) {
                                  final itemIndex =
                                      index - groceryStartIndex - 1;
                                  final itemId =
                                      groceryItems.elementAt(itemIndex);
                                  return ShoppingListItem(
                                    itemId: itemId,
                                    status: macroManager.groceryList[itemId] ??
                                        false,
                                    onToggle: () {
                                      macroManager.markItemPurchased(
                                          userService.userId!, itemId,
                                          collectionName: 'groceryList');
                                    },
                                  );
                                }
                              }
                              return const SizedBox
                                  .shrink(); // Should not be reached
                            },
                          );
                        }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: getPercentageWidth(4, context),
        vertical: getPercentageHeight(1.5, context),
      ),
      child: Text(
        title,
        style: TextStyle(
          fontSize: getTextScale(4, context),
          fontWeight: FontWeight.bold,
          color: kAccent,
        ),
      ),
    );
  }
}

class ShoppingListItem extends StatelessWidget {
  final String itemId;
  final bool status;
  final VoidCallback onToggle;

  const ShoppingListItem({
    super.key,
    required this.itemId,
    required this.status,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final parts = itemId.split('/');
    final ingredientId = parts[0];
    final amount = parts.length > 1 ? parts.sublist(1).join('/') : null;

    final ingredient =
        macroManager.ingredient.firstWhereOrNull((i) => i.id == ingredientId);

    if (ingredient == null) {
      // It might take a moment for ingredients to load, show a placeholder
      return ListTile(
        title: const Text('Loading ingredient...'),
        trailing: Checkbox(
          value: status,
          onChanged: (_) => onToggle(),
          activeColor: kAccent,
        ),
        onTap: onToggle,
      );
    }
    final isDarkMode = getThemeProvider(context).isDarkMode;

    return ListTile(
      tileColor: isDarkMode ? kDarkGrey : kWhite,
      title: Text(
        capitalizeFirstLetter(ingredient.title),
        style: TextStyle(
            decoration:
                status ? TextDecoration.lineThrough : TextDecoration.none,
            color: status
                ? (isDarkMode ? Colors.grey[500] : Colors.grey[500])
                : (isDarkMode ? kWhite : kBlack)),
      ),
      subtitle: amount != null && amount.isNotEmpty
          ? Text(
              amount,
              style: TextStyle(
                  decoration:
                      status ? TextDecoration.lineThrough : TextDecoration.none,
                  color: status
                      ? (isDarkMode ? Colors.grey[500] : Colors.grey[500])
                      : (isDarkMode
                          ? kWhite.withOpacity(0.7)
                          : kBlack.withOpacity(0.7))),
            )
          : null,
      trailing: Theme(
        data: Theme.of(context).copyWith(
          unselectedWidgetColor: isDarkMode ? kPrimaryColor : kDarkGrey,
        ),
        child: Checkbox(
          value: status,
          onChanged: (_) => onToggle(),
          activeColor: kAccent,
        ),
      ),
      onTap: onToggle,
    );
  }
}
