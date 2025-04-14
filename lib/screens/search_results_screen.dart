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
  String _lastSearchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadMoreMealsIfNeeded();
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
    _apiMeals.clear(); // Clear previous API results
    _hasMore.value = true;

    try {
      final newMeals = await _apiService.fetchMeals(
        limit: 20,
        searchQuery: widget.search,
        screen: widget.screen,
      );

      final localMeals = mealManager.meals;
      // Filter out duplicates based on mealId
      final existingIds = localMeals.map((m) => m.mealId).toList();
      final uniqueNewMeals =
          newMeals.where((meal) => !existingIds.contains(meal.mealId)).toList();

      _apiMeals.addAll(uniqueNewMeals);
      _hasMore.value = uniqueNewMeals.isNotEmpty;
    } catch (e) {
      print('Error searching meals: $e');
    } finally {
      _isLoading.value = false;
    }
  }

  Future<void> _loadMoreMealsIfNeeded() async {
    if (_isLoading.value || !_hasMore.value) return;

    final localMeals = mealManager.meals;
    if (localMeals.length + _apiMeals.length >= 50 && _apiMeals.isEmpty) return;

    _isLoading.value = true;
    try {
      final newMeals = await _apiService.fetchMeals(
        limit: widget.search.isEmpty ? 10 : 20,
        searchQuery: widget.search,
        screen: widget.screen,
      );

      // Filter out duplicates based on mealId
      final existingIds = [
        ...localMeals.map((m) => m.mealId),
        ..._apiMeals.map((m) => m.mealId)
      ];
      final uniqueNewMeals =
          newMeals.where((meal) => !existingIds.contains(meal.mealId)).toList();

      _apiMeals.addAll(uniqueNewMeals);
      _hasMore.value = uniqueNewMeals.isNotEmpty;
    } catch (e) {
      print('Error loading more meals: $e');
    } finally {
      _isLoading.value = false;
    }
  }

  @override
  Widget build(BuildContext context) {

    return Obx(() {
      final localMeals = mealManager.meals;
      List<Meal> displayedMeals = [...localMeals, ..._apiMeals];

      // Filter meals by search keyword
      if (widget.search.isNotEmpty) {
        if (widget.screen == 'ingredient') {
          displayedMeals = displayedMeals
              .where((meal) => meal.ingredients.keys.any((ingredient) =>
                  ingredient
                      .toLowerCase()
                      .contains(widget.search.toLowerCase())))
              .toList();
        } else {
          displayedMeals = displayedMeals
              .where((meal) => meal.categories.any((category) =>
                  category.toLowerCase().contains(widget.search.toLowerCase())))
              .toList();
        }
      }

      if (displayedMeals.isEmpty && !_isLoading.value) {
        return SliverFillRemaining(
          child: noItemTastyWidget(
            "No meals available.",
            "Search for a meal to see results.",
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
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: _isLoading.value
                        ? const CircularProgressIndicator(
                            color: kAccent,
                          )
                        : TextButton(
                            onPressed: _loadMoreMealsIfNeeded,
                            child: const Text('See More'),
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
