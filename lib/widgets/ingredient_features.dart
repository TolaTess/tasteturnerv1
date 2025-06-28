import '../widgets/bottom_nav.dart';
import '../widgets/search_button.dart';
import 'package:flutter/material.dart';

import '../constants.dart';
import '../data_models/macro_data.dart';
import '../detail_screen/ingredientdetails_screen.dart';
import '../helper/utils.dart';
import 'icon_widget.dart';

class IngredientFeatures extends StatefulWidget {
  final List<MacroData> items;
  final bool isRecipe;
  const IngredientFeatures({
    Key? key,
    required this.items,
    this.isRecipe = false,
  }) : super(key: key);

  @override
  State<IngredientFeatures> createState() => _IngredientFeaturesState();
}

class _IngredientFeaturesState extends State<IngredientFeatures> {
  final TextEditingController _searchController = TextEditingController();
  Set<String> _selectedIngredients = {};
  List<MacroData> _filteredItems = [];
  int _displayedItemCount = 10;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _filteredItems = widget.items.take(10).toList();

    // Fetch user's shopping list and pre-select items
    _preselectShoppingList();
  }

  void _preselectShoppingList() async {
    final userId = userService.userId;
    if (userId == null) return;
    final currentWeek = getCurrentWeek();
    final shoppingListMap = await macroManager
        .fetchShoppingListForWeekWithStatus(userId, currentWeek);
    final selectedTitles = widget.items
        .where((item) =>
            shoppingListMap[item.id] == true ||
            shoppingListMap[item.id] == false)
        .map((item) => item.title)
        .toSet();
    setState(() {
      _selectedIngredients = selectedTitles;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleSelection(String title) {
    setState(() {
      if (_selectedIngredients.contains(title)) {
        _selectedIngredients.remove(title);
      } else {
        _selectedIngredients.add(title);
      }
    });

    // Update Firestore after state update
    final item = widget.items.firstWhere(
      (i) => i.title == title,
      orElse: () => MacroData(
        title: '',
        type: '',
        mediaPaths: [],
        macros: {},
        categories: [],
        features: {},
      ),
    );
    if (item.id != null && item.title.isNotEmpty) {
      if (_selectedIngredients.contains(title)) {
        macroManager.saveShoppingList([item]);
      } else {
        macroManager.removeFromShoppingList(userService.userId ?? '', item);
      }
    }
  }

  void _filterItems(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredItems = widget.items.take(10).toList();
      } else {
        _filteredItems = widget.items
            .where((item) =>
                item.title.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
      // Reset displayed count on new search
      _displayedItemCount = 10;
    });
  }

  Future<void> _loadMore() async {
    setState(() {
      _isLoading = true;
    });

    await Future.delayed(const Duration(milliseconds: 500));

    setState(() {
      final nextBatch = _displayedItemCount + 10;
      if (_searchController.text.isEmpty) {
        // If no search query, load from widget.items
        _displayedItemCount = nextBatch;
        _filteredItems = widget.items.take(_displayedItemCount).toList();
      } else {
        // If there's a search query, load more from filtered results
        final allFiltered = widget.items
            .where((item) => item.title
                .toLowerCase()
                .contains(_searchController.text.toLowerCase()))
            .toList();
        _displayedItemCount = nextBatch;
        _filteredItems = allFiltered.take(_displayedItemCount).toList();
      }
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    final sortedItems = List<MacroData>.from(_filteredItems)
      ..sort((a, b) => a.title.compareTo(b.title));

    // Update hasMoreItems condition to check against the appropriate list
    final bool hasMoreItems;
    if (_searchController.text.isEmpty) {
      hasMoreItems = widget.items.length > _filteredItems.length;
    } else {
      final allFilteredCount = widget.items
          .where((item) => item.title
              .toLowerCase()
              .contains(_searchController.text.toLowerCase()))
          .length;
      hasMoreItems = allFilteredCount > _filteredItems.length;
    }

    return Scaffold(
      appBar: AppBar(
        leading: Padding(
          padding:
              EdgeInsets.symmetric(horizontal: getPercentageWidth(2, context)),
          child: InkWell(
            onTap: () {
              if (!widget.isRecipe) {
                Navigator.pop(context);
              } else {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const BottomNavSec(
                      selectedIndex: 1,
                    ),
                  ),
                );
              }
            },
            child: const IconCircleButton(),
          ),
        ),
        title: Text(
          'Ingredient Features',
          style: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: getTextScale(4, context),
          ),
        ),
      ),
      body: Column(
        children: [
          SizedBox(height: getPercentageHeight(2, context)),
          // Search Box
          Padding(
            padding: EdgeInsets.symmetric(
                horizontal: getPercentageWidth(2, context)),
            child: SearchButton2(
              controller: _searchController,
              onChanged: _filterItems,
              kText: 'Search ingredients...',
            ),
          ),

          Padding(
            padding: EdgeInsets.symmetric(
                horizontal: getPercentageWidth(2, context),
                vertical: getPercentageHeight(1, context)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Ingredients',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: getTextScale(3.5, context),
                    color: isDarkMode ? kWhite : kBlack,
                  ),
                ),
                SizedBox(width: getPercentageWidth(2, context)),
                if (hasMoreItems)
                  Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: getPercentageWidth(2, context)),
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _loadMore,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kAccent,
                        foregroundColor: kWhite,
                        padding: EdgeInsets.symmetric(
                            horizontal: getPercentageWidth(2, context),
                            vertical: getPercentageHeight(1, context)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isLoading
                          ? SizedBox(
                              width: getPercentageWidth(4, context),
                              height: getPercentageHeight(2, context),
                              child: CircularProgressIndicator(
                                color: kAccent,
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(kWhite),
                              ),
                            )
                          : Text(
                              'See More',
                              style: TextStyle(
                                  color: kWhite,
                                  fontSize: getTextScale(3, context)),
                            ),
                    ),
                  ),
              ],
            ),
          ),

          // New List View
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.symmetric(
                  vertical: getPercentageHeight(1, context)),
              itemCount: sortedItems.length,
              itemBuilder: (context, index) {
                final item = sortedItems[index];
                return _buildIngredientListItem(item, isDarkMode);
              },
            ),
          ),
        ],
      ),
    );
  }

  String _buildSubtitle(MacroData item) {
    List<String> parts = [];
    if (item.calories > 0) {
      parts.add('${item.calories} cal');
    }

    // Add up to 3 features from macros and features map
    int featuresCount = 0;

    for (var entry in item.macros.entries) {
      if (featuresCount >= 3) break;
      if (entry.key != 'amount' &&
          entry.value != null &&
          entry.value.toString().isNotEmpty) {
        parts.add('${capitalizeFirstLetter(entry.key)}: ${entry.value}');
        featuresCount++;
      }
    }

    for (var entry in item.features.entries) {
      if (featuresCount >= 3) break;
      if (entry.value != null && entry.value.toString().isNotEmpty) {
        parts.add(
            '${capitalizeFirstLetter(removeDashWithSpace(entry.key))}: ${entry.value}');
        featuresCount++;
      }
    }

    return parts.join(', ');
  }

  Widget _buildIngredientListItem(MacroData item, bool isDarkMode) {
    final bool isSelected = _selectedIngredients.contains(item.title);

    // Subtitle generation logic
    String subtitle = _buildSubtitle(item);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 2,
      color: isDarkMode ? kDarkGrey : kWhite,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => IngredientDetailsScreen(
                item: item,
                ingredientItems: widget.items,
              ),
            ),
          );
        },
        title: Text(
          capitalizeFirstLetter(item.title),
          style: TextStyle(
              fontWeight: FontWeight.bold, color: isDarkMode ? kWhite : kBlack),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(color: Colors.grey[500]),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: IconButton(
          icon: Icon(
            isSelected ? Icons.check_circle : Icons.add_circle_outline,
            color: isSelected ? kAccent : (isDarkMode ? kWhite : kDarkGrey),
            size: 30,
          ),
          onPressed: () => _toggleSelection(item.title),
        ),
      ),
    );
  }
}
