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
import '../widgets/secondary_button.dart';

class BuddyTab extends StatefulWidget {
  const BuddyTab({super.key});

  @override
  State<BuddyTab> createState() => _BuddyTabState();
}

class _BuddyTabState extends State<BuddyTab> {
  Future<QuerySnapshot<Map<String, dynamic>>>? _buddyDataFuture;
  bool isPremium = userService.currentUser?.isPremium ?? false;
  DateTime? trailEndDate = userService.currentUser?.created_At?.add(Duration(
      days: int.tryParse(
              firebaseService.generalData['freeTrailDays']?.toString() ?? '') ??
          29));

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
      final meals = await MealManager.instance.getMealsByMealIds(stringMealIds);
      return meals.map((meal) => meal.toJson()).toList();
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
    final isInFreeTrail =
        DateTime.now().isBefore(trailEndDate ?? DateTime.now());
    String tastyMessage = "It's $appNameBuddy Time!";
    String tastyMessage2 =
        "Let's craft a perfect meal plan for a healthier you.";
    String tastyMessage1 = "$appNameBuddy, at your service";
    String tastyMessage4 =
        "AI-powered food coach, crafting the perfect plan for a fitter you.";

    final date = DateFormat('d MMMM').format(trailEndDate ?? DateTime.now());

    String tastyMessage3 =
        "Please enjoy our AI-powered food coach, helping you craft the perfect plan for a fitter you. \n \n Free trail until $date";

    return SafeArea(
      child: SingleChildScrollView(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(height: getPercentageHeight(8, context),),
              TweenAnimationBuilder(
                tween: Tween<double>(begin: 0.8, end: 1.2),
                duration: const Duration(seconds: 2),
                curve: Curves.easeInOut,
                builder: (context, double scale, child) {
                  return Transform.scale(
                    scale: scale,
                    child: child,
                  );
                },
                child: Container(
                  width: 170,
                  height: 170,
                  decoration: const BoxDecoration(
                    color: kAccentLight,
                    shape: BoxShape.circle,
                    image: DecorationImage(
                      image: AssetImage(tastyImage),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
              SizedBox(height: getPercentageHeight(5, context),),
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
                      : isInFreeTrail
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
              if (isPremium || isInFreeTrail)
                SecondaryButton(
                  text: 'Get Meal Plan',
                  press: () => _checkAndNavigateToGenerate(context),
                )
              else
                SecondaryButton(
                  text: goPremium,
                  press: () => Navigator.push(
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
              );
            }

            return SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 24),
                  ListTile(
                    leading: GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const TastyScreen()),
                      ),
                      child: const CircleAvatar(
                        backgroundColor: kAccentLight,
                        backgroundImage: AssetImage(tastyImage),
                        radius: 22,
                      ),
                    ),
                    title: Text(
                      '$appNameBuddy 👋',
                      style: TextStyle(
                        color: isDarkMode ? Colors.white : Colors.black,
                        fontWeight: FontWeight.w600,
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
                        style: TextStyle(color: isDarkMode ? kWhite : kBlack),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Builder(
                    builder: (context) {
                      String bio = getRandomMealTypeBio(mostCommonCategory);
                      List<String> parts = bio.split(': ');
                      return Column(
                        children: [
                          Text(
                            parts[0] + ':',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: kAccent,
                            ),
                          ),
                          Text(
                            parts.length > 1 ? parts[1] : '',
                            style: const TextStyle(
                              fontSize: 13,
                              color: kLightGrey,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Column(
                        children: [
                          Text(
                            '${selectedGeneration['nutritionalSummary']['totalCalories']}',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Text(
                            'Calories',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        children: [
                          Text(
                            '${selectedGeneration['nutritionalSummary']['totalProtein']}g',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Text(
                            'Protein',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        children: [
                          Text(
                            '${selectedGeneration['nutritionalSummary']['totalCarbs']}g',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Text(
                            'Carbs',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        children: [
                          Text(
                            '${selectedGeneration['nutritionalSummary']['totalFat']}g',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Text(
                            'Fat',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  ...meals.map(
                    (meal) => Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
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
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 4),
                            leading: Container(
                              width: 50,
                              height: 50,
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
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            subtitle: Row(
                              children: [
                                const Icon(
                                  Icons.restaurant,
                                  size: 16,
                                  color: Colors.white70,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${meal['calories'] ?? 0} kcal',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.7),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 130),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
