import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../constants.dart';
import '../helper/utils.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/category_selector.dart';
import '../widgets/icon_widget.dart';
import '../widgets/search_button.dart';
import 'createrecipe_screen.dart';
import 'search_results_screen.dart';

class RecipeListCategory extends StatefulWidget {
  final String searchIngredient;
  final int index;
  final bool isFilter;
  final bool isMealplan;
  final String? mealPlanDate;
  final String screen;
  final bool? isSpecial;
  final bool isSharedCalendar;
  final String? sharedCalendarId;
  final bool isBack;
  final bool isFamilyMode;
  final String? familyMember;
  final bool? isBackToMealPlan;

  const RecipeListCategory({
    Key? key,
    required this.index,
    required this.searchIngredient,
    this.isFilter = false,
    this.isMealplan = false,
    this.mealPlanDate,
    this.screen = 'recipe',
    this.isSpecial,
    this.isSharedCalendar = false,
    this.sharedCalendarId,
    this.isBack = false,
    this.isFamilyMode = false,
    this.familyMember = '',
    this.isBackToMealPlan = false,
  }) : super(key: key);

  @override
  _RecipeListCategoryState createState() => _RecipeListCategoryState();
}

class _RecipeListCategoryState extends State<RecipeListCategory> {
  final TextEditingController _searchController = TextEditingController();
  String searchQuery = '';
  List<String> selectedMealIds = [];
  List<Map<String, dynamic>> _categoryDatasIngredient = [];
  String selectedCategory = 'general';
  String selectedCategoryId = '';

  @override
  void initState() {
    super.initState();
    _onRefresh();
    _searchController.text = widget.searchIngredient;
    if (userService.currentUser?.familyMode ?? false) {
      _categoryDatasIngredient = [...helperController.kidsCategory];
    } else {
      _categoryDatasIngredient = [...helperController.category];
    }

    if (_categoryDatasIngredient.isNotEmpty && selectedCategoryId.isEmpty) {
      selectedCategoryId = _categoryDatasIngredient[0]['id'] ?? '';
      selectedCategory = _categoryDatasIngredient[0]['name'] ?? '';
    }
  }

