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
  final String?
      searchQuery; // For distinguishing between initial filter and search
  final String? searchIngredient; // For passing original technique context
  final Function(String mealId)? onMealToggle;
  final Function()? onSave;
  final Function(Meal meal)? onRecipeTap; // New callback for recipe navigation

  const SearchResultGrid({
    super.key,
    this.search = '',
    this.enableSelection = false,
    required this.selectedMealIds,
    this.onMealToggle,
    this.onSave,
    this.screen = 'recipe',
    this.searchQuery,
    this.searchIngredient,
    this.onRecipeTap,
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
    _lastSearchQuery = widget.search;

    // Only perform search if there's a specific search query, not for initial load
    if (widget.search.isNotEmpty &&
        widget.search.toLowerCase() != 'general' &&
        widget.search.toLowerCase() != 'all') {
      _performSearch();
    }
  }

  @override
  void didUpdateWidget(SearchResultGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only perform search if search query actually changed and it's not empty
    if (widget.search != _lastSearchQuery &&
        widget.search.isNotEmpty &&
        widget.search.toLowerCase() != 'general' &&
        widget.search.toLowerCase() != 'all') {
      _lastSearchQuery = widget.search;
      _performSearch();
    } else if (widget.search != _lastSearchQuery) {
      // If search changed to empty/general/all, just reset without fetching
      _lastSearchQuery = widget.search;
      _apiMeals.clear();
      _localMealsDisplayed.value = _localPageSize;
      _hasMore.value = mealManager.meals.length > _localPageSize;
    }
  }

  Future<void> _performSearch() async {
    if (_isLoading.value) return;

    _isLoading.value = true;
    _apiMeals.clear();
    _hasMore.value = true;
    _localMealsDisplayed.value = _localPageSize;

    try {
      if (widget.search.isNotEmpty &&
          widget.search.toLowerCase() != 'general' &&
          widget.search.toLowerCase() != 'all') {
        // Use existing meals data if available to avoid unnecessary Firestore calls
        List<Meal> allMeals = mealManager.meals;

        // Only fetch from Firestore if we don't have meals data
        if (allMeals.isEmpty) {
          final querySnapshot = await firestore
              .collection('meals')
              .orderBy('createdAt', descending: true)
              .get();

          allMeals = querySnapshot.docs
              .map((doc) => Meal.fromJson(doc.id, doc.data()))
              .toList();
        }

        // Special case: show only user's meals if search == 'myMeals'
        if (widget.search == 'myMeals') {
          final userId = userService.userId;
          final myMeals =
              allMeals.where((meal) => meal.userId == userId).toList();
          _apiMeals.addAll(myMeals);
          _hasMore.value = false;
          _localMealsDisplayed.value = myMeals.length;
        } else {
          List<Meal> filteredMeals = [];
          if (widget.screen == 'ingredient') {
            filteredMeals = allMeals
                .where((meal) =>
                    meal.title
                        .toLowerCase()
                        .contains(widget.search.toLowerCase()) ||
                    (meal.ingredients).keys.any((ingredient) => ingredient
                        .toLowerCase()
                        .contains(widget.search.toLowerCase())))
                .toList();
          } else if (widget.screen == 'technique') {
            if (widget.searchQuery != null && widget.searchQuery!.isNotEmpty) {
              // User is searching - first filter by technique, then search within results

              // Get the original technique from searchIngredient parameter
              String originalTechnique =
                  widget.searchIngredient ?? widget.search;

              // First, get technique-filtered meals
              final techniqueFilteredMeals = allMeals
                  .where((meal) => originalTechnique.contains('&')
                      ? originalTechnique.toLowerCase().split('&').every(
                          (method) => meal.cookingMethod!
                              .toLowerCase()
                              .contains(method.trim()))
                      : meal.cookingMethod!
                          .toLowerCase()
                          .contains(originalTechnique.toLowerCase()))
                  .toList();

              // Then search within technique-filtered meals
              filteredMeals = techniqueFilteredMeals
                  .where((meal) => meal.title
                      .toLowerCase()
                      .contains(widget.searchQuery!.toLowerCase()))
                  .toList();
            } else {
              // No search query, show technique-filtered meals
              filteredMeals = allMeals
                  .where((meal) => widget.search.contains('&')
                      ? widget.search.toLowerCase().split('&').every((method) =>
                          meal.cookingMethod!
                              .toLowerCase()
                              .contains(method.trim()))
                      : meal.cookingMethod!
                          .toLowerCase()
                          .contains(widget.search.toLowerCase()))
                  .toList();
            }
          } else {
            // Default search: search by title, ingredients, and categories
            filteredMeals = allMeals
                .where((meal) =>
                    meal.title
                        .toLowerCase()
                        .contains(widget.search.toLowerCase()) ||
                    (meal.ingredients).keys.any((ingredient) => ingredient
                        .toLowerCase()
                        .contains(widget.search.toLowerCase())) ||
                    (meal.categories).any((category) => category
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
    if (widget.search.isNotEmpty &&
        widget.search.toLowerCase() != 'all' &&
        widget.search.toLowerCase() != 'general') {
      // For search, just show the Firestore (api) meals, already sorted
      return _apiMeals;
    } else {
      // For normal browsing or 'all'/'general', show local meals paginated
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
            false,
            '',
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
                    padding: EdgeInsets.all(getPercentageWidth(1, context)),
                    child: _isLoading.value
                        ? Container(
                            padding: EdgeInsets.all(
                                getPercentageWidth(0.8, context)),
                            decoration: BoxDecoration(
                              color: kAccent.withValues(alpha: 0.1),
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
                              padding: EdgeInsets.symmetric(
                                  horizontal: getPercentageWidth(2, context),
                                  vertical: getPercentageHeight(1, context)),
                              backgroundColor: kAccent.withValues(alpha: 0.1),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Text(
                              'See More',
                              style: TextStyle(
                                fontSize: getTextScale(3, context),
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
                    : () {
                        // Use the callback if provided, otherwise fall back to direct navigation
                        if (widget.onRecipeTap != null) {
                          widget.onRecipeTap!(meal);
                        } else {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => RecipeDetailScreen(
                                mealData: meal,
                              ),
                            ),
                          );
                        }
                      },
                height: getPercentageHeight(22, context),
              );
            },
            childCount: displayedMeals.length + (_hasMore.value ? 1 : 0),
          ),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisExtent: getPercentageHeight(20, context),
            crossAxisSpacing: getPercentageWidth(2, context),
            mainAxisSpacing: getPercentageHeight(2, context),
          ),
        ),
      );
    });
  }
}
