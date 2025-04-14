import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';
import '../data_models/macro_data.dart';
import '../helper/utils.dart';

class ShoppingListView extends StatefulWidget {
  final List<MacroData> items;
  final Set<String> selectedItems;
  final Function(String) onToggle;

  const ShoppingListView({
    Key? key,
    required this.items,
    required this.selectedItems,
    required this.onToggle,
  }) : super(key: key);

  @override
  State<ShoppingListView> createState() => _ShoppingListViewState();
}

class _ShoppingListViewState extends State<ShoppingListView> {
  static const String _shoppingListKey = 'shopping_list_selections';
  late Set<String> selectedItems;

  @override
  void initState() {
    super.initState();
    selectedItems = widget.selectedItems;
    _loadSelections();
  }

  Future<void> _loadSelections() async {
    final prefs = await SharedPreferences.getInstance();
    final savedSelections = prefs.getStringList(_shoppingListKey) ?? [];
    if (mounted) {
      setState(() {
        selectedItems = Set.from(savedSelections.where((id) => id != null));
      });
    }
  }

  Future<void> _saveSelections() async {
    final prefs = await SharedPreferences.getInstance();
    final validSelections = selectedItems.where((id) => id != null).toList();
    await prefs.setStringList(_shoppingListKey, validSelections);
  }

  void _toggleItem(MacroData item) {
    if (item.id == null) return;

    setState(() {
      if (selectedItems.contains(item.id)) {
        selectedItems.remove(item.id);
      } else {
        selectedItems.add(item.id!);
      }
    });
    widget.onToggle(item.id!);
    _saveSelections();
  }

  Future<void> _removeItem(MacroData item) async {
    if (item.id == null) return;

    try {
      final userId = userService.userId;
      if (userId == null) return;

      await macroManager.removeFromShoppingList(userId, item);

      if (selectedItems.contains(item.id)) {
        setState(() {
          selectedItems.remove(item.id);
        });
        _saveSelections();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Removed ${item.title} from shopping list')),  
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error removing item: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = getThemeProvider(context).isDarkMode;

    return ListView.builder(
      itemCount: widget.items.length,
      itemBuilder: (context, index) {
        final item = widget.items[index];
        final isSelected = item.id != null && selectedItems.contains(item.id);

        return Dismissible(
          key: Key(item.id ?? '${index}_${item.title}'),
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
          onDismissed: (direction) => _removeItem(item),
          child: Container(
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
              backgroundImage: AssetImage(getAssetImageForItem(item.mediaPaths.first)),
            ),
            title: Text(
              capitalizeFirstLetter(item.title),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: isDarkMode ? Colors.white : Colors.black,
                decoration: isSelected ? TextDecoration.lineThrough : null,
              ),
            ),
            trailing: Theme(
              data: Theme.of(context).copyWith(
                unselectedWidgetColor: isDarkMode ? Colors.white : Colors.black,
              ),
              child: Checkbox(
                value: isSelected,
                onChanged: (_) => _toggleItem(item),
                activeColor: kAccent,
                checkColor: kWhite,
              ),
              ),
            ),
          ),
        );
      },
    );
  }
}