  Future<void> _onRefresh() async {
    await firebaseService.fetchGeneralData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void toggleMealSelection(String mealId) {
    setState(() {
      if (selectedMealIds.contains(mealId)) {
        selectedMealIds.remove(mealId);
      } else {
        selectedMealIds.add(mealId);
      }
    });
  }

  void _updateCategoryData(String categoryId, String category) {
    if (!mounted) return;
    setState(() {
      selectedCategoryId = categoryId;
      selectedCategory = category;
    });
  }

  void _onSearchChanged(String query) {
    setState(() {
      searchQuery = query;
    });
  }

  Future<void> addMealsToMealPlan(
      List<String> selectedMealIds, String? mealPlanDate) async {
    if (mealPlanDate == null) {
      print('Meal plan date is required.');
      return;
    }

    try {
      final userId = userService.userId!;
      final docRef = widget.isSharedCalendar
          ? firestore
              .collection('shared_calendars')
              .doc(widget.sharedCalendarId ?? '')
              .collection('date')
              .doc(mealPlanDate)
          : firestore
              .collection('mealPlans')
              .doc(userId)
              .collection('date')
              .doc(mealPlanDate);

      // Check if the document exists
      final docSnapshot = await docRef.get();

      if (widget.isFamilyMode && widget.familyMember != null) {
        // Append family member to each meal ID for family mode
        if (widget.familyMember?.toLowerCase() == userService.currentUser?.displayName?.toLowerCase()) {
          selectedMealIds = selectedMealIds.map((mealId) => '$mealId/${userService.userId}').toList();
        } else {
          selectedMealIds = selectedMealIds.map((mealId) => '$mealId/${widget.familyMember}').toList();
        }
      }

      if (docSnapshot.exists) {
        // Update the existing document with the new mealIds
        await docRef.update({
          'meals': FieldValue.arrayUnion(selectedMealIds),
          'date': mealPlanDate,
          'isSpecial': docSnapshot.data()?['isSpecial'] ?? false,
          'userId': userId,
          'timestamp': FieldValue.serverTimestamp(),
        });
      } else {
        // Create a new document for the date
        final data = {
          'meals': selectedMealIds,
          'date': mealPlanDate,
          'isSpecial': widget.isSpecial ?? false,
          'userId': userId,
          'timestamp': FieldValue.serverTimestamp(),
        };

        await docRef.set(data);
      }

      Get.back();
    } catch (e) {
      print('Error adding meals to meal plan: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: getPercentageWidth(3, context),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: getPercentageHeight(2, context)),

                    // Home app bar
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: getPercentageWidth(0.5, context)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Back arrow
                          InkWell(
                            onTap: () {
                              if (widget.isBack || widget.isBackToMealPlan == true) {
                                Get.back();
                              } else {
                                Get.to(() => const BottomNavSec(
                                      selectedIndex: 1,
                                      foodScreenTabIndex: 1,
                                    ));
                              }
                            },
                            child: IconCircleButton(),
                          ),

                          Text(
                            'Meals',
                            style: TextStyle(
                                fontSize: getPercentageWidth(4, context), fontWeight: FontWeight.w700),
                          ),
                          // Add new recipe button
                          InkWell(
                            onTap: () => Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const CreateRecipeScreen(
                                  screenType: 'list',
                                ),
                              ),
                            ),
                            child: const IconCircleButton(
                              icon: Icons.add,
                              isRemoveContainer: false,
                            ),
                          ),
                        ],
                      ),
                    ),
                    widget.isFilter
                        ? const SizedBox.shrink()
                        : SizedBox(height: getPercentageHeight(2, context)),

                    // Search bar
                    widget.isFilter
                        ? const SizedBox.shrink()
                        : Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: getPercentageWidth(1.5, context)),
                            child: SearchButton2(
                              controller: _searchController,
                              onChanged: _onSearchChanged,
                              kText: searchMealHint,
                            ),
                          ),
                    widget.isFilter
                        ? const SizedBox.shrink()
                        : SizedBox(height: getPercentageHeight(2, context)),

                    // Category selector
                    widget.isFilter
                        ? const SizedBox.shrink()
                        : CategorySelector(
                            categories: _categoryDatasIngredient,
                            selectedCategoryId: selectedCategoryId,
                            onCategorySelected: _updateCategoryData,
                            isDarkMode: isDarkMode,
                            accentColor: kAccentLight,
                            darkModeAccentColor: kDarkModeAccent,
                          ),
                    SizedBox(height: getPercentageHeight(2, context)),
                  ],
                ),
              ),
            ),

            // Recipes list per category

            SearchResultGrid(
              search: searchQuery.isEmpty && widget.searchIngredient.isEmpty
                  ? selectedCategory
                  : (searchQuery.isEmpty
                      ? widget.searchIngredient
                      : searchQuery),
              enableSelection: widget.isMealplan,
              selectedMealIds: selectedMealIds,
              onMealToggle: toggleMealSelection,
              screen: widget.screen,
            ),
          ],
        ),
      ),
      floatingActionButton: widget.isMealplan
          ? MediaQuery.of(context).size.height > 1100
              ? FloatingActionButton.large(
              onPressed: selectedMealIds.isNotEmpty
                  ? () => addMealsToMealPlan(
                      appendMealTypes(selectedMealIds), widget.mealPlanDate)
                  : null,
              backgroundColor:
                  selectedMealIds.isNotEmpty ? kAccent : kLightGrey,
              child: Icon(Icons.save, size: getPercentageWidth(6, context)),
            )
          : FloatingActionButton(
              onPressed: selectedMealIds.isNotEmpty
                  ? () => addMealsToMealPlan(
                      appendMealTypes(selectedMealIds), widget.mealPlanDate)
                  : null,
              backgroundColor:
                  selectedMealIds.isNotEmpty ? kAccent : kLightGrey,
              child: Icon(Icons.save, size: getPercentageWidth(6, context)),
            )
          : null,
    );
  }
}
