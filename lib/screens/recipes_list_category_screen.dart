import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tasteturner/pages/edit_goal.dart';
import '../constants.dart';
import '../helper/utils.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/category_selector.dart';
import '../widgets/icon_widget.dart';
import '../widgets/search_button.dart';
import 'createrecipe_screen.dart';
import 'search_results_screen.dart';
import '../data_models/meal_model.dart';
import '../pages/recipe_card_flex.dart';
import '../detail_screen/recipe_detail.dart';

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
  String selectedCategory = 'general';
  String selectedCategoryId = '';
  String selectedDietFilter = '';
  @override
  void initState() {
    super.initState();
    _onRefresh();
    _searchController.text = widget.searchIngredient;
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
        if (widget.familyMember?.toLowerCase() ==
            userService.currentUser.value?.displayName?.toLowerCase()) {
          selectedMealIds = selectedMealIds
              .map((mealId) => '$mealId/${userService.userId}')
              .toList();
        } else {
          selectedMealIds = selectedMealIds
              .map((mealId) => '$mealId/${widget.familyMember}')
              .toList();
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
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          'Meals',
          style: TextStyle(fontSize: getTextScale(4, context)),
        ),
        actions: [
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
          SizedBox(width: getPercentageWidth(2, context)),
        ],
      ),
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

                    // Curated dietPreference meals section
                    Obx(() {
                      final dietPreference =
                          userService.currentUser.value?.settings['dietPreference'];
                    if (dietPreference != null && !widget.isFilter) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Curated $dietPreference Meals',
                                style: TextStyle(
                                    fontSize: getTextScale(4, context),
                                    fontWeight: FontWeight.w600,
                                    color: kAccent),
                              ),
                              IconButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const NutritionSettingsPage(
                                              isHealthExpand: true),
                                    ),
                                  );
                                },
                                icon: Icon(
                                  Icons.edit,
                                  size: getIconScale(5, context),
                                  color: kAccent,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: getPercentageHeight(2, context)),
                          FutureBuilder<List<Meal>>(
                            future: mealManager.fetchMealsByCategory(
                              dietPreference.toString().toLowerCase(),
                            ),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return SizedBox(
                                  height: getPercentageHeight(18, context),
                                  child: Center(
                                      child: CircularProgressIndicator()),
                                );
                              }
                              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                                return SizedBox(
                                  height: getPercentageHeight(6, context),
                                  child: Center(
                                      child: Text(
                                          'No meals found for your diet preference.')),
                                );
                              }
                              final meals = snapshot.data!;
                              return SizedBox(
                                height: getPercentageHeight(18, context),
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: meals.length,
                                  separatorBuilder: (context, idx) => SizedBox(
                                      width: getPercentageWidth(2, context)),
                                  itemBuilder: (context, idx) {
                                    final meal = meals[idx];
                                    return SizedBox(
                                      width: getPercentageWidth(45, context),
                                      child: RecipeCardFlex(
                                        recipe: meal,
                                        press: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  RecipeDetailScreen(
                                                mealData: meal,
                                                screen: 'recipe',
                                              ),
                                            ),
                                          );
                                        },
                                        height:
                                            getPercentageHeight(16, context),
                                      ),
                                    );
                                  },
                                ),
                              );
                            },
                          ),
                          SizedBox(height: getPercentageHeight(2, context)),
                        ],
                      );
                    }
                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const NutritionSettingsPage(isHealthExpand: true)),
                          );
                        },
                        child: Container(
                          padding: EdgeInsets.all(getPercentageWidth(2, context)),
                          decoration: BoxDecoration(
                            color: kAccent.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(getPercentageWidth(2, context)),
                          ),
                          child: Text('No diet preference found',
                          style: TextStyle(
                            fontSize: getTextScale(3, context),
                            fontWeight: FontWeight.w600,
                            color: isDarkMode ? kWhite : kDarkGrey,
                          ),),
                        ),
                      );
                    }),

                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Center(
                          child: Text(
                            'All Meals',
                            style: TextStyle(
                                fontSize: getTextScale(4, context),
                                fontWeight: FontWeight.w600,
                                color: kAccent),
                          ),
                        ),
                        SizedBox(height: getPercentageHeight(1.5, context)),
                      ],
                    ),
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
