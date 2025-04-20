import 'package:fit_hify/widgets/bottom_nav.dart';
import 'package:fit_hify/widgets/search_button.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  static const String _shoppingListKey = 'shopping_list_selections';
  final Set<String> headerSet = {};
  final TextEditingController _searchController = TextEditingController();
  Set<String> _selectedIngredients = {};
  List<MacroData> _filteredItems = [];
  int _displayedItemCount = 10;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    for (var item in widget.items) {
      headerSet.addAll(item.features.keys);
    }
    _filteredItems = widget.items.take(10).toList();
    _loadSelections();
  }

  Future<void> _loadSelections() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedSelections = prefs.getStringList(_shoppingListKey) ?? [];

      if (mounted) {
        setState(() {
          _selectedIngredients = Set<String>.from(savedSelections);
        });
      }
    } catch (e) {
      print('Error loading selections: $e');
    }
  }

  Future<void> _saveSelections() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> selectionsToSave = _selectedIngredients.toList();
      await prefs.setStringList(_shoppingListKey, selectionsToSave);
    } catch (e) {
      print('Error saving selections: $e');
    }
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

    // Save selections after state update
    _saveSelections();
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
        _displayedItemCount = nextBatch;
        _filteredItems = widget.items
            .where((item) => item.title
                .toLowerCase()
                .contains(_searchController.text.toLowerCase()))
            .take(_displayedItemCount)
            .toList();
      }
      _isLoading = false;
    });
  }

  Future<void> _saveSelectedToShoppingList() async {
    try {
      if (_selectedIngredients.isEmpty) return;

      // Convert selected items to MacroData objects
      final macroDataList = await macroManager
          .fetchAndEnsureIngredientsExist(_selectedIngredients.toList());

      // Save the MacroData items
      await macroManager.saveShoppingList(
        userService.userId ?? '',
        macroDataList,
      );

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Items added to shopping list'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error saving to shopping list: $e');  
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to add items to shopping list'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    final List<String> headers = headerSet.toList();

    final sortedItems = List<MacroData>.from(_filteredItems)
      ..sort((a, b) => a.title.compareTo(b.title));

    // Update hasMoreItems condition to check against the appropriate list
    final hasMoreItems = _searchController.text.isEmpty
        ? widget.items.length > _filteredItems.length
        : widget.items
                .where((item) => item.title
                    .toLowerCase()
                    .contains(_searchController.text.toLowerCase()))
                .length >
            _filteredItems.length;

    return Scaffold(
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
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
        title: const Text('Ingredient Features'),
        actions: [
          if (_selectedIngredients.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 15.0),
              child: GestureDetector(
                onTap: _saveSelectedToShoppingList,
                child: IconCircleButton(
                  icon: Icons.save,
                  isColorChange: true,
                  h: 50,
                  w: 50,
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Search Box
          Padding(
            padding: const EdgeInsets.all(15.0),
            child: SearchButton2(
              controller: _searchController,
              onChanged: _filterItems,
              kText: 'Search ingredients...',
            ),
          ),

          Padding(
            padding: const EdgeInsets.only(left: 20, right: 15),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Ingredients',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                    color: isDarkMode ? kWhite : kBlack,
                  ),
                ),
                const SizedBox(width: 10),
                if (hasMoreItems)
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _loadMore,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kAccent,
                        foregroundColor: kWhite,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(kWhite),
                              ),
                            )
                          : const Text(
                              'See More',
                              style: TextStyle(color: kWhite),
                            ),
                    ),
                  ),
              ],
            ),
          ),

          // Table
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 75),
              scrollDirection: Axis.vertical,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Column(
                  children: [
                    DataTable(
                      columns: [
                        DataColumn(
                          label: Text(
                            'Add to list',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 16,
                              color: isDarkMode ? kWhite : kBlack,
                            ),
                          ),
                        ),
                        const DataColumn(label: Text('')),
                        ...headers
                            .map((header) => DataColumn(
                                headingRowAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                label: Expanded(
                                  child: GestureDetector(
                                    onTap: () {
                                      //todo - header page
                                    },
                                    child: Center(
                                      child: Text(
                                        removeDashWithSpace(header),
                                        style: TextStyle(
                                          fontWeight: FontWeight.w500,
                                          color: isDarkMode
                                              ? kPrimaryColor
                                              : kBlack,
                                        ),
                                      ),
                                    ),
                                  ),
                                )))
                            .toList(),
                      ],
                      rows: sortedItems.map((item) {
                        return DataRow(
                          cells: [
                            DataCell(
                              Theme(
                                data: Theme.of(context).copyWith(
                                  unselectedWidgetColor:
                                      isDarkMode ? Colors.white : Colors.black,
                                ),
                                child: Checkbox(
                                  value:
                                      _selectedIngredients.contains(item.title),
                                  onChanged: (_) =>
                                      _toggleSelection(item.title),
                                  activeColor: kAccent,
                                  checkColor: isDarkMode ? kWhite : kBlack,
                                ),
                              ),
                            ),
                            DataCell(
                              GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          IngredientDetailsScreen(
                                        item: item,
                                        ingredientItems: widget.items,
                                      ),
                                    ),
                                  );
                                },
                                child: Padding(
                                  padding:
                                      const EdgeInsets.only(top: 6, bottom: 6),
                                  child: Text(
                                    capitalizeFirstLetter(item.title),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            ...headers.map((header) {
                              final featureValue = item.features[header];
                              return DataCell(
                                SizedBox(
                                  width: getPercentageWidth(20, context),
                                  child: GestureDetector(
                                    onTap: () {
                                      //todo - cell item page
                                    },
                                    child: Center(
                                      child: header.toLowerCase() == "rainbow"
                                          ? CircleAvatar(
                                              radius: 10,
                                              backgroundColor:
                                                  checkRainbowGroup(
                                                      featureValue.toString()),
                                            )
                                          : header.toLowerCase() == "season"
                                              ? Text(
                                                  textAlign: TextAlign.center,
                                                  featureValue != null
                                                      ? featureValue
                                                          .toString()
                                                          .toUpperCase()
                                                      : '-',
                                                  style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w500,
                                                      color: checkSeason(
                                                          featureValue
                                                              .toString())),
                                                )
                                              : header.toLowerCase() == "water"
                                                  ? Row(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .center,
                                                      children: [
                                                        Expanded(
                                                          child: SizedBox(
                                                            width:
                                                                getPercentageWidth(
                                                                    80,
                                                                    context),
                                                            child:
                                                                LinearProgressIndicator(
                                                              value: (double.tryParse(
                                                                          featureValue
                                                                              .toString()) ??
                                                                      0) /
                                                                  100,
                                                              backgroundColor:
                                                                  kBlue.withOpacity(
                                                                      kOpacity),
                                                              color: kBlue
                                                                  .withOpacity(
                                                                      kOpacity),
                                                            ),
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                            width: 3),
                                                        Text(
                                                          featureValue != null
                                                              ? '${featureValue.toString()}%'
                                                              : '-',
                                                          style:
                                                              const TextStyle(
                                                                  fontSize: 9),
                                                        ),
                                                      ],
                                                    )
                                                  : header.toLowerCase() ==
                                                          "vitamin levels"
                                                      ? Icon(
                                                          Icons.local_florist,
                                                          color: featureValue !=
                                                                      null &&
                                                                  featureValue ==
                                                                      "High"
                                                              ? Colors.green
                                                              : Colors.red,
                                                        )
                                                      : Text(
                                                          featureValue != null
                                                              ? featureValue
                                                                  .toString()
                                                              : '-',
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ],
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
