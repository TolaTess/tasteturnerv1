import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../constants.dart';
import '../helper/utils.dart';
import '../widgets/bottom_nav.dart';
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
  }) : super(key: key);

  @override
  _RecipeListCategoryState createState() => _RecipeListCategoryState();
}

class _RecipeListCategoryState extends State<RecipeListCategory> {
  final TextEditingController _searchController = TextEditingController();
  String searchQuery = '';
  List<String> selectedMealIds = [];

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
                    const SizedBox(height: 24),

                    // Home app bar
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Back arrow
                          InkWell(
                            onTap: () {
                              if (widget.isBack) {
                                Get.back();
                              } else {
                                Get.to(() => const BottomNavSec(
                                      selectedIndex: 1,
                                      foodScreenTabIndex: 1,
                                    ));
                              }
                            },
                            child: const IconCircleButton(),
                          ),

                          const Text(
                            'Meals',
                            style: TextStyle(
                                fontSize: 20, fontWeight: FontWeight.w700),
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
                    const SizedBox(height: 8),

                    // Search bar
                    widget.isFilter
                        ? const SizedBox.shrink()
                        : Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: SearchButton2(
                              controller: _searchController,
                              onChanged: _onSearchChanged,
                              kText: searchMealHint,
                            ),
                          ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),

            // Recipes list per category

            SearchResultGrid(
              search:
                  searchQuery.isEmpty ? widget.searchIngredient : searchQuery,
              enableSelection: widget.isMealplan,
              selectedMealIds: selectedMealIds,
              onMealToggle: toggleMealSelection,
              screen: widget.screen,
            ),
          ],
        ),
      ),
      floatingActionButton: widget.isMealplan
          ? FloatingActionButton(
              onPressed: selectedMealIds.isNotEmpty
                  ? () =>
                      addMealsToMealPlan(selectedMealIds, widget.mealPlanDate)
                  : null,
              backgroundColor:
                  selectedMealIds.isNotEmpty ? kAccent : kLightGrey,
              child: const Icon(Icons.save),
            )
          : null,
    );
  }
}
