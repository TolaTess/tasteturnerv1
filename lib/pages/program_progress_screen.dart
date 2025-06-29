import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../constants.dart';
import '../helper/utils.dart';

class ProgramProgressScreen extends StatefulWidget {
  final String programName;
  final String description;

  const ProgramProgressScreen({
    super.key,
    this.programName = "Mindful Living Program",
    this.description = "Just 50 minutes a day to change your life.",
  });

  @override
  State<ProgramProgressScreen> createState() => _ProgramProgressScreenState();
}

class _ProgramProgressScreenState extends State<ProgramProgressScreen> {
  // Track completion status for each component
  Map<String, bool> completionStatus = {
    'guided_meditation': false,
    'breathing_exercise': false,
    'healthy_recipes': false,
    'yoga_classes': false,
  };

  // Mock previous day progress data (in percentage)
  final List<Map<String, dynamic>> previousDaysProgress = [
    {'day': 'Mon', 'progress': 75},
    {'day': 'Tue', 'progress': 50},
    {'day': 'Wed', 'progress': 100},
    {'day': 'Thu', 'progress': 25},
    {'day': 'Fri', 'progress': 80},
    {'day': 'Sat', 'progress': 60},
  ];

  // Program components data
  final List<Map<String, dynamic>> programComponents = [
    {
      'id': 'guided_meditation',
      'title': 'Guided Meditation',
      'subtitle': '15 minutes',
      'description': 'Daily mindfulness practice',
      'image': 'assets/images/placeholder.jpg',
      'color': Color(0xFFE8D5B7),
      'level': 'Beginner',
    },
    {
      'id': 'breathing_exercise',
      'title': 'Breathing Exercise',
      'subtitle': '10 minutes',
      'description': 'Stress relief techniques',
      'image': 'assets/images/placeholder.jpg',
      'color': Color(0xFFF5E6D3),
      'level': 'Intermediate',
    },
    {
      'id': 'healthy_recipes',
      'title': 'Healthy Recipes',
      'subtitle': '3 recipes',
      'description': 'Nutritious meal ideas',
      'image': 'assets/images/placeholder.jpg',
      'color': Color(0xFFE8D5B7),
      'recipes': ['Green Smoothie', 'Quinoa Bowl', 'Avocado Toast'],
    },
    {
      'id': 'yoga_classes',
      'title': 'Yoga Classes',
      'subtitle': '25 minutes',
      'description': 'Full body wellness',
      'image': 'assets/images/placeholder.jpg',
      'color': Color(0xFFF5E6D3),
      'level': 'Beginner',
      'type': 'Intermediate',
    },
  ];

  void _completeComponent(String componentId) {
    setState(() {
      completionStatus[componentId] = !completionStatus[componentId]!;
    });

    // Show success message
    showTastySnackbar(
      'Progress Updated!',
      completionStatus[componentId]!
          ? 'Component completed successfully!'
          : 'Component marked as incomplete',
      context,
      backgroundColor: completionStatus[componentId]! ? Colors.green : kAccent,
    );
  }

