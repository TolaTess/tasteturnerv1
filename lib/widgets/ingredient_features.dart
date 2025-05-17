import '../helper/helper_functions.dart';
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
  final Set<String> headerSet = {};
  final TextEditingController _searchController = TextEditingController();
  late final ScrollController _horizontalScrollController;
  Set<String> _selectedIngredients = {};
  List<MacroData> _filteredItems = [];
  int _displayedItemCount = 10;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _horizontalScrollController = ScrollController();
    for (var item in widget.items) {
      headerSet.addAll(item.features.keys);
    }
    _filteredItems = widget.items.take(10).toList();

    // Fetch user's shopping list and pre-select items
    _preselectShoppingList();
  }

  void _preselectShoppingList() async {
    final userId = userService.userId;
    if (userId == null) return;
    final shoppingListMap = await macroManager
        .fetchShoppingListForWeekWithStatus(userId, getCurrentWeek());
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
    _horizontalScrollController.dispose();
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
        macroManager.addToShoppingList(userService.userId ?? '', item);
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
        title: const Text(
          'Ingredient Features',
          style: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 20,
          ),
        ),
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
                    fontSize: 18,
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
            child: Scrollbar(
              thumbVisibility: true,
              trackVisibility: true,
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 75, right: 20, left: 20),
                scrollDirection: Axis.vertical,
                child: Column(
                  children: [
                    // Horizontal RawScrollbar at the top, above the header
                    RawScrollbar(
                      controller: _horizontalScrollController,
                      thumbVisibility: true,
                      thickness: 8,
                      radius: const Radius.circular(8),
                      thumbColor: kAccentLight,
                      child: SingleChildScrollView(
                        controller: _horizontalScrollController,
                        scrollDirection: Axis.horizontal,
                        child: Builder(
                          builder: (context) {
                            // Calculate total table width
                            final double checkboxColWidth = 60;
                            final double titleColWidth = 100;
                            final double featureColWidth =
                                getPercentageWidth(20, context);
                            final double totalTableWidth = checkboxColWidth +
                                titleColWidth +
                                headers.length * featureColWidth;
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Custom header row
                                Container(
                                  color: kAccentLight.withOpacity(0.1),
                                  child: SizedBox(
                                    width: totalTableWidth,
                                    child: Row(
                                      children: [
                                        Container(
                                          width: checkboxColWidth,
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 12),
                                          child: const Text(
                                            'Check \nto save',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w500,
                                              fontSize: 14,
                                              color: kAccentLight,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                        Container(width: titleColWidth),
                                        ...headers.map(
                                          (header) => Container(
                                            width: featureColWidth,
                                            alignment: Alignment.center,
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
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                Divider(
                                  height: 1,
                                  color: kAccentLight.withOpacity(0.1),
                                ),
                                // Table body (rows)
                                SizedBox(
                                  height:
                                      400, // or use MediaQuery to set max height
                                  width: totalTableWidth,
                                  child: ListView.builder(
                                    shrinkWrap: true,
                                    itemCount: sortedItems.length,
                                    itemBuilder: (context, rowIndex) {
                                      final item = sortedItems[rowIndex];
                                      return Row(
                                        children: [
                                          Container(
                                            width: checkboxColWidth,
                                            alignment: Alignment.center,
                                            child: Theme(
                                              data: Theme.of(context).copyWith(
                                                unselectedWidgetColor:
                                                    isDarkMode
                                                        ? Colors.white
                                                        : Colors.black,
                                              ),
                                              child: Checkbox(
                                                value: _selectedIngredients
                                                    .contains(item.title),
                                                onChanged: (_) =>
                                                    _toggleSelection(
                                                        item.title),
                                                activeColor: kAccent,
                                                checkColor: isDarkMode
                                                    ? kWhite
                                                    : kBlack,
                                              ),
                                            ),
                                          ),
                                          Container(
                                            width: titleColWidth,
                                            alignment: Alignment.centerLeft,
                                            child: GestureDetector(
                                              onTap: () {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) =>
                                                        IngredientDetailsScreen(
                                                      item: item,
                                                      ingredientItems:
                                                          widget.items,
                                                    ),
                                                  ),
                                                );
                                              },
                                              child: Padding(
                                                padding: const EdgeInsets.only(
                                                    top: 6, bottom: 6),
                                                child: Text(
                                                  capitalizeFirstLetter(
                                                      item.title),
                                                  style: const TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          ...headers.map((header) {
                                            final featureValue =
                                                item.features[header];
                                            return Container(
                                              width: featureColWidth,
                                              alignment: Alignment.center,
                                              child: GestureDetector(
                                                onTap: () {
                                                  showFeatureDialog(
                                                      context,
                                                      isDarkMode,
                                                      header,
                                                      featureValue);
                                                },
                                                child: Center(
                                                  child: header.toLowerCase() ==
                                                          "rainbow"
                                                      ? CircleAvatar(
                                                          radius: 10,
                                                          backgroundColor:
                                                              checkRainbowGroup(
                                                                  featureValue
                                                                      .toString()),
                                                        )
                                                      : header.toLowerCase() ==
                                                              "season"
                                                          ? Text(
                                                              textAlign:
                                                                  TextAlign
                                                                      .center,
                                                              featureValue !=
                                                                      null
                                                                  ? featureValue
                                                                      .toString()
                                                                      .toUpperCase()
                                                                  : '-',
                                                              style: TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w500,
                                                                  color: checkSeason(
                                                                      featureValue
                                                                          .toString())),
                                                            )
                                                          : header.toLowerCase() ==
                                                                  "water"
                                                              ? Row(
                                                                  crossAxisAlignment:
                                                                      CrossAxisAlignment
                                                                          .center,
                                                                  children: [
                                                                    Expanded(
                                                                      child:
                                                                          SizedBox(
                                                                        width: getPercentageWidth(
                                                                            80,
                                                                            context),
                                                                        child:
                                                                            LinearProgressIndicator(
                                                                          value:
                                                                              (double.tryParse(featureValue.toString()) ?? 0) / 100,
                                                                          backgroundColor:
                                                                              kBlue.withOpacity(kOpacity),
                                                                          color:
                                                                              kBlueLight.withOpacity(kOpacity),
                                                                        ),
                                                                      ),
                                                                    ),
                                                                    const SizedBox(
                                                                        width:
                                                                            3),
                                                                    Text(
                                                                      featureValue !=
                                                                              null
                                                                          ? '${featureValue.toString()}'
                                                                          : '-',
                                                                      style: const TextStyle(
                                                                          fontSize:
                                                                              10),
                                                                    ),
                                                                  ],
                                                                )
                                                              : Text(
                                                                  featureValue !=
                                                                          null
                                                                      ? capitalizeFirstLetter(
                                                                              featureValue)
                                                                          .toString()
                                                                      : '-',
                                                                  overflow:
                                                                      TextOverflow
                                                                          .ellipsis,
                                                                ),
                                                ),
                                              ),
                                            );
                                          }).toList(),
                                        ],
                                      );
                                    },
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
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
