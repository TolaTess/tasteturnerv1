import 'dart:async';
import 'dart:io';

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
import '../screens/friend_screen.dart';
import '../service/meal_plan_controller.dart';
import '../service/tasty_popup_service.dart';
import '../widgets/category_selector.dart';
import '../widgets/custom_drawer.dart';
import '../widgets/icon_widget.dart';
import '../screens/recipes_list_category_screen.dart';
import '../detail_screen/recipe_detail.dart';
import '../widgets/info_icon_widget.dart';
import '../widgets/optimized_image.dart';
import 'buddy_tab.dart';
import '../helper/calendar_sharing_controller.dart';
import '../service/calendar_sharing_service.dart';
import '../service/cycle_adjustment_service.dart';
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
  late PageController
      _calendarPageController; // Move PageController to widget level
  DateTime selectedDate = DateTime.now();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  Future<QuerySnapshot<Map<String, dynamic>>>? _buddyDataFuture;
  int get _tabCount => 2;
  bool isPremium = userService.currentUser.value?.isPremium ?? false;
  bool familyMode = userService.currentUser.value?.familyMode ?? false;
  final CalendarSharingController sharingController =
      Get.put(CalendarSharingController());
  final CalendarSharingService calendarSharingService =
      CalendarSharingService();
  final cycleAdjustmentService = CycleAdjustmentService.instance;

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
    try {
      _mealPlanController = Get.find<MealPlanController>();
    } catch (e) {
      // If not found, put it
      _mealPlanController = Get.put(MealPlanController());
    }

    _tabController = TabController(
        length: _tabCount, vsync: this, initialIndex: widget.initialTabIndex);
    _tabController.addListener(_handleTabIndex);

    // Initialize PageController for calendar at widget level
    _calendarPageController = PageController(initialPage: 1);

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
        final firstCategory = _categoryDatasIngredient[0];
        selectedCategoryId = firstCategory['id']?.toString() ?? '';
        selectedCategory = firstCategory['name']?.toString() ?? '';
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
    // Don't await - fire and forget for initial setup
    _onRefresh();
  }

  /// Format date as yyyy-MM-dd for Firestore document ID
  String _formatDate(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  /// Handle errors with consistent snackbar display
  void _handleError(String message, {String? details}) {
    if (!mounted || !context.mounted) return;
    debugPrint('Error: $message${details != null ? ' - $details' : ''}');
        showTastySnackbar(
          'Error',
      message,
          context,
          backgroundColor: Colors.red,
        );
      }


  Future<void> _onRefresh() async {
    if (!mounted) return;
    try {
      _mealPlanController.refresh();
    } catch (e) {
      _handleError('Failed to refresh meal plan. Please try again.',
          details: e.toString());
    }
  }

  void _initializeBuddyData() {
    if (!mounted) return;

    final userId = userService.userId;
    if (userId == null || userId.isEmpty) {
      debugPrint('Warning: userId is null in _initializeBuddyData');
      return;
    }

    try {
      final now = DateTime.now();
      final sevenDaysAgo = now.subtract(const Duration(days: 7));
      final dateFormat = DateFormat('yyyy-MM-dd');
      final lowerBound = dateFormat.format(sevenDaysAgo);
      final upperBound = dateFormat.format(now);

      _buddyDataFuture = firestore
          .collection('mealPlans')
          .doc(userId)
          .collection('buddy')
          .where(FieldPath.documentId, isGreaterThanOrEqualTo: lowerBound)
          .where(FieldPath.documentId, isLessThanOrEqualTo: upperBound)
          .get();
    } catch (e) {
      debugPrint('Error initializing buddy data: $e');
      if (mounted && context.mounted) {
        showTastySnackbar(
          'Error',
          'Failed to load buddy data. Please try again.',
          context,
          backgroundColor: Colors.red,
        );
      }
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

    // Only update premium status if it changed, avoid unnecessary refresh
    final newPremiumStatus = userService.currentUser.value?.isPremium ?? false;
    if (newPremiumStatus != isPremium && mounted) {
      setState(() {
        isPremium = newPremiumStatus;
      });
    }
    // Removed _onRefresh() call - it's inefficient to refresh on every dependency change
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
    _tabController.removeListener(_handleTabIndex);
    _tabController.dispose();
    _calendarPageController.dispose(); // Dispose PageController
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
                              fontSize: getTextScale(5, context))),
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
                              fontSize: getTextScale(5, context))),
                      SizedBox(width: getPercentageWidth(1, context)),
                    ],
                  ),
                ),
              ],
              labelColor: isDarkMode ? kWhite : kBlack,
              labelStyle: textTheme.displayMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: Platform.isMacOS
                      ? getPercentageWidth(5, context)
                      : getPercentageWidth(4, context)),
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
                  padding: EdgeInsets.only(
                    top: getPercentageHeight(1, context),
                  ),
                  child: _buildCalendarTab(),
                ),
                Padding(
                  padding: EdgeInsets.only(
                    top: getPercentageHeight(1, context),
                  ),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Meal Planner',
                style: textTheme.displaySmall?.copyWith(
                  color: kAccent,
                ),
              ),
              SizedBox(width: getPercentageWidth(2, context)),
              Builder(
                builder: (context) {
                  // Get user gender to conditionally show cycle syncing
                  final userGender = userService
                      .currentUser.value?.settings['gender'] as String?;
                  final isMale = userGender?.toLowerCase() == 'male';

                  // Build details list, excluding cycle syncing for males
                  final details = <Map<String, dynamic>>[
                    {
                      'icon': Icons.calendar_month,
                      'title': 'Add Meals',
                      'description':
                          'Add your meals or drag and drop meals to copy to other dates',
                      'color': kAccentLight,
                    },
                    if (!isMale)
                      {
                        'icon': Icons.shopping_cart,
                        'title': 'Cycle Syncing',
                        'description':
                            'Adjust macro goals based on your menstrual cycle phase',
                        'color': kAccentLight,
                      },
                    {
                      'icon': Icons.people_outline,
                      'title': 'Share Calendar',
                      'description':
                          'Share your meal plan with friends and family',
                      'color': kAccentLight,
                    },
                    {
                      'icon': Icons.cake,
                      'title': 'Special Days',
                      'description': 'Mark special occasions and celebrations',
                      'color': kAccentLight,
                    },
                    {
                      'icon': Icons.family_restroom,
                      'title': 'Family Mode',
                      'description': 'Plan meals for your entire family',
                      'color': kAccentLight,
                    },
                    {
                      'icon': Icons.shopping_cart,
                      'title': 'Shopping List',
                      'description':
                          'Generate shopping lists at a click of a button',
                      'color': kAccentLight,
                    },
                  ];

                  return InfoIconWidget(
                    title: 'Meal Planner',
                    description: 'Plan your meals for the week',
                    details: details,
                    iconColor: kAccentLight,
                  );
                },
              ),
            ],
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
                    Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: getPercentageWidth(1.5, context),
                          vertical: getPercentageHeight(0.5, context)),
                      decoration: BoxDecoration(
                        color: kAccent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
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
                                fontSize: getTextScale(4, context)),
                          ),
                          SizedBox(width: getPercentageWidth(1, context)),
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
                              size: getIconScale(5.5, context),
                            ),
                            onPressed: () {
                              if (!mounted) return;
                              setState(() {
                                _mealPlanController.showSharedCalendars.value =
                                    !_mealPlanController
                                        .showSharedCalendars.value;
                              });
                              _mealPlanController.refresh();
                            },
                            tooltip:
                                _mealPlanController.showSharedCalendars.value
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
                        ],
                      ),
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
                          future: () {
                            final userId = userService.userId;
                            if (userId == null || userId.isEmpty) {
                              return Future.value(<SharedCalendar>[]);
                            }
                            return calendarSharingService
                                .fetchSharedCalendarsForUser(userId);
                          }(),
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
                          controller:
                              _calendarPageController, // Use widget-level controller
                          onPageChanged: (index) {
                            final monthOffset = index - 1;
                            final currentDate = DateTime.now();
                            final targetDate = DateTime(currentDate.year,
                                currentDate.month + monthOffset);
                            _mealPlanController.updateFocusedDate(targetDate);
                          },
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

                                return DragTarget<Map<String, dynamic>>(
                                  onWillAccept: (data) {
                                    // Only accept drops on future dates (not past dates)
                                    return !isPastDate;
                                  },
                                  onAccept: (data) async {
                                    final fullMealId =
                                        data['fullMealId'] as String?;
                                    final sourceDate =
                                        data['sourceDate'] as DateTime?;

                                    if (fullMealId == null ||
                                        sourceDate == null) return;

                                    // Don't move if source and target are the same
                                    if (normalizedDate.year ==
                                            sourceDate.year &&
                                        normalizedDate.month ==
                                            sourceDate.month &&
                                        normalizedDate.day == sourceDate.day) {
                                      return;
                                    }

                                    // Copy the meal
                                    try {
                                      final success = await _mealPlanController
                                          .mealManager
                                          .copyMealPlan(
                                        sourceDate,
                                        normalizedDate,
                                        fullMealId,
                                      );

                                      if (mounted) {
                                        if (success) {
                                          // Refresh meal plans
                                          _mealPlanController.refresh();

                                          // Update selected date if copying to a different date
                                          if (normalizedDate !=
                                              normalizedSelectedDate) {
                                            _selectDate(normalizedDate);
                                          }

                                          showTastySnackbar(
                                            'Success',
                                            'Meal copied to ${DateFormat('MMM dd, yyyy').format(normalizedDate)}',
                                            context,
                                          );
                                        } else {
                                          showTastySnackbar(
                                            'Error',
                                            'Failed to copy meal. Please try again.',
                                            context,
                                            backgroundColor: Colors.red,
                                          );
                                        }
                                      }
                                    } catch (e) {
                                      debugPrint('Error copying meal: $e');
                                      if (mounted && context.mounted) {
                                        showTastySnackbar(
                                          'Error',
                                          'Failed to copy meal: $e',
                                          context,
                                          backgroundColor: Colors.red,
                                        );
                                      }
                                    }
                                  },
                                  builder:
                                      (context, candidateData, rejectedData) {
                                    final isDraggingOver =
                                        candidateData.isNotEmpty;

                                    return GestureDetector(
                                      onTap: () {
                                        if (hasSpecialMeal) {
                                          if (isPastDate) {
                                            _showSpecialDayDetails(context,
                                                normalizedDate, dayType);
                                          } else {
                                            _selectDate(date);
                                          }
                                        } else if (!isPastDate) {
                                          _selectDate(date);
                                        }
                                      },
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: isDraggingOver && !isPastDate
                                              ? kAccentLight.withValues(
                                                  alpha: 0.5)
                                              : hasSpecialMeal
                                                  ? getDayTypeColor(
                                                          _mealPlanController
                                                                  .dayTypes[
                                                                      normalizedDate]
                                                                  ?.replaceAll(
                                                                      '_',
                                                                      ' ') ??
                                                              'regular_day',
                                                          isDarkMode)
                                                      .withValues(alpha: 0.2)
                                                  : hasMeal
                                                      ? kLightGrey.withValues(
                                                          alpha: 0.2)
                                                      : null,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          border: normalizedDate ==
                                                  normalizedSelectedDate
                                              ? Border.all(
                                                  color: kAccentLight,
                                                  width: getPercentageWidth(
                                                      0.25, context))
                                              : isDraggingOver && !isPastDate
                                                  ? Border.all(
                                                      color: kAccent, width: 2)
                                                  : null,
                                        ),
                                        child: Stack(
                                          children: [
                                            Center(
                                              child: Text(
                                                '${date.day}',
                                                style: textTheme.bodyLarge
                                                    ?.copyWith(
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
                                                              DateTime.now()
                                                                  .year,
                                                              DateTime.now()
                                                                  .month,
                                                              DateTime.now()
                                                                  .day)
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
                                                  getDayTypeIcon(
                                                      _mealPlanController
                                                              .dayTypes[
                                                                  normalizedDate]
                                                              ?.replaceAll(
                                                                  '_', ' ') ??
                                                          'regular_day'),
                                                  size: getPercentageWidth(
                                                      2.5, context),
                                                  color: getDayTypeColor(
                                                      _mealPlanController
                                                              .dayTypes[
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
                                            // Cycle phase indicator
                                            if (_shouldShowCycleIndicator(
                                                normalizedDate))
                                              Positioned(
                                                left: 2,
                                                top: 2,
                                                child: Text(
                                                  _getCyclePhaseEmoji(
                                                      normalizedDate),
                                                  style: TextStyle(
                                                    fontSize:
                                                        getPercentageWidth(
                                                            2.5, context),
                                                    color: _getCyclePhaseColor(
                                                        normalizedDate),
                                                  ),
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
                                            if (isDraggingOver && !isPastDate)
                                              Positioned.fill(
                                                child: Container(
                                                  decoration: BoxDecoration(
                                                    color: kAccent.withValues(
                                                        alpha: 0.2),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8),
                                                  ),
                                                  child: Center(
                                                    child: Icon(
                                                      Icons.add_circle_outline,
                                                      color: kAccent,
                                                      size: getPercentageWidth(
                                                          8, context),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
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
    if (!mounted) return;

    final userId = userService.userId;
    if (userId == null || userId.isEmpty) {
      if (mounted && context.mounted) {
        showTastySnackbar(
          'Error',
          'User ID is missing. Please try again.',
          context,
          backgroundColor: Colors.red,
        );
      }
      return;
    }

    try {
      // Check if user is premium or has free share left
      final userDoc = await firestore.collection('users').doc(userId).get();
      final isPremium = userService.currentUser.value?.isPremium ?? false;
      int calendarShares = 0;
      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>;
        calendarShares = (data['calendarShares'] ?? 0) as int;
      }
      if (!mounted) return;

      if (!isPremium && calendarShares >= 1) {
        // Show upgrade dialog
        if (context.mounted) {
          showDialog(
            context: context,
            builder: (context) => showPremiumDialog(
                context,
                getThemeProvider(context).isDarkMode,
                'Premium Feature',
                'Please upgrade to premium to share more calenders!'),
          );
        }
        return;
      }

      if (!mounted) return;
      if (!context.mounted) return;

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
                  try {
                    if (calendarTitle.isNotEmpty) {
                      Navigator.pop(context);
                      if (_mealPlanController.isPersonalCalendar.value) {
                        // 1. Create new shared calendar doc
                        final newCalRef =
                            await firestore.collection('shared_calendars').add({
                          'header': calendarTitle,
                          'owner': userId,
                          'userIds': [userId],
                          'createdAt': FieldValue.serverTimestamp(),
                        });
                        final newCalId = newCalRef.id;

                        // 2. Fetch personal calendar items: single day or all days
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
                            final date =
                                DateFormat('yyyy-MM-dd').parse(dateStr);
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

                        if (!mounted) return;

                        // 5. Navigate to FriendScreen with newCalId
                        try {
                          await Get.to(() => FriendScreen(
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
                        } catch (e) {
                          debugPrint('Error navigating to FriendScreen: $e');
                          if (mounted && context.mounted) {
                            showTastySnackbar(
                              'Error',
                              'Failed to open sharing screen. Please try again.',
                              context,
                              backgroundColor: Colors.red,
                            );
                          }
                        }
                      } else {
                        final selectedCalendarId =
                            _mealPlanController.selectedSharedCalendarId.value;
                        if (selectedCalendarId == null ||
                            selectedCalendarId.isEmpty) {
                          if (mounted && context.mounted) {
                            showTastySnackbar(
                              'Error',
                              'No calendar selected. Please select a calendar first.',
                              context,
                              backgroundColor: Colors.red,
                            );
                          }
                          return;
                        }

                        try {
                          await Get.to(() => FriendScreen(
                                dataSrc: {
                                  'type': 'entire_calendar',
                                  'screen': 'meal_design',
                                  'calendarId': selectedCalendarId,
                                  'header': calendarTitle,
                                  'isPersonal': 'false',
                                },
                              ));
                        } catch (e) {
                          debugPrint('Error navigating to FriendScreen: $e');
                          if (mounted && context.mounted) {
                            showTastySnackbar(
                              'Error',
                              'Failed to open sharing screen. Please try again.',
                              context,
                              backgroundColor: Colors.red,
                            );
                          }
                        }
                      }
                    }
                  } catch (e) {
                    debugPrint('Error in share calendar dialog: $e');
                    if (mounted && context.mounted) {
                      Navigator.pop(context);
                      showTastySnackbar(
                        'Error',
                        'Failed to share calendar. Please try again.',
                        context,
                        backgroundColor: Colors.red,
                      );
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
    } catch (e) {
      debugPrint('Error in _shareCalendar: $e');
      if (mounted && context.mounted) {
        showTastySnackbar(
          'Error',
          'Failed to share calendar. Please try again.',
          context,
          backgroundColor: Colors.red,
        );
      }
    }
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
    final cycleSuggestion = _getCycleSuggestionForDate(normalizedSelectedDate);

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

        if (cycleSuggestion != null) ...[
          SizedBox(height: getPercentageHeight(0.5, context)),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: getPercentageWidth(2, context),
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: getPercentageWidth(80, context),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Cycle Goals',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: isDarkMode ? kLightGrey : kDarkGrey,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                    SizedBox(height: getPercentageHeight(0.3, context)),
                    Text(
                      cycleSuggestion['appAction'] ?? '',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: isDarkMode ? kLightGrey : kDarkGrey,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ),
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
    final mediaQuery = MediaQuery.of(context);
    final size = mediaQuery.size;
    final shortestSide = size.shortestSide;

    // Treat iPad/tablet layouts differently so we can show a denser grid (e.g. 3x3+)
    final bool isTablet = shortestSide >= 600;
    final int crossAxisCount = isTablet ? 6 : 3;

    final double baseCardHeight = mediaQuery.size.height > 700
        ? getPercentageHeight(isTablet ? 15 : 18, context)
        : getPercentageHeight(isTablet ? 20 : 25, context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final double itemWidth = constraints.maxWidth / crossAxisCount;
        final double itemHeight = baseCardHeight;
        final double childAspectRatio = itemWidth / itemHeight;

        return GridView.builder(
          padding: EdgeInsets.symmetric(
            horizontal: getPercentageWidth(2, context),
            vertical: getPercentageHeight(0.5, context),
          ),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            // Tighter, consistent spacing similar to SearchContentGrid
            mainAxisSpacing: getPercentageHeight(0.8, context),
            crossAxisSpacing: getPercentageWidth(1.5, context),
            childAspectRatio: childAspectRatio,
          ),
          itemCount: meals.length,
          itemBuilder: (context, index) {
            final mealWithType = meals[index];
            final meal = mealWithType.meal;
            final mealType = mealWithType.mealType;
            final mealMember = mealWithType.familyMember;

            // Create draggable meal card in a grid cell (drag starts on long-press)
            return LongPressDraggable<Map<String, dynamic>>(
              data: {
                'fullMealId': mealWithType.fullMealId,
                'meal': meal,
                'mealType': mealType,
                'familyMember': mealMember,
                'sourceDate': selectedDate,
              },
              feedback: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: itemWidth,
                  height: itemHeight,
                  decoration: BoxDecoration(
                    color: kAccentLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Opacity(
                    opacity: 0.8,
                    child: Column(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Container(
                            padding:
                                EdgeInsets.all(getPercentageWidth(1, context)),
                            child: AspectRatio(
                              aspectRatio: 1,
                              child: ClipOval(
                                child: meal.mediaPaths.isNotEmpty
                                    ? meal.mediaPaths.first.contains('https')
                                        ? OptimizedImage(
                                            imageUrl: meal.mediaPaths.first,
                                            fit: BoxFit.cover,
                                            borderRadius: BorderRadius.circular(
                                                getPercentageWidth(
                                                    100, context)),
                                            width: double.infinity,
                                            height: double.infinity,
                                          )
                                        : Image.asset(
                                            getAssetImageForItem(
                                                meal.mediaPaths.first),
                                            fit: BoxFit.cover,
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
                            child: Center(
                              child: Text(
                                capitalizeFirstLetter(meal.title),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w500,
                                  fontSize: getPercentageWidth(3, context),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              childWhenDragging: Opacity(
                opacity: 0.3,
                child: _buildMealCard(mealWithType, meal, mealType, mealMember,
                    meals, index, isDarkMode, textTheme),
              ),
              child: _buildMealCard(mealWithType, meal, mealType, mealMember,
                  meals, index, isDarkMode, textTheme),
            );
          },
        );
      },
    );
  }

  Widget _buildMealCard(
    MealWithType mealWithType,
    Meal meal,
    String mealType,
    String mealMember,
    List<MealWithType> meals,
    int index,
    bool isDarkMode,
    TextTheme textTheme,
  ) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          // Let the grid cell define the width; avoid extra margin so spacing
          // is controlled by the GridView's main/cross axis spacing.
          width: double.infinity,
          margin: EdgeInsets.zero,
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
                    if (!mounted) return;
                    try {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => RecipeDetailScreen(
                            mealData: meal,
                          ),
                        ),
                      );
                    } catch (e) {
                      debugPrint('Error navigating to RecipeDetailScreen: $e');
                      if (mounted && context.mounted) {
                        showTastySnackbar(
                          'Error',
                          'Unable to open recipe details. Please try again.',
                          context,
                          backgroundColor: Colors.red,
                        );
                      }
                    }
                  },
                  child: Column(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Container(
                          padding:
                              EdgeInsets.all(getPercentageWidth(1, context)),
                          child: AspectRatio(
                            aspectRatio: 1,
                            child: ClipOval(
                              child: meal.mediaPaths.isNotEmpty
                                  ? meal.mediaPaths.first.contains('https')
                                      ? OptimizedImage(
                                          imageUrl: meal.mediaPaths.first,
                                          fit: BoxFit.cover,
                                          borderRadius: BorderRadius.circular(
                                              getPercentageWidth(100, context)),
                                          width: double.infinity,
                                          height: double.infinity,
                                        )
                                      : Image.asset(
                                          getAssetImageForItem(
                                              meal.mediaPaths.first),
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (context, error, stackTrace) =>
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
                                      fontSize: getPercentageWidth(3, context)),
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
                  right: MediaQuery.of(context).size.height > 1100 ? -3 : -11,
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

                      try {
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
                      } catch (e) {
                        debugPrint('Error removing meal from plan: $e');
                        if (mounted && context.mounted) {
                          showTastySnackbar(
                            'Error',
                            'Failed to remove meal. Please try again.',
                            context,
                            backgroundColor: Colors.red,
                          );
                        }
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
              _updateMealType(mealWithType.fullMealId, meal.mealId, mealType,
                  mealMember, isDarkMode);
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
                {
                  'label': 'Breakfast (BF)',
                  'icon': Icons.emoji_food_beverage,
                  'value': 'breakfast'
                },
                {
                  'label': 'Lunch (LH)',
                  'icon': Icons.lunch_dining,
                  'value': 'lunch'
                },
                {
                  'label': 'Dinner (DN)',
                  'icon': Icons.dinner_dining,
                  'value': 'dinner'
                },
                {
                  'label': 'Snacks (SK)',
                  'icon': Icons.fastfood,
                  'value': 'snacks'
                },
              ].map((item) => ListTile(
                    leading: Icon(item['icon'] as IconData,
                        color: isDarkMode ? kWhite : kBlack),
                    title: Text(item['label'] as String,
                        style: textTheme.bodyLarge?.copyWith(
                          color: isDarkMode ? kWhite : kBlack,
                        )),
                    onTap: () =>
                        Navigator.pop(context, item['value'] as String),
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
    if (!mounted) return;

    try {
      final result = await showMealTypePicker(context, isDarkMode);
      if (result != null && mounted) {
        final formattedDate = DateFormat('yyyy-MM-dd').format(selectedDate);
        final mealToAdd = '${mealId}/${result}/${familyMember.toLowerCase()}';
        await mealManager.updateMealType(fullMealId, mealToAdd, formattedDate);
        if (mounted) {
          _mealPlanController.refresh();
        }
      }
    } catch (e) {
      debugPrint('Error updating meal type: $e');
      if (mounted && context.mounted) {
        showTastySnackbar(
          'Error',
          'Failed to update meal type. Please try again.',
          context,
          backgroundColor: Colors.red,
        );
      }
    }
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
      if (!mounted) return;

      final formattedDate = DateFormat('yyyy-MM-dd').format(selectedDate);
      final sharedCalendarId = _mealPlanController.showSharedCalendars.value
          ? _mealPlanController.selectedSharedCalendarId.value
          : null;

      try {
        await Navigator.push(
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
              sharedCalendarId: sharedCalendarId,
              familyMember: selectedCategory.toLowerCase(),
              isFamilyMode: familyMode,
              isBackToMealPlan: true,
              isNoTechnique: true,
            ),
          ),
        );
        if (mounted) {
          _mealPlanController.refresh();
        }
      } catch (e) {
        debugPrint('Error navigating to RecipeListCategory: $e');
        if (mounted && context.mounted) {
          showTastySnackbar(
            'Error',
            'Unable to open recipe selection. Please try again.',
            context,
            backgroundColor: Colors.red,
          );
        }
      }
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
                'Add your own'
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
                    onTap: () async {
                      if (!mounted) return;

                      if (type == 'Add your own') {
                        // Show custom input dialog
                        final customType = await showDialog<String>(
                          context: context,
                          builder: (BuildContext dialogContext) {
                            String customDayType = '';
                            return AlertDialog(
                              backgroundColor: isDarkMode ? kDarkGrey : kWhite,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              title: Text(
                                'Custom Day Type',
                                style: TextStyle(
                                  color: kAccent,
                                  fontSize: getTextScale(4, context),
                                ),
                              ),
                              content: SafeTextField(
                                style: TextStyle(
                                  color: isDarkMode ? kWhite : kBlack,
                                  fontSize: getTextScale(3, context),
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Enter custom day type',
                                  labelText: 'Day Type',
                                  hintStyle: TextStyle(
                                    color: isDarkMode ? kWhite : kBlack,
                                    fontSize: getTextScale(3, context),
                                  ),
                                  labelStyle: TextStyle(
                                    color: isDarkMode ? kWhite : kBlack,
                                    fontSize: getTextScale(3, context),
                                  ),
                                ),
                                onChanged: (value) {
                                  customDayType = value;
                                },
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () {
                                    Navigator.pop(dialogContext);
                                  },
                                  child: Text(
                                    'Cancel',
                                    style: TextStyle(
                                      color: isDarkMode ? kWhite : kBlack,
                                      fontSize: getTextScale(3, context),
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () {
                                    if (customDayType.isNotEmpty) {
                                      Navigator.pop(
                                          dialogContext, customDayType.trim());
                                    }
                                  },
                                  child: Text(
                                    'OK',
                                    style: TextStyle(
                                      color: kAccent,
                                      fontSize: getTextScale(3, context),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        );

                        if (customType != null && customType.isNotEmpty) {
                          setState(() {
                            selectedDayType =
                                customType.toLowerCase().replaceAll(' ', '_');
                          });
                        }
                      } else {
                        setState(() {
                          selectedDayType =
                              type.toLowerCase().replaceAll(' ', '_');
                        });
                      }
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
                      if (!mounted) return;
                      Navigator.pop(context);
                      if (mounted) {
                        _shareCalendar('single_day');
                        if (mounted) {
                          _mealPlanController.refresh();
                        }
                      }
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
    final formattedDate = _formatDate(selectedDate);
    final userId = userService.userId;

    if (userId == null || userId.isEmpty) {
      if (mounted && context.mounted) {
        showTastySnackbar(
          'Error',
          'User ID is missing. Please try again.',
          context,
          backgroundColor: Colors.red,
        );
      }
      return;
    }

    try {
      DocumentReference? sharedCalendarRef;

      if (_mealPlanController.showSharedCalendars.value) {
        final selectedCalendarId =
            _mealPlanController.selectedSharedCalendarId.value;
        if (selectedCalendarId == null || selectedCalendarId.isEmpty) {
          if (mounted && context.mounted) {
            showTastySnackbar(
              'Error',
              'No calendar selected. Please select a calendar first.',
              context,
              backgroundColor: Colors.red,
            );
          }
          return;
        }

        sharedCalendarRef = firestore
            .collection('shared_calendars')
            .doc(selectedCalendarId)
            .collection('date')
            .doc(formattedDate);
        await sharedCalendarRef.set({
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
        if (!mounted) return;

        FirebaseAnalytics.instance.logEvent(name: 'meal_plan_added');
        final sharedCalendarId = _mealPlanController.showSharedCalendars.value
            ? _mealPlanController.selectedSharedCalendarId.value
            : null;

        try {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => RecipeListCategory(
                  index: 0,
                  searchIngredient: '',
                  isMealplan: true,
                  mealPlanDate: formattedDate,
                  isSpecial: dayType != 'regular_day',
                  screen: 'ingredient',
                  isSharedCalendar:
                      _mealPlanController.showSharedCalendars.value,
                  sharedCalendarId: sharedCalendarId,
                  familyMember: selectedCategory.toLowerCase(),
                  isFamilyMode: familyMode,
                  isNoTechnique: true,
                  isBackToMealPlan: true),
            ),
          );
          if (mounted) {
            // Refresh meal plans after adding new meals
            _mealPlanController.refresh();
          }
        } catch (e) {
          debugPrint('Error navigating to RecipeListCategory: $e');
          if (mounted && context.mounted) {
            showTastySnackbar(
              'Error',
              'Unable to open recipe selection. Please try again.',
              context,
              backgroundColor: Colors.red,
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Error in _addMealPlan: $e');
      if (mounted && context.mounted) {
        showTastySnackbar(
          'Error',
          'Failed to add meal plan. Please try again.',
          context,
          backgroundColor: Colors.red,
        );
      }
    }
  }

  Widget _buildEmptyState(DateTime date, String birthdayName, bool isDarkMode,
      {DateTime? normalizedSelectedDate, bool? isSpecialDay}) {
    final textTheme = Theme.of(context).textTheme;
    final currentDayType = _mealPlanController.dayTypes[date] ?? 'regular_day';
    final cycleSuggestion = _getCycleSuggestionForDate(date);
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
                    if (cycleSuggestion != null) ...[
                      // Cycle Syncing messaging for luteal phase
                      Align(
                        alignment: Alignment.centerLeft,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: getPercentageWidth(80, context),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Cycle Goals',
                                style: textTheme.bodySmall?.copyWith(
                                  color: isDarkMode ? kLightGrey : kDarkGrey,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              SizedBox(
                                  height: getPercentageHeight(0.5, context)),
                              Text(
                                cycleSuggestion['description'] ?? '',
                                style: textTheme.bodySmall?.copyWith(
                                  color: isDarkMode ? kLightGrey : kDarkGrey,
                                ),
                              ),
                              SizedBox(
                                  height: getPercentageHeight(0.3, context)),
                              Text(
                                cycleSuggestion['appAction'] ?? '',
                                style: textTheme.bodySmall?.copyWith(
                                  color: isDarkMode ? kLightGrey : kDarkGrey,
                                ),
                              ),
                              SizedBox(
                                  height: getPercentageHeight(0.8, context)),
                              Text(
                                getRelativeDayString(selectedDate) == 'Today' ||
                                        getRelativeDayString(selectedDate) ==
                                            'Tomorrow'
                                    ? 'No meals planned for ${getRelativeDayString(selectedDate)}'
                                    : 'No meals planned for this day',
                                style: textTheme.bodyMedium?.copyWith(
                                  color: isDarkMode ? kLightGrey : kDarkGrey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ] else ...[
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
                              if (!mounted) return;
                              try {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const ShoppingTab(),
                                  ),
                                );
                              } catch (e) {
                                debugPrint(
                                    'Error navigating to ShoppingTab: $e');
                                if (mounted && context.mounted) {
                                  showTastySnackbar(
                                    'Error',
                                    'Unable to open shopping list. Please try again.',
                                    context,
                                    backgroundColor: Colors.red,
                                  );
                                }
                              }
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

  // Cycle tracking helpers
  Map<String, dynamic>? _getCycleData() {
    final user = userService.currentUser.value;
    if (user == null) return null;

    final cycleDataRaw = user.settings['cycleTracking'];
    if (cycleDataRaw == null) return null;

    // Handle both Map and String types safely
    if (cycleDataRaw is Map) {
      return Map<String, dynamic>.from(cycleDataRaw);
    }

    return null; // If it's not a Map, we can't process it
  }

  bool _shouldShowCycleIndicator(DateTime date) {
    final cycleData = _getCycleData();
    if (cycleData == null) return false;

    final isEnabled = cycleData['isEnabled'] as bool? ?? false;
    if (!isEnabled) return false;

    final lastPeriodStartStr = cycleData['lastPeriodStart'] as String?;
    if (lastPeriodStartStr == null) return false;

    final lastPeriodStart = DateTime.tryParse(lastPeriodStartStr);
    if (lastPeriodStart == null) return false;

    // Only show indicator for current month dates
    final now = DateTime.now();
    if (date.month != now.month || date.year != now.year) return false;

    return true;
  }

  Color _getCyclePhaseColor(DateTime date) {
    final cycleData = _getCycleData();
    if (cycleData == null) return Colors.transparent;

    final lastPeriodStartStr = cycleData['lastPeriodStart'] as String?;
    if (lastPeriodStartStr == null) return Colors.transparent;

    final lastPeriodStart = DateTime.tryParse(lastPeriodStartStr);
    if (lastPeriodStart == null) return Colors.transparent;

    final cycleLength = (cycleData['cycleLength'] as num?)?.toInt() ?? 28;
    // Pass the specific date to calculate phase for that date, not today
    final phase = cycleAdjustmentService.getCurrentPhase(
        lastPeriodStart, cycleLength, date);

    return cycleAdjustmentService.getPhaseColor(phase);
  }

  String _getCyclePhaseEmoji(DateTime date) {
    final cycleData = _getCycleData();
    if (cycleData == null) return '';

    final lastPeriodStartStr = cycleData['lastPeriodStart'] as String?;
    if (lastPeriodStartStr == null) return '';

    final lastPeriodStart = DateTime.tryParse(lastPeriodStartStr);
    if (lastPeriodStart == null) return '';

    final cycleLength = (cycleData['cycleLength'] as num?)?.toInt() ?? 28;
    // Pass the specific date to calculate phase for that date, not today
    final phase = cycleAdjustmentService.getCurrentPhase(
        lastPeriodStart, cycleLength, date);

    return cycleAdjustmentService.getPhaseEmoji(phase);
  }

  /// Returns a suggestion for the given date if cycle syncing is enabled,
  /// the user is not male, and the phase is luteal. Otherwise returns null.
  Map<String, String>? _getCycleSuggestionForDate(DateTime date) {
    final user = userService.currentUser.value;
    if (user == null) return null;

    final genderRaw = user.settings['gender'] as String?;
    final gender = genderRaw?.toLowerCase() ?? '';
    if (gender == 'male') return null;

    final cycleData = _getCycleData();
    if (cycleData == null) return null;

    final isEnabled = cycleData['isEnabled'] as bool? ?? false;
    if (!isEnabled) return null;

    final lastPeriodStartStr = cycleData['lastPeriodStart'] as String?;
    if (lastPeriodStartStr == null) return null;

    final lastPeriodStart = DateTime.tryParse(lastPeriodStartStr);
    if (lastPeriodStart == null) return null;

    final cycleLength = (cycleData['cycleLength'] as num?)?.toInt() ?? 28;
    final phase = cycleAdjustmentService.getCurrentPhase(
        lastPeriodStart, cycleLength, date);

    // Handle both enum-like and string-like phases by inspecting the text.
    final phaseText = phase.toString().toLowerCase();
    if (!phaseText.contains('luteal')) return null;

    return {
      'title': 'Luteal Phase – Support Recovery & Energy',
      'description':
          'You\'re in the luteal phase of your cycle, when energy can dip and recovery matters a bit more.',
      'appAction':
          'Today we need to focus on steadier energy by nudging complex carbs slightly higher and keeping protein consistent to support recovery.'
    };
  }
}

