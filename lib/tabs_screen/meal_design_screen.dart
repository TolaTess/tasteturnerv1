import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';
import 'package:intl/intl.dart';
import 'package:get/get.dart';
import '../constants.dart';
import '../data_models/meal_plan_model.dart';
import '../helper/helper_functions.dart';
import '../helper/utils.dart';
import '../data_models/meal_model.dart';
import '../data_models/user_meal.dart';
import '../screens/friend_screen.dart';
import '../screens/premium_screen.dart';
import '../widgets/custom_drawer.dart';
import '../widgets/icon_widget.dart';
import '../widgets/secondary_button.dart';
import '../screens/recipes_list_category_screen.dart';
import '../detail_screen/recipe_detail.dart';
import 'buddy_tab.dart';

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
  Map<DateTime, List<SharedMealPlan>> sharedMealPlans = {};
  Set<String> selectedShoppingItems = {};
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  Future<QuerySnapshot<Map<String, dynamic>>>? _buddyDataFuture;
  bool showSharedCalendars = false;
  int get _tabCount => 2;
  bool isPremium = userService.currentUser?.isPremium ?? false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
        length: _tabCount, vsync: this, initialIndex: widget.initialTabIndex);
    _tabController.addListener(_handleTabIndex);
    _setupDataListeners();
    if (widget.initialTabIndex == 1) {
      _initializeBuddyData();
    }
  }

  void _setupDataListeners() {
    _onRefresh();
  }

  Future<void> _onRefresh() async {
    await Future.wait([
      _loadMealPlans(),
      _loadSharedCalendars(),
    ]);
  }

  void _initializeBuddyData() {
    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 7));
    final dateFormat = DateFormat('yyyy-MM-dd');
    final lowerBound = dateFormat.format(sevenDaysAgo);
    final upperBound = dateFormat.format(now);

    _buddyDataFuture = firestore
        .collection('mealPlans')
        .doc(userService.userId)
        .collection('buddy')
        .where(FieldPath.documentId, isGreaterThanOrEqualTo: lowerBound)
        .where(FieldPath.documentId, isLessThanOrEqualTo: upperBound)
        .get();
  }

  Future<void> _loadSharedCalendars() async {
    try {
      final userId = userService.userId;
      if (userId == null) return;

      // Get all shared calendars for the user
      final sharedCalendarsQuery = await FirebaseFirestore.instance
          .collection('shared_calendars')
          .where('userIds', arrayContains: userId)
          .get();

      final newSharedMealPlans = <DateTime, List<SharedMealPlan>>{};

      for (var calendarDoc in sharedCalendarsQuery.docs) {
        // Get all meal plans from the shared calendar
        final mealPlansQuery = await FirebaseFirestore.instance
            .collection('shared_calendars')
            .doc(calendarDoc.id)
            .collection('date')
            .get();

        for (var doc in mealPlansQuery.docs) {
          final dateStr = doc.id; // Use document ID as the date string
          if (dateStr.isEmpty) continue;

          final date = DateFormat('yyyy-MM-dd').parse(dateStr);
          final sharedByUserId = doc.data()['userId'] as String?;

          if (sharedByUserId == userId)
            continue; // Skip user's own shared meals

          final meals = (doc.data()['meals'] as List<dynamic>?)
                  ?.map((m) => UserMeal.fromMap(m as Map<String, dynamic>))
                  .toList() ??
              [];

          final sharedPlan = SharedMealPlan(
            userId: sharedByUserId ?? '',
            meals: meals,
            isSpecial: doc.data()['isSpecial'] ?? false,
            dayType: doc.data()['dayType'],
            sharedBy: sharedByUserId ?? '',
          );

          if (!newSharedMealPlans.containsKey(date)) {
            newSharedMealPlans[date] = [];
          }
          newSharedMealPlans[date]!.add(sharedPlan);
        }
      }

      setState(() {
        sharedMealPlans = newSharedMealPlans;
      });
    } catch (e) {
      print('Error loading shared calendars: $e');
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Only recreate tab controller if count changes
    final newTabCount = _tabCount;
    if (_tabController.length != newTabCount) {
      final oldIndex = _tabController.index;
      _tabController.dispose();
      _tabController = TabController(
        length: newTabCount,
        vsync: this,
        initialIndex: oldIndex.clamp(0, newTabCount - 1),
      );
      _tabController.addListener(_handleTabIndex);
    }
    setState(() {
      isPremium = userService.currentUser?.isPremium ?? false;
    });
  }

  void _handleTabIndex() {
    if (_tabController.index == 1 && _buddyDataFuture == null) {
      _initializeBuddyData();
    }
    setState(() {});
  }

  @override
  void dispose() {
    // _saveCurrentShoppingList();
    _tabController.removeListener(_handleTabIndex);
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadMealPlans() async {
    try {
      final now = DateTime.now();
      final startDate = DateTime(now.year, now.month, now.day);
      final endDate =
          startDate.add(const Duration(days: 95)); // 95 days including today

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
          return !date.isBefore(startDate) && !date.isAfter(endDate);
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
    final avatarUrl =
        userService.currentUser?.profileImage ?? intPlaceholderImage;

    return Scaffold(
      key: _scaffoldKey,
      drawer: const CustomDrawer(),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Profile image that opens drawer
            GestureDetector(
              onTap: () => _scaffoldKey.currentState?.openDrawer(),
              child: CircleAvatar(
                radius: 20,
                backgroundColor: kAccent.withOpacity(kOpacity),
                child: CircleAvatar(
                  backgroundImage: getAvatarImage(avatarUrl),
                  radius: 18,
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Center(
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
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w400,
                        color: kAccentLight,
                      ),
                    ),
                  ],
                ),
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
              onPressed: () => _addMealPlan(context, isDarkMode, true, ''),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(
              text: 'Calendar',
            ),
            Tab(text: '$appNameBuddy'),
          ],
          labelColor: isDarkMode ? kWhite : kBlack,
          labelStyle: const TextStyle(fontWeight: FontWeight.w600),
          unselectedLabelColor: kLightGrey,
          indicatorColor: isDarkMode ? kWhite : kBlack,
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildCalendarTab(),
            if (isPremium) const BuddyTab() else _buildDefaultView(context)
          ],
        ),
      ),
    );
  }

