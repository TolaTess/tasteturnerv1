import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../constants.dart';
import '../data_models/meal_model.dart';
import '../detail_screen/recipe_detail.dart';
import '../helper/helper_files.dart';
import '../helper/notifications_helper.dart';
import '../helper/utils.dart';
import '../screens/buddy_screen.dart';
import '../screens/premium_screen.dart';
import '../widgets/premium_widget.dart';
import '../widgets/primary_button.dart';
import '../helper/helper_functions.dart';

class BuddyTab extends StatefulWidget {
  const BuddyTab({super.key});

  @override
  State<BuddyTab> createState() => _BuddyTabState();
}

class _BuddyTabState extends State<BuddyTab> {
  Future<QuerySnapshot<Map<String, dynamic>>>? _buddyDataFuture;

  // State for meal type filtering
  final ValueNotifier<Set<String>> selectedMealTypesNotifier =
      ValueNotifier({});

  // Toggle meal type selection
  void toggleMealTypeSelection(String mealType) {
    final currentSelection = Set<String>.from(selectedMealTypesNotifier.value);
    if (currentSelection.contains(mealType)) {
      currentSelection.remove(mealType);
    } else {
      currentSelection.add(mealType);
    }
    selectedMealTypesNotifier.value = currentSelection;
  }

  // Filter meals based on selected categories
  List<MealWithType> filterMealsByType(
      List<MealWithType> meals, Set<String> selectedMealTypes) {
    if (selectedMealTypes.isEmpty) return meals; // Show all if none selected

    return meals.where((mealWithType) {
      final meal = mealWithType.meal;
      final category = meal.category?.toLowerCase() ?? '';
      return selectedMealTypes.contains(category);
    }).toList();
  }

  @override
  void dispose() {
    selectedMealTypesNotifier.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _initializeBuddyData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _initializeBuddyData();
  }

  void _initializeBuddyData() {
    final now = DateTime.now();
    final thirtyDaysAgo = now.subtract(const Duration(days: 31));
    final dateFormat = DateFormat('yyyy-MM-dd');
    final lowerBound = dateFormat.format(thirtyDaysAgo);
    final upperBound = dateFormat.format(now);

    _buddyDataFuture = firestore
        .collection('mealPlans')
        .doc(userService.userId)
        .collection('buddy')
        .where(FieldPath.documentId, isGreaterThanOrEqualTo: lowerBound)
        .where(FieldPath.documentId, isLessThanOrEqualTo: upperBound)
        .orderBy(FieldPath.documentId, descending: true)
        .limit(1)
        .get();
  }

  Future<List<Map<String, dynamic>>> _fetchMealsFromIds(
      List<dynamic> mealIds) async {
    if (mealIds.isEmpty) return [];

    try {
      final List<MealWithType> mealWithTypes = [];
      for (final mealId in mealIds) {
        if (mealId is String && mealId.contains('/')) {
          final parts = mealId.split('/');
          final id = parts[0];
          final mealType = parts.length > 1 ? parts[1] : '';
          final meal = await mealManager.getMealbyMealID(id);
          if (meal != null) {
            mealWithTypes.add(MealWithType(
              meal: meal,
              mealType: mealType,
              familyMember: '',
              fullMealId: mealId,
            ));
          }
        }
      }

      // Group meals by type
      final groupedMeals = {
        'breakfast': mealWithTypes
            .where((m) => m.mealType.toLowerCase() == 'bf')
            .toList(),
        'lunch': mealWithTypes
            .where((m) => m.mealType.toLowerCase() == 'lh')
            .toList(),
        'dinner': mealWithTypes
            .where((m) => m.mealType.toLowerCase() == 'dn')
            .toList(),
        'snacks': mealWithTypes
            .where((m) => m.mealType.toLowerCase() == 'sk')
            .toList(),
      };

      return [
        {'groupedMeals': groupedMeals}
      ];
    } catch (e) {
      print('Error fetching meals: $e');
      return [];
    }
  }

  String getMostCommonCategory(List<Map<String, dynamic>> meals) {
    final allCategories = meals
        .expand((meal) => meal['categories'] as List<dynamic>)
        .map((category) => category.toString().toLowerCase())
        .toList();

    final categoryCount = <String, int>{};
    for (final category in allCategories) {
      categoryCount[category] = (categoryCount[category] ?? 0) + 1;
    }

    String mostCommonCategory = 'balanced';
    int highestCount = 0;

    categoryCount.forEach((category, count) {
      if (count > highestCount) {
        mostCommonCategory = category;
        highestCount = count;
      }
    });
    return mostCommonCategory;
  }

