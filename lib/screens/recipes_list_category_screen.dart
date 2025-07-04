import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../constants.dart';
import '../helper/helper_functions.dart';
import '../helper/utils.dart';
import '../pages/edit_goal.dart';
import '../widgets/icon_widget.dart';
import '../widgets/search_button.dart';
import 'createrecipe_screen.dart';
import 'search_results_screen.dart';
import '../data_models/meal_model.dart';
import '../detail_screen/recipe_detail.dart';
import '../widgets/card_overlap.dart';

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
  final bool isNoTechnique;

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
    this.isNoTechnique = false,
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
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: true,
        toolbarHeight: getPercentageHeight(10, context),
        centerTitle: true,
        title: Text(
          capitalizeFirstLetter(widget.searchIngredient.isEmpty
              ? 'Meals'
              : widget.searchIngredient),
          style: textTheme.displaySmall?.copyWith(
            fontSize: getTextScale(7, context),
          ),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: getPercentageHeight(1, context)),

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
                  (widget.isNoTechnique)
                      ? const SizedBox.shrink()
                      : Obx(() {
                          final dietPreference = userService
                              .currentUser.value?.settings['dietPreference'];
                          if (dietPreference != null && !widget.isNoTechnique) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Padding(
                                      padding: EdgeInsets.only(
                                          left: getPercentageWidth(3, context)),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Curated',
                                            style:
                                                textTheme.titleLarge?.copyWith(
                                              fontSize:
                                                  getTextScale(5, context),
                                              fontWeight: FontWeight.w600,
                                              color: isDarkMode
                                                  ? kWhite
                                                  : kDarkGrey,
                                            ),
                                          ),
                                          SizedBox(
                                              width: getPercentageWidth(
                                                  1, context)),
                                          Text(
                                            '$dietPreference Meals',
                                            textAlign: TextAlign.left,
                                            style: textTheme.titleLarge
                                                ?.copyWith(
                                                    fontSize: getTextScale(
                                                        5, context),
                                                    fontWeight: FontWeight.w600,
                                                    fontStyle: FontStyle.italic,
                                                    color: kAccent),
                                          ),
                                        ],
                                      ),
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
                                        size: getIconScale(4.5, context),
                                        color: kAccent,
                                      ),
                                    ),
                                  ],
                                ),
                                FutureBuilder<List<Meal>>(
                                  future: mealManager.fetchMealsByCategory(
                                    dietPreference.toString().toLowerCase(),
                                  ),
                                  builder: (context, snapshot) {
                                    if (snapshot.connectionState ==
                                        ConnectionState.waiting) {
                                      return SizedBox(
                                        height:
                                            getPercentageHeight(25, context),
                                        child: const Center(
                                            child: CircularProgressIndicator()),
                                      );
                                    }
                                    if (!snapshot.hasData ||
                                        snapshot.data!.isEmpty) {
                                      return SizedBox(
                                        height: getPercentageHeight(6, context),
                                        child: const Center(
                                            child: Text(
                                                'No meals found for your diet preference.')),
                                      );
                                    }
                                    final allMeals = snapshot.data!;
                                    // Randomly select 5 meals
                                    allMeals.shuffle();
                                    final meals = allMeals.take(5).toList();

                                    return Container(
                                      height: getPercentageHeight(
                                          25, context), // Increased height
                                      margin: EdgeInsets.symmetric(
                                        vertical:
                                            getPercentageHeight(1, context),
                                      ), // Add vertical margin
                                      child: OverlappingCardsView(
                                        cardWidth:
                                            getPercentageWidth(70, context),
                                        cardHeight: getPercentageHeight(25,
                                            context), // Slightly reduced card height
                                        overlap: 60,
                                        isRecipe: true,
                                        padding: EdgeInsets.symmetric(
                                          horizontal: getPercentageWidth(2,
                                              context), // Reduced horizontal padding
                                        ),
                                        children: List.generate(
                                          meals.length,
                                          (index) {
                                            final meal = meals[index];
                                            return OverlappingCard(
                                              title: meal.title,
                                              subtitle: meal.description
                                                          ?.isNotEmpty ==
                                                      true
                                                  ? meal.description!
                                                  : '${meal.calories} kcal • ${meal.serveQty} servings',
                                              color:
                                                  colors[index % colors.length],
                                              imageUrl: meal.mediaPaths
                                                          .isNotEmpty &&
                                                      meal.mediaPaths.first
                                                          .startsWith('http')
                                                  ? meal.mediaPaths.first
                                                  : null,
                                              width: getPercentageWidth(
                                                  70, context),
                                              height: getPercentageHeight(20,
                                                  context), // Match the cardHeight
                                              index: index,
                                              isRecipe: true,
                                              onTap: () {
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
                                            );
                                          },
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            );
                          }
                          return GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) =>
                                        const NutritionSettingsPage(
                                            isHealthExpand: true)),
                              );
                            },
                            child: Container(
                              padding: EdgeInsets.all(
                                  getPercentageWidth(2, context)),
                              decoration: BoxDecoration(
                                color: kAccent.withValues(alpha: 0.1),        
                                borderRadius: BorderRadius.circular(
                                    getPercentageWidth(2, context)),
                              ),
                              child: Text(
                                'No diet preference found',
                                style: TextStyle(
                                  fontSize: getTextScale(3, context),
                                  fontWeight: FontWeight.w600,
                                  color: isDarkMode ? kWhite : kDarkGrey,
                                ),
                              ),
                            ),
                          );
                        }),

                  widget.isNoTechnique
                      ? const SizedBox.shrink()
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(height: getPercentageHeight(4, context)),
                            Center(
                              child: Text(
                                'All Meals',
                                style: textTheme.displayMedium?.copyWith(
                                  fontSize: getTextScale(5.5, context),
                                ),
                              ),
                            ),
                            SizedBox(height: getPercentageHeight(1.5, context)),
                          ],
                        ),
                ],
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
                  child: Icon(Icons.save_alt,
                      size: getPercentageWidth(7, context)),
                )
              : FloatingActionButton(
                  onPressed: selectedMealIds.isNotEmpty
                      ? () => addMealsToMealPlan(
                          appendMealTypes(selectedMealIds), widget.mealPlanDate)
                      : null,
                  backgroundColor:
                      selectedMealIds.isNotEmpty ? kAccent : kLightGrey,
                  child: Icon(Icons.save_alt,
                      size: getPercentageWidth(7, context)),
                )
          : null,
    );
  }
}
