import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_svg/svg.dart';
import 'package:intl/intl.dart';
import 'package:get/get.dart';
import 'package:tasteturner/pages/safe_text_field.dart';
import '../constants.dart';
import '../data_models/meal_plan_model.dart';
import '../data_models/user_data_model.dart';
import '../helper/helper_functions.dart';
import '../helper/utils.dart';
import '../data_models/meal_model.dart';
import '../data_models/user_meal.dart';
import '../screens/friend_screen.dart';
import '../service/meal_plan_controller.dart';
import '../service/tasty_popup_service.dart';
import '../widgets/category_selector.dart';
import '../widgets/custom_drawer.dart';
import '../widgets/icon_widget.dart';
import '../screens/recipes_list_category_screen.dart';
import '../detail_screen/recipe_detail.dart';
import '../widgets/optimized_image.dart';
import 'buddy_tab.dart';
import '../helper/calendar_sharing_controller.dart';
import '../service/calendar_sharing_service.dart';
import 'shopping_tab.dart';

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
  Set<String> selectedShoppingItems = {};
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  Future<QuerySnapshot<Map<String, dynamic>>>? _buddyDataFuture;
  int get _tabCount => 2;
  bool isPremium = userService.currentUser.value?.isPremium ?? false;
  bool familyMode = userService.currentUser.value?.familyMode ?? false;
  final CalendarSharingController sharingController =
      Get.put(CalendarSharingController());
  final CalendarSharingService calendarSharingService =
      CalendarSharingService();

  final GlobalKey _toggleCalendarButtonKey = GlobalKey();
  final GlobalKey _sharedCalendarButtonKey = GlobalKey();
  final GlobalKey _addMealButtonKey = GlobalKey();
  // Get the MealPlanController instance
  late final MealPlanController _mealPlanController;

  String selectedCategory = 'name';
  String selectedCategoryId = '';
  List<Map<String, dynamic>> _categoryDatasIngredient = [];

  @override
  void initState() {
    super.initState();

    // Initialize MealPlanController
    _mealPlanController = Get.find<MealPlanController>();

    _tabController = TabController(
        length: _tabCount, vsync: this, initialIndex: widget.initialTabIndex);
    _tabController.addListener(_handleTabIndex);
    _setupDataListeners();

    if (widget.initialTabIndex == 1) {
      _initializeBuddyData();
    }

    if (familyMode) {
      final currentUser = {
        'name': userService.currentUser.value?.displayName ?? 'Me',
        'id': userService.userId ?? 'me',
      };

      final List<FamilyMember> familyMembers =
          userService.currentUser.value?.familyMembers ?? [];
      final List<Map<String, dynamic>> familyList = familyMembers
          .map((f) => {
                'name': f.name,
                'id': '${f.name}_${f.ageGroup}'
                    .toLowerCase()
                    .replaceAll(' ', '_'),
              })
          .toList();

      _categoryDatasIngredient = [currentUser, ...familyList];
      if (_categoryDatasIngredient.isNotEmpty && selectedCategoryId.isEmpty) {
        selectedCategoryId = _categoryDatasIngredient[0]['id'] ?? '';
        selectedCategory = _categoryDatasIngredient[0]['name'] ?? '';
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showMealDesignTutorial();
    });
  }

  void _showMealDesignTutorial() {
    tastyPopupService.showSequentialTutorials(
      context: context,
      sequenceKey: 'meal_design_tutorial',
      tutorials: [
        TutorialStep(
          tutorialId: 'toggle_calendar_button',
          message: 'Tap to toggle between personal and shared calendar!',
          targetKey: _toggleCalendarButtonKey,
        ),
        TutorialStep(
          tutorialId: 'shared_calendar_button',
          message: 'Tap to share your calendar with friends!',
          targetKey: _sharedCalendarButtonKey,
        ),
        TutorialStep(
          tutorialId: 'add_meal_button',
          message: 'Tap here to add your meal!',
          targetKey: _addMealButtonKey,
        ),
      ],
    );
  }

  void _setupDataListeners() {
    _onRefresh();
  }

  Future<void> _onRefresh() async {
    _mealPlanController.refresh();
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
    _onRefresh();
    if (!mounted) return;
    setState(() {
      isPremium = userService.currentUser.value?.isPremium ?? false;
    });
  }

  void _handleTabIndex() {
    if (_tabController.index == 1 && _buddyDataFuture == null) {
      _initializeBuddyData();
    }
    if (!mounted) return;
    setState(() {});
  }

  @override
  void dispose() {
    // _saveCurrentShoppingList();
    _tabController.removeListener(_handleTabIndex);
    _tabController.dispose();
    super.dispose();
  }

  /// Returns true if the given date is the user's birthday and in personal view
  bool _isUserBirthday(DateTime date) {
    if (_mealPlanController.showSharedCalendars.value) return false;
    final userDob = userService.currentUser.value?.dob;
    if (userDob == null || userDob.length != 5) return false;
    final month = int.tryParse(userDob.substring(0, 2));
    final day = int.tryParse(userDob.substring(3, 5));
    if (month == null || day == null) return false;
    return date.month == month && date.day == day;
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    final textTheme = Theme.of(context).textTheme;
    final avatarUrl =
        userService.currentUser.value?.profileImage ?? intPlaceholderImage;

    return Obx(() => Scaffold(
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
                    radius: MediaQuery.of(context).size.height > 1100
                        ? getResponsiveBoxSize(context, 14, 14)
                        : getResponsiveBoxSize(context, 18, 18),
                    backgroundColor: kAccent.withValues(alpha: kOpacity),
                    child: CircleAvatar(
                      backgroundImage: getAvatarImage(avatarUrl),
                      radius: MediaQuery.of(context).size.height > 1100
                          ? getResponsiveBoxSize(context, 12, 12)
                          : getResponsiveBoxSize(context, 16, 16),
                    ),
                  ),
                ),

                Padding(
                  padding: EdgeInsets.symmetric(
                      horizontal: getPercentageWidth(2, context)),
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${getRelativeDayString(DateTime.now())}, ',
                          style: textTheme.displayMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                              fontSize: getPercentageWidth(4.5, context)),
                        ),
                        Text(
                          ' ${shortMonthName(DateTime.now().month)} ${DateTime.now().day}',
                          style: textTheme.displayMedium?.copyWith(
                              color: kAccentLight,
                              fontWeight: FontWeight.w500,
                              fontSize: getPercentageWidth(4.5, context)),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_tabController.index == 0)
                  InkWell(
                    onTap: () => _addMealPlan(context, isDarkMode, true, '',
                        goStraightToAddMeal: false),
                    child: IconCircleButton(
                      icon: _tabController.index == 0
                          ? Icons.add
                          : Icons.calendar_month,
                      colorD: kAccent,
                      isRemoveContainer: false,
                    ),
                  ),
                if (_tabController.index == 1)
                  SizedBox(width: getPercentageWidth(1, context)),
              ],
            ),
            bottom: TabBar(
              controller: _tabController,
              tabs: [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Planner',
                          style: textTheme.displaySmall?.copyWith(
                              fontWeight: FontWeight.w300,
                              fontSize: getPercentageWidth(6, context))),
                      SizedBox(width: getPercentageWidth(1, context)),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('$appNameBuddy',
                          style: textTheme.displaySmall?.copyWith(
                              fontWeight: FontWeight.w300,
                              fontSize: getPercentageWidth(6, context))),
                      SizedBox(width: getPercentageWidth(1, context)),
                    ],
                  ),
                ),
              ],
              labelColor: isDarkMode ? kWhite : kBlack,
              labelStyle: textTheme.displayMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: getPercentageWidth(4, context)),
              unselectedLabelColor: kLightGrey,
              indicatorColor: isDarkMode ? kWhite : kBlack,
            ),
          ),
          body: RefreshIndicator(
            onRefresh: _onRefresh,
            child: TabBarView(
              controller: _tabController,
              children: [
                Padding(
                  padding:
                      EdgeInsets.only(top: getProportionalHeight(5, context)),
                  child: _buildCalendarTab(),
                ),
                Padding(
                  padding:
                      EdgeInsets.only(top: getProportionalHeight(5, context)),
                  child: const BuddyTab(),
                ),
              ],
            ),
          ),
        ));
  }

  Widget _buildCalendarTab() {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    final textTheme = Theme.of(context).textTheme;
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: getPercentageHeight(1, context)),
          Text(
            'Meal Planner',
            style: textTheme.displaySmall?.copyWith(
              color: kAccent,
            ),
          ),
          SizedBox(height: getPercentageHeight(1, context)),

          // Collapsible Calendar Section
          Container(
            decoration: BoxDecoration(
              color: isDarkMode
                  ? kDarkGrey.withValues(alpha: 0.9)
                  : kWhite.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Padding(
              padding: EdgeInsets.all(getPercentageWidth(1, context)),
              child: ExpansionTile(
                initiallyExpanded: true,
                iconColor: kAccent,
                collapsedIconColor: kAccent,
                title: Row(
                  children: [
                    // Calendar view toggle
                    SizedBox(width: getPercentageWidth(1, context)),
                    Text(
                      _mealPlanController.showSharedCalendars.value
                          ? 'Shared'
                          : familyMode
                              ? 'Family'
                              : 'Personal',
                      style: textTheme.titleLarge?.copyWith(
                          color: isDarkMode ? kWhite : kDarkGrey,
                          fontWeight: FontWeight.w600,
                          fontSize: getPercentageWidth(4.5, context)),
                    ),
                    SizedBox(
                        width: MediaQuery.of(context).size.height > 1100
                            ? getPercentageWidth(5, context)
                            : getPercentageWidth(1, context)),
                    IconButton(
                      key: _toggleCalendarButtonKey,
                      icon: Icon(
                        _mealPlanController.showSharedCalendars.value
                            ? Icons.person_outline
                            : Icons.people_outline,
                        size: getIconScale(7, context),
                      ),
                      onPressed: () {
                        if (!mounted) return;
                        setState(() {
                          _mealPlanController.showSharedCalendars.value =
                              !_mealPlanController.showSharedCalendars.value;
                        });
                        _mealPlanController.refresh();
                      },
                      tooltip: _mealPlanController.showSharedCalendars.value
                          ? 'Show Personal Calendar'
                          : 'Show Shared Calendars',
                    ),
                    SizedBox(
                        width: MediaQuery.of(context).size.height > 1100
                            ? getPercentageWidth(5, context)
                            : getPercentageWidth(1, context)),

                    IconButton(
                      key: _sharedCalendarButtonKey,
                      icon: Icon(
                        Icons.ios_share,
                        size: getIconScale(4.5, context),
                      ),
                      onPressed: () => _shareCalendar(''),
                    ),
                    SizedBox(width: getPercentageWidth(2, context)),
                    if (!_mealPlanController.showSharedCalendars.value)
                      Spacer(),
                    if (!_mealPlanController.showSharedCalendars.value)
                      Text(
                        ' ${shortMonthName(selectedDate.month)} ${selectedDate.day}',
                        style: textTheme.titleMedium?.copyWith(
                            color: kAccent, fontWeight: FontWeight.w500),
                      ),

                    // Shared calendar selector
                    if (_mealPlanController.showSharedCalendars.value)
                      Flexible(
                        child: FutureBuilder<List<SharedCalendar>>(
                          future: calendarSharingService
                              .fetchSharedCalendarsForUser(userService.userId!),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const CircularProgressIndicator(
                                  color: kAccent);
                            }
                            if (!snapshot.hasData || snapshot.data!.isEmpty) {
                              return Text(
                                'No shared calender',
                                style: textTheme.bodyMedium?.copyWith(
                                    color: isDarkMode ? kWhite : kDarkGrey,
                                    overflow: TextOverflow.ellipsis),
                              );
                            }
                            final calendars = snapshot.data!;
                            return DropdownButton<String>(
                              isExpanded: true,
                              dropdownColor:
                                  getThemeProvider(context).isDarkMode
                                      ? kAccent
                                      : kBackgroundColor,
                              iconEnabledColor: kAccent,
                              value: _mealPlanController
                                  .selectedSharedCalendarId.value,
                              hint: Text('Select Calendar',
                                  style: textTheme.titleSmall?.copyWith(
                                      color: isDarkMode ? kWhite : kDarkGrey)),
                              style: textTheme.bodyMedium?.copyWith(
                                  color: isDarkMode ? kWhite : kDarkGrey,
                                  overflow: TextOverflow.ellipsis),
                              items: calendars
                                  .map((cal) => DropdownMenuItem(
                                        value: cal.calendarId,
                                        child: Text(
                                            capitalizeFirstLetter(cal.header)),
                                      ))
                                  .toList(),
                              onChanged: (val) {
                                if (!mounted) return;
                                setState(() {
                                  _mealPlanController
                                      .selectedSharedCalendarId.value = val;
                                });
                                if (val != null) {
                                  sharingController.selectSharedCalendar(val);
                                  sharingController
                                      .selectSharedDate(selectedDate);
                                  _mealPlanController.refresh();
                                }
                              },
                            );
                          },
                        ),
                      ),
                  ],
                ),
                children: [
                  // Calendar Header
                  SizedBox(
                      height: MediaQuery.of(context).size.height > 1100
                          ? getPercentageHeight(1.5, context)
                          : getPercentageHeight(1, context)),
                  Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: getPercentageWidth(1, context)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        'Mon',
                        'Tue',
                        'Wed',
                        'Thu',
                        'Fri',
                        'Sat',
                        'Sun'
                      ]
                          .map((day) => Text(
                                day,
                                style: textTheme.displayMedium?.copyWith(
                                    color: isDarkMode ? kLightGrey : kDarkGrey,
                                    fontWeight: FontWeight.w100,
                                    fontSize: getPercentageWidth(3.5, context)),
                              ))
                          .toList(),
                    ),
                  ),
                  SizedBox(height: getPercentageHeight(1, context)),

                  // Calendar Grid
                  Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: getPercentageWidth(96, context),
                        minWidth: getPercentageWidth(32, context),
                      ),
                      child: SizedBox(
                        height: MediaQuery.of(context).size.height > 1100
                            ? getPercentageHeight(42, context)
                            : getPercentageHeight(32, context),
                        child: PageView.builder(
                          controller: PageController(
                              initialPage: 1), // Start at current month
                          itemBuilder: (context, pageIndex) {
                            // Calculate the month offset (-1, 0, 1 for prev, current, next)
                            final monthOffset = pageIndex - 1;
                            final currentDate = DateTime.now();
                            final targetDate = DateTime(currentDate.year,
                                currentDate.month + monthOffset);

                            // Find the first day of the month
                            final firstDayOfMonth =
                                DateTime(targetDate.year, targetDate.month, 1);
                            // Calculate days to subtract to get to the previous Monday
                            final daysToSubtract =
                                (firstDayOfMonth.weekday - 1) % 7;
                            // Get the first Monday
                            final firstMonday = firstDayOfMonth
                                .subtract(Duration(days: daysToSubtract));

                            return GridView.builder(
                              physics: const NeverScrollableScrollPhysics(),
                              padding: EdgeInsets.symmetric(
                                  horizontal: getPercentageWidth(1, context)),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 7,
                                mainAxisSpacing: 8,
                                crossAxisSpacing: 8,
                                childAspectRatio: 1.2,
                              ),
                              itemCount: 42, // 6 weeks × 7 days
                              itemBuilder: (context, index) {
                                final date =
                                    firstMonday.add(Duration(days: index));
                                final normalizedDate =
                                    DateTime(date.year, date.month, date.day);
                                final normalizedSelectedDate = DateTime(
                                    selectedDate.year,
                                    selectedDate.month,
                                    selectedDate.day);

                                final hasSpecialMeal = _mealPlanController
                                        .specialMealDays[normalizedDate] ??
                                    false;
                                final hasMeal = _mealPlanController
                                        .mealPlans[normalizedDate] !=
                                    null;
                                final isCurrentMonth =
                                    date.month == targetDate.month;
                                final today = DateTime.now();
                                final isPastDate = normalizedDate.isBefore(
                                    DateTime(
                                        today.year, today.month, today.day));
                                final hasBirthday = _mealPlanController
                                    .getFriendsBirthdaysForDate(normalizedDate)
                                    .isNotEmpty;
                                final isUserBirthday =
                                    _isUserBirthday(normalizedDate);
                                final dayType = _mealPlanController
                                        .dayTypes[normalizedDate] ??
                                    'regular_day';

                                return GestureDetector(
                                  onTap: () {
                                    if (hasSpecialMeal) {
                                      if (isPastDate) {
                                        _showSpecialDayDetails(
                                            context, normalizedDate, dayType);
                                      } else {
                                        _selectDate(date);
                                      }
                                    } else if (!isPastDate) {
                                      _selectDate(date);
                                    }
                                  },
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: hasSpecialMeal
                                          ? getDayTypeColor(
                                                  _mealPlanController.dayTypes[
                                                              normalizedDate]
                                                          ?.replaceAll(
                                                              '_', ' ') ??
                                                      'regular_day',
                                                  isDarkMode)
                                              .withValues(alpha: 0.2)
                                          : hasMeal
                                              ? kLightGrey.withValues(
                                                  alpha: 0.2)
                                              : null,
                                      borderRadius: BorderRadius.circular(8),
                                      border: normalizedDate ==
                                              normalizedSelectedDate
                                          ? Border.all(
                                              color: kAccentLight,
                                              width: getPercentageWidth(
                                                  0.25, context))
                                          : null,
                                    ),
                                    child: Stack(
                                      children: [
                                        Center(
                                          child: Text(
                                            '${date.day}',
                                            style:
                                                textTheme.bodyLarge?.copyWith(
                                              color: isPastDate
                                                  ? isDarkMode
                                                      ? Colors.white54
                                                      : Colors.black54
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
                                              getDayTypeIcon(_mealPlanController
                                                      .dayTypes[normalizedDate]
                                                      ?.replaceAll('_', ' ') ??
                                                  'regular_day'),
                                              size: getPercentageWidth(
                                                  2.5, context),
                                              color: getDayTypeColor(
                                                  _mealPlanController.dayTypes[
                                                              normalizedDate]
                                                          ?.replaceAll(
                                                              '_', ' ') ??
                                                      'regular_day',
                                                  isDarkMode),
                                            ),
                                          ),
                                        if (hasBirthday &&
                                            _mealPlanController
                                                .showSharedCalendars.value)
                                          Positioned(
                                            right: 2,
                                            bottom: 2,
                                            child: Icon(
                                              Icons.cake,
                                              size: getPercentageWidth(
                                                  3, context),
                                              color: kAccent,
                                            ),
                                          ),
                                        if (isUserBirthday)
                                          Positioned(
                                            right: 2,
                                            bottom: 2,
                                            child: Icon(
                                              Icons.cake,
                                              size: getPercentageWidth(
                                                  3, context),
                                              color: kAccent,
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
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Meals List Section
          _buildMealsList(),
          SizedBox(height: getPercentageHeight(11, context)),
        ],
      ),
    );
  }

  void _shareCalendar(String shareType) async {
    // Check if user is premium or has free share left
    final userDoc =
        await firestore.collection('users').doc(userService.userId).get();
    final isPremium = userService.currentUser.value?.isPremium ?? false;
    int calendarShares = 0;
    if (userDoc.exists) {
      final data = userDoc.data() as Map<String, dynamic>;
      calendarShares = (data['calendarShares'] ?? 0) as int;
    }
    if (!isPremium && calendarShares >= 1) {
      // Show upgrade dialog
      showDialog(
        context: context,
        builder: (context) => showPremiumDialog(
            context,
            getThemeProvider(context).isDarkMode,
            'Premium Feature',
            'Please upgrade to premium to share more calenders!'),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final isDarkMode = getThemeProvider(context).isDarkMode;
        String calendarTitle = '';
        return AlertDialog(
          backgroundColor: isDarkMode ? kDarkGrey : kWhite,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: Text(
            'Share Calendar',
            style: TextStyle(
              color: kAccent,
              fontSize: getTextScale(3.5, context),
            ),
          ),
          content: SafeTextField(
            style: TextStyle(
                color: isDarkMode ? kWhite : kBlack,
                fontSize: getTextScale(3, context)),
            decoration: InputDecoration(
              hintText: 'Enter title',
              labelText: _mealPlanController.isPersonalCalendar.value
                  ? 'Calendar Title'
                  : 'Update calendar title',
              hintStyle: TextStyle(
                  color: isDarkMode ? kWhite : kBlack,
                  fontSize: getTextScale(3, context)),
              labelStyle: TextStyle(
                  color: isDarkMode ? kWhite : kBlack,
                  fontSize: getTextScale(3, context)),
            ),
            onChanged: (value) {
              calendarTitle = value;
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text(
                'Cancel',
                style: TextStyle(
                    color: isDarkMode ? kWhite : kBlack,
                    fontSize: getTextScale(3, context)),
              ),
            ),
            TextButton(
              onPressed: () async {
                if (calendarTitle.isNotEmpty) {
                  Navigator.pop(context);
                  if (_mealPlanController.isPersonalCalendar.value) {
                    // 1. Create new shared calendar doc
                    final newCalRef =
                        await firestore.collection('shared_calendars').add({
                      'header': calendarTitle,
                      'owner': userService.userId,
                      'userIds': [userService.userId],
                      'createdAt': FieldValue.serverTimestamp(),
                    });
                    final newCalId = newCalRef.id;

                    // 2. Fetch personal calendar items: single day or all days
                    final userId = userService.userId!;
                    QuerySnapshot personalItems;

                    if (shareType == 'single_day') {
                      // Only fetch the selected date
                      final dateStr =
                          DateFormat('yyyy-MM-dd').format(selectedDate);
                      personalItems = await firestore
                          .collection('mealPlans')
                          .doc(userId)
                          .collection('date')
                          .where(FieldPath.documentId, isEqualTo: dateStr)
                          .get();
                    } else {
                      // Fetch all dates
                      personalItems = await firestore
                          .collection('mealPlans')
                          .doc(userId)
                          .collection('date')
                          .get();
                    }

                    // 3. Only include items from today onwards
                    final today = DateTime.now();
                    final filteredDocs = personalItems.docs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>?;
                      final dateStr = data?['date'] as String?;
                      if (dateStr == null) return false;
                      try {
                        final date = DateFormat('yyyy-MM-dd').parse(dateStr);
                        final normalizedDate =
                            DateTime(date.year, date.month, date.day);
                        final normalizedToday =
                            DateTime(today.year, today.month, today.day);
                        return !normalizedDate.isBefore(normalizedToday);
                      } catch (e) {
                        return false;
                      }
                    });

                    // 4. Copy to shared calendar in batches
                    final batch = firestore.batch();
                    for (final doc in filteredDocs) {
                      final data = doc.data() as Map<String, dynamic>?;
                      final dateId = doc.id;
                      final sharedDocRef = firestore
                          .collection('shared_calendars')
                          .doc(newCalId)
                          .collection('date')
                          .doc(dateId);
                      batch.set(sharedDocRef, data);
                    }
                    await batch.commit();
                    FirebaseAnalytics.instance
                        .logEvent(name: 'calendar_shared');

                    // 5. Navigate to FriendScreen with newCalId
                    Get.to(() => FriendScreen(
                          dataSrc: {
                            'type': shareType == 'single_day'
                                ? 'specific_date'
                                : 'entire_calendar',
                            'screen': 'meal_design',
                            'calendarId': newCalId,
                            'header': calendarTitle,
                            'isPersonal': 'true',
                          },
                        ));
                  } else {
                    Get.to(() => FriendScreen(
                          dataSrc: {
                            'type': 'entire_calendar',
                            'screen': 'meal_design',
                            'calendarId': _mealPlanController
                                .selectedSharedCalendarId.value,
                            'header': calendarTitle,
                            'isPersonal': 'false',
                          },
                        ));
                  }
                }
              },
              child: Text(
                'Share',
                style: TextStyle(
                    color: kAccent, fontSize: getTextScale(3, context)),
              ),
            ),
          ],
        );
      },
    );
  }

  void _updateCategoryData(String categoryId, String category) {
    if (!mounted) return;
    setState(() {
      selectedCategoryId = categoryId;
      selectedCategory = category;
    });
  }

  Widget _buildMealsList() {
    final normalizedSelectedDate = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
    );
    final isDarkMode = getThemeProvider(context).isDarkMode;
    final isPersonalSpecialDay =
        _mealPlanController.specialMealDays[normalizedSelectedDate] ?? false;

    // Fallback to personal calendar logic
    List<MealWithType> personalMeals = [];
    final List<FamilyMember> currentFamilyMembers =
        userService.currentUser.value?.familyMembers ?? [];
    final List<Map<String, dynamic>> familyList =
        currentFamilyMembers.map((f) => f.toMap()).toList();

    if (familyMode) {
      personalMeals = updateMealForFamily(
          _mealPlanController.mealPlans[normalizedSelectedDate] ?? [],
          selectedCategory,
          familyList);
    } else {
      personalMeals =
          _mealPlanController.mealPlans[normalizedSelectedDate] ?? [];
    }

    final sharedPlans =
        _mealPlanController.sharedMealPlans[normalizedSelectedDate] ?? [];
    final hasMeal =
        _mealPlanController.mealPlans.containsKey(normalizedSelectedDate);
    final friendsBirthdays =
        _mealPlanController.getFriendsBirthdaysForDate(normalizedSelectedDate);
    final birthdayNames = friendsBirthdays
        .map((birthday) => birthday['name'] as String? ?? '')
        .toList();

    final birthdayName = birthdayNames.isEmpty ? '' : birthdayNames.join(', &');

    // Check if we have any meals to show
    final hasPersonalMeals = personalMeals.isNotEmpty;
    final hasSharedMeals =
        _mealPlanController.showSharedCalendars.value && sharedPlans.isNotEmpty;
    final hasAnyMeals = hasPersonalMeals || hasSharedMeals;

    // Show empty state only if there are truly no meals and no special day
    if (!hasAnyMeals && !hasMeal && !isPersonalSpecialDay) {
      return Column(
        children: [
          SizedBox(
            height: getPercentageHeight(2, context),
          ),
          if (familyMode)
            CategorySelector(
              categories: _categoryDatasIngredient,
              selectedCategoryId: selectedCategoryId,
              onCategorySelected: _updateCategoryData,
              isDarkMode: isDarkMode,
              accentColor: kAccentLight,
              darkModeAccentColor: kDarkModeAccent,
            ),
          _buildEmptyState(normalizedSelectedDate, birthdayName, isDarkMode),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: getPercentageHeight(familyMode ? 3 : 0.5, context),
        ),
        if (familyMode)
          CategorySelector(
            categories: _categoryDatasIngredient,
            selectedCategoryId: selectedCategoryId,
            onCategorySelected: _updateCategoryData,
            isDarkMode: isDarkMode,
            accentColor: kAccentLight,
            darkModeAccentColor: kDarkModeAccent,
          ),
        SizedBox(height: getPercentageHeight(1, context)),

        // Show personal meals section
        if (_mealPlanController.showSharedCalendars.value) ...[
          _buildDateHeader(
              normalizedSelectedDate, birthdayName, isDarkMode, sharedPlans),
        ] else ...[
          _buildDateHeader(
              normalizedSelectedDate, birthdayName, isDarkMode, personalMeals),
        ],

        if (hasPersonalMeals &&
            !_mealPlanController.showSharedCalendars.value) ...[
          SizedBox(height: getPercentageHeight(1, context)),
          _buildMealsRowContent(personalMeals, isDarkMode),
          SizedBox(height: getPercentageHeight(1, context)),
        ],

        // Show shared meals section
        if (hasSharedMeals &&
            _mealPlanController.showSharedCalendars.value) ...[
          SizedBox(height: getPercentageHeight(1, context)),
          _buildMealsRowContent(sharedPlans, isDarkMode),
          SizedBox(height: getPercentageHeight(1, context)),
        ],

        if (!hasAnyMeals)
          _buildEmptyState(normalizedSelectedDate, birthdayName, isDarkMode,
              normalizedSelectedDate: normalizedSelectedDate,
              isSpecialDay: isPersonalSpecialDay),

        SizedBox(height: getPercentageHeight(7.5, context)),
      ],
    );
  }

  // Content-only version for when we know meals exist
  Widget _buildMealsRowContent(List<MealWithType> meals, bool isDarkMode) {
    return _buildMealsListView(meals, isDarkMode);
  }

  Widget _buildMealsListView(List<MealWithType> meals, bool isDarkMode) {
    final textTheme = Theme.of(context).textTheme;
    return SizedBox(
      height: MediaQuery.of(context).size.height > 700
          ? getPercentageHeight(18, context)
          : getPercentageHeight(25, context),
      child: ListView.builder(
        padding:
            EdgeInsets.symmetric(horizontal: getPercentageWidth(2, context)),
        scrollDirection: Axis.horizontal,
        itemCount: meals.length,
        itemBuilder: (context, index) {
          final mealWithType = meals[index];
          final meal = mealWithType.meal;
          final mealType = mealWithType.mealType;
          final mealMember = mealWithType.familyMember;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: MediaQuery.of(context).size.height > 1100
                    ? getPercentageWidth(25.5, context)
                    : getPercentageWidth(30, context),
                margin: EdgeInsets.only(right: getPercentageWidth(2, context)),
                child: Card(
                  color: kAccentLight,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Stack(
                    children: [
                      // Main meal content
                      InkWell(
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
                                padding: EdgeInsets.all(
                                    getPercentageWidth(1, context)),
                                child: AspectRatio(
                                  aspectRatio: 1,
                                  child: ClipOval(
                                    child: meal.mediaPaths.isNotEmpty
                                        ? meal.mediaPaths.first
                                                .contains('https')
                                            ? OptimizedImage(
                                                imageUrl: meal.mediaPaths.first,
                                                fit: BoxFit.cover,
                                                borderRadius:
                                                    BorderRadius.circular(
                                                        getPercentageWidth(
                                                            100, context)),
                                                width: double.infinity,
                                                height: double.infinity,)
                                            : Image.asset(
                                                getAssetImageForItem(
                                                    meal.mediaPaths.first),
                                                fit: BoxFit.cover,
                                                errorBuilder: (context, error,
                                                        stackTrace) =>
                                                    Container(
                                                  decoration: BoxDecoration(
                                                    color: Colors.grey[300],
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: Icon(
                                                    Icons.restaurant,
                                                    size: getPercentageWidth(
                                                        6, context),
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
                                padding: EdgeInsets.symmetric(
                                    horizontal: getPercentageWidth(1, context)),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Center(
                                      child: Text(
                                        capitalizeFirstLetter(meal.title),
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                        style: textTheme.bodyMedium?.copyWith(
                                            fontWeight: FontWeight.w500,
                                            fontSize:
                                                getPercentageWidth(3, context)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Close button
                      Positioned(
                        top: 0,
                        right: MediaQuery.of(context).size.height > 1100
                            ? -3
                            : -11,
                        child: IconButton(
                          icon: Icon(Icons.close,
                              size: getIconScale(6, context), color: kAccent),
                          tooltip: 'Remove from meal plan',
                          onPressed: () async {
                            final formattedDate =
                                DateFormat('yyyy-MM-dd').format(selectedDate);
                            final userId = userService.userId;
                            if (userId == null) return;

                            final docRef =
                                _mealPlanController.showSharedCalendars.value
                                    ? firestore
                                        .collection('shared_calendars')
                                        .doc(_mealPlanController
                                            .selectedSharedCalendarId.value)
                                        .collection('date')
                                        .doc(formattedDate)
                                    : firestore
                                        .collection('mealPlans')
                                        .doc(userId)
                                        .collection('date')
                                        .doc(formattedDate);

                            final doc = await docRef.get();
                            if (doc.exists) {
                              await docRef.update({
                                'meals': FieldValue.arrayRemove(
                                    [mealWithType.fullMealId])
                              });

                              if (!mounted) return;
                              setState(() {
                                meals.removeAt(index);
                              });
                              _mealPlanController.refresh();
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Meal type icon as a top-level overlay
              Positioned(
                top: getPercentageWidth(-2, context),
                left: getPercentageWidth(-1, context),
                child: GestureDetector(
                  onTap: () {
                    _updateMealType(mealWithType.fullMealId, meal.mealId,
                        mealType, mealMember, isDarkMode);
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDarkMode ? kDarkGrey : kWhite,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: kAccent.withValues(alpha: 0.5),
                          blurRadius: getPercentageWidth(1, context),
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    padding: EdgeInsets.all(getPercentageWidth(2, context)),
                    child: Text(
                      getMealTypeSubtitle(mealType),
                      style: textTheme.displaySmall?.copyWith(
                        fontSize: getTextScale(5, context),
                        color: kAccent,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<String?> showMealTypePicker(
      BuildContext context, bool isDarkMode) async {
    return await showModalBottomSheet<String>(
      backgroundColor: isDarkMode ? kDarkGrey : kWhite,
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final textTheme = Theme.of(context).textTheme;
        return Padding(
          padding: EdgeInsets.all(getPercentageWidth(2, context)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Select Meal Type',
                  style: textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w200,
                      fontSize: getTextScale(7, context),
                      color: isDarkMode ? kWhite : kBlack)),
              SizedBox(height: getPercentageHeight(1, context)),
              ...[
                {'label': 'Breakfast (BF)', 'icon': Icons.emoji_food_beverage},
                {'label': 'Lunch (LH)', 'icon': Icons.lunch_dining},
                {'label': 'Dinner (DN)', 'icon': Icons.dinner_dining},
                {'label': 'Snacks (SK)', 'icon': Icons.fastfood},
              ].map((item) => ListTile(
                    leading: Icon(item['icon'] as IconData,
                        color: isDarkMode ? kWhite : kBlack),
                    title: Text(item['label'] as String,
                        style: textTheme.bodyLarge?.copyWith(
                          color: isDarkMode ? kWhite : kBlack,
                        )),
                    onTap: () => Navigator.pop(
                        context, (item['label'] as String).toLowerCase()),
                  )),
              SizedBox(height: getPercentageHeight(0.5, context)),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel',
                    style: textTheme.bodyMedium?.copyWith(
                      color: isDarkMode ? kWhite : kBlack,
                    )),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _updateMealType(String fullMealId, String mealId,
      String mealType, String familyMember, bool isDarkMode) async {
    final result = await showMealTypePicker(context, isDarkMode);
    if (result != null) {
      final formattedDate = DateFormat('yyyy-MM-dd').format(selectedDate);
      final mealToAdd =
          '${mealId}/${result.toLowerCase()}/${familyMember.toLowerCase()}';
      mealManager.updateMealType(fullMealId, mealToAdd, formattedDate);
    }
    _mealPlanController.refresh();
  }

  void _selectDate(DateTime date) {
    final normalizedSelectedDate = DateTime(date.year, date.month, date.day);
    if (!mounted) return;
    setState(() {
      selectedDate = normalizedSelectedDate;
    });

    if (_mealPlanController.showSharedCalendars.value &&
        _mealPlanController.selectedSharedCalendarId.value != null) {
      sharingController.selectSharedDate(normalizedSelectedDate);
    }
  }

  Future<void> _addMealPlan(
      BuildContext context, bool isDarkMode, bool needDatePicker, String typeW,
      {bool goStraightToAddMeal = false}) async {
    final textTheme = Theme.of(context).textTheme;
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
    if (!mounted) return;
    setState(() {
      selectedDate = pickedDate!;
    });

    if (!mounted) return;

    // Show dialog to mark as special meal
    String selectedDayType = '';
    if (typeW.isNotEmpty) {
      selectedDayType = typeW;
    } else {
      selectedDayType = 'regular_day';
    }

    if (goStraightToAddMeal) {
      final formattedDate = DateFormat('yyyy-MM-dd').format(selectedDate);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RecipeListCategory(
            index: 0,
            searchIngredient: '',
            isMealplan: true,
            mealPlanDate: formattedDate,
            isSpecial: selectedDayType != 'regular_day',
            screen: 'ingredient',
            isSharedCalendar: _mealPlanController.showSharedCalendars.value,
            sharedCalendarId: _mealPlanController.showSharedCalendars.value
                ? _mealPlanController.selectedSharedCalendarId.value
                : null,
            familyMember: selectedCategory.toLowerCase(),
            isFamilyMode: familyMode,
            isBackToMealPlan: true,
            isNoTechnique: true,
          ),
        ),
      ).then((_) {
        _mealPlanController.refresh();
      });
      return;
    }

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          backgroundColor: isDarkMode ? kDarkGrey : kWhite,
          title: Text(
            'Special Day?',
            style:
                TextStyle(color: kAccent, fontSize: getTextScale(4, context)),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'What type of day is this?',
                style: textTheme.bodyMedium?.copyWith(
                    color: isDarkMode ? kWhite : kBlack,
                    fontSize: getPercentageWidth(3.5, context)),
              ),
              SizedBox(height: getPercentageWidth(1.5, context)),
              ...[
                'Regular Day',
                'Diet Day',
                'Cheat Day',
                'Family Dinner',
                'Workout Boost',
                'Special Celebration'
              ].map(
                (type) => Flexible(
                  child: ListTile(
                    selected: selectedDayType ==
                        type.toLowerCase().replaceAll(' ', '_'),
                    selectedTileColor: kAccentLight.withValues(alpha: 0.1),
                    title: Text(
                      type,
                      style: textTheme.bodyMedium?.copyWith(
                          color: isDarkMode ? kWhite : kBlack,
                          fontSize: getPercentageWidth(3.5, context)),
                    ),
                    leading: Icon(
                      getDayTypeIcon(type),
                      color: getDayTypeColor(type, isDarkMode),
                    ),
                    onTap: () {
                      if (!mounted) return;
                      setState(() {
                        selectedDayType =
                            type.toLowerCase().replaceAll(' ', '_');
                      });
                    },
                  ),
                ),
              ),
            ],
          ),
          actions: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: Icon(Icons.close, size: getIconScale(6, context)),
                  onPressed: () => Navigator.pop(context),
                  color: isDarkMode ? kWhite : kBlack,
                ),
                if (_mealPlanController.isPersonalCalendar.value)
                  IconButton(
                    icon: Icon(Icons.ios_share, size: getIconScale(5, context)),
                    onPressed: () async {
                      Navigator.pop(context);
                      _shareCalendar('single_day');
                      _mealPlanController.refresh();
                    },
                    color: isDarkMode ? kWhite : kBlack,
                  ),
                Flexible(
                  child: TextButton(
                    onPressed: () async {
                      Navigator.pop(context,
                          {'dayType': selectedDayType, 'action': 'save'});
                      _mealPlanController.refresh();
                    },
                    child: Text(
                      'Save',
                      style: textTheme.displaySmall?.copyWith(
                          color: kAccentLight,
                          fontSize: getPercentageWidth(4.5, context)),
                    ),
                  ),
                ),
                Flexible(
                  child: TextButton(
                    onPressed: () {
                      Navigator.pop(context,
                          {'dayType': selectedDayType, 'action': 'add_meal'});
                    },
                    child: Text(
                      'Add Meal',
                      style: textTheme.displaySmall?.copyWith(
                          color: kAccent,
                          fontSize: getPercentageWidth(4.5, context)),
                    ),
                  ),
                ),
              ],
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

      if (_mealPlanController.showSharedCalendars.value) {
        sharedCalendarRef = firestore
            .collection('shared_calendars')
            .doc(_mealPlanController.selectedSharedCalendarId.value!)
            .collection('date')
            .doc(formattedDate);
        await sharedCalendarRef!.set({
          'userId': userId,
          'dayType': dayType,
          'isSpecial': dayType.isNotEmpty && dayType != 'regular_day',
          'date': formattedDate,
          'meals': FieldValue.arrayUnion(
              []), // Only initialize if meals field doesn't exist
        }, SetOptions(merge: true));
      } else {
        // For personal calendar
        await helperController.saveMealPlan(userId, formattedDate, dayType);
      }
      if (!mounted) return;
      setState(() {
        _mealPlanController.specialMealDays[selectedDate] =
            dayType != 'regular_day';
        _mealPlanController.dayTypes[selectedDate] = dayType;
      });

      // Only navigate to recipe selection if "Add Meal" was clicked
      if (action == 'add_meal') {
        FirebaseAnalytics.instance.logEvent(name: 'meal_plan_added');
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
                isSharedCalendar: _mealPlanController.showSharedCalendars.value,
                sharedCalendarId: _mealPlanController.showSharedCalendars.value
                    ? _mealPlanController.selectedSharedCalendarId.value
                    : null,
                familyMember: selectedCategory.toLowerCase(),
                isFamilyMode: familyMode,
                isNoTechnique: true,
                isBackToMealPlan: true),
          ),
        ).then((_) {
          // Refresh meal plans after adding new meals
          _mealPlanController.refresh();
        });
      }
    } catch (e) {
      print('Error in _addMealPlan: $e');
    }
  }

  Widget _buildEmptyState(DateTime date, String birthdayName, bool isDarkMode,
      {DateTime? normalizedSelectedDate, bool? isSpecialDay}) {
    final textTheme = Theme.of(context).textTheme;
    final currentDayType = _mealPlanController.dayTypes[date] ?? 'regular_day';
    return SizedBox(
      height: 200,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (birthdayName.isNotEmpty &&
                _mealPlanController.showSharedCalendars.value) ...[
              getBirthdayTextContainer(birthdayName, false, context),
            ],
            if (_isUserBirthday(date)) ...[
              getBirthdayTextContainer('You', false, context),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (!date.isBefore(
                    DateTime.now().subtract(const Duration(days: 1)))) ...[
                  SizedBox(height: getPercentageHeight(1, context)),
                  TextButton.icon(
                    onPressed: () => _addMealPlan(
                        context, isDarkMode, false, '',
                        goStraightToAddMeal: !familyMode ||
                                selectedCategory.toLowerCase() ==
                                    userService.currentUser.value?.displayName
                                        ?.toLowerCase()
                            ? false
                            : true),
                    icon: Icon(Icons.add, size: getIconScale(6, context)),
                    label: Text('Add Meal',
                        style: textTheme.bodyMedium?.copyWith(
                            fontSize: getPercentageWidth(3.5, context),
                            fontWeight: FontWeight.w400)),
                    style: TextButton.styleFrom(
                      foregroundColor: kAccent,
                    ),
                  ),
                ],
              ],
            ),
            SizedBox(height: getPercentageHeight(1, context)),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (birthdayName.isEmpty && !_isUserBirthday(date)) ...[
                  Icon(
                    Icons.restaurant,
                    size: getPercentageWidth(6, context),
                    color: isDarkMode ? Colors.white24 : Colors.black26,
                  ),
                ],
                SizedBox(width: getPercentageWidth(1.5, context)),
                Column(
                  children: [
                    if (isSpecialDay == true) ...[
                      Text(
                        'Enjoy your ${currentDayType.toLowerCase() == 'regular_day' ? 'meal plan' : capitalizeFirstLetter(currentDayType.replaceAll('_', ' '))}!',
                        style: textTheme.bodyMedium?.copyWith(
                          color: getDayTypeColor(
                              currentDayType.replaceAll('_', ' '), isDarkMode),
                        ),
                      ),
                    ],
                    SizedBox(width: getPercentageWidth(1.5, context)),
                    Text(
                      getRelativeDayString(selectedDate) == 'Today' ||
                              getRelativeDayString(selectedDate) == 'Tomorrow'
                          ? 'No meals planned for ${getRelativeDayString(selectedDate)}'
                          : 'No meals planned for this day',
                      style: textTheme.bodyMedium?.copyWith(
                        color: isDarkMode ? kLightGrey : kDarkGrey,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateHeader(DateTime date, String birthdayName, bool isDarkMode,
      List<MealWithType> meals) {
    final currentDayType = _mealPlanController.dayTypes[date] ?? 'regular_day';
    final isUserBirthday = _isUserBirthday(date);
    final textTheme = Theme.of(context).textTheme;
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.all(getPercentageWidth(2, context)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          DateFormat('MMMM d, yyyy').format(date),
                          style: textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                              fontSize: getPercentageWidth(4.5, context)),
                        ),
                        if (isUserBirthday) ...[
                          SizedBox(width: getPercentageWidth(1, context)),
                          Icon(Icons.cake,
                              color: kAccent,
                              size: getPercentageWidth(4, context)),
                        ],
                        if (meals.isNotEmpty) ...[
                          SizedBox(width: getPercentageWidth(2, context)),
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const ShoppingTab(),
                                ),
                              );
                            },
                            child: SvgPicture.asset(
                              'assets/images/svg/shopping.svg',
                              height: getPercentageWidth(4.5, context),
                              width: getPercentageWidth(4.5, context),
                              color: kAccent,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (isUserBirthday)
                      getBirthdayTextContainer('You', true, context),
                    if (meals.isNotEmpty)
                      if (birthdayName.isNotEmpty &&
                          _mealPlanController.showSharedCalendars.value) ...[
                        getBirthdayTextContainer(birthdayName, true, context),
                      ],
                    Text(
                      '${meals.length} ${meals.length == 1 ? 'meal' : 'meals'} planned',
                      style: textTheme.bodyMedium?.copyWith(
                          color: isDarkMode ? kLightGrey : kDarkGrey,
                          fontWeight: FontWeight.w500,
                          fontSize: getPercentageWidth(3.5, context)),
                    ),
                  ],
                ),
              ),
              if (!familyMode ||
                  selectedCategory.toLowerCase() ==
                      userService.currentUser.value?.displayName
                          ?.toLowerCase()) ...[
                GestureDetector(
                  key: _addMealButtonKey,
                  onTap: () => _addMealPlan(
                      context, isDarkMode, false, currentDayType,
                      goStraightToAddMeal: false),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: getPercentageWidth(2, context),
                        vertical: getPercentageHeight(1, context)),
                    decoration: BoxDecoration(
                      color: getDayTypeColor(
                              currentDayType.replaceAll('_', ' '), isDarkMode)
                          .withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          getDayTypeIcon(currentDayType.replaceAll('_', ' ')),
                          size: getPercentageWidth(3.5, context),
                          color: getDayTypeColor(
                              currentDayType.replaceAll('_', ' '), isDarkMode),
                        ),
                        SizedBox(width: getPercentageWidth(1, context)),
                        Text(
                          currentDayType.toLowerCase() == 'regular_day'
                              ? 'Meal Plan'
                              : capitalizeFirstLetter(
                                  currentDayType.replaceAll('_', ' ')),
                          style: textTheme.displaySmall?.copyWith(
                              color: getDayTypeColor(
                                  currentDayType.replaceAll('_', ' '),
                                  isDarkMode),
                              fontWeight: FontWeight.w600,
                              fontSize: getPercentageWidth(4.5, context)),
                        ),
                        SizedBox(width: getPercentageWidth(1, context)),
                        Icon(
                          Icons.edit,
                          size: getIconScale(5, context),
                          color: getDayTypeColor(
                              currentDayType.replaceAll('_', ' '), isDarkMode),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else ...[
                GestureDetector(
                  onTap: () => _addMealPlan(
                      context, isDarkMode, false, currentDayType,
                      goStraightToAddMeal: true),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: getPercentageWidth(2, context),
                        vertical: getPercentageHeight(1, context)),
                    decoration: BoxDecoration(
                      color: getDayTypeColor(
                              currentDayType.replaceAll('_', ' '), isDarkMode)
                          .withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.edit,
                      size: getIconScale(4, context),
                      color: getDayTypeColor(
                          currentDayType.replaceAll('_', ' '), isDarkMode),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  void _showSpecialDayDetails(
      BuildContext context, DateTime date, String dayType) {
    final textTheme = Theme.of(context).textTheme;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor:
            getThemeProvider(context).isDarkMode ? kDarkGrey : kWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Text(
          'Special Day',
          style: textTheme.titleLarge?.copyWith(
              color: getThemeProvider(context).isDarkMode ? kWhite : kBlack),
        ),
        content: Text(
          caseDayType(dayType),
          style: textTheme.bodyLarge?.copyWith(
              color: getDayTypeColor(dayType.replaceAll('_', ' '),
                  getThemeProvider(context).isDarkMode)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Close',
              style: textTheme.bodyMedium?.copyWith(color: kAccent),
            ),
          ),
        ],
      ),
    );
  }
}

caseDayType(String dayType) {
  switch (dayType.toLowerCase()) {
    case 'welcome_day':
      return 'This was your first day with TastyTurner!';
    case 'family_dinner':
      return 'This was a Family Dinner day.';
    case 'workout_boost':
      return 'This was a Workout Boost day.';
    case 'special_celebration':
      return 'You had a Special Celebration.';
    default:
      return 'This was a ${capitalizeFirstLetter(dayType.replaceAll('_', ' '))}.';
  }
}

// Add SharedMealPlan class
class SharedMealPlan {
  final String date;
  final String userId;
  final List<UserMeal> meals;
  final bool isSpecial;
  final String? dayType;
  final String sharedBy;

  SharedMealPlan({
    required this.date,
    required this.userId,
    required this.meals,
    required this.isSpecial,
    this.dayType,
    required this.sharedBy,
  });
}

// Helper to get meal type icon
IconData getMealTypeIcon(String? type) {
  switch ((type ?? '').toLowerCase()) {
    case 'breakfast':
      return Icons.emoji_food_beverage_outlined;
    case 'lunch':
      return Icons.lunch_dining_outlined;
    case 'dinner':
      return Icons.dinner_dining_outlined;
    case 'snacks':
      return Icons.cake_outlined;
    default:
      return Icons.question_mark;
  }
}
