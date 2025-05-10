import 'package:flutter/material.dart';
import '../constants.dart';
import '../data_models/macro_data.dart';
import '../helper/utils.dart';

class ShoppingListView extends StatefulWidget {
  final List<String> items; // ingredient IDs
  final Map<String, bool> statusMap; // id -> purchased status
  final Function(String) onToggle;
  final bool isCurrentWeek;

  const ShoppingListView({
    Key? key,
    required this.items,
    required this.statusMap,
    required this.onToggle,
    this.isCurrentWeek = true,
  }) : super(key: key);

  @override
  State<ShoppingListView> createState() => _ShoppingListViewState();
}

class _ShoppingListViewState extends State<ShoppingListView> {
  late List<String> localItems;

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

  void _toggleItem(String id) async {
    final macro = macroManager.ingredient.firstWhere((m) => m.id == id,
        orElse: () => MacroData(
            title: '',
            type: '',
            mediaPaths: [],
            macros: {},
            categories: [],
            features: {}));
    if (macro.id == null || macro.title.isEmpty) return;
    await macroManager.markItemPurchased(userService.userId ?? '', macro);
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

    return ListView.builder(
      itemCount: localItems.length,
      itemBuilder: (context, index) {
        final id = localItems[index];
        final purchased = widget.statusMap[id] == true;
        final macro = macroManager.ingredient.firstWhere((m) => m.id == id,
            orElse: () => MacroData(
                title: '',
                type: '',
                mediaPaths: [],
                macros: {},
                categories: [],
                features: {}));
        if (macro.id == null || macro.title.isEmpty) {
          return const SizedBox.shrink();
        }

        Widget listItem = Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: isDarkMode ? Colors.white.withOpacity(0.05) : Colors.white,
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
            leading: CircleAvatar(
              radius: 25,
              backgroundImage: macro.mediaPaths.isNotEmpty &&
                      macro.mediaPaths.first.startsWith('http')
                  ? NetworkImage(macro.mediaPaths.first) as ImageProvider
                  : AssetImage(getAssetImageForItem(macro.mediaPaths.isNotEmpty
                      ? macro.mediaPaths.first
                      : '')),
            ),
            title: Text(
              capitalizeFirstLetter(macro.title),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: purchased
                    ? kAccent
                    : isDarkMode
                        ? Colors.white
                        : Colors.black,
                decoration: purchased ? TextDecoration.lineThrough : null,
              ),
            ),
            trailing: Theme(
              data: Theme.of(context).copyWith(
                unselectedWidgetColor: isDarkMode ? Colors.white : Colors.black,
              ),
              child: Checkbox(
                value: purchased,
                onChanged: (bool? value) {
                  _toggleItem(id);
                },
                activeColor: kAccent,
                checkColor: kWhite,
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
    );
  }
}
