import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../constants.dart';
import '../data_models/meal_model.dart';
import '../helper/utils.dart';
import '../pages/recipe_card_flex.dart';
import '../detail_screen/recipe_detail.dart';
import '../service/meal_api_service.dart';

class SearchResultGrid extends StatefulWidget {
  final bool enableSelection;
  final List<String> selectedMealIds;
  final String search;
  final String screen;
  final Function(String mealId)? onMealToggle;
  final Function()? onSave;

  const SearchResultGrid({
    super.key,
    this.search = '',
    this.enableSelection = false,
    required this.selectedMealIds,
    this.onMealToggle,
    this.onSave,
    this.screen = 'recipe',
  });

  @override
  State<SearchResultGrid> createState() => _SearchResultGridState();
}

class _SearchResultGridState extends State<SearchResultGrid> {
  final _apiService = MealApiService();
  final RxList<Meal> _apiMeals = <Meal>[].obs;
  final RxBool _isLoading = false.obs;
  final RxBool _hasMore = true.obs;
  final RxInt _localMealsDisplayed = 0.obs;
  String _lastSearchQuery = '';
  static const int _localPageSize = 15;
  static const int _apiPageSize = 20;

  @override
  void initState() {
    super.initState();
    // Initialize with exactly 15 local meals
    _localMealsDisplayed.value = _localPageSize;
    _hasMore.value = mealManager.meals.length > _localPageSize;

    // If there's an initial search query, perform search
    if (widget.search.isNotEmpty) {
      _performSearch();
    }
  }

  @override
  void didUpdateWidget(SearchResultGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If search query changed, perform new search
    if (widget.search != _lastSearchQuery) {
      _lastSearchQuery = widget.search;
      _performSearch();
    }
  }

  Future<void> _performSearch() async {
    if (_isLoading.value) return;

    _isLoading.value = true;
    _apiMeals.clear();
    _hasMore.value = true;
    _localMealsDisplayed.value = _localPageSize;

    try {
      if (widget.search.isNotEmpty) {
        // Special case: show only user's meals if search == 'myMeals'
        if (widget.search == 'myMeals') {
          final userId = userService.userId;
          final querySnapshot = await firestore
              .collection('meals')
              .where('userId', isEqualTo: userId)
              .orderBy('createdAt', descending: true)
              .get();

          final myMeals = querySnapshot.docs
              .map((doc) => Meal.fromJson(doc.id, doc.data()))
              .toList();
          _apiMeals.addAll(myMeals);
          _hasMore.value = false;
          _localMealsDisplayed.value = myMeals.length;
        } else {
          // Search Firestore for all meals matching the search, ordered by createdAt desc
          final querySnapshot = await firestore
              .collection('meals')
              .orderBy('createdAt', descending: true)
              .get();

          final allMeals = querySnapshot.docs
              .map((doc) => Meal.fromJson(doc.id, doc.data()))
              .toList();

          List<Meal> filteredMeals = [];
          if (widget.screen == 'ingredient') {
            filteredMeals = allMeals
                .where((meal) => (meal.ingredients).keys.any((ingredient) =>
                    ingredient
                        .toLowerCase()
                        .contains(widget.search.toLowerCase())))
                .toList();
          } else {
            filteredMeals = allMeals
                .where((meal) => (meal.categories).any((category) => category
                    .toLowerCase()
                    .contains(widget.search.toLowerCase())))
                .toList();
          }

          // Show only the most recent meals first
          filteredMeals.sort((a, b) => b.createdAt.compareTo(a.createdAt));

          _apiMeals.addAll(filteredMeals);
          _hasMore.value = false;
          _localMealsDisplayed.value = filteredMeals.length;
        }
      } else {
        _apiMeals.clear();
        _hasMore.value = mealManager.meals.length > _localPageSize;
      }
    } catch (e) {
      print('Error searching meals: $e');
    } finally {
      _isLoading.value = false;
    }
  }

