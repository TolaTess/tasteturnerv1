import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../constants.dart';
import '../data_models/macro_data.dart';
import '../helper/utils.dart';
import '../data_models/meal_model.dart';
import '../pages/dietary_choose_screen.dart';
import '../screens/buddy_screen.dart';
import '../screens/premium_screen.dart';
import '../widgets/icon_widget.dart';
import '../widgets/secondary_button.dart';
import '../widgets/shopping_list_view.dart';
import '../screens/favorite_screen.dart';
import '../screens/recipes_list_category_screen.dart';
import '../detail_screen/recipe_detail.dart';
import 'dart:ui' as ui;

import '../screens/shopping_list.dart';

class MealDesignScreen extends StatefulWidget {
  final int initialTabIndex;
  const MealDesignScreen({super.key, this.initialTabIndex = 0});

  @override
  State<MealDesignScreen> createState() => _MealDesignScreenState();
}

class _MealDesignScreenState extends State<MealDesignScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTime selectedDate = DateTime.now();
  Map<DateTime, bool> specialMealDays = {};
  Map<DateTime, List<Meal>> mealPlans = {};
  Map<DateTime, String> dayTypes = {};
  List<MacroData> shoppingList = [];
  List<MacroData> myShoppingList = [];
  Set<String> selectedShoppingItems = {};
  Timer? _tastyPopupTimer;
  int get _tabCount => 3;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
        length: _tabCount, vsync: this, initialIndex: widget.initialTabIndex);
    _tabController.addListener(_handleTabIndex);
    _loadMealPlans();
    shoppingList = macroManager.ingredient;
    macroManager.fetchShoppingList(userService.userId ?? '');
    // Show Tasty popup after a short delay
    _tastyPopupTimer = Timer(const Duration(milliseconds: 10000), () {
      if (mounted) {
        tastyPopupService.showTastyPopup(context, 'meal_design', [], []);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final newTabCount = _tabCount;
    if (_tabController.length != newTabCount) {
      final oldIndex = _tabController.index;
      _tabController.dispose();
      _tabController = TabController(
        length: newTabCount,
        vsync: this,
        initialIndex: oldIndex.clamp(0, newTabCount - 1),
      );
    }
  }

  void _handleTabIndex() {
    setState(() {});
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabIndex);
    _tabController.dispose();
    _tastyPopupTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadMealPlans() async {
    try {
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      final endOfMonth = DateTime(now.year, now.month + 1, 0);

      final userId = userService.userId;
      if (userId == null || userId.isEmpty) {
        setState(() {
          mealPlans = {};
          specialMealDays = {};
          dayTypes = {};
        });
        return;
      }

      // Get the user's meal plans
      final userMealPlansQuery = await FirebaseFirestore.instance
          .collection('mealPlans')
          .doc(userId)
          .collection('date')
          .get();

      if (userMealPlansQuery.docs.isEmpty) {
        setState(() {
          mealPlans = {};
          specialMealDays = {};
          dayTypes = {};
        });
        return;
      }

      // Filter documents by date range in the app
      final filteredDocs = userMealPlansQuery.docs.where((doc) {
        final data = doc.data();
        final dateStr = data['date'] as String?;
        if (dateStr == null) return false;

        try {
          final date = DateFormat('yyyy-MM-dd').parse(dateStr);
          return date.isAfter(startOfMonth.subtract(const Duration(days: 1))) &&
              date.isBefore(endOfMonth.add(const Duration(days: 1)));
        } catch (e) {
          print('Error parsing date: $e');
          return false;
        }
      }).toList();

      final newMealPlans = <DateTime, List<Meal>>{};
      final newSpecialMealDays = <DateTime, bool>{};
      final newDayTypes = <DateTime, String>{};

      for (var doc in filteredDocs) {
        final data = doc.data();
        final dateStr = data['date'] as String?;
        if (dateStr == null) continue;

        try {
          final date = DateFormat('yyyy-MM-dd').parse(dateStr);
          final mealIds = List<String>.from(data['meals'] ?? []);
          final isSpecial = data['isSpecial'] ?? false;
          final dayType = data['dayType'] ?? 'regular_day';

          if (mealIds.isNotEmpty) {
            final meals = await mealManager.getMealsByMealIds(mealIds);
            if (meals.isNotEmpty) {
              newMealPlans[date] = meals;
            }
          }

          if (isSpecial) {
            newSpecialMealDays[date] = true;
            newDayTypes[date] = dayType;
          }
        } catch (e) {
          print('Error processing meal plan for date $dateStr: $e');
          continue;
        }
      }

      setState(() {
        mealPlans = newMealPlans;
        specialMealDays = newSpecialMealDays;
        dayTypes = newDayTypes;
      });
    } catch (e) {
      print('Error loading meal plans: $e');
      setState(() {
        mealPlans = {};
        specialMealDays = {};
        dayTypes = {};
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = getThemeProvider(context).isDarkMode;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: [
            // Date Header
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${DateFormat('EEEE').format(DateTime.now())}, ',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w400,
                      color: getThemeProvider(context).isDarkMode
                          ? Colors.white
                          : Colors.black,
                    ),
                  ),
                  Text(
                    DateFormat('d MMMM').format(DateTime.now()),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w400,
                      color: Colors.amber[700],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isDarkMode ? Colors.white24 : Colors.black12,
              ),
            ),
            child: IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => _addMealPlan(context, isDarkMode),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(
              text: 'Calendar',
            ),
            Tab(text: 'Shopping'),
            Tab(text: '$appNameBuddy'),
          ],
          labelColor: isDarkMode ? kWhite : kBlack,
          labelStyle: const TextStyle(fontWeight: FontWeight.w900),
          unselectedLabelColor: kLightGrey,
          indicatorColor: isDarkMode ? kWhite : kBlack,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCalendarTab(),
          _buildShoppingListTab(),
          if (userService.currentUser?.isPremium == true)
            _buildBuddyTab()
          else
            _buildDefaultView(context)
        ],
      ),
    );
  }

  Widget _buildBuddyTab() {
    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 7));
    final dateFormat = DateFormat('yyyy-MM-dd');
    final lowerBound = dateFormat.format(sevenDaysAgo);
    final upperBound = dateFormat.format(now);

    return FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
      future: firestore
          .collection('mealPlans')
          .doc(userService.userId)
          .collection('buddy')
          .where(FieldPath.documentId, isGreaterThanOrEqualTo: lowerBound)
          .where(FieldPath.documentId, isLessThanOrEqualTo: upperBound)
          .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: kAccent));
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return _buildDefaultView(context);
        }

        // Use the most recent plan (last doc)
        final mealPlan = docs.last.data();
        final isDarkMode = getThemeProvider(context).isDarkMode;

        if (mealPlan == null) {
          // No meal plan found for today
          return _buildDefaultView(context);
        }

        final generations = (mealPlan['generations'] as List<dynamic>?)
                ?.map((gen) => gen as Map<String, dynamic>)
                .toList() ??
            [];

        if (generations.isEmpty) {
          // No generations available
          return _buildDefaultView(context);
        }

        // Use the first generation (or adjust to use a specific one)
        final selectedGeneration =
            generations[0]; // Could be dynamic based on user selection

        return FutureBuilder<List<Map<String, dynamic>>>(
          future: _fetchMealsFromIds(selectedGeneration['mealIds']),
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
            // Get the most common category from all meals
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
                      onTap: () => _tastyChefUserPage(context),
                      child: const CircleAvatar(
                        backgroundImage:
                            AssetImage('assets/images/tasty_cheerful.jpg'),
                        radius: 25,
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
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      onPressed: () => _checkAndNavigateToGenerate(context),
                      child: Text(
                        'Generate more',
                        style: TextStyle(color: isDarkMode ? kWhite : kBlack),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Builder(
                    builder: (context) {
                      String bio = getRandomMealTypeBio(mostCommonCategory);
                      List<String> parts = bio.split(': ');
                      return Column(
                        children: [
                          Text(
                            parts[0] + ':',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: kAccent,
                            ),
                          ),
                          Text(
                            parts.length > 1 ? parts[1] : '',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      );
                    },
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
                          trailing: IconButton(
                            icon: const Icon(
                              Icons.arrow_forward_ios,
                            ),
                            onPressed: () {
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
                                          : int.tryParse(meal['calories']
                                                      ?.toString() ??
                                                  '0') ??
                                              0,
                                      ingredients: meal['ingredients'] is Map
                                          ? Map<String, String>.from(
                                              meal['ingredients'])
                                          : <String,
                                              String>{}, // Default to empty map if not present
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
                                          : <String>[
                                              ''
                                            ], // Default to single empty string if not present
                                      serveQty: meal['serveQty'] is int
                                          ? meal['serveQty'] as int
                                          : int.tryParse(meal['serveQty']
                                                      ?.toString() ??
                                                  '1') ??
                                              1,
                                      steps: meal['steps'] is List
                                          ? List<String>.from(meal['steps']
                                              .map((e) => e.toString()))
                                          : <String>[],
                                      macros: meal['macros'] is Map
                                          ? Map<String, String>.from(
                                              meal['macros'])
                                          : <String,
                                              String>{}, // Default to empty map if not present
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
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

// Helper method for default "No meal plan" view
  Widget _buildDefaultView(BuildContext context) {
    String tastyMessage = "$appNameBuddy, at your service";
    String tastyMessage2 =
        "Your AI-powered food coach, crafting the perfect plan for a fitter you.";
    if (userService.currentUser?.isPremium != true) {
      tastyMessage = "$appNameBuddy, here to help";
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
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
              width: 200,
              height: 200,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                image: DecorationImage(
                  image: AssetImage(tastyWithName),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          const SizedBox(height: 40),
          Text(
            tastyMessage,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              tastyMessage2,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
          ),
          const SizedBox(height: 20),
          if (userService.currentUser?.isPremium == true)
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
    );
  }

// Sample _fetchMealsFromIds implementation (unchanged from previous suggestion)
  Future<List<Map<String, dynamic>>> _fetchMealsFromIds(
      List<dynamic> mealIds) async {
    if (mealIds.isEmpty) return [];

    final List<Map<String, dynamic>> meals = [];
    final mealCollection = firestore.collection('meals');

    for (final mealId in mealIds) {
      final docSnapshot = await mealCollection.doc(mealId).get();
      if (docSnapshot.exists) {
        meals.add(docSnapshot.data() as Map<String, dynamic>);
      }
    }
    return meals;
  }

  Future<void> _tastyChefUserPage(BuildContext context) async {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const TastyScreen()),
    );
  }

  Future<void> _checkAndNavigateToGenerate(BuildContext context) async {
    try {
      // Get the start of the current week (Monday)
      final now = DateTime.now();
      final monday = now.subtract(Duration(days: now.weekday - 1));
      final startOfWeek = DateTime(monday.year, monday.month, monday.day);

      // Query generations for this week
      final generations = await FirebaseFirestore.instance
          .collection('mealPlans')
          .doc(userService.userId)
          .collection('buddy')
          .where('timestamp', isGreaterThanOrEqualTo: startOfWeek)
          .get();

      if (generations.docs.length >= 5) {
        if (!mounted) return;

        // Show limit reached dialog
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
              'You have reached your limit of 2 meal plan generations per week. Try again next week!',
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
        // Navigate to generate new meal plan
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const ChooseDietScreen(),
          ),
        );
      }
    } catch (e) {
      print('Error checking generation limit: $e');
      // Show error dialog
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

  Widget _buildCalendarTab() {
    final isDarkMode = getThemeProvider(context).isDarkMode;

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 25),
          // Collapsible Calendar Section
          ExpansionTile(
            initiallyExpanded: true,
            iconColor: kAccent,
            collapsedIconColor: kAccent,
            title: Text(
              'Calendar',
              style: TextStyle(
                color: isDarkMode ? Colors.white : Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            children: [
              // Calendar Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: ['Mon', 'Tue', 'Wed', 'Thr', 'Fri', 'Sat', 'Sun']
                      .map((day) => Text(
                            day,
                            style: TextStyle(
                              fontSize: 12,
                              color:
                                  isDarkMode ? Colors.white54 : Colors.black54,
                            ),
                          ))
                      .toList(),
                ),
              ),
              const SizedBox(height: 10),

              // Calendar Grid
              SizedBox(
                height: 270,
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 1.2,
                  ),
                  itemCount: 35,
                  itemBuilder: (context, index) {
                    final date = DateTime.now()
                        .subtract(Duration(days: DateTime.now().weekday - 1))
                        .add(Duration(days: index));
                    final normalizedDate =
                        DateTime(date.year, date.month, date.day);
                    final normalizedSelectedDate = DateTime(selectedDate.year,
                        selectedDate.month, selectedDate.day);

                    final hasSpecialMeal =
                        specialMealDays[normalizedDate] ?? false;
                    final hasMeal = mealPlans.containsKey(normalizedDate);
                    final isCurrentMonth = date.month == selectedDate.month;
                    final isPastDate = normalizedDate.isBefore(
                        DateTime.now().subtract(const Duration(days: 1)));

                    return GestureDetector(
                      onTap: isPastDate ? null : () => _selectDate(date),
                      child: Container(
                        decoration: BoxDecoration(
                          color: hasSpecialMeal
                              ? _getDayTypeColor(
                                      dayTypes[normalizedDate]
                                              ?.replaceAll('_', ' ') ??
                                          'regular_day',
                                      isDarkMode)
                                  .withOpacity(0.2)
                              : hasMeal
                                  ? kLightGrey.withOpacity(0.3)
                                  : null,
                          borderRadius: BorderRadius.circular(8),
                          border: normalizedDate == normalizedSelectedDate
                              ? Border.all(color: kAccentLight, width: 2)
                              : null,
                        ),
                        child: Stack(
                          children: [
                            Center(
                              child: Text(
                                '${date.day}',
                                style: TextStyle(
                                  fontSize: 15,
                                  color: isPastDate
                                      ? isDarkMode
                                          ? Colors.white24
                                          : Colors.black26
                                      : !isCurrentMonth
                                          ? isDarkMode
                                              ? Colors.white38
                                              : Colors.black38
                                          : isDarkMode
                                              ? Colors.white
                                              : Colors.black,
                                  fontWeight: normalizedDate ==
                                          DateTime(
                                              DateTime.now().year,
                                              DateTime.now().month,
                                              DateTime.now().day)
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                            if (hasSpecialMeal)
                              Positioned(
                                right: 2,
                                top: 2,
                                child: Icon(
                                  _getDayTypeIcon(dayTypes[normalizedDate]
                                          ?.replaceAll('_', ' ') ??
                                      'regular_day'),
                                  size: 8,
                                  color: _getDayTypeColor(
                                      dayTypes[normalizedDate]
                                              ?.replaceAll('_', ' ') ??
                                          'regular_day',
                                      isDarkMode),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),

          // Meals List Section
          _buildMealsList(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildShoppingListTab() {
    return Column(
      children: [
        // Action buttons row
        const SizedBox(height: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            MealCategoryItem(
              title: 'Favorite',
              press: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const FavoriteScreen(),
                  ),
                );
              },
              icon: Icons.favorite,
            ),
            MealCategoryItem(
              title: 'Add to Shopping List',
              press: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ShoppingListScreen(
                      shoppingList:
                          shoppingList.map((item) => item.toJson()).toList(),
                      isMealSpin: false,
                    ),
                  ),
                );
              },
              icon: Icons.shopping_basket,
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Shopping list
        Expanded(
          child: Obx(() {
            if (macroManager.shoppingList.isEmpty) {
              return noItemTastyWidget(
                'No items in shopping list',
                '',
                context,
                false,
              );
            }

            return ShoppingListView(
              items: macroManager.shoppingList,
              selectedItems: selectedShoppingItems,
              onToggle: (item) {
                setState(() {
                  if (selectedShoppingItems.contains(item)) {
                    selectedShoppingItems.remove(item);
                  } else {
                    selectedShoppingItems.add(item);
                  }
                });
              },
            );
          }),
        ),
      ],
    );
  }

  Widget _buildMealsList() {
    final normalizedSelectedDate = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
    );
    final meals = mealPlans[normalizedSelectedDate] ?? [];
    final isSpecialDay = specialMealDays[normalizedSelectedDate] ?? false;

    final dayType = dayTypes[normalizedSelectedDate] ?? 'regular_day';
    final isDarkMode = getThemeProvider(context).isDarkMode;

    if (meals.isEmpty && !isSpecialDay) {
      return SizedBox(
        height: 200,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.restaurant,
                size: 48,
                color: isDarkMode ? Colors.white24 : Colors.black26,
              ),
              const SizedBox(height: 16),
              Text(
                'No meals planned for this day',
                style: TextStyle(
                  color: isDarkMode ? Colors.white54 : Colors.black54,
                  fontSize: 16,
                ),
              ),
              if (!normalizedSelectedDate.isBefore(DateTime.now())) ...[
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () => _addMealPlan(context, isDarkMode),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Meal'),
                  style: TextButton.styleFrom(
                    foregroundColor: kAccent,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('MMMM d, yyyy').format(selectedDate),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : Colors.black,
                      ),
                    ),
                    if (meals.isNotEmpty)
                      Text(
                        '${meals.length} ${meals.length == 1 ? 'meal' : 'meals'} planned',
                        style: TextStyle(
                          fontSize: 14,
                          color: isDarkMode ? Colors.white70 : Colors.black54,
                        ),
                      ),
                  ],
                ),
              ),
              if (isSpecialDay &&
                  dayTypes[normalizedSelectedDate] != 'regular_day')
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getDayTypeColor(
                            dayType.replaceAll('_', ' '), isDarkMode)
                        .withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getDayTypeIcon(dayType.replaceAll('_', ' ')),
                        size: 16,
                        color: _getDayTypeColor(
                            dayType.replaceAll('_', ' '), isDarkMode),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        capitalizeFirstLetter(dayType.replaceAll('_', ' ')),
                        style: TextStyle(
                          color: _getDayTypeColor(
                              dayType.replaceAll('_', ' '), isDarkMode),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        if (meals.isNotEmpty)
          SizedBox(
            height: 200,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: meals.length,
              itemBuilder: (context, index) {
                final meal = meals[index];
                return Container(
                  width: 160,
                  margin: const EdgeInsets.only(right: 16),
                  child: Card(
                    color: kAccentLight,
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: InkWell(
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
                      child: Column(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              child: AspectRatio(
                                aspectRatio: 1,
                                child: ClipOval(
                                  child: meal.mediaPaths.isNotEmpty
                                      ? Image.network(
                                          meal.mediaPaths.first
                                                  .startsWith('http')
                                              ? meal.mediaPaths.first
                                              : extPlaceholderImage,
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (context, error, stackTrace) =>
                                                  Container(
                                            decoration: BoxDecoration(
                                              color: Colors.grey[300],
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.restaurant,
                                              size: 30,
                                            ),
                                          ),
                                        )
                                      : Image.asset(
                                          getAssetImageForItem(
                                              meal.category ?? 'default'),
                                          fit: BoxFit.cover,
                                        ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    meal.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: isDarkMode ? kBlack : kWhite,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        if (meals.isEmpty)
          noItemTastyWidget(
            'No meals planned for this day',
            '',
            context,
            false,
          ),
      ],
    );
  }

  void _selectDate(DateTime date) {
    final normalizedSelectedDate = DateTime(date.year, date.month, date.day);
    setState(() {
      selectedDate = normalizedSelectedDate;
    });
  }

  Future<void> _addMealPlan(BuildContext context, bool isDarkMode) async {
    // Show date picker for future dates
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: kAccent, // Header background color
              onPrimary: Colors.white, // Header text color
              onSurface: Colors.black, // Calendar text color
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: kAccent, // Button text color
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate == null) return;

    setState(() {
      selectedDate = pickedDate;
    });

    if (!mounted) return;

    // Show dialog to mark as special meal
    final dayType = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        backgroundColor: isDarkMode ? kDarkGrey : kWhite,
        title: const Text(
          'Special Day?',
          style: TextStyle(color: kAccent),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'What type of day is this?',
              style: TextStyle(
                color: isDarkMode ? kWhite : kBlack,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 16),
            ...[
              'Regular Day',
              'Cheat Day',
              'Family Dinner',
              'Workout Boost',
              'Special Celebration'
            ].map(
              (type) => ListTile(
                title: Text(
                  type,
                  style: TextStyle(
                    color: isDarkMode ? kWhite : kBlack,
                    fontSize: 16,
                  ),
                ),
                leading: Icon(
                  _getDayTypeIcon(type),
                  color: _getDayTypeColor(type, isDarkMode),
                ),
                onTap: () => Navigator.pop(
                    context, type.toLowerCase().replaceAll(' ', '_')),
              ),
            ),
          ],
        ),
      ),
    );

    if (dayType == null) return;

    // Format date as yyyy-MM-dd for Firestore document ID
    final formattedDate = DateFormat('yyyy-MM-dd').format(selectedDate);

    // Update special meal status in Firestore
    await firestore
        .collection('mealPlans')
        .doc(userService.userId!)
        .collection('date')
        .doc(formattedDate)
        .set({
      'date': formattedDate,
      'dayType': dayType,
      'isSpecial': dayType.isNotEmpty && dayType != 'regular_day',
    }, SetOptions(merge: true));

    setState(() {
      specialMealDays[selectedDate] = dayType != 'regular_day';
    });

    // Navigate to recipe selection
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RecipeListCategory(
          index: 0,
          searchIngredient: '',
          isMealplan: true,
          mealPlanDate: formattedDate,
          isSpecial: dayType != 'regular_day',
          screen: 'ingredient',
        ),
      ),
    ).then((_) {
      // Refresh meal plans after adding new meals
      _loadMealPlans();
    });
  }

  IconData _getDayTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'cheat day':
        return Icons.cake;
      case 'family dinner':
        return Icons.people;
      case 'workout boost':
        return Icons.fitness_center;
      case 'special celebration':
        return Icons.celebration;
      default:
        return Icons.restaurant;
    }
  }

  Color _getDayTypeColor(String type, bool isDarkMode) {
    switch (type.toLowerCase()) {
      case 'cheat day':
        return Colors.purple;
      case 'family dinner':
        return Colors.green;
      case 'workout boost':
        return Colors.blue;
      case 'special celebration':
        return Colors.orange;
      default:
        return isDarkMode ? kWhite : kBlack;
    }
  }
}

// Custom painter for the special meals graph
class SpecialMealsGraphPainter extends CustomPainter {
  final Map<DateTime, bool> specialDays;
  final DateTime currentMonth;
  final bool isDarkMode;

  SpecialMealsGraphPainter({
    required this.specialDays,
    required this.currentMonth,
    required this.isDarkMode,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isDarkMode ? Colors.white12 : Colors.black12
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final width = size.width;
    final height = size.height;
    final startOfMonth = DateTime(currentMonth.year, currentMonth.month, 1);
    final daysInMonth =
        DateTime(currentMonth.year, currentMonth.month + 1, 0).day;

    // Draw the base line
    final path = Path();
    path.moveTo(0, height * 0.5);
    path.lineTo(width, height * 0.5);
    canvas.drawPath(path, paint);

    // Draw special day markers
    final markerPaint = Paint()
      ..color = Colors.amber[700]!
      ..style = PaintingStyle.fill;

    for (var i = 0; i < daysInMonth; i++) {
      final date = startOfMonth.add(Duration(days: i));
      if (specialDays[date] ?? false) {
        final x = (width * (i + 1)) / (daysInMonth + 1);
        final y = height * 0.3; // Elevated position for special days

        // Draw connecting line
        final linePaint = Paint()
          ..color = Colors.amber[700]!.withOpacity(0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2;
        canvas.drawLine(
          Offset(x, height * 0.5),
          Offset(x, y),
          linePaint,
        );

        // Draw marker
        canvas.drawCircle(Offset(x, y), 8, markerPaint);

        // Draw date text
        final textPainter = TextPainter(
          text: TextSpan(
            text: '${date.day}',
            style: TextStyle(
              color: isDarkMode ? Colors.white70 : Colors.black87,
              fontSize: 12,
            ),
          ),
          textDirection: ui.TextDirection.ltr,
        );
        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset(x - textPainter.width / 2, y - 25),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

//ingredients category
class MealCategoryItem extends StatelessWidget {
  const MealCategoryItem({
    super.key,
    required this.title,
    required this.press,
    this.icon = Icons.favorite,
    this.size = 40,
    this.image = intPlaceholderImage,
    this.isHome = false,
  });

  final String title, image;
  final VoidCallback press;
  final IconData icon;
  final double size;
  final bool isHome;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: press,
      child: Column(
        children: [
          isHome
              ? Container(
                  height: size,
                  width: size,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                  ),
                  clipBehavior: Clip.hardEdge,
                  child: Image.asset(
                    image,
                    fit: BoxFit.cover,
                  ),
                )
              : IconCircleButton(
                  h: size,
                  w: size,
                  icon: icon,
                  isRemoveContainer: false,
                ),
          const SizedBox(
            height: 5,
          ),
          Text(title,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              )),
        ],
      ),
    );
  }
}
