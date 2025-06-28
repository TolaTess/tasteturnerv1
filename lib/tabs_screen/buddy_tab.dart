import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../constants.dart';
import '../data_models/meal_model.dart';
import '../detail_screen/recipe_detail.dart';
import '../helper/helper_files.dart';
import '../helper/utils.dart';
import '../pages/dietary_choose_screen.dart';
import '../screens/buddy_screen.dart';
import '../screens/premium_screen.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/premium_widget.dart';
import '../widgets/primary_button.dart';

class BuddyTab extends StatefulWidget {
  const BuddyTab({super.key});

  @override
  State<BuddyTab> createState() => _BuddyTabState();
}

class _BuddyTabState extends State<BuddyTab> {
  Future<QuerySnapshot<Map<String, dynamic>>>? _buddyDataFuture;
  bool isPremium = userService.currentUser.value?.isPremium ?? false;

  @override
  void initState() {
    super.initState();
    _initializeBuddyData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    setState(() {
      isPremium = userService.currentUser.value?.isPremium ?? false;
    });
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
      final List<String> stringMealIds =
          mealIds.map((id) => id.toString()).toList();
      final snapshot = await firestore
          .collection('meals')
          .where(FieldPath.documentId, whereIn: stringMealIds)
          .get();

      return snapshot.docs
          .map((doc) => {
                ...doc.data(),
                'mealId': doc.id,
              })
          .toList();
    } catch (e) {
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

  Color _getMealTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'protein':
        return Colors.green[200]!;
      case 'grain':
        return Colors.orange[200]!;
      case 'vegetable':
        return Colors.lightGreen[200]!;
      default:
        return Colors.blue[200]!;
    }
  }

  String _getMealTypeImage(String type) {
    switch (type.toLowerCase()) {
      case 'protein':
        return 'assets/images/meat.jpg';
      case 'grain':
        return 'assets/images/grain.jpg';
      case 'vegetable':
        return 'assets/images/vegetable.jpg';
      default:
        return 'assets/images/placeholder.jpg';
    }
  }

  Widget _buildDefaultView(BuildContext context) {
    final isDarkMode = getThemeProvider(context).isDarkMode;

    String tastyMessage = "It's $appNameBuddy Time!";
    String tastyMessage2 =
        "Let's craft a perfect meal plan for a healthier you.";
    String tastyMessage1 = "$appNameBuddy, at your service";
    String tastyMessage4 =
        "AI-powered food coach, crafting the perfect plan for a fitter you.";

    final date = DateFormat('d MMMM')
        .format(userService.currentUser.value?.freeTrialDate ?? DateTime.now());

    String tastyMessage3 =
        "Please enjoy our AI-powered food coach, helping you craft the perfect plan for a fitter you. \n \n Free trail until $date";

    final freeTrialDate = userService.currentUser.value?.freeTrialDate;
    final isInFreeTrial =
        freeTrialDate != null && DateTime.now().isBefore(freeTrialDate);

    return SafeArea(
      child: SingleChildScrollView(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ------------------------------------Premium / Ads------------------------------------
              SizedBox(
                height: getPercentageHeight(2, context),
              ),
              userService.currentUser.value?.isPremium ?? false
                  ? const SizedBox.shrink()
                  : PremiumSection(
                      isPremium:
                          userService.currentUser.value?.isPremium ?? false,
                      titleOne: joinChallenges,
                      titleTwo: premium,
                      isDiv: false,
                    ),

              userService.currentUser.value?.isPremium ?? false
                  ? const SizedBox.shrink()
                  : SizedBox(height: getPercentageHeight(1, context)),

              // ------------------------------------Premium / Ads-------------------------------------
              userService.currentUser.value?.isPremium ?? false
                  ? const SizedBox.shrink()
                  : SizedBox(height: getPercentageHeight(0.5, context)),
              SizedBox(
                height: getPercentageHeight(2, context),
              ),

              TweenAnimationBuilder(
                tween: Tween<double>(
                    begin: 0.8,
                    end: userService.currentUser.value?.isPremium ?? false
                        ? 1.2
                        : 1.0),
                duration: const Duration(seconds: 2),
                curve: Curves.easeInOut,
                builder: (context, double scale, child) {
                  return Transform.scale(
                    scale: scale,
                    child: child,
                  );
                },
                child: Container(
                  width: userService.currentUser.value?.isPremium ?? false
                      ? getPercentageWidth(17, context)
                      : getPercentageWidth(12, context),
                  height: userService.currentUser.value?.isPremium ?? false
                      ? getPercentageWidth(17, context)
                      : getPercentageWidth(12, context),
                  decoration: BoxDecoration(
                    color: kAccentLight.withOpacity(0.5),
                    shape: BoxShape.circle,
                    image: const DecorationImage(
                      image: AssetImage(tastyImage),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
              SizedBox(
                height: getPercentageHeight(3, context),
              ),
              Text(
                isPremium ? tastyMessage : tastyMessage1,
                style: TextStyle(
                  fontSize: getTextScale(4, context),
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: getPercentageHeight(1.6, context)),
              Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: getPercentageWidth(3.2, context)),
                child: Text(
                  isPremium
                      ? tastyMessage2
                      : isInFreeTrial
                          ? tastyMessage3
                          : tastyMessage4,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: getTextScale(3, context),
                    color: Colors.grey,
                  ),
                ),
              ),
              SizedBox(height: getPercentageHeight(2, context)),
              if (isPremium || isInFreeTrial)
                AppButton(
                    text: 'Get Meal Plan',
                    onPressed: () async {
                      final canGenerate =
                          await checkMealPlanGenerationLimit(context);
                      if (canGenerate) {
                        navigateToChooseDiet(context);
                      } else {
                        showGenerationLimitDialog(context,
                            isDarkMode: isDarkMode);
                      }
                    },
                    type: AppButtonType.secondary,
                    width: 50)
              else
                AppButton(
                  text: goPremium,
                  type: AppButtonType.secondary,
                  width: 50,
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const PremiumScreen(),
                    ),
                  ),
                ),
              SizedBox(height: getPercentageHeight(10, context)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_buddyDataFuture == null) {
      _initializeBuddyData();
    }

    return FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
      future: _buddyDataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: kAccent));
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

            return SingleChildScrollView(
              child: Column(
                children: [
                  SizedBox(height: getPercentageHeight(2, context)),
                  ListTile(
                    leading: GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) =>
                                const TastyScreen(screen: 'message')),
                      ),
                      child: CircleAvatar(
                        backgroundColor: kAccentLight.withOpacity(kMidOpacity),
                        child: Image.asset(
                          'assets/images/tasty/tasty.png',
                          width: getIconScale(5, context),
                          height: getIconScale(5, context),
                        ),
                      ),
                    ),
                    title: GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) =>
                                const TastyScreen(screen: 'message')),
                      ),
                      child: Text(
                        'Chef $appNameBuddy 👋',
                        style: TextStyle(
                          color: kAccentLight,
                          fontWeight: FontWeight.w600,
                          fontSize: getTextScale(3.5, context),
                        ),
                      ),
                    ),
                    trailing: TextButton(
                      style: TextButton.styleFrom(
                        backgroundColor: kAccentLight.withOpacity(kOpacity),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () async {
                        final canGenerate =
                            await checkMealPlanGenerationLimit(context);
                        if (canGenerate) {
                          navigateToChooseDiet(context);
                        } else {
                          showGenerationLimitDialog(context,
                              isDarkMode: isDarkMode);
                        }
                      },
                      child: Text(
                        'Generate New Meals',
                        style: TextStyle(
                          color: isDarkMode ? kWhite : kBlack,
                          fontSize: getTextScale(3.5, context),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: getPercentageHeight(1, context)),
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
                            style: TextStyle(
                              fontSize: getTextScale(4, context),
                              fontWeight: FontWeight.w600,
                              color: kAccent,
                            ),
                          ),
                          Text(
                            parts.length > 1 ? parts[1] : '',
                            style: TextStyle(
                              fontSize: getTextScale(3, context),
                              color: kLightGrey,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  SizedBox(height: getPercentageHeight(2, context)),
                  Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: getPercentageWidth(4, context),
                        vertical: getPercentageHeight(1, context)),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: kAccent),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Column(
                          children: [
                            Text(
                              '${selectedGeneration['nutritionalSummary']['totalCalories']}',
                              style: TextStyle(
                                fontSize: getTextScale(4, context),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Calories',
                              style: TextStyle(
                                fontSize: getTextScale(3, context),
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          children: [
                            Text(
                              '${selectedGeneration['nutritionalSummary']['totalProtein']}g',
                              style: TextStyle(
                                fontSize: getTextScale(4, context),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Protein',
                              style: TextStyle(
                                fontSize: getTextScale(3, context),
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          children: [
                            Text(
                              '${selectedGeneration['nutritionalSummary']['totalCarbs']}g',
                              style: TextStyle(
                                fontSize: getTextScale(4, context),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Carbs',
                              style: TextStyle(
                                fontSize: getTextScale(3, context),
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          children: [
                            Text(
                              '${selectedGeneration['nutritionalSummary']['totalFat']}g',
                              style: TextStyle(
                                fontSize: getTextScale(4, context),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Fat',
                              style: TextStyle(
                                fontSize: getTextScale(3, context),
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: getPercentageHeight(2, context)),
                  GestureDetector(
                    onTap: () async {
                      final now = DateTime.now();
                      final List<DateTime> weekStarts = List.generate(5, (i) {
                        if (i == 0) return now;
                        // For subsequent weeks, find next Monday
                        final nextWeek = now.add(Duration(days: 7 * i));
                        // Calculate days until next Monday (1 = Monday, 7 = Sunday)
                        final daysUntilMonday = (8 - nextWeek.weekday) % 7;
                        return nextWeek.add(Duration(days: daysUntilMonday));
                      });
                      final List<String> weekLabels = [
                        'Today',
                        'Next week',
                        'In 2 weeks',
                        'In 3 weeks',
                        'In 4 weeks',
                      ];
                      showModalBottomSheet(
                        backgroundColor: isDarkMode ? kDarkGrey : kWhite,
                        context: context,
                        shape: const RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.vertical(top: Radius.circular(20)),
                        ),
                        builder: (ctx) {
                          return SafeArea(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: List.generate(weekStarts.length, (i) {
                                final weekStart = weekStarts[i];
                                final label = weekLabels[i];
                                final formattedDate =
                                    DateFormat('yyyy-MM-dd').format(weekStart);
                                return ListTile(
                                  title: Text(label,
                                      style: TextStyle(
                                          color:
                                              isDarkMode ? kWhite : kDarkGrey,
                                          fontWeight: FontWeight.w500,
                                          fontSize:
                                              getTextScale(3.5, context))),
                                  subtitle: Text('Start: $formattedDate',
                                      style: TextStyle(
                                          color:
                                              isDarkMode ? kWhite : kDarkGrey,
                                          fontSize: getTextScale(3, context))),
                                  onTap: () async {
                                    Navigator.pop(ctx);
                                    await helperController.saveMealPlanBuddy(
                                      userService.userId ?? '',
                                      formattedDate,
                                      'chef_tasty',
                                      meals
                                          .map((meal) =>
                                              meal['mealId'] as String)
                                          .toList(),
                                    );
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                          content: Text(
                                              'Meal plan added for $label')),
                                    );
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const BottomNavSec(
                                          selectedIndex: 4,
                                        ),
                                      ),
                                    );
                                  },
                                );
                              }),
                            ),
                          );
                        },
                      );
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: kAccent.withOpacity(0.20),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: EdgeInsets.symmetric(
                          horizontal: getPercentageWidth(4, context),
                          vertical: getPercentageHeight(1, context)),
                      child: Text('Add meals to your calendar',
                          style: TextStyle(
                              fontSize: getTextScale(4, context),
                              fontWeight: FontWeight.w600,
                              color: kAccent)),
                    ),
                  ),
                  SizedBox(height: getPercentageHeight(1, context)),
                  ...meals.map(
                    (meal) => Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal: getPercentageWidth(4, context),
                          vertical: getPercentageHeight(1, context)),
                      child: Container(
                        decoration: BoxDecoration(
                          color:
                              _getMealTypeColor(meal['category'] ?? 'default'),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => RecipeDetailScreen(
                                  mealData: Meal(
                                    mealId: meal['mealId']?.toString() ?? '',
                                    title: meal['title']?.toString() ??
                                        'Delicious Meal - Untitled',
                                    userId: meal['userId']?.toString() ??
                                        'Taste Turner',
                                    category: meal['category']?.toString() ??
                                        'default',
                                    calories: meal['calories'] is int
                                        ? meal['calories'] as int
                                        : int.tryParse(
                                                meal['calories']?.toString() ??
                                                    '0') ??
                                            0,
                                    ingredients: meal['ingredients'] is Map
                                        ? Map<String, String>.from(
                                            meal['ingredients'])
                                        : <String, String>{},
                                    categories: meal['categories'] is List
                                        ? List<String>.from(meal['categories']
                                            .map((e) => e.toString()))
                                        : <String>[],
                                    createdAt: meal['createdAt'] is Timestamp
                                        ? (meal['createdAt'] as Timestamp)
                                            .toDate()
                                        : DateTime.now(),
                                    mediaPaths: meal['mediaPaths'] is List
                                        ? List<String>.from(meal['mediaPaths']
                                            .map((e) => e.toString()))
                                        : <String>[''],
                                    serveQty: meal['serveQty'] is int
                                        ? meal['serveQty'] as int
                                        : int.tryParse(
                                                meal['serveQty']?.toString() ??
                                                    '1') ??
                                            1,
                                    steps: meal['steps'] is List
                                        ? List<String>.from(meal['steps']
                                            .map((e) => e.toString()))
                                        : <String>[],
                                    macros: meal['macros'] is Map
                                        ? Map<String, String>.from(
                                            meal['macros'])
                                        : <String, String>{},
                                  ),
                                ),
                              ),
                            );
                          },
                          child: ListTile(
                            minTileHeight: getPercentageHeight(4, context),
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: getPercentageWidth(4, context),
                                vertical: getPercentageHeight(1, context)),
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
                                  _getMealTypeImage(
                                      meal['category'] ?? 'default'),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            title: Text(
                              meal['title'] ?? 'Untitled Meal',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                                fontSize: getTextScale(3.5, context),
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
                                  '${meal['calories'] ?? 0} kcal',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.7),
                                    fontSize: getTextScale(3, context),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: getPercentageHeight(13, context)),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