  List<Meal> _getFilteredMeals() {
    if (widget.search.isNotEmpty) {
      // For search, just show the Firestore (api) meals, already sorted
      return _apiMeals;
    } else {
      // For normal browsing, show local meals (recent first) and then API meals
      final localMeals = mealManager.meals;
      final sortedLocalMeals = [...localMeals];
      sortedLocalMeals.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return [
        ...sortedLocalMeals.take(_localMealsDisplayed.value),
        ..._apiMeals
      ];
    }
  }

  Future<void> _loadMoreMealsIfNeeded() async {
    if (_isLoading.value) return;

    final localMeals = mealManager.meals;

    // Set loading state before any operation
    _isLoading.value = true;

    try {
      // If we still have local meals to show
      if (_localMealsDisplayed.value < localMeals.length) {
        // Add a small delay to show loading state
        await Future.delayed(const Duration(milliseconds: 300));
        _localMealsDisplayed.value += _localPageSize;
        _hasMore.value = _localMealsDisplayed.value < localMeals.length ||
            widget.search.isEmpty;
        return;
      }

      // If we've shown all local meals and search is empty, start fetching from API
      if (widget.search.isEmpty &&
          _localMealsDisplayed.value >= localMeals.length) {
        final newMeals = await _apiService.fetchMeals(
          limit: _apiPageSize,
          searchQuery: widget.search,
          screen: widget.screen,
        );

        // Filter out duplicates
        final existingIds = [
          ...localMeals.map((m) => m.mealId),
          ..._apiMeals.map((m) => m.mealId)
        ];
        final uniqueNewMeals = newMeals
            .where((meal) => !existingIds.contains(meal.mealId))
            .toList();

        _apiMeals.addAll(uniqueNewMeals);
        _hasMore.value = uniqueNewMeals.isNotEmpty;
      }
    } catch (e) {
      print('Error loading more meals: $e');
    } finally {
      _isLoading.value = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final displayedMeals = _getFilteredMeals();

      if (displayedMeals.isEmpty && !_isLoading.value) {
        return SliverFillRemaining(
          child: noItemTastyWidget(
            "No meals available.",
            "",
            context,
            true,
          ),
        );
      }

      return SliverPadding(
        padding: EdgeInsets.symmetric(
          horizontal: getPercentageWidth(3, context),
          vertical: getPercentageHeight(1, context),
        ),
        sliver: SliverGrid(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              if (index == displayedMeals.length) {
                if (!_hasMore.value) return null;

                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: _isLoading.value
                        ? Container(
                            padding: const EdgeInsets.all(8.0),
                            decoration: BoxDecoration(
                              color: kAccent.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const CircularProgressIndicator(
                              color: kAccent,
                              strokeWidth: 3,
                            ),
                          )
                        : TextButton(
                            onPressed: _loadMoreMealsIfNeeded,
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 12),
                              backgroundColor: kAccent.withOpacity(0.1),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              'See More',
                              style: TextStyle(
                                color: kAccent,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                  ),
                );
              }

              final meal = displayedMeals[index];
              final isSelected = widget.selectedMealIds.contains(meal.mealId);
              return RecipeCardFlex(
                recipe: meal,
                isSelected: widget.enableSelection && isSelected,
                press: widget.enableSelection
                    ? () {
                        if (widget.onMealToggle != null) {
                          widget.onMealToggle!(meal.mealId);
                        }
                      }
                    : () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => RecipeDetailScreen(
                              mealData: meal,
                            ),
                          ),
                        ),
                height: getPercentageHeight(28, context),
              );
            },
            childCount: displayedMeals.length + (_hasMore.value ? 1 : 0),
          ),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisExtent: getPercentageHeight(25, context),
            crossAxisSpacing: getPercentageWidth(2, context),
            mainAxisSpacing: getPercentageHeight(2, context),
          ),
        ),
      );
    });
  }
}
