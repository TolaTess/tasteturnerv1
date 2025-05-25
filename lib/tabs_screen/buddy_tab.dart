import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../constants.dart';
import '../data_models/meal_model.dart';
import '../detail_screen/recipe_detail.dart';
import '../helper/utils.dart';
import '../pages/dietary_choose_screen.dart';
import '../screens/buddy_screen.dart';
import '../screens/premium_screen.dart';
import '../service/meal_manager.dart';
import '../widgets/premium_widget.dart';
import '../widgets/primary_button.dart';

class BuddyTab extends StatefulWidget {
  const BuddyTab({super.key});

  @override
  State<BuddyTab> createState() => _BuddyTabState();
}

class _BuddyTabState extends State<BuddyTab> {
  Future<QuerySnapshot<Map<String, dynamic>>>? _buddyDataFuture;
  bool isPremium = userService.currentUser?.isPremium ?? false;

  @override
  void initState() {
    super.initState();
    _initializeBuddyData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    setState(() {
      isPremium = userService.currentUser?.isPremium ?? false;
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

  Future<void> _checkAndNavigateToGenerate(BuildContext context) async {
    try {
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);

      final generations = await firestore
          .collection('mealPlans')
          .doc(userService.userId)
          .collection('buddy')
          .where('timestamp', isGreaterThanOrEqualTo: startOfMonth)
          .get();

      if (generations.docs.length >= 5) {
        if (!mounted) return;

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            backgroundColor:
                getThemeProvider(context).isDarkMode ? kDarkGrey : kWhite,
            title: const Text('Generation Limit Reached'),
            content: const Text(
              'You have reached your limit of 5 meal plan generations per month. Try again next week!',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const ChooseDietScreen(isOnboarding: false),
          ),
        );
      }
    } catch (e) {
      print('Error checking generation limit: $e');
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('$appNameBuddy tips'),
          content: const Text('Something went wrong. Please try again later.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
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
        .format(userService.currentUser?.freeTrialDate ?? DateTime.now());

    String tastyMessage3 =
        "Please enjoy our AI-powered food coach, helping you craft the perfect plan for a fitter you. \n \n Free trail until $date";

    final freeTrialDate = userService.currentUser?.freeTrialDate;
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
              userService.currentUser?.isPremium ?? false
                  ? const SizedBox.shrink()
                  : PremiumSection(
                      isPremium: userService.currentUser?.isPremium ?? false,
                      titleOne: joinChallenges,
                      titleTwo: premium,
                      isDiv: false,
                    ),

              userService.currentUser?.isPremium ?? false
                  ? const SizedBox.shrink()
                  : const SizedBox(height: 10),

              // ------------------------------------Premium / Ads-------------------------------------
              userService.currentUser?.isPremium ?? false
                  ? const SizedBox.shrink()
                  : const SizedBox(height: 5),
              SizedBox(
                height: getPercentageHeight(2, context),
              ),

              TweenAnimationBuilder(
                tween: Tween<double>(
                    begin: 0.8,
                    end: userService.currentUser?.isPremium ?? false
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
                  width:
                      userService.currentUser?.isPremium ?? false ? 170 : 120,
                  height:
                      userService.currentUser?.isPremium ?? false ? 170 : 120,
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
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  isPremium
                      ? tastyMessage2
                      : isInFreeTrial
                          ? tastyMessage3
                          : tastyMessage4,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              if (isPremium || isInFreeTrial)
                AppButton(
                  text: 'Get Meal Plan',
                  onPressed: () => _checkAndNavigateToGenerate(context),
                  type: AppButtonType.secondary,
                  width: 50
                )
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
              const SizedBox(height: 100),
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

            final mostCommonCategory = getMostCommonCategory(meals);

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
                        backgroundColor: kAccentLight.withOpacity(0.5),
                        backgroundImage: const AssetImage(tastyImage),
                            radius: getPercentageWidth(5, context),
                      ),
                    ),
                    title: Text(
                      '$appNameBuddy 👋',
                      style: TextStyle(
                        color: isDarkMode ? Colors.white : Colors.black,
                        fontWeight: FontWeight.w600,
                        fontSize: getPercentageWidth(4.5, context),
                      ),
                    ),
                    trailing: TextButton(
                      style: TextButton.styleFrom(
                        backgroundColor: kAccentLight.withOpacity(kOpacity),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () => _checkAndNavigateToGenerate(context),
                      child: Text(
                        'Generate New Plan',
                        style: TextStyle(
                          color: isDarkMode ? kWhite : kBlack,
                          fontSize: getPercentageWidth(3.5, context),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: getPercentageHeight(1, context)),
                  Builder(
                    builder: (context) {
                      String bio = getRandomMealTypeBio(mostCommonCategory);
                      List<String> parts = bio.split(': ');
                      return Column(
                        children: [
                          Text(
                            parts[0] + ':',
                                style: TextStyle(
                              fontSize: getPercentageWidth(4.5, context),
                              fontWeight: FontWeight.w600,
                              color: kAccent,
                            ),
                          ),
                          Text(
                            parts.length > 1 ? parts[1] : '',
                            style: TextStyle(
                              fontSize: getPercentageWidth(3.5, context),
                              color: kLightGrey,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  SizedBox(height: getPercentageHeight(2, context)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Column(
                        children: [
                          Text(
                            '${selectedGeneration['nutritionalSummary']['totalCalories']}',
                            style: TextStyle(
                              fontSize: getPercentageWidth(5, context),   
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Calories',
                            style: TextStyle(
                              fontSize: getPercentageWidth(3.5, context),   
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
                              fontSize: getPercentageWidth(5, context),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Protein',
                            style: TextStyle(
                              fontSize: getPercentageWidth(3.5, context),
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
                                  fontSize: getPercentageWidth(5, context),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Carbs',
                            style: TextStyle(
                              fontSize: getPercentageWidth(3.5, context),
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
                              fontSize: getPercentageWidth(5, context),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Fat',
                            style: TextStyle( 
                              fontSize: getPercentageWidth(3.5, context),
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  SizedBox(height: getPercentageHeight(2, context)),
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
                            minTileHeight: getPercentageHeight(10, context),
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
                                fontSize: getPercentageWidth(4.5, context),
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
                                    fontSize: getPercentageWidth(3, context),
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