  Widget _buildSectionHeader({required String title}) {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: getPercentageWidth(4, context),
        vertical: getPercentageHeight(1, context),
      ),
      child: Center(
        child: Text(
          title,
          style: textTheme.titleLarge?.copyWith(
            fontSize: getTextScale(5, context),
            fontWeight: FontWeight.w600,
            color: isDarkMode ? kWhite : kDarkGrey,
          ),
        ),
      ),
    );
  }

  Widget _buildComponentCard(Map<String, dynamic> component, double height) {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    final textTheme = Theme.of(context).textTheme;
    final isCompleted = completionStatus[component['id']] ?? false;

    return GestureDetector(
      onTap: () => _completeComponent(component['id']),
      child: Container(
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isCompleted ? kAccent : Colors.transparent,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              // Background Image
              Positioned.fill(
                child: Image.asset(
                  component['image'],
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: isDarkMode ? kDarkGrey : component['color'],
                    child: Icon(
                      _getComponentIcon(component['id']),
                      size: getIconScale(15, context),
                      color: isDarkMode
                          ? kWhite.withOpacity(0.3)
                          : kDarkGrey.withOpacity(0.3),
                    ),
                  ),
                ),
              ),
              // Gradient Overlay
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        isCompleted
                            ? kAccent.withOpacity(0.7)
                            : Colors.black.withOpacity(0.7),
                      ],
                    ),
                  ),
                ),
              ),
              // Content
              Positioned(
                left: getPercentageWidth(4, context),
                right: getPercentageWidth(4, context),
                bottom: getPercentageHeight(2, context),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            component['title'],
                            style: textTheme.titleMedium?.copyWith(
                              fontSize: getTextScale(4.5, context),
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        if (isCompleted)
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: kAccent,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.check,
                              color: Colors.white,
                              size: getIconScale(4, context),
                            ),
                          ),
                      ],
                    ),
                    if (component['subtitle'] != null)
                      Text(
                        component['subtitle'],
                        style: textTheme.bodyMedium?.copyWith(
                          fontSize: getTextScale(3, context),
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    SizedBox(height: getPercentageHeight(0.5, context)),
                    Row(
                      children: [
                        if (component['level'] != null)
                          Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 2),
                            decoration: BoxDecoration(
                              color: kAccent.withOpacity(0.8),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              component['level'],
                              style: textTheme.bodySmall?.copyWith(
                                fontSize: getTextScale(2.5, context),
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        if (component['type'] != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.8),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              component['type'],
                              style: textTheme.bodySmall?.copyWith(
                                fontSize: getTextScale(2.5, context),
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecipeCard(Map<String, dynamic> component, double height) {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    final textTheme = Theme.of(context).textTheme;
    final isCompleted = completionStatus[component['id']] ?? false;
    final recipes = component['recipes'] as List<String>;

    return GestureDetector(
      onTap: () => _completeComponent(component['id']),
      child: Container(
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isCompleted ? kAccent : Colors.transparent,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              // Background Image
              Positioned.fill(
                child: Image.asset(
                  component['image'],
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: isDarkMode ? kDarkGrey : component['color'],
                    child: Icon(
                      Icons.restaurant_menu,
                      size: getIconScale(15, context),
                      color: isDarkMode
                          ? kWhite.withOpacity(0.3)
                          : kDarkGrey.withOpacity(0.3),
                    ),
                  ),
                ),
              ),
              // Gradient Overlay
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        isCompleted
                            ? kAccent.withOpacity(0.7)
                            : Colors.black.withOpacity(0.7),
                      ],
                    ),
                  ),
                ),
              ),
              // Content
              Positioned(
                left: getPercentageWidth(4, context),
                right: getPercentageWidth(4, context),
                bottom: getPercentageHeight(2, context),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            component['title'],
                            style: textTheme.titleMedium?.copyWith(
                              fontSize: getTextScale(4.5, context),
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        if (isCompleted)
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: kAccent,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.check,
                              color: Colors.white,
                              size: getIconScale(4, context),
                            ),
                          ),
                      ],
                    ),
                    if (component['subtitle'] != null)
                      Text(
                        component['subtitle'],
                        style: textTheme.bodyMedium?.copyWith(
                          fontSize: getTextScale(3, context),
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    SizedBox(height: getPercentageHeight(1, context)),
                    // Recipe thumbnails
                    Row(
                      children: recipes
                          .take(2)
                          .map((recipe) => Container(
                                width: getPercentageWidth(12, context),
                                height: getPercentageWidth(12, context),
                                margin: const EdgeInsets.only(right: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.9),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.restaurant,
                                  color: kDarkGrey,
                                  size: getIconScale(4, context),
                                ),
                              ))
                          .toList(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getComponentIcon(String componentId) {
    switch (componentId) {
      case 'guided_meditation':
        return Icons.self_improvement;
      case 'breathing_exercise':
        return Icons.air;
      case 'healthy_recipes':
        return Icons.restaurant_menu;
      case 'yoga_classes':
        return Icons.accessibility_new;
      default:
        return Icons.circle;
    }
  }

  Widget _buildProgressSummary() {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    final textTheme = Theme.of(context).textTheme;
    final completedCount =
        completionStatus.values.where((completed) => completed).length;
    final totalCount = completionStatus.length;
    final todayProgressPercentage = (completedCount / totalCount * 100).round();

    return Container(
      margin: EdgeInsets.all(getPercentageWidth(4, context)),
      padding: EdgeInsets.all(getPercentageWidth(4, context)),
      decoration: BoxDecoration(
        color: isDarkMode ? kDarkGrey : kWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: kAccent.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDarkMode
                ? kWhite.withOpacity(0.4)
                : kDarkGrey.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Weekly Progress',
            style: textTheme.titleLarge?.copyWith(
              fontSize: getTextScale(5, context),
              fontWeight: FontWeight.w600,
              color: kAccent,
            ),
          ),
          // Bar Chart or Today's Progress
          if (previousDaysProgress.isNotEmpty)
            _buildBarChart()
          else
            _buildTodayProgress(completedCount, totalCount,
                todayProgressPercentage, isDarkMode, textTheme),
        ],
      ),
    );
  }

  Widget _buildBarChart() {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    final completedCount =
        completionStatus.values.where((completed) => completed).length;
    final totalCount = completionStatus.length;
    final todayProgressPercentage = (completedCount / totalCount * 100).round();

    // Add today's progress to the chart data
    final chartData = [
      ...previousDaysProgress,
      {'day': 'Today', 'progress': todayProgressPercentage}
    ];

    return SizedBox(
      height: getPercentageHeight(20, context),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: chartData.map((data) {
          final progress = data['progress'] as int;
          final isToday = data['day'] == 'Today';

          return Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  '$progress%',
                  style: TextStyle(
                    fontSize: getTextScale(2.5, context),
                    color: isDarkMode
                        ? kWhite.withOpacity(0.7)
                        : kDarkGrey.withOpacity(0.7),
                    fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                SizedBox(height: getPercentageHeight(0.5, context)),
                Container(
                  width: getPercentageWidth(8, context),
                  height: (progress / 100) * getPercentageHeight(12, context),
                  decoration: BoxDecoration(
                    color: isToday
                        ? kAccent
                        : (isDarkMode ? kLightGrey : Colors.grey[400]),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                SizedBox(height: getPercentageHeight(0.5, context)),
                Text(
                  data['day'],
                  style: TextStyle(
                    fontSize: getTextScale(2.5, context),
                    color: isDarkMode ? kWhite : kDarkGrey,
                    fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTodayProgress(int completedCount, int totalCount,
      int progressPercentage, bool isDarkMode, TextTheme textTheme) {
    return Row(
      children: [
        CircularProgressIndicator(
          value: completedCount / totalCount,
          backgroundColor: isDarkMode ? kLightGrey : Colors.grey[300],
          valueColor: const AlwaysStoppedAnimation<Color>(kAccent),
          strokeWidth: 4,
        ),
        SizedBox(width: getPercentageWidth(4, context)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Today\'s Progress',
                style: textTheme.titleMedium?.copyWith(
                  fontSize: getTextScale(4, context),
                  fontWeight: FontWeight.w600,
                  color: isDarkMode ? kWhite : kDarkGrey,
                ),
              ),
              Text(
                '$completedCount of $totalCount completed ($progressPercentage%)',
                style: textTheme.bodyMedium?.copyWith(
                  fontSize: getTextScale(3, context),
                  color: isDarkMode
                      ? kWhite.withOpacity(0.7)
                      : kDarkGrey.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: isDarkMode ? kBlack : kWhite,
      appBar: AppBar(
        backgroundColor: kAccent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Your Program Progress',
          style: textTheme.displaySmall?.copyWith(
            fontSize: getTextScale(7, context),
            fontWeight: FontWeight.w200,
          ),
        ),
        automaticallyImplyLeading: true,
        toolbarHeight: getPercentageHeight(10, context),
        iconTheme: IconThemeData(
          color: isDarkMode ? kWhite : kBlack,
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section Header
            SizedBox(height: getPercentageHeight(1, context)),

            // Progress Summary
            _buildProgressSummary(),

            // Section Header
            _buildSectionHeader(title: 'Program Details'),

            SizedBox(height: getPercentageHeight(1, context)),

            // Program Components - Staggered Grid
            Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: getPercentageWidth(4, context)),
              child: StaggeredGrid.count(
                crossAxisCount: 2,
                mainAxisSpacing: getPercentageHeight(1, context),
                crossAxisSpacing: getPercentageWidth(3, context),
                children: programComponents.asMap().entries.map((entry) {
                  final index = entry.key;
                  final component = entry.value;

                  // Vary the heights for Pinterest-like effect
                  double cardHeight;
                  if (component['id'] == 'healthy_recipes') {
                    cardHeight = getCardHeight(index, true, context);
                  } else if (index % 3 == 0) {
                    cardHeight = getCardHeight(index, false, context);
                  } else if (index % 2 == 0) {
                    cardHeight = getCardHeight(index, false, context);
                  } else {
                    cardHeight = getCardHeight(index, false, context);
                  }

                  return StaggeredGridTile.fit(
                    crossAxisCellCount: 1,
                    child: component['id'] == 'healthy_recipes'
                        ? _buildRecipeCard(component, cardHeight)
                        : _buildComponentCard(component, cardHeight),
                  );
                }).toList(),
              ),
            ),

            SizedBox(height: getPercentageHeight(3, context)),
          ],
        ),
      ),
    );
  }
}

double getCardHeight(int index, bool isMeal, BuildContext context) {
  Random random = Random();
  double minHeight = 12;
  double maxHeight = 20;
  double range = maxHeight - minHeight;

  if (isMeal) {
    return getPercentageHeight(
        minHeight + 5 + (random.nextDouble() * range), context);
  } else {
    return getPercentageHeight(
        minHeight + (random.nextDouble() * range), context);
  }
}
