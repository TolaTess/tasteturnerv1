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
      body: 'Today is your shopping day! Don\'t forget to buy your groceries for a healthy week!',
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: _daysOfWeek.map((day) {
              return ListTile(
                title: Text(day,
                    style: TextStyle(
                      color: isDarkMode ? kWhite : kBlack,
                    )),
                trailing: _selectedDay == day
                    ? const Icon(Icons.check, color: kAccent)
                    : null,
                onTap: () {
                  Navigator.pop(ctx);
                  _saveSelectedDay(day);
                },
              );
            }).toList(),
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
            padding:
                const EdgeInsets.symmetric(vertical: 5.0, horizontal: 16.0),
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              color: isDarkMode ? kDarkGrey : kWhite,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    vertical: 18.0, horizontal: 20.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.calendar_today,
                                color: kAccent, size: 28),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Shopping Day',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                    color: kAccent,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                GestureDetector(
                                  onTap: () => _showDayPicker(
                                      context, isDarkMode),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
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
                                          style: const TextStyle(
                                            color: kAccent,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 15,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        const Icon(Icons.edit_calendar,
                                            color: kAccent, size: 18),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                              ],
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text(
                              'Items',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                                color: kAccent,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.shopping_basket,
                                    color: kAccent, size: 20),
                                const SizedBox(width: 4),
                                Obx(
                                  () => Text(
                                    '${macroManager.shoppingList.length}',
                                    style: const TextStyle(
                                      fontSize: 18,
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
                    const SizedBox(height: 5),
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
                      child: const Center(
                        child: Text(
                          textAlign: TextAlign.center,
                          'SEE MORE INGREDIENTS',
                          style: TextStyle(
                            fontSize: 12,
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
          const SizedBox(height: 10),
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

// MealCategoryItem widget definition moved from meal_design_screen.dart
class MealCategoryItem extends StatelessWidget {
  const MealCategoryItem({
    super.key,
    required this.title,
    required this.press,
    this.icon = Icons.favorite,
    this.size = 35,
    this.image = intPlaceholderImage,
  });

  final String title, image;
  final VoidCallback press;
  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: press,
      child: Column(
        children: [
          IconCircleButton(
            h: size,
            w: size,
            icon: icon,
            isRemoveContainer: false,
          ),
          const SizedBox(
            height: 5,
          ),
          Text(title,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              )),
        ],
      ),
    );
  }
}
