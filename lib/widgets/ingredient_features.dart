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

          // Table
          Expanded(
            child: Scrollbar(
              thumbVisibility: true,
              trackVisibility: true,
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                    horizontal: getPercentageWidth(2, context),
                    vertical: getPercentageHeight(2, context)),
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
                            final double checkboxColWidth =
                                getPercentageWidth(10, context);
                            final double titleColWidth =
                                getPercentageWidth(20, context);
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
                                          padding: EdgeInsets.symmetric(
                                              vertical: getPercentageHeight(
                                                  1, context)),
                                          child: Text(
                                            'Check \nto save',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w500,
                                              fontSize:
                                                  getTextScale(3, context),
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
                                                    fontSize: getTextScale(
                                                        3, context),
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
                                  height: getPercentageHeight(0.5, context),
                                  color: kAccentLight.withOpacity(0.1),
                                ),
                                // Table body (rows)
                                SizedBox(
                                  height: getPercentageHeight(60,
                                      context), // or use MediaQuery to set max height
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
                                                padding: EdgeInsets.symmetric(
                                                    vertical:
                                                        getPercentageHeight(
                                                            1, context)),
                                                child: Text(
                                                  capitalizeFirstLetter(
                                                      item.title),
                                                  style: TextStyle(
                                                    fontSize:
                                                        getTextScale(3, context),
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
                                                          radius:
                                                              getPercentageWidth(
                                                                  2, context),
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
                                                                  fontSize:
                                                                      getTextScale(
                                                                          2.5,
                                                                          context),
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
                                                                    SizedBox(
                                                                        width: getPercentageWidth(
                                                                            1,
                                                                            context)),
                                                                    Text(
                                                                      featureValue !=
                                                                              null
                                                                          ? '${featureValue.toString()}'
                                                                          : '-',
                                                                      style: TextStyle(
                                                                          fontSize: getTextScale(
                                                                              2,
                                                                              context)),
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
                                                                  style: TextStyle(
                                                                      fontSize: getTextScale(
                                                                          2.5,
                                                                          context)),
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