  Widget _buildDefaultView(BuildContext context) {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    final textTheme = Theme.of(context).textTheme;
    final isPremium = userService.currentUser.value?.isPremium ?? false;
    final freeTrialDate = userService.currentUser.value?.freeTrialDate;
    final isInFreeTrial =
        freeTrialDate != null && DateTime.now().isBefore(freeTrialDate);

    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          children: [
            // Premium/Ads Section
            getAdsWidget(isPremium, isDiv: false),

            SizedBox(height: getPercentageHeight(4, context)),

            // Main Content Container
            Container(
              margin: EdgeInsets.symmetric(
                  horizontal: getPercentageWidth(4, context)),
              padding: EdgeInsets.all(getPercentageWidth(5, context)),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isPremium
                      ? [
                          kAccent.withValues(alpha: 0.1),
                          kAccentLight.withValues(alpha: 0.05)
                        ]
                      : [
                          isDarkMode
                              ? kDarkGrey.withValues(alpha: 0.3)
                              : kLightGrey.withValues(alpha: 0.3),
                          isDarkMode
                              ? kDarkGrey.withValues(alpha: 0.1)
                              : kLightGrey.withValues(alpha: 0.1)
                        ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isPremium
                      ? kAccent.withValues(alpha: 0.3)
                      : kLightGrey.withValues(alpha: 0.5),
                  width: 1.5,
                ),
              ),
              child: Column(
                children: [
                  // Animated Tasty Avatar
                  TweenAnimationBuilder(
                    tween:
                        Tween<double>(begin: 0.8, end: isPremium ? 1.2 : 1.0),
                    duration: const Duration(seconds: 2),
                    curve: Curves.elasticOut,
                    builder: (context, double scale, child) {
                      return Transform.scale(
                        scale: scale,
                        child: Container(
                          width: isPremium
                              ? getPercentageWidth(20, context)
                              : getPercentageWidth(15, context),
                          height: isPremium
                              ? getPercentageWidth(20, context)
                              : getPercentageWidth(15, context),
                          decoration: BoxDecoration(
                            gradient: RadialGradient(
                              colors: [
                                kAccentLight.withValues(alpha: 0.8),
                                kAccent.withValues(alpha: 0.6),
                              ],
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: kAccent.withValues(alpha: 0.3),
                                blurRadius: 20,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: Container(
                            margin:
                                EdgeInsets.all(getPercentageWidth(1, context)),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              image: const DecorationImage(
                                image: AssetImage(tastyImage),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  SizedBox(height: getPercentageHeight(4, context)),

                  // Title Section
                  Text(
                    isPremium
                        ? "It's $appNameBuddy Time!"
                        : "$appNameBuddy, at your service",
                    textAlign: TextAlign.center,
                    style: textTheme.headlineMedium?.copyWith(
                      fontSize: getTextScale(5.5, context),
                      fontWeight: FontWeight.bold,
                      color: isPremium
                          ? kAccent
                          : (isDarkMode ? kWhite : kDarkGrey),
                    ),
                  ),

                  SizedBox(height: getPercentageHeight(2, context)),

                  // Description Section
                  Container(
                    padding: EdgeInsets.all(getPercentageWidth(3, context)),
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? kDarkGrey.withValues(alpha: 0.5)
                          : kWhite.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: isPremium
                            ? kAccent.withValues(alpha: 0.2)
                            : kLightGrey.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      children: [
                        if (isPremium) ...[
                          _buildFeatureItem(context, Icons.restaurant_menu,
                              "Personalized Meal Plans"),
                          _buildFeatureItem(context, Icons.psychology,
                              "AI-Powered Recommendations"),
                          _buildFeatureItem(context, Icons.trending_up,
                              "Track Your Progress"),
                        ] else ...[
                          if (isInFreeTrial) ...[
                            Text(
                              "Free Trial Active",
                              style: textTheme.titleMedium?.copyWith(
                                color: kAccent,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(height: getPercentageHeight(1, context)),
                            Text(
                              "Enjoy premium features until ${DateFormat('MMM d, yyyy').format(freeTrialDate!)}",
                              textAlign: TextAlign.center,
                              style: textTheme.bodyMedium?.copyWith(
                                color: isDarkMode
                                    ? kLightGrey
                                    : kDarkGrey.withValues(alpha: 0.7),
                              ),
                            ),
                          ] else ...[
                            Text(
                              "AI-Powered Food Coach",
                              style: textTheme.titleMedium?.copyWith(
                                color: kAccent,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(height: getPercentageHeight(1, context)),
                            Text(
                              "Crafting the perfect plan for a fitter you",
                              textAlign: TextAlign.center,
                              style: textTheme.bodyMedium?.copyWith(
                                color: isDarkMode
                                    ? kLightGrey
                                    : kDarkGrey.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),

                  SizedBox(height: getPercentageHeight(4, context)),

                  // Action Button
                  Container(
                    width: double.infinity,
                    height: getPercentageHeight(6, context),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isPremium
                            ? [kAccent, kAccent.withValues(alpha: 0.5)]
                            : [
                                kAccent.withValues(alpha: 0.8),
                                kAccent.withValues(alpha: 0.6)
                              ],
                      ),
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: kAccent.withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(15),
                        onTap: () async {
                          if (canUseAI()) {
                            final canGenerate =
                                await checkMealPlanGenerationLimit(context);
                            if (canGenerate) {
                              navigateToChooseDiet(context);
                            } else {
                              showGenerationLimitDialog(context,
                                  isDarkMode: isDarkMode);
                            }
                          } else {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const PremiumScreen(),
                              ),
                            );
                          }
                        },
                        child: Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                isPremium ? Icons.auto_awesome : Icons.star,
                                color: kWhite,
                                size: getIconScale(6, context),
                              ),
                              SizedBox(width: getPercentageWidth(2, context)),
                              Text(
                                canUseAI() ? 'Get Meal Plan' : goPremium,
                                style: textTheme.titleMedium?.copyWith(
                                  color: kWhite,
                                  fontWeight: FontWeight.w600,
                                  fontSize: getTextScale(4, context),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Premium Badge for Premium Users
                  if (isPremium) ...[
                    SizedBox(height: getPercentageHeight(2, context)),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: getPercentageWidth(3, context),
                        vertical: getPercentageHeight(1, context),
                      ),
                      decoration: BoxDecoration(
                        color: kAccentLight.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: kAccentLight),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.verified,
                            color: kAccentLight,
                            size: getIconScale(5, context),
                          ),
                          SizedBox(width: getPercentageWidth(1, context)),
                          Text(
                            'Premium Member',
                            style: textTheme.bodyMedium?.copyWith(
                              color: kAccentLight,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            SizedBox(height: getPercentageHeight(6, context)),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureItem(BuildContext context, IconData icon, String text) {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding:
          EdgeInsets.symmetric(vertical: getPercentageHeight(0.5, context)),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(getPercentageWidth(1.5, context)),
            decoration: BoxDecoration(
              color: kAccent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: kAccent,
              size: getIconScale(5, context),
            ),
          ),
          SizedBox(width: getPercentageWidth(2, context)),
          Expanded(
            child: Text(
              text,
              style: textTheme.bodyMedium?.copyWith(
                color: isDarkMode ? kWhite : kDarkGrey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    if (_buddyDataFuture == null) {
      _initializeBuddyData();
    }

    return Scaffold(
      floatingActionButtonLocation: CustomFloatingActionButtonLocation(
        verticalOffset: getPercentageHeight(5, context),
        horizontalOffset: getPercentageWidth(2, context),
      ),
      floatingActionButton: buildTastyFloatingActionButton(
        context: context,
        buttonKey: ValueKey('buddy_tab_button'),
        themeProvider: getThemeProvider(context),
      ),
      body: FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
        future: _buddyDataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: kAccent));
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return _buildDefaultView(context);
          }

          final mealPlan = docs.last.data();
          final isDarkMode = getThemeProvider(context).isDarkMode;

          if (mealPlan == null) {
            return _buildDefaultView(context);
          }

          final generations = (mealPlan['generations'] as List<dynamic>?)
                  ?.map((gen) => gen as Map<String, dynamic>)
                  .toList() ??
              [];

          if (generations.isEmpty) {
            return _buildDefaultView(context);
          }

          final selectedGeneration =
              generations[generations.length - 1]; // Get last generation
          final diet = selectedGeneration['diet']?.toString() ?? 'general';
          final mealsFuture = _fetchMealsFromIds(selectedGeneration['mealIds']);

          return FutureBuilder<List<Map<String, dynamic>>>(
            future: mealsFuture,
            builder: (context, mealsSnapshot) {
              if (mealsSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(color: kAccent));
              }

              if (mealsSnapshot.hasError) {
                return Center(
                  child: Text(
                    'Error loading meals: ${mealsSnapshot.error}',
                    style: TextStyle(color: isDarkMode ? kWhite : kDarkGrey),
                  ),
                );
              }

              final meals = mealsSnapshot.data ?? [];
              if (meals.isEmpty) {
                return noItemTastyWidget(
                  'No meals available for this generation.',
                  '',
                  context,
                  false,
                  '',
                );
              }

              final groupedMeals = meals.first['groupedMeals']
                  as Map<String, List<MealWithType>>;

              return SingleChildScrollView(
                child: Column(
                  children: [
                    SizedBox(height: getPercentageHeight(2, context)),
                    Builder(
                      builder: (context) {
                        final goal = userService
                                .currentUser.value?.settings['fitnessGoal'] ??
                            'Healthy Eating';
                        String bio = getRandomMealTypeBio(goal, diet);
                        List<String> parts = bio.split(': ');
                        return Column(
                          children: [
                            Text(
                              parts[0] + ':',
                              textAlign: TextAlign.center,
                              style: textTheme.displaySmall?.copyWith(
                                color: kAccent,
                              ),
                            ),
                            SizedBox(height: getPercentageHeight(0.5, context)),
                            Center(
                              child: Text(
                                maxLines: 2,
                                textAlign: TextAlign.center,
                                overflow: TextOverflow.ellipsis,
                                parts.length > 1 ? parts[1] : '',
                                style: textTheme.bodyMedium?.copyWith(
                                  color: kLightGrey,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    SizedBox(height: getPercentageHeight(2, context)),
                    TextButton(
                      style: TextButton.styleFrom(
                        backgroundColor:
                            kAccentLight.withValues(alpha: kOpacity),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () async {
                        // final canGenerate =
                        //     await checkMealPlanGenerationLimit(context);
                        if (canUseAI()) {
                          navigateToChooseDiet(context);
                        } else {
                          // showGenerationLimitDialog(context,
                          //     isDarkMode: isDarkMode);
                          showPremiumRequiredDialog(context, isDarkMode);
                        }
                      },
                      child: Text(
                        canUseAI() ? 'Generate New Meals' : goPremium,
                        style: textTheme.labelLarge?.copyWith(
                          color: isDarkMode ? kWhite : kBlack,
                        ),
                      ),
                    ),
                    userService.currentUser.value?.isPremium ?? false
                        ? const SizedBox.shrink()
                        : SizedBox(height: getPercentageHeight(1, context)),
                    userService.currentUser.value?.isPremium ?? false
                        ? const SizedBox.shrink()
                        : PremiumSection(
                            isPremium:
                                userService.currentUser.value?.isPremium ??
                                    false,
                            titleOne: joinChallenges,
                            titleTwo: premium,
                            isDiv: false,
                          ),
                    userService.currentUser.value?.isPremium ?? false
                        ? const SizedBox.shrink()
                        : SizedBox(height: getPercentageHeight(0.5, context)),

                    // ------------------------------------Premium / Ads-------------------------------------
                    SizedBox(height: getPercentageHeight(2, context)),
                    Container(
                      margin: EdgeInsets.symmetric(
                          horizontal: getPercentageWidth(4, context)),
                      padding: EdgeInsets.symmetric(
                          vertical: getPercentageHeight(1, context)),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: kAccentLight),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Column(
                            children: [
                              Text(
                                '${selectedGeneration['nutritionalSummary']['totalCalories']}',
                                style: textTheme.bodyLarge?.copyWith(),
                              ),
                              Text(
                                'Calories',
                                style: textTheme.bodyMedium?.copyWith(
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            children: [
                              Text(
                                '${selectedGeneration['nutritionalSummary']['totalProtein']}g',
                                style: textTheme.bodyLarge?.copyWith(),
                              ),
                              Text(
                                'Protein',
                                style: textTheme.bodyMedium?.copyWith(
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            children: [
                              Text(
                                '${selectedGeneration['nutritionalSummary']['totalCarbs']}g',
                                style: textTheme.bodyLarge?.copyWith(),
                              ),
                              Text(
                                'Carbs',
                                style: textTheme.bodyMedium?.copyWith(
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            children: [
                              Text(
                                '${selectedGeneration['nutritionalSummary']['totalFat']}g',
                                style: textTheme.bodyLarge?.copyWith(),
                              ),
                              Text(
                                'Fat',
                                style: textTheme.bodyMedium?.copyWith(
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: getPercentageHeight(2, context)),
                    ValueListenableBuilder<Set<String>>(
                      valueListenable: selectedMealTypesNotifier,
                      builder: (context, selectedMealTypes, child) {
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            GestureDetector(
                              onTap: () => toggleMealTypeSelection('protein'),
                              child: buildAddMealTypeLegend(
                                context,
                                'protein',
                                isSelected:
                                    selectedMealTypes.contains('protein'),
                              ),
                            ),
                            GestureDetector(
                              onTap: () => toggleMealTypeSelection('grain'),
                              child: buildAddMealTypeLegend(
                                context,
                                'grain',
                                isSelected: selectedMealTypes.contains('grain'),
                              ),
                            ),
                            GestureDetector(
                              onTap: () => toggleMealTypeSelection('vegetable'),
                              child: buildAddMealTypeLegend(
                                context,
                                'vegetable',
                                isSelected:
                                    selectedMealTypes.contains('vegetable'),
                              ),
                            ),
                            GestureDetector(
                              onTap: () => toggleMealTypeSelection('fruit'),
                              child: buildAddMealTypeLegend(
                                context,
                                'fruit',
                                isSelected: selectedMealTypes.contains('fruit'),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    // Filterable meal lists section
                    ValueListenableBuilder<Set<String>>(
                      valueListenable: selectedMealTypesNotifier,
                      builder: (context, selectedMealTypes, child) {
                        final totalMeals =
                            (groupedMeals['breakfast']?.length ?? 0) +
                                (groupedMeals['lunch']?.length ?? 0) +
                                (groupedMeals['dinner']?.length ?? 0) +
                                (groupedMeals['snacks']?.length ?? 0);

                        final filteredBreakfast = filterMealsByType(
                            groupedMeals['breakfast'] ?? [], selectedMealTypes);
                        final filteredLunch = filterMealsByType(
                            groupedMeals['lunch'] ?? [], selectedMealTypes);
                        final filteredDinner = filterMealsByType(
                            groupedMeals['dinner'] ?? [], selectedMealTypes);
                        final filteredSnacks = filterMealsByType(
                            groupedMeals['snacks'] ?? [], selectedMealTypes);

                        final filteredMealsCount = filteredBreakfast.length +
                            filteredLunch.length +
                            filteredDinner.length +
                            filteredSnacks.length;

                        final hasAnyFilteredMeals = filteredMealsCount > 0;

                        return Column(
                          children: [
                            SizedBox(height: getPercentageHeight(0.5, context)),
                            // Show filter status
                            if (selectedMealTypes.isNotEmpty && totalMeals > 0)
                              Padding(
                                padding: EdgeInsets.symmetric(
                                    horizontal: getPercentageWidth(4, context)),
                                child: Text(
                                  'Showing $filteredMealsCount of $totalMeals meals',
                                  textAlign: TextAlign.center,
                                  style: textTheme.bodySmall?.copyWith(
                                    color: Colors.grey[600],
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                            SizedBox(height: getPercentageHeight(1, context)),
                            // Meal lists
                            if (filteredBreakfast.isNotEmpty)
                              _buildMealsList(
                                  filteredBreakfast, 'Breakfast', context),
                            if (filteredLunch.isNotEmpty)
                              _buildMealsList(filteredLunch, 'Lunch', context),
                            if (filteredDinner.isNotEmpty)
                              _buildMealsList(
                                  filteredDinner, 'Dinner', context),
                            if (filteredSnacks.isNotEmpty)
                              _buildMealsList(
                                  filteredSnacks, 'Snacks', context),
                            // Show message when no meals match the filter
                            if (!hasAnyFilteredMeals &&
                                selectedMealTypes.isNotEmpty)
                              Padding(
                                padding: EdgeInsets.all(
                                    getPercentageWidth(4, context)),
                                child: Center(
                                  child: Column(
                                    children: [
                                      SizedBox(
                                          height:
                                              getPercentageHeight(2, context)),
                                      Icon(
                                        Icons.restaurant_menu,
                                        size: getPercentageWidth(12, context),
                                        color: Colors.grey,
                                      ),
                                      SizedBox(
                                          height:
                                              getPercentageHeight(1, context)),
                                      Text(
                                        'No meals match the current filter',
                                        textAlign: TextAlign.center,
                                        style: textTheme.bodyMedium?.copyWith(
                                          color: Colors.grey,
                                        ),
                                      ),
                                      SizedBox(
                                          height:
                                              getPercentageHeight(1, context)),
                                      Text(
                                        'Try selecting different meal types above',
                                        textAlign: TextAlign.center,
                                        style: textTheme.bodySmall?.copyWith(
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                    SizedBox(height: getPercentageHeight(13, context)),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildMealsList(
      List<MealWithType> meals, String mealType, BuildContext context) {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    final textTheme = Theme.of(context).textTheme;

    if (meals.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.all(getPercentageWidth(4, context)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                mealType,
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isDarkMode ? kWhite : kBlack,
                ),
              ),
              Text(
                '(${meals.length})',
                style: textTheme.displaySmall?.copyWith(
                  fontSize: getTextScale(4.5, context),
                  color: kAccent,
                ),
              ),
            ],
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: meals.length,
          itemBuilder: (context, index) {
            final mealWithType = meals[index];
            final meal = mealWithType.meal;

            return Container(
              margin: EdgeInsets.symmetric(
                horizontal: getPercentageWidth(4, context),
                vertical: getPercentageHeight(1, context),
              ),
              decoration: BoxDecoration(
                color: getMealTypeColor(meal.category ?? 'default'),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                contentPadding: EdgeInsets.all(getPercentageWidth(2, context)),
                leading: Container(
                  width: getPercentageWidth(12, context),
                  height: getPercentageWidth(12, context),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset(
                      getMealTypeImage(meal.category ?? 'default'),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                title: Text(
                  meal.title,
                  style: textTheme.bodyLarge?.copyWith(
                    color: Colors.white,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                subtitle: Row(
                  children: [
                    Icon(
                      Icons.restaurant,
                      size: getPercentageWidth(3, context),
                      color: Colors.white70,
                    ),
                    SizedBox(width: getPercentageWidth(1, context)),
                    Text(
                      '${meal.calories} kcal',
                      style: textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
                trailing: IconButton(
                  icon: Icon(
                    Icons.add_circle_outline,
                    color: Colors.white,
                    size: getPercentageWidth(6, context),
                  ),
                  onPressed: () => _showAddToMealPlanDialog(
                      context, meal, mealType, isDarkMode),
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => RecipeDetailScreen(
                        mealData: meal,
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }

  Future<void> _showAddToMealPlanDialog(BuildContext context, Meal meal,
      String mealTypeVariable, bool isDarkMode) async {
    final textTheme = Theme.of(context).textTheme;
    final DateTime now = DateTime.now();

    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: getDatePickerTheme(context, isDarkMode),
          child: child!,
        );
      },
    );

    if (pickedDate != null && context.mounted) {
      final formattedDate = DateFormat('yyyy-MM-dd').format(pickedDate);

      // Show meal type selection dialog
      final mealType = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          backgroundColor: isDarkMode ? kDarkGrey : kWhite,
          title: Text(
            'Select Meal Type',
            style: textTheme.titleLarge?.copyWith(
              color: isDarkMode ? kWhite : kBlack,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(
                  'Breakfast',
                  style: textTheme.bodyMedium?.copyWith(
                    color: mealTypeVariable.toLowerCase() == 'breakfast'
                        ? kAccent
                        : null,
                  ),
                ),
                onTap: () => Navigator.pop(context, 'bf'),
              ),
              ListTile(
                title: Text(
                  'Lunch',
                  style: textTheme.bodyMedium?.copyWith(
                    color: mealTypeVariable.toLowerCase() == 'lunch'
                        ? kAccent
                        : null,
                  ),
                ),
                onTap: () => Navigator.pop(context, 'lh'),
              ),
              ListTile(
                title: Text(
                  'Dinner',
                  style: textTheme.bodyMedium?.copyWith(
                    color: mealTypeVariable.toLowerCase() == 'dinner'
                        ? kAccent
                        : null,
                  ),
                ),
                onTap: () => Navigator.pop(context, 'dn'),
              ),
              ListTile(
                title: Text(
                  'Snacks',
                  style: textTheme.bodyMedium?.copyWith(
                    color: mealTypeVariable.toLowerCase() == 'snacks'
                        ? kAccent
                        : null,
                  ),
                ),
                onTap: () => Navigator.pop(context, 'sk'),
              ),
            ],
          ),
        ),
      );

      if (mealType != null && context.mounted) {
        // Add meal to the selected date with the selected type
        final mealId = '${meal.mealId}/$mealType';
        await helperController.saveMealPlanBuddy(
          userService.userId ?? '',
          formattedDate,
          'chef_tasty',
          [mealId],
        );

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Meal added to ${DateFormat('MMM d').format(pickedDate)} as ${getMealTypeLabel(mealType)}',
              ),
            ),
          );
        }
      }
    }
  }
}
