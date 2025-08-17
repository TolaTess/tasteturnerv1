import 'package:flutter/material.dart';
import '../widgets/search_button.dart';

import '../constants.dart';
import '../data_models/macro_data.dart';
import '../detail_screen/ingredientdetails_screen.dart';
import '../helper/utils.dart';

class IngredientFeatures extends StatefulWidget {
  final List<MacroData> items;
  final bool isRecipe;
  final String? searchIngredient;
  final String? screen;

  const IngredientFeatures({
    Key? key,
    required this.items,
    this.isRecipe = false,
    this.searchIngredient,
    this.screen,
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

  // Helper method to get base filtered items based on searchIngredient
  List<MacroData> get _baseFilteredItems {
    if (widget.searchIngredient == null || widget.searchIngredient!.isEmpty) {
      return widget.items;
    }

    return widget.items.where((item) {
      // Search in techniques if they exist
      if (item.techniques.isNotEmpty) {
        return item.techniques.any((technique) => technique
            .toLowerCase()
            .contains(widget.searchIngredient!.toLowerCase()));
      }
      if (widget.screen == 'technique') {
        return item.techniques.any((technique) => technique
            .toLowerCase()
            .contains(widget.searchIngredient!.toLowerCase()));
      }
      // Fallback to title search
      return item.title
          .toLowerCase()
          .contains(widget.searchIngredient!.toLowerCase());
    }).toList();
  }

  // Helper method to get technique-filtered items (only for initial display)
  List<MacroData> get _techniqueFilteredItems {
    if (widget.screen != 'technique' ||
        widget.searchIngredient == null ||
        widget.searchIngredient!.isEmpty) {
      return widget.items;
    }

    return widget.items.where((item) {
      return item.techniques.any((technique) => technique
          .toLowerCase()
          .contains(widget.searchIngredient!.toLowerCase()));
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.searchIngredient ?? '';
    // Apply initial filtering based on searchIngredient
    // For technique screen, start with technique-filtered items
    if (widget.screen == 'technique') {
      _filteredItems = _techniqueFilteredItems.take(10).toList();
    } else {
      _filteredItems = _baseFilteredItems.take(10).toList();
    }

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
        // When search is empty, show initial filtered items
        if (widget.screen == 'technique') {
          _filteredItems = _techniqueFilteredItems.take(10).toList();
        } else {
          _filteredItems = _baseFilteredItems.take(10).toList();
        }
        _displayedItemCount = 10;
      } else {
        // When there's a search query, search within the current context
        if (widget.screen == 'technique') {
          // For technique screen, search only within technique-filtered items
          _filteredItems = _techniqueFilteredItems
              .where((item) =>
                  item.title.toLowerCase().contains(query.toLowerCase()))
              .toList();
        } else {
          _filteredItems = _baseFilteredItems
              .where((item) =>
                  item.title.toLowerCase().contains(query.toLowerCase()) ||
                  item.type.toLowerCase().contains(query.toLowerCase()))
              .toList();
        }
        // Reset displayed count on new search
        _displayedItemCount = 10;
      }
    });
  }

  Future<void> _loadMore() async {
    setState(() {
      _isLoading = true;
    });

    await Future.delayed(const Duration(milliseconds: 500));

    setState(() {
      if (widget.screen == 'technique') {
        // For technique screen, "Show All" resets to show all items (not technique-filtered)
        _searchController.clear();
        _filteredItems = widget.items.take(10).toList();
        _displayedItemCount = 10;
      } else {
        final nextBatch = _displayedItemCount + 10;
        if (_searchController.text.isEmpty) {
          // If no search query, load more from base filtered items
          _displayedItemCount = nextBatch;
          _filteredItems =
              _baseFilteredItems.take(_displayedItemCount).toList();
        } else {
          // If there's a search query, load more from search filtered results
          final allFiltered = _baseFilteredItems
              .where((item) => item.title
                  .toLowerCase()
                  .contains(_searchController.text.toLowerCase()))
              .toList();
          _displayedItemCount = nextBatch;
          _filteredItems = allFiltered.take(_displayedItemCount).toList();
        }
      }
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    final textTheme = Theme.of(context).textTheme;
    final sortedItems = List<MacroData>.from(_filteredItems)
      ..sort((a, b) => a.title.compareTo(b.title));

    // Update hasMoreItems condition to work with base filtered items
    final bool hasMoreItems;
    if (widget.screen == 'technique') {
      // For technique screen, show button when there's a technique filter applied that can be reset
      hasMoreItems = widget.searchIngredient != null &&
          widget.searchIngredient!.isNotEmpty &&
          _techniqueFilteredItems.length < widget.items.length;
    } else {
      if (_searchController.text.isEmpty) {
        hasMoreItems = _baseFilteredItems.length > _filteredItems.length;
      } else {
        final allFilteredCount = _baseFilteredItems
            .where((item) => item.title
                .toLowerCase()
                .contains(_searchController.text.toLowerCase()))
            .length;
        hasMoreItems = allFilteredCount > _filteredItems.length;
      }
    }

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: true,
        backgroundColor: kAccent,
        toolbarHeight: getPercentageHeight(10, context),
        centerTitle: true,
        title: Text(
          capitalizeFirstLetter(
              widget.searchIngredient ?? 'Ingredient Features'),
          style: textTheme.displaySmall?.copyWith(
            fontSize: getTextScale(7, context),
            color: isDarkMode ? kWhite : kDarkGrey,
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
              kText: widget.screen == 'technique'
                  ? 'Search ${capitalizeFirstLetter(widget.searchIngredient ?? '')} ingredients..'
                  : 'Search ingredients...',
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
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: getTextScale(5, context),
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
                              child: const CircularProgressIndicator(
                                color: kAccent,
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(kWhite),
                              ),
                            )
                          : Text(
                              widget.screen == 'technique'
                                  ? 'Show All'
                                  : 'See More',
                              style: textTheme.bodyMedium?.copyWith(
                                color: kWhite,
                                fontSize: getTextScale(4, context),
                              ),
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