// Helper method for default "No meal plan" view
  Widget _buildDefaultView(BuildContext context) {
    String tastyMessage = "$appNameBuddy, at your service";
    String tastyMessage2 =
        "Your AI-powered food coach, crafting the perfect plan for a fitter you.";

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
                color: kAccentLight,
                shape: BoxShape.circle,
                image: DecorationImage(
                  image: AssetImage(tastyImage),
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

  Widget _buildCalendarTab() {
    final isDarkMode = getThemeProvider(context).isDarkMode;

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 15),
          // Collapsible Calendar Section
          ExpansionTile(
            initiallyExpanded: true,
            iconColor: kAccent,
            collapsedIconColor: kAccent,
            title: Row(
              children: [
                // Calendar view toggle
                Text(
                  'Calendar',
                  style: TextStyle(
                    color: isDarkMode ? Colors.white : Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(width: 10),
                IconButton(
                  icon: Icon(
                    showSharedCalendars
                        ? Icons.people_outline
                        : Icons.person_outline,
                    size: 20,
                  ),
                  onPressed: () {
                    setState(() {
                      showSharedCalendars = !showSharedCalendars;
                    });
                  },
                  tooltip: showSharedCalendars
                      ? 'Show Personal Calendar'
                      : 'Show Shared Calendars',
                ),
                if (!showSharedCalendars)
                  IconButton(
                    icon: const Icon(
                      Icons.share,
                      size: 20,
                    ),
                    onPressed: () {
                      Get.to(() => const FriendScreen(
                            dataSrc: {
                              'type': 'calendar_share',
                              'screen': 'meal_design',
                            },
                          ));
                    },
                    tooltip: 'Share Calendar',
                  ),
              ],
            ),
            children: [
              // Calendar Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
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
                height: getPercentageHeight(26, context),
                child: PageView.builder(
                  controller:
                      PageController(initialPage: 1), // Start at current month
                  itemBuilder: (context, pageIndex) {
                    // Calculate the month offset (-1, 0, 1 for prev, current, next)
                    final monthOffset = pageIndex - 1;
                    final currentDate = DateTime.now();
                    final targetDate = DateTime(
                        currentDate.year, currentDate.month + monthOffset);

                    // Find the first day of the month
                    final firstDayOfMonth =
                        DateTime(targetDate.year, targetDate.month, 1);
                    // Calculate days to subtract to get to the previous Monday
                    final daysToSubtract = (firstDayOfMonth.weekday - 1) % 7;
                    // Get the first Monday
                    final firstMonday = firstDayOfMonth
                        .subtract(Duration(days: daysToSubtract));

                    return GridView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 7,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        childAspectRatio: 1.2,
                      ),
                      itemCount: 42, // 6 weeks × 7 days
                      itemBuilder: (context, index) {
                        final date = firstMonday.add(Duration(days: index));
                        final normalizedDate =
                            DateTime(date.year, date.month, date.day);
                        final normalizedSelectedDate = DateTime(
                            selectedDate.year,
                            selectedDate.month,
                            selectedDate.day);

                        final hasSpecialMeal =
                            specialMealDays[normalizedDate] ?? false;
                        final hasMeal = mealPlans.containsKey(normalizedDate);
                        final isCurrentMonth = date.month == targetDate.month;
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
                    );
                  },
                  itemCount: 3, // Show 3 months
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

  Widget _buildMealsList() {
    final normalizedSelectedDate = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
    );

    final personalMeals = mealPlans[normalizedSelectedDate] ?? [];
    final isPersonalSpecialDay =
        specialMealDays[normalizedSelectedDate] ?? false;
    final personalDayType = dayTypes[normalizedSelectedDate] ?? 'regular_day';

    final sharedPlans = sharedMealPlans[normalizedSelectedDate] ?? [];

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final dateStr = DateFormat('yyyy-MM-dd').format(normalizedSelectedDate);

    if (personalMeals.isEmpty && !isPersonalSpecialDay && sharedPlans.isEmpty) {
      return _buildEmptyState(normalizedSelectedDate, isDarkMode);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildDateHeader(normalizedSelectedDate, isDarkMode, personalMeals),

        // Personal meals section
        if (!showSharedCalendars && personalMeals.isNotEmpty)
          _buildMealsRow(personalMeals, isDarkMode),

        // Shared meals section
        if (showSharedCalendars && sharedPlans.isNotEmpty)
          ...sharedPlans
              .map((sharedPlan) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: kAccent.withOpacity(0.2),
                              child: const Icon(Icons.people,
                                  size: 20, color: kAccent),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Shared by ${sharedPlan.sharedBy}',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: kAccent,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _buildMealsRow(
                        sharedPlan.meals
                            .map((m) => Meal(
                                  userId: sharedPlan.userId,
                                  title: m.name ?? '',
                                  createdAt: DateTime.now(),
                                  mediaPaths: [],
                                  serveQty: int.tryParse(m.servings ?? '') ?? 1,
                                  calories: m.calories,
                                ))
                            .toList(),
                        isDarkMode,
                      ),
                    ],
                  ))
              .toList(),

        const SizedBox(height: 30),
      ],
    );
  }

  Widget _buildMealsRow(List<Meal> meals, bool isDarkMode) {
    return SizedBox(
      height: 150,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: meals.length,
        itemBuilder: (context, index) {
          final meal = meals[index];
          return Container(
            width: 130,
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
                                    meal.mediaPaths.first.startsWith('http')
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
                        padding: const EdgeInsets.symmetric(horizontal: 8),
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
    );
  }

  void _selectDate(DateTime date) {
    final normalizedSelectedDate = DateTime(date.year, date.month, date.day);
    setState(() {
      selectedDate = normalizedSelectedDate;
    });
  }

  Future<void> _addMealPlan(BuildContext context, bool isDarkMode,
      bool needDatePicker, String type) async {
    // Show date picker for future dates
    DateTime? pickedDate;
    if (needDatePicker) {
      pickedDate = await showDatePicker(
        context: context,
        initialDate: selectedDate,
        firstDate: DateTime.now(),
        lastDate: DateTime.now().add(const Duration(days: 365)),
        builder: (context, child) {
          return Theme(
            data: getDatePickerTheme(context, isDarkMode),
            child: child!,
          );
        },
      );
    } else {
      pickedDate = selectedDate;
    }

    if (pickedDate == null) return;

    setState(() {
      selectedDate = pickedDate!;
    });

    if (!mounted) return;

    // Show dialog to mark as special meal
    String selectedDayType = '';
    if (type.isNotEmpty) {
      selectedDayType = type;
    } else {
      selectedDayType = 'regular_day';
    }

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
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
                  selected: selectedDayType ==
                      type.toLowerCase().replaceAll(' ', '_'),
                  selectedTileColor: kAccentLight.withOpacity(0.1),
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
                  onTap: () {
                    setState(() {
                      selectedDayType = type.toLowerCase().replaceAll(' ', '_');
                    });
                  },
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context),
              color: isDarkMode ? kWhite : kBlack,
            ),
            IconButton(
              icon: const Icon(Icons.share),
              onPressed: () => Get.to(() => FriendScreen(
                    dataSrc: {
                      'type': 'specific_date',
                      'screen': 'meal_design',
                      'date': selectedDate.toString(),
                    },
                  )),
              color: isDarkMode ? kWhite : kBlack,
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(
                    context, {'dayType': selectedDayType, 'action': 'save'});
                await _loadMealPlans();
              },
              child: const Text(
                'Save',
                style: TextStyle(color: kAccentLight),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context,
                    {'dayType': selectedDayType, 'action': 'add_meal'});
              },
              child: const Text(
                'Add Meal',
                style: TextStyle(color: kAccent),
              ),
            ),
          ],
        ),
      ),
    );

    if (result == null) return;

    final String dayType = result['dayType'];
    final String action = result['action'];

    // Format date as yyyy-MM-dd for Firestore document ID
    final formattedDate = DateFormat('yyyy-MM-dd').format(selectedDate);
    final userId = userService.userId!;

    try {
      DocumentReference? sharedCalendarRef;

      if (showSharedCalendars) {
        // First try to find an existing shared calendar for this user
        final existingCalendarsQuery = await firestore
            .collection('shared_calendars')
            .where('userIds', arrayContains: userId)
            .get();

        if (existingCalendarsQuery.docs.isNotEmpty) {
          // Use the first shared calendar found
          sharedCalendarRef = existingCalendarsQuery.docs.first.reference;
        } else {
          // Create a new shared calendar only if none exists
          sharedCalendarRef = firestore.collection('shared_calendars').doc();
          await sharedCalendarRef.set({
            'userIds': [userId],
            'createdAt': FieldValue.serverTimestamp(),
            'createdBy': userId,
            'type': 'personal',
          });
        }

        // Update or create the meal plan document in the date subcollection
        await sharedCalendarRef.collection('date').doc(formattedDate).set({
          'userId': userId,
          'dayType': dayType,
          'isSpecial': dayType.isNotEmpty && dayType != 'regular_day',
          'date': formattedDate,
          'meals': [], // Initialize empty meals array if it doesn't exist
        }, SetOptions(merge: true));
      } else {
        // For personal calendar
        await firestore
            .collection('mealPlans')
            .doc(userId)
            .collection('date')
            .doc(formattedDate)
            .set({
          'userId': userId,
          'dayType': dayType,
          'isSpecial': dayType.isNotEmpty && dayType != 'regular_day',
          'date': formattedDate,
          'meals': [], // Initialize empty meals array if it doesn't exist
        }, SetOptions(merge: true));
      }

      setState(() {
        specialMealDays[selectedDate] = dayType != 'regular_day';
        dayTypes[selectedDate] = dayType;
      });

      // Only navigate to recipe selection if "Add Meal" was clicked
      if (action == 'add_meal') {
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
              isSharedCalendar: showSharedCalendars,
              sharedCalendarId:
                  showSharedCalendars ? sharedCalendarRef?.id : null,
            ),
          ),
        ).then((_) {
          // Refresh meal plans after adding new meals
          _loadMealPlans();
          if (showSharedCalendars) {
            _loadSharedCalendars();
          }
        });
      }
    } catch (e) {
      print('Error in _addMealPlan: $e');
    }
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

  Widget _buildEmptyState(DateTime date, bool isDarkMode) {
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
            if (!date.isBefore(DateTime.now())) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => _addMealPlan(context, isDarkMode, false, ''),
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

  Widget _buildDateHeader(DateTime date, bool isDarkMode, List<Meal> meals) {
    final isSpecialDay = specialMealDays[date] ?? false;
    final currentDayType = dayTypes[date] ?? 'regular_day';

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('MMMM d, yyyy').format(date),
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
              if (isSpecialDay && currentDayType != 'regular_day')
                GestureDetector(
                  onTap: () =>
                      _addMealPlan(context, isDarkMode, false, currentDayType),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getDayTypeColor(
                              currentDayType.replaceAll('_', ' '), isDarkMode)
                          .withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getDayTypeIcon(currentDayType.replaceAll('_', ' ')),
                          size: 16,
                          color: _getDayTypeColor(
                              currentDayType.replaceAll('_', ' '), isDarkMode),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          capitalizeFirstLetter(
                              currentDayType.replaceAll('_', ' ')),
                          style: TextStyle(
                            color: _getDayTypeColor(
                                currentDayType.replaceAll('_', ' '),
                                isDarkMode),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
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
  });

  final String title, image;
  final VoidCallback press;
  final IconData icon;
  final double size;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: press,
      child: Column(
        children: [
          IconCircleButton(
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

// Add SharedMealPlan class
class SharedMealPlan {
  final String userId;
  final List<UserMeal> meals;
  final bool isSpecial;
  final String? dayType;
  final String sharedBy;

  SharedMealPlan({
    required this.userId,
    required this.meals,
    required this.isSpecial,
    this.dayType,
    required this.sharedBy,
  });
}
