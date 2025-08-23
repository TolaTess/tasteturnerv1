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

  // Feature filter state
  Map<String, String> _activeFilters = {};
  Map<String, List<String>> _availableFeatureValues = {};
  bool _showFeatureFilters = false;

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

  // Helper method to get feature-filtered items
  List<MacroData> get _featureFilteredItems {
    List<MacroData> items =
        widget.items; // Use all items, not just base filtered

    if (_activeFilters.isEmpty) {
      return items;
    }

    return items.where((item) {
      return _activeFilters.entries.every((filter) {
        String featureKey = filter.key;
        String filterValue = filter.value;

        if (!item.features.containsKey(featureKey)) {
          return false;
        }

        String itemValue = item.features[featureKey]?.toString() ?? '';

        // Handle consolidated categories for fiber and g_i
        if (featureKey == 'fiber' &&
            (filterValue == 'Low' ||
                filterValue == 'Medium' ||
                filterValue == 'High')) {
          return _matchesFiberCategory(itemValue, filterValue);
        } else if (featureKey == 'g_i' &&
            (filterValue == 'Low' ||
                filterValue == 'Medium' ||
                filterValue == 'High')) {
          return _matchesGiCategory(itemValue, filterValue);
        } else {
          // For other features, use exact match
          return itemValue.toLowerCase() == filterValue.toLowerCase();
        }
      });
    }).toList();
  }

  bool _matchesFiberCategory(String itemValue, String category) {
    double? numericValue = _extractNumericValue(itemValue);
    if (numericValue == null) return false;

    switch (category) {
      case 'Low':
        return numericValue < 3.0;
      case 'Medium':
        return numericValue >= 3.0 && numericValue < 6.0;
      case 'High':
        return numericValue >= 6.0;
      default:
        return false;
    }
  }

  bool _matchesGiCategory(String itemValue, String category) {
    String lowerValue = itemValue.toLowerCase();

    // Check if it's already a category
    if (lowerValue == 'low' || lowerValue == 'medium' || lowerValue == 'high') {
      return capitalizeFirstLetter(itemValue) == category;
    }

    // Extract numeric value and categorize
    double? numericValue = _extractNumericValue(itemValue);
    if (numericValue == null) return false;

    switch (category) {
      case 'Low':
        return numericValue < 55;
      case 'Medium':
        return numericValue >= 55 && numericValue < 70;
      case 'High':
        return numericValue >= 70;
      default:
        return false;
    }
  }

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.searchIngredient ?? '';

    // Initialize feature filters
    _initializeFeatureFilters();

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

  void _initializeFeatureFilters() {
    // Extract unique feature keys and their possible values from all items
    // Only include specific features: fiber, rainbow, season, g_i
    Map<String, Set<String>> featureValues = {};

    for (var item in widget.items) {
      for (var entry in item.features.entries) {
        String key = entry.key;
        String value = entry.value?.toString() ?? '';

        // Only include specific features
        if (key.isNotEmpty &&
            value.isNotEmpty &&
            (key == 'fiber' ||
                key == 'rainbow' ||
                key == 'season' ||
                key == 'g_i')) {
          featureValues.putIfAbsent(key, () => <String>{});
          featureValues[key]!.add(value);
        }
      }
    }

    // Convert to the format we need with consolidated options for fiber and g_i
    _availableFeatureValues = featureValues.map((key, values) {
      List<String> consolidatedValues = [];

      if (key == 'fiber') {
        // Consolidate fiber values into Low, Medium, High categories
        consolidatedValues = _consolidateFiberValues(values.toList());
      } else if (key == 'g_i') {
        // Consolidate g_i values into Low, Medium, High categories
        consolidatedValues = _consolidateGiValues(values.toList());
      } else {
        // For other features, use original values
        consolidatedValues = values.toList()..sort();
      }

      return MapEntry(key, consolidatedValues);
    });
  }

  List<String> _consolidateFiberValues(List<String> values) {
    Set<String> categories = {};

    for (String value in values) {
      // Extract numeric value from fiber string (e.g., "2g" -> 2.0)
      double? numericValue = _extractNumericValue(value);

      if (numericValue != null) {
        if (numericValue < 3.0) {
          categories.add('Low');
        } else if (numericValue < 6.0) {
          categories.add('Medium');
        } else {
          categories.add('High');
        }
      } else {
        // If we can't parse the value, keep it as is
        categories.add(value);
      }
    }

    return categories.toList()..sort();
  }

  List<String> _consolidateGiValues(List<String> values) {
    Set<String> categories = {};

    for (String value in values) {
      String lowerValue = value.toLowerCase();

      // Check if it's already a category
      if (lowerValue == 'low' ||
          lowerValue == 'medium' ||
          lowerValue == 'high') {
        categories.add(capitalizeFirstLetter(value));
      } else {
        // Extract numeric value from g_i string
        double? numericValue = _extractNumericValue(value);

        if (numericValue != null) {
          if (numericValue < 55) {
            categories.add('Low');
          } else if (numericValue < 70) {
            categories.add('Medium');
          } else {
            categories.add('High');
          }
        } else {
          // If we can't parse the value, keep it as is
          categories.add(value);
        }
      }
    }

    return categories.toList()..sort();
  }

  double? _extractNumericValue(String value) {
    // Remove common units and extract numeric value
    String cleaned = value
        .toLowerCase()
        .replaceAll('g', '')
        .replaceAll('%', '')
        .replaceAll(' ', '')
        .trim();

    try {
      return double.parse(cleaned);
    } catch (e) {
      return null;
    }
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
        // When search is empty, show feature-filtered items or all items
        if (_activeFilters.isNotEmpty) {
          _filteredItems = _featureFilteredItems.take(10).toList();
        } else if (widget.screen == 'technique') {
          _filteredItems = _techniqueFilteredItems.take(10).toList();
        } else {
          _filteredItems = _baseFilteredItems.take(10).toList();
        }
        _displayedItemCount = 10;
      } else {
        // When there's a search query, search within feature-filtered items
        List<MacroData> searchBase = _activeFilters.isNotEmpty
            ? _featureFilteredItems
            : (widget.screen == 'technique'
                ? _techniqueFilteredItems
                : _baseFilteredItems);

        if (widget.screen == 'technique') {
          _filteredItems = searchBase
              .where((item) =>
                  item.title.toLowerCase().contains(query.toLowerCase()))
              .toList();
        } else {
          _filteredItems = searchBase
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

  void _applyFeatureFilter(String featureKey, String? value) {
    setState(() {
      // Handle the "Any [Feature]" option (value is null or empty string)
      if (value == null ||
          value.toString().isEmpty ||
          value.toString().toLowerCase().contains('any')) {
        _activeFilters.remove(featureKey);
      } else {
        _activeFilters[featureKey] = value;
      }

      // Reapply all filters and search
      List<MacroData> filteredItems = _featureFilteredItems;

      // Apply search filter if there's a search query
      if (_searchController.text.isNotEmpty) {
        filteredItems = filteredItems.where((item) {
          if (widget.screen == 'technique') {
            return item.title
                .toLowerCase()
                .contains(_searchController.text.toLowerCase());
          } else {
            return item.title
                    .toLowerCase()
                    .contains(_searchController.text.toLowerCase()) ||
                item.type
                    .toLowerCase()
                    .contains(_searchController.text.toLowerCase());
          }
        }).toList();
      }

      _filteredItems = filteredItems.take(10).toList();
      _displayedItemCount = 10;
    });
  }

  void _clearAllFilters() {
    setState(() {
      _activeFilters.clear();

      // Reapply search filter if there's a search query
      List<MacroData> filteredItems = widget.items;
      if (_searchController.text.isNotEmpty) {
        filteredItems = _baseFilteredItems;
      }

      _filteredItems = filteredItems.take(10).toList();
      _displayedItemCount = 10;
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
        if (_searchController.text.isEmpty && _activeFilters.isEmpty) {
          // If no search query and no filters, load more from base filtered items
          _displayedItemCount = nextBatch;
          _filteredItems =
              _baseFilteredItems.take(_displayedItemCount).toList();
        } else {
          // If there's a search query or filters, load more from filtered results
          List<MacroData> allFiltered = _featureFilteredItems;

          // Apply search filter if there's a search query
          if (_searchController.text.isNotEmpty) {
            allFiltered = allFiltered.where((item) {
              if (widget.screen == 'technique') {
                return item.title
                    .toLowerCase()
                    .contains(_searchController.text.toLowerCase());
              } else {
                return item.title
                        .toLowerCase()
                        .contains(_searchController.text.toLowerCase()) ||
                    item.type
                        .toLowerCase()
                        .contains(_searchController.text.toLowerCase());
              }
            }).toList();
          }

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

    // Update hasMoreItems condition to work with filtered items
    final bool hasMoreItems;
    if (widget.screen == 'technique') {
      // For technique screen, show button when there's a technique filter applied that can be reset
      hasMoreItems = widget.searchIngredient != null &&
          widget.searchIngredient!.isNotEmpty &&
          _techniqueFilteredItems.length < widget.items.length;
    } else {
      if (_searchController.text.isEmpty && _activeFilters.isEmpty) {
        hasMoreItems = _baseFilteredItems.length > _filteredItems.length;
      } else {
        final allFilteredCount = _featureFilteredItems
            .where((item) =>
                _searchController.text.isEmpty ||
                item.title
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

          // Feature Filters Toggle
          Padding(
            padding: EdgeInsets.symmetric(
                horizontal: getPercentageWidth(2, context),
                vertical: getPercentageHeight(1, context)),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _showFeatureFilters = !_showFeatureFilters;
                      });
                    },
                    icon: Icon(
                      _showFeatureFilters
                          ? Icons.filter_list
                          : Icons.filter_list_outlined,
                      color: kWhite,
                    ),
                    label: Text(
                      'Feature Filters',
                      style: textTheme.bodyMedium?.copyWith(
                        color: kWhite,
                        fontSize: getTextScale(4, context),
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          _showFeatureFilters ? kAccent : Colors.grey[600],
                      padding: EdgeInsets.symmetric(
                          horizontal: getPercentageWidth(2, context),
                          vertical: getPercentageHeight(1, context)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                if (_activeFilters.isNotEmpty) ...[
                  SizedBox(width: getPercentageWidth(2, context)),
                  ElevatedButton(
                    onPressed: _clearAllFilters,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[400],
                      foregroundColor: kWhite,
                      padding: EdgeInsets.symmetric(
                          horizontal: getPercentageWidth(2, context),
                          vertical: getPercentageHeight(1, context)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Clear',
                      style: textTheme.bodyMedium?.copyWith(
                        color: kWhite,
                        fontSize: getTextScale(4, context),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Feature Filters Panel
          if (_showFeatureFilters)
            Container(
              margin: EdgeInsets.symmetric(
                  horizontal: getPercentageWidth(2, context),
                  vertical: getPercentageHeight(1, context)),
              padding: EdgeInsets.all(getPercentageWidth(2, context)),
              decoration: BoxDecoration(
                color:
                    isDarkMode ? kDarkGrey.withOpacity(0.8) : Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color:
                      isDarkMode ? kWhite.withOpacity(0.2) : Colors.grey[300]!,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Filter by Features',
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isDarkMode ? kWhite : kBlack,
                    ),
                  ),
                  SizedBox(height: getPercentageHeight(1, context)),
                  Wrap(
                    spacing: getPercentageWidth(2, context),
                    runSpacing: getPercentageHeight(1, context),
                    children: _availableFeatureValues.entries.map((entry) {
                      String featureKey = entry.key;
                      List<String> values = entry.value;
                      String? selectedValue = _activeFilters[featureKey];

                      return _buildFeatureFilterChip(
                        featureKey,
                        values,
                        selectedValue,
                        isDarkMode,
                      );
                    }).toList(),
                  ),
                ],
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

  Widget _buildFeatureFilterChip(
    String featureKey,
    List<String> values,
    String? selectedValue,
    bool isDarkMode,
  ) {
    // Get display name for feature key
    String getDisplayName(String key) {
      switch (key) {
        case 'rainbow':
          return 'Rainbow Colors';
        case 'g_i':
          return 'Glycemic Index';
        default:
          return capitalizeFirstLetter(key);
      }
    }

    return PopupMenuButton<String>(
      onSelected: (value) {
        _applyFeatureFilter(featureKey, value);
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'any_${featureKey}',
          child: Text(
            'Any ${getDisplayName(featureKey)}',
            style: TextStyle(
              color: selectedValue == null ? kAccent : Colors.grey[600],
              fontWeight:
                  selectedValue == null ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
        ...values.map((value) => PopupMenuItem(
              value: value,
              child: Text(
                capitalizeFirstLetter(value),
                style: TextStyle(
                  color: selectedValue == value ? kAccent : Colors.grey[600],
                  fontWeight: selectedValue == value
                      ? FontWeight.w600
                      : FontWeight.normal,
                ),
              ),
            )),
      ],
      child: Container(
        padding: EdgeInsets.symmetric(
            horizontal: getPercentageWidth(2, context),
            vertical: getPercentageHeight(0.5, context)),
        decoration: BoxDecoration(
          color: selectedValue != null
              ? kAccent.withOpacity(0.8)
              : isDarkMode
                  ? kWhite.withOpacity(0.1)
                  : Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selectedValue != null
                ? kAccent
                : isDarkMode
                    ? kWhite.withOpacity(0.3)
                    : Colors.grey[400]!,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              getDisplayName(featureKey),
              style: TextStyle(
                color: selectedValue != null
                    ? kWhite
                    : (isDarkMode ? kWhite : kBlack),
                fontWeight: FontWeight.w500,
                fontSize: getTextScale(3.5, context),
              ),
            ),
            if (selectedValue != null) ...[
              SizedBox(width: getPercentageWidth(1, context)),
              Container(
                padding: EdgeInsets.symmetric(
                    horizontal: getPercentageWidth(1, context), vertical: 2),
                decoration: BoxDecoration(
                  color: kWhite.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  capitalizeFirstLetter(selectedValue),
                  style: TextStyle(
                    color: kWhite,
                    fontWeight: FontWeight.w600,
                    fontSize: getTextScale(3, context),
                  ),
                ),
              ),
            ],
            SizedBox(width: getPercentageWidth(1, context)),
            Icon(
              Icons.arrow_drop_down,
              color: selectedValue != null
                  ? kWhite
                  : (isDarkMode ? kWhite : kBlack),
              size: 20,
            ),
          ],
        ),
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
