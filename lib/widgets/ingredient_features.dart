import 'package:flutter/material.dart';
import '../widgets/search_button.dart';

import '../constants.dart';
import '../data_models/macro_data.dart';
import '../detail_screen/ingredientdetails_screen.dart';
import '../helper/utils.dart';
import '../helper/helper_functions.dart';

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
  bool _isGridView = true; // Grid view by default

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
          // For rainbow colors, consolidate and normalize color names
          if (key == 'rainbow') {
            final lowerValue = value.toLowerCase().trim();
            // Check if it's a known color
            final knownColors = ['red', 'orange', 'yellow', 'green', 'blue', 'purple', 'violet', 'white', 'brown', 'pink', 'grey'];
            
            // Normalize color name (capitalize first letter for display)
            String normalizedColor;
            if (knownColors.contains(lowerValue)) {
              // Use the normalized version (capitalize first letter)
              normalizedColor = lowerValue.isEmpty 
                  ? '' 
                  : lowerValue[0].toUpperCase() + (lowerValue.length > 1 ? lowerValue.substring(1) : '');
            } else {
              // Unknown color - use 'Grey'
              normalizedColor = 'Grey';
            }
            
            // Add normalized color (Set will automatically handle duplicates)
            if (normalizedColor.isNotEmpty) {
              featureValues[key]!.add(normalizedColor);
            }
          } else {
          featureValues[key]!.add(value);
          }
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
      } else if (key == 'rainbow') {
        // For rainbow colors, values are already normalized and consolidated
        // Just sort them (but keep 'Grey' at the end if present)
        consolidatedValues = values.toList();
        consolidatedValues.sort((a, b) {
          // Put 'Grey' at the end
          if (a.toLowerCase() == 'grey') return 1;
          if (b.toLowerCase() == 'grey') return -1;
          return a.toLowerCase().compareTo(b.toLowerCase());
        });
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
          widget.searchIngredient != null && widget.searchIngredient!.isNotEmpty
              ? capitalizeFirstLetter(widget.searchIngredient!)
              : 'The Walk-In',
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
                  : 'Check inventory...',
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

          // Feature Filters Panel - Chef Terminology
          if (_showFeatureFilters)
            Container(
              margin: EdgeInsets.symmetric(
                  horizontal: getPercentageWidth(2, context),
                  vertical: getPercentageHeight(1, context)),
              padding: EdgeInsets.all(getPercentageWidth(2, context)),
              decoration: BoxDecoration(
                color: isDarkMode
                    ? kDarkGrey.withValues(alpha: 0.8)
                    : Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDarkMode
                      ? kWhite.withValues(alpha: 0.2)
                      : Colors.grey[300]!,
                ),
              ),
              child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                      'Chef\'s Selection Criteria',
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isDarkMode ? kWhite : kBlack,
                    ),
                  ),
                    SizedBox(height: getPercentageHeight(1.5, context)),
                    // Plating Aesthetics (Rainbow Colors)
                    if (_availableFeatureValues.containsKey('rainbow'))
                      _buildPlatingAestheticsFilter(
                          context, isDarkMode, textTheme),
                  SizedBox(height: getPercentageHeight(1, context)),
                    // Market Status (Season)
                    if (_availableFeatureValues.containsKey('season'))
                      _buildMarketStatusFilter(context, isDarkMode, textTheme),
                    SizedBox(height: getPercentageHeight(1, context)),
                    // Texture / Satiety (Fiber)
                    if (_availableFeatureValues.containsKey('fiber'))
                      _buildTextureSatietyFilter(context, isDarkMode, textTheme),
                    SizedBox(height: getPercentageHeight(1, context)),
                    // Burn Rate (GI)
                    if (_availableFeatureValues.containsKey('g_i'))
                      _buildBurnRateFilter(context, isDarkMode, textTheme),
                  ],
                ),
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
                  'Stockpile',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: getTextScale(5, context),
                    color: isDarkMode ? kWhite : kBlack,
                  ),
                ),
                Row(
                  children: [
                    // Grid/List Toggle
                    IconButton(
                      onPressed: () {
                        setState(() {
                          _isGridView = !_isGridView;
                        });
                      },
                      icon: Icon(
                        _isGridView ? Icons.view_list : Icons.grid_view,
                        color: isDarkMode ? kWhite : kBlack,
                        size: getPercentageWidth(5, context),
                      ),
                      tooltip: _isGridView
                          ? 'Switch to List View'
                          : 'Switch to Grid View',
                    ),
                    SizedBox(width: getPercentageWidth(1, context)),
                if (hasMoreItems)
                      ElevatedButton(
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
                  ],
                  ),
              ],
            ),
          ),

          // Inventory View (Grid or List)
          Expanded(
            child: _isGridView
                ? GridView.builder(
              padding: EdgeInsets.symmetric(
                        horizontal: getPercentageWidth(2, context),
                        vertical: getPercentageHeight(1, context)),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: getPercentageWidth(2, context),
                      mainAxisSpacing: getPercentageHeight(1, context),
                      childAspectRatio: 0.75,
                    ),
                    itemCount: sortedItems.length,
                    itemBuilder: (context, index) {
                      final item = sortedItems[index];
                      return _buildInventoryCard(item, isDarkMode);
                    },
                  )
                : ListView.builder(
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

  // Plating Aesthetics Filter - Color Swatches
  Widget _buildPlatingAestheticsFilter(
      BuildContext context, bool isDarkMode, TextTheme textTheme) {
    final selectedColor = _activeFilters['rainbow'];
    final availableColors = _availableFeatureValues['rainbow'] ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.palette,
                size: getPercentageWidth(4, context),
                color: isDarkMode ? kWhite : kBlack),
            SizedBox(width: getPercentageWidth(1, context)),
            Text(
              'Plating Aesthetics',
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: isDarkMode ? kWhite : kBlack,
                fontSize: getTextScale(4, context),
              ),
            ),
          ],
        ),
        SizedBox(height: getPercentageHeight(1, context)),
        Wrap(
          spacing: getPercentageWidth(2, context),
          runSpacing: getPercentageHeight(1, context),
          children: [
            // "Any" option
            GestureDetector(
              onTap: () => _applyFeatureFilter('rainbow', null),
              child: Container(
                width: getPercentageWidth(8, context),
                height: getPercentageWidth(8, context),
                decoration: BoxDecoration(
                  color: selectedColor == null
                      ? kAccent.withValues(alpha: 0.3)
                      : isDarkMode
                          ? kWhite.withValues(alpha: 0.1)
                          : Colors.grey[200],
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selectedColor == null
                        ? kAccent
                        : (isDarkMode
                            ? kWhite.withValues(alpha: 0.3)
                            : Colors.grey[400]!),
                    width: selectedColor == null ? 2 : 1,
                  ),
                ),
                child: Center(
                  child: Text(
                    'Any',
                    style: TextStyle(
                      fontSize: getTextScale(2.5, context),
                      color: selectedColor == null
                          ? kAccent
                          : (isDarkMode ? kWhite : kBlack),
                      fontWeight: selectedColor == null
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            ),
            // Color swatches
            ...availableColors.map((colorName) {
              final isSelected = selectedColor == colorName;
              // Get color, defaulting to grey for unknown/empty/null values
              final color = getRainbowColor(colorName);
              return GestureDetector(
                onTap: () => _applyFeatureFilter('rainbow', colorName),
                child: Container(
                  width: getPercentageWidth(8, context),
                  height: getPercentageWidth(8, context),
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected
                          ? kAccent
                          : (isDarkMode
                              ? kWhite.withValues(alpha: 0.3)
                              : Colors.grey[400]!),
                      width: isSelected ? 3 : 1,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: kAccent.withValues(alpha: 0.5),
                              blurRadius: 8,
                              spreadRadius: 2,
                            )
                          ]
                        : null,
                  ),
                ),
              );
            }),
          ],
        ),
      ],
    );
  }

  // Market Status Filter - Season Toggle
  Widget _buildMarketStatusFilter(
      BuildContext context, bool isDarkMode, TextTheme textTheme) {
    final selectedSeason = _activeFilters['season'];
    final availableSeasons = _availableFeatureValues['season'] ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.local_grocery_store,
                size: getPercentageWidth(4, context),
                color: isDarkMode ? kWhite : kBlack),
            SizedBox(width: getPercentageWidth(1, context)),
            Text(
              'Market Status',
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: isDarkMode ? kWhite : kBlack,
                fontSize: getTextScale(4, context),
              ),
            ),
          ],
        ),
        SizedBox(height: getPercentageHeight(1, context)),
        Wrap(
          spacing: getPercentageWidth(2, context),
          runSpacing: getPercentageHeight(1, context),
          children: [
            // "Any" option
            _buildSeasonChip(context, isDarkMode, 'Any', null, selectedSeason,
                () {
              _applyFeatureFilter('season', null);
            }),
            // "Peak Season" option
            if (availableSeasons.any((s) =>
                s.toLowerCase().contains('spring') ||
                s.toLowerCase().contains('summer') ||
                s.toLowerCase().contains('fall') ||
                s.toLowerCase().contains('winter')))
              _buildSeasonChip(
                  context, isDarkMode, 'Peak Season', 'peak', selectedSeason,
                  () {
                // Find a season that's currently in season
                final inSeason = availableSeasons.firstWhere(
                    (s) => isCurrentlyInSeason(s),
                    orElse: () => availableSeasons.first);
                _applyFeatureFilter('season', inSeason);
              }),
            // "Year-Round" option
            if (availableSeasons.any((s) =>
                s.toLowerCase().contains('all-year') ||
                s.toLowerCase().contains('year-round')))
              _buildSeasonChip(context, isDarkMode, 'Year-Round', 'year-round',
                  selectedSeason, () {
                final yearRound = availableSeasons.firstWhere(
                    (s) =>
                        s.toLowerCase().contains('all-year') ||
                        s.toLowerCase().contains('year-round'),
                    orElse: () => availableSeasons.first);
                _applyFeatureFilter('season', yearRound);
              }),
          ],
        ),
      ],
    );
  }

  Widget _buildSeasonChip(BuildContext context, bool isDarkMode, String label,
      String? value, String? selectedValue, VoidCallback onTap) {
    bool isSelected;
    if (value == null) {
      // "Any" option - selected when no filter is active
      isSelected = selectedValue == null;
    } else if (value == 'peak') {
      // "Peak Season" option - selected when the selected season is currently in season
      isSelected = selectedValue != null && isCurrentlyInSeason(selectedValue);
    } else if (value == 'year-round') {
      // "Year-Round" option - selected when selected season contains all-year or year-round
      isSelected = selectedValue != null &&
          (selectedValue.toLowerCase().contains('all-year') ||
              selectedValue.toLowerCase().contains('year-round'));
    } else {
      isSelected = false;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
            horizontal: getPercentageWidth(2.5, context),
            vertical: getPercentageHeight(0.8, context)),
        decoration: BoxDecoration(
          color: isSelected
              ? kAccent.withValues(alpha: 0.8)
              : isDarkMode
                  ? kWhite.withValues(alpha: 0.1)
                  : Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? kAccent
                : (isDarkMode
                    ? kWhite.withValues(alpha: 0.3)
                    : Colors.grey[400]!),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (label == 'Peak Season')
              Icon(Icons.eco, size: 16, color: isSelected ? kWhite : null),
            if (label == 'Peak Season')
              SizedBox(width: getPercentageWidth(0.5, context)),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? kWhite : (isDarkMode ? kWhite : kBlack),
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                fontSize: getTextScale(3.5, context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Texture / Satiety Filter - Fiber Selector
  Widget _buildTextureSatietyFilter(
      BuildContext context, bool isDarkMode, TextTheme textTheme) {
    final selectedFiber = _activeFilters['fiber'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.scale,
                size: getPercentageWidth(4, context),
                color: isDarkMode ? kWhite : kBlack),
            SizedBox(width: getPercentageWidth(1, context)),
            Text(
              'Texture / Satiety',
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: isDarkMode ? kWhite : kBlack,
                fontSize: getTextScale(4, context),
              ),
            ),
          ],
        ),
        SizedBox(height: getPercentageHeight(1, context)),
        Row(
          children: [
            _buildSatietyChip(context, isDarkMode, 'Any', null, selectedFiber,
                () {
              _applyFeatureFilter('fiber', null);
            }),
            SizedBox(width: getPercentageWidth(2, context)),
            _buildSatietyChip(
                context, isDarkMode, 'Light', 'Low', selectedFiber, () {
              _applyFeatureFilter('fiber', 'Low');
            }),
            SizedBox(width: getPercentageWidth(2, context)),
            _buildSatietyChip(
                context, isDarkMode, 'Medium Body', 'Medium', selectedFiber,
                () {
              _applyFeatureFilter('fiber', 'Medium');
            }),
            SizedBox(width: getPercentageWidth(2, context)),
            _buildSatietyChip(
                context, isDarkMode, 'Dense', 'High', selectedFiber, () {
              _applyFeatureFilter('fiber', 'High');
            }),
          ],
        ),
      ],
    );
  }

  Widget _buildSatietyChip(BuildContext context, bool isDarkMode, String label,
      String? value, String? selectedValue, VoidCallback onTap) {
    final isSelected =
        value == null ? selectedValue == null : selectedValue == value;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding:
              EdgeInsets.symmetric(vertical: getPercentageHeight(0.8, context)),
          decoration: BoxDecoration(
            color: isSelected
                ? kAccent.withValues(alpha: 0.8)
                : isDarkMode
                    ? kWhite.withValues(alpha: 0.1)
                    : Colors.grey[200],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? kAccent
                  : (isDarkMode
                      ? kWhite.withValues(alpha: 0.3)
                      : Colors.grey[400]!),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? kWhite : (isDarkMode ? kWhite : kBlack),
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                fontSize: getTextScale(3, context),
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }

  // Burn Rate Filter - GI Selector
  Widget _buildBurnRateFilter(
      BuildContext context, bool isDarkMode, TextTheme textTheme) {
    final selectedGi = _activeFilters['g_i'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.speed,
                size: getPercentageWidth(4, context),
                color: isDarkMode ? kWhite : kBlack),
            SizedBox(width: getPercentageWidth(1, context)),
            Text(
              'Burn Rate',
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: isDarkMode ? kWhite : kBlack,
                fontSize: getTextScale(4, context),
              ),
            ),
          ],
        ),
        SizedBox(height: getPercentageHeight(1, context)),
        Row(
          children: [
            Expanded(
              child: _buildBurnRateChip(
                  context, isDarkMode, 'Any', null, selectedGi, () {
                _applyFeatureFilter('g_i', null);
              }, null),
            ),
            SizedBox(width: getPercentageWidth(2, context)),
            Expanded(
              child: _buildBurnRateChip(
                  context, isDarkMode, 'Slow Burn', 'Low', selectedGi, () {
                _applyFeatureFilter('g_i', 'Low');
              }, Icons.trending_down),
            ),
            SizedBox(width: getPercentageWidth(2, context)),
            Expanded(
              child: _buildBurnRateChip(
                  context, isDarkMode, 'Fast Burn', 'High', selectedGi, () {
                _applyFeatureFilter('g_i', 'High');
              }, Icons.local_fire_department),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBurnRateChip(
      BuildContext context,
      bool isDarkMode,
      String label,
      String? value,
      String? selectedValue,
      VoidCallback onTap,
      IconData? icon) {
    final isSelected =
        value == null ? selectedValue == null : selectedValue == value;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            EdgeInsets.symmetric(vertical: getPercentageHeight(0.8, context)),
        decoration: BoxDecoration(
          color: isSelected
              ? kAccent.withValues(alpha: 0.8)
              : isDarkMode
                  ? kWhite.withValues(alpha: 0.1)
                  : Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? kAccent
                : (isDarkMode
                    ? kWhite.withValues(alpha: 0.3)
                    : Colors.grey[400]!),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null)
              Icon(
                icon,
                size: getPercentageWidth(5, context),
                color: isSelected ? kWhite : (isDarkMode ? kWhite : kBlack),
              ),
            if (icon != null)
              SizedBox(height: getPercentageHeight(0.3, context)),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? kWhite : (isDarkMode ? kWhite : kBlack),
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                fontSize: getTextScale(3, context),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
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
              ? kAccent.withValues(alpha: 0.8)
              : isDarkMode
                  ? kWhite.withValues(alpha: 0.1)
                  : Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selectedValue != null
                ? kAccent
                : isDarkMode
                    ? kWhite.withValues(alpha: 0.3)
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
                  color: kWhite.withValues(alpha: 0.2),
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

  // Stockpile Card for Grid View
  Widget _buildInventoryCard(MacroData item, bool isDarkMode) {
    final bool isSelected = _selectedIngredients.contains(item.title);
    final imagePath = item.mediaPaths.isNotEmpty
        ? item.mediaPaths.first
        : item.type.isNotEmpty
            ? item.type.toLowerCase()
            : 'placeholder';

    // Check if item is in season
    final season = item.features['season']?.toString() ?? '';
    final isInSeason = season.isNotEmpty && isCurrentlyInSeason(season);

    return Card(
      margin: EdgeInsets.zero,
      elevation: 2,
      color: isDarkMode ? kDarkGrey : kWhite,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: InkWell(
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
        borderRadius: BorderRadius.circular(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image with seasonality badge
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(15),
                    topRight: Radius.circular(15),
                  ),
                  child: Image.asset(
                    getAssetImageForItem(imagePath),
                    height: getPercentageHeight(20, context),
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                // Seasonality badge
                if (isInSeason)
                  Positioned(
                    top: getPercentageHeight(0.5, context),
                    right: getPercentageWidth(1, context),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: getPercentageWidth(1.5, context),
                          vertical: getPercentageHeight(0.3, context)),
                      decoration: BoxDecoration(
                        color: kGreen.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.eco,
                              size: getPercentageWidth(3, context),
                              color: kWhite),
                          SizedBox(width: getPercentageWidth(0.5, context)),
                          Text(
                            'Peak',
                            style: TextStyle(
                              color: kWhite,
                              fontSize: getTextScale(2.5, context),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                // Shopping list toggle
                Positioned(
                  top: getPercentageHeight(0.5, context),
                  left: getPercentageWidth(1, context),
                  child: GestureDetector(
                    onTap: () => _toggleSelection(item.title),
                    child: Container(
                      padding: EdgeInsets.all(getPercentageWidth(1, context)),
                      decoration: BoxDecoration(
                        color: isDarkMode
                            ? kDarkGrey.withValues(alpha: 0.8)
                            : kWhite.withValues(alpha: 0.8),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isSelected
                            ? Icons.check_circle
                            : Icons.add_circle_outline,
                        color: isSelected
                            ? kAccent
                            : (isDarkMode ? kWhite : kDarkGrey),
                        size: getPercentageWidth(5, context),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            // Ingredient name
            Padding(
              padding: EdgeInsets.all(getPercentageWidth(2, context)),
              child: Text(
                capitalizeFirstLetter(item.title),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: getTextScale(3.5, context),
                  color: isDarkMode ? kWhite : kBlack,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
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
