import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../constants.dart';
import '../helper/helper_functions.dart';
import '../helper/utils.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tasteturner/data_models/macro_data.dart';

import '../service/macro_manager.dart';
import '../widgets/ingredient_features.dart';

class ShoppingTab extends StatefulWidget {
  const ShoppingTab({super.key});

  @override
  State<ShoppingTab> createState() => _ShoppingTabState();
}

class _ShoppingTabState extends State<ShoppingTab> {
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

  final MacroManager _macroManager = Get.find<MacroManager>();

  @override
  void initState() {
    super.initState();
    _loadSelectedDay();
    _macroManager.fetchIngredients();
  }

  Future<void> _loadSelectedDay() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _selectedDay = prefs.getString('shopping_day');
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
      ),
      body: Obx(() {
        final generatedItems = _macroManager.generatedShoppingList;
        final manualItems = _macroManager.manualShoppingList;
        final hasItems = generatedItems.isNotEmpty || manualItems.isNotEmpty;

        final consolidatedCounts = _getConsolidatedCounts();
        final purchasedCount = consolidatedCounts['purchased'] ?? 0;
        final totalCount = consolidatedCounts['total'] ?? 0;
        List<Widget> listWidgets = [];

        if (hasItems) {
          if (manualItems.isNotEmpty) {
            listWidgets
                .add(_buildSectionHeader('Added Manually', textTheme, context));
            listWidgets.addAll(
                _buildConsolidatedList(manualItems.toList(), isManual: true));
          }

          if (generatedItems.isNotEmpty) {
            listWidgets.add(
                _buildSectionHeader('From Your Meal Plan', textTheme, context));
            listWidgets.addAll(_buildConsolidatedList(generatedItems.toList(),
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

        return Column(
          children: [
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
                              title: 'Items',
                              icon: Icons.shopping_basket,
                              text: '$purchasedCount / $totalCount',
                              textTheme: textTheme,
                            ),
                          ],
                        ),
                      ),
                    ),
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
                  ],
                ),
              ),
            ),
            Expanded(
              child: ListView(
                children: listWidgets,
              ),
            ),
          ],
        );
      }),
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
      String title, TextTheme textTheme, BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: getPercentageWidth(4, context),
        vertical: getPercentageHeight(1.5, context),
      ),
      child: Text(
        title,
        style: textTheme.titleLarge?.copyWith(
          fontSize: getTextScale(4.5, context),
          fontWeight: FontWeight.w200,
          color: kAccent,
        ),
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

      widgets.add(ShoppingListItem(
        item: displayItem,
        onToggle: onToggle,
      ));
    });

    // Sort widgets alphabetically by item title
    widgets.sort((a, b) {
      final itemA = (a as ShoppingListItem).item.title;
      final itemB = (b as ShoppingListItem).item.title;
      return itemA.toLowerCase().compareTo(itemB.toLowerCase());
    });

    return widgets;
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

    ImageProvider<Object> backgroundImage;
    if (item.mediaPaths.isNotEmpty &&
        item.mediaPaths.first.startsWith('http')) {
      backgroundImage = NetworkImage(item.mediaPaths.first);
    } else {
      backgroundImage = AssetImage(getAssetImageForItem(item.type));
    }

    return Padding(
      padding: EdgeInsets.symmetric(
          horizontal: getPercentageWidth(2, context),
          vertical: getPercentageHeight(1, context)),
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
