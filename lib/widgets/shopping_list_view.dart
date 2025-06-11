import 'package:flutter/material.dart';
import '../constants.dart';
import '../data_models/macro_data.dart';
import '../helper/utils.dart';

class ShoppingListView extends StatefulWidget {
  final List<String> items; // ingredient IDs
  final Map<String, bool> statusMap; // id -> purchased status
  final Function(String) onToggle;
  final bool isCurrentWeek;
  final bool isGroceryList;

  const ShoppingListView({
    Key? key,
    required this.items,
    required this.statusMap,
    required this.onToggle,
    this.isCurrentWeek = true,
    this.isGroceryList = false,
  }) : super(key: key);

  @override
  State<ShoppingListView> createState() => _ShoppingListViewState();
}

class _ShoppingListViewState extends State<ShoppingListView> {
  late List<String> localItems;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    localItems = List<String>.from(widget.items);
  }

  @override
  void didUpdateWidget(covariant ShoppingListView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.items != oldWidget.items) {
      setState(() {
        localItems = List<String>.from(widget.items);
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _toggleItem(String id) async {
    final collectionName = widget.isGroceryList ? 'groceryList' : null;
    await macroManager.markItemPurchased(userService.userId ?? '', id,
        collectionName: collectionName);
    setState(() {}); // To trigger UI update
    widget.onToggle(id);
  }

  Future<void> _removeItem(MacroData item) async {
    if (item.id == null) return;

    try {
      final userId = userService.userId;
      if (userId == null) return;

      await macroManager.removeFromShoppingList(userId, item);

      if (mounted) {
        showTastySnackbar(
          'Success',
          'Removed ${item.title} from shopping list',
          context,
        );
      }
    } catch (e) {
      if (mounted) {
        showTastySnackbar(
          'Please try again.',
          'Error removing item: $e',
          context,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = getThemeProvider(context).isDarkMode;

    return Theme(
      data: Theme.of(context).copyWith(
        scrollbarTheme: ScrollbarThemeData(
          thumbColor: WidgetStateProperty.all(kAccentLight),
          radius: const Radius.circular(10),
          thickness: WidgetStateProperty.all(getPercentageHeight(
            1,
            context,
          )),
        ),
      ),
      child: Scrollbar(
        controller: _scrollController,
        thumbVisibility: true,
        child: ListView.builder(
          controller: _scrollController,
          itemCount: localItems.length,
          itemBuilder: (context, index) {
            final id = localItems[index];
            String idWithoutAmount = id;
            String amount = '';
            if (id.contains('/')) {
              final parts = id.split('/');
              idWithoutAmount = parts.first;
              amount =
                  parts.sublist(1).join('/'); // In case amount contains '/'
            }
            final purchased = widget.statusMap[id] == true;
            final macro = macroManager.ingredient.firstWhere(
                (m) => m.id == idWithoutAmount,
                orElse: () => MacroData(
                    title: '',
                    type: '',
                    mediaPaths: [],
                    macros: {},
                    categories: [],
                    features: {}));
            // If not found in MacroData, fallback to showing the id and amount directly
            final isFallback = macro.id == null || macro.title.isEmpty;

            Widget listItem = Container(
              margin: EdgeInsets.symmetric(horizontal: getPercentageWidth(2, context), vertical: getPercentageHeight(0.5, context)),
              decoration: BoxDecoration(
                color:
                    isDarkMode ? Colors.white.withOpacity(0.05) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  if (!isDarkMode)
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                ],
              ),
              child: ListTile(
                leading: isFallback
                    ? CircleAvatar(
                        radius: getPercentageWidth(6, context),
                        backgroundColor: kAccentLight.withOpacity(0.2),
                        child: Text(
                          idWithoutAmount.isNotEmpty
                              ? idWithoutAmount[0].toUpperCase()
                              : '?',
                          style: TextStyle(
                            color: kAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: getPercentageWidth(4, context),
                          ),
                        ),
                      )
                    : CircleAvatar(
                        radius: getPercentageWidth(6, context),
                        backgroundImage: macro.mediaPaths.isNotEmpty &&
                                macro.mediaPaths.first.startsWith('http')
                            ? NetworkImage(macro.mediaPaths.first)
                                as ImageProvider
                            : AssetImage(getAssetImageForItem(
                                macro.mediaPaths.isNotEmpty
                                    ? macro.mediaPaths.first
                                    : '')),
                      ),
                title: isFallback
                    ? Text(
                        capitalizeFirstLetter(idWithoutAmount),
                        style: TextStyle(
                          fontSize: getPercentageWidth(4, context),
                          fontWeight: FontWeight.w500,
                          color: purchased
                              ? kAccentLight
                              : isDarkMode
                                  ? Colors.white
                                  : Colors.black,
                          decoration:
                              purchased ? TextDecoration.lineThrough : null,
                        ),
                      )
                    : Text(
                        capitalizeFirstLetter(macro.title),
                        style: TextStyle(
                          fontSize: getPercentageWidth(4, context),
                          fontWeight: FontWeight.w500,
                          color: purchased
                              ? kAccentLight
                              : isDarkMode
                                  ? Colors.white
                                  : Colors.black,
                          decoration:
                              purchased ? TextDecoration.lineThrough : null,
                        ),
                      ),
                subtitle: amount != null && amount.isNotEmpty
                    ? Text(
                        amount,
                        style: TextStyle(
                          fontSize: getPercentageWidth(3, context),
                          color: isDarkMode ? kWhite : kDarkGrey,
                        ),
                      )
                    : null,
                trailing: Theme(
                  data: Theme.of(context).copyWith(
                    unselectedWidgetColor:
                        isDarkMode ? Colors.white : Colors.black,
                  ),
                  child: Transform.scale(
                    scale: MediaQuery.of(context).size.height > 1100 ? 1.5 : 1, // Adjust this value to control checkbox size
                    child: Checkbox(
                      value: purchased,
                      onChanged: (bool? value) {
                        _toggleItem(id);
                      },
                      activeColor: kAccentLight,
                      checkColor: kWhite,
                    ),
                  ),
                ),
              ),
            );

            return widget.isCurrentWeek
                ? Dismissible(
                    key: Key(id),
                    background: Container(
                      color: kRed.withOpacity(kMidOpacity),
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      child: const Icon(
                        Icons.delete,
                        color: Colors.white,
                      ),
                    ),
                    direction: DismissDirection.endToStart,
                    onDismissed: (direction) {
                      setState(() {
                        localItems.removeAt(index);
                      });
                      _removeItem(macro);
                    },
                    child: listItem,
                  )
                : listItem;
          },
        ),
      ),
    );
  }
}
