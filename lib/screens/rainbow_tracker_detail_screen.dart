import 'package:flutter/material.dart';
import '../constants.dart';
import '../helper/utils.dart';
import '../service/plant_detection_service.dart';
import '../service/symptom_analysis_service.dart';

class RainbowTrackerDetailScreen extends StatefulWidget {
  final DateTime weekStart;

  const RainbowTrackerDetailScreen({
    super.key,
    required this.weekStart,
  });

  @override
  State<RainbowTrackerDetailScreen> createState() =>
      _RainbowTrackerDetailScreenState();
}

class _RainbowTrackerDetailScreenState
    extends State<RainbowTrackerDetailScreen> {
  final plantDetectionService = PlantDetectionService.instance;
  final symptomAnalysisService = SymptomAnalysisService.instance;
  PlantDiversityScore? _diversityScore;
  List<PlantIngredient> _plants = [];
  bool _isLoading = true;
  PlantCategory? _selectedCategory; // Track selected category filter
  List<String> _triggerIngredients =
      []; // List of trigger ingredient names (lowercase)
  List<Map<String, dynamic>> _previousWeeksSummary = []; // Previous weeks data

  @override
  void initState() {
    super.initState();
    // Defer data loading to after first frame to avoid blocking navigation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadPlantData();
      }
    });
  }

  Future<void> _loadPlantData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final userId = userService.userId ?? '';
      if (userId.isEmpty) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Load plant data, trigger ingredients, and previous weeks summary in parallel
      final score = await plantDetectionService.getPlantDiversityScore(
        userId,
        widget.weekStart,
      );
      final plants = await plantDetectionService.getUniquePlantsForWeek(
        userId,
        widget.weekStart,
      );
      final previousWeeks = await plantDetectionService.getPreviousWeeksSummary(
        userId,
        widget.weekStart,
        numberOfWeeks: 4,
      );

      // Load trigger ingredients from symptom analysis
      List<String> triggerIngredients = [];
      try {
        final topTriggers = await symptomAnalysisService.getTopTriggers(
          userId,
          limit: 20,
          days: 30,
        );
        triggerIngredients = topTriggers
            .map((trigger) =>
                (trigger['ingredient'] as String? ?? '').toLowerCase())
            .where((ingredient) => ingredient.isNotEmpty)
            .toList();
      } catch (e) {
        debugPrint('Error loading trigger ingredients: $e');
        // Continue without triggers if there's an error
      }

      if (mounted) {
        setState(() {
          _diversityScore = score;
          _plants = plants;
          _triggerIngredients = triggerIngredients;
          _previousWeeksSummary = previousWeeks;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading plant data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _getLevelName(int level) {
    switch (level) {
      case 1:
        return 'Beginner';
      case 2:
        return 'Healthy';
      case 3:
        return 'Gut Hero';
      default:
        return 'Getting Started';
    }
  }

  Color _getLevelColor(int level) {
    switch (level) {
      case 1:
        return kGreen;
      case 2:
        return kPurple;
      case 3:
        return kAccent;
      default:
        return kLightGrey;
    }
  }

  String _getCategoryName(PlantCategory category) {
    switch (category) {
      case PlantCategory.vegetable:
        return 'Vegetables';
      case PlantCategory.fruit:
        return 'Fruits';
      case PlantCategory.grain:
        return 'Grains';
      case PlantCategory.legume:
        return 'Legumes';
      case PlantCategory.nutSeed:
        return 'Nuts & Seeds';
      case PlantCategory.herbSpice:
        return 'Herbs & Spices';
    }
  }

  /// Get filtered plants based on selected category
  List<PlantIngredient> _getFilteredPlants() {
    if (_selectedCategory == null) {
      return _plants;
    }
    return _plants
        .where((plant) => plant.category == _selectedCategory)
        .toList();
  }

  IconData _getCategoryIcon(PlantCategory category) {
    switch (category) {
      case PlantCategory.vegetable:
        return Icons.eco;
      case PlantCategory.fruit:
        return Icons.apple;
      case PlantCategory.grain:
        return Icons.grass;
      case PlantCategory.legume:
        return Icons.circle;
      case PlantCategory.nutSeed:
        return Icons.radio_button_unchecked;
      case PlantCategory.herbSpice:
        return Icons.local_florist;
    }
  }

  /// Check if a plant ingredient is a trigger
  /// Uses normalized names to match "fresh parsley" with "parsley"
  bool _isTriggerIngredient(PlantIngredient plant) {
    // Normalize both plant name and trigger ingredients for robust matching
    final normalizedPlantName =
        plantDetectionService.normalizeIngredientName(plant.name);
    return _triggerIngredients.any((trigger) {
      final normalizedTrigger =
          plantDetectionService.normalizeIngredientName(trigger);
      return normalizedPlantName == normalizedTrigger ||
          normalizedPlantName.contains(normalizedTrigger) ||
          normalizedTrigger.contains(normalizedPlantName);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: isDarkMode ? kDarkGrey : kWhite,
      appBar: AppBar(
        backgroundColor: isDarkMode ? kDarkGrey : kWhite,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: isDarkMode ? kWhite : kBlack),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Rainbow Tracker',
          style: textTheme.displaySmall?.copyWith(
            color: isDarkMode ? kWhite : kBlack,
            fontWeight: FontWeight.w400,
            fontSize: getTextScale(7, context),
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: kAccent),
            )
          : _diversityScore == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.eco_outlined,
                        size: getIconScale(15, context),
                        color: kLightGrey,
                      ),
                      SizedBox(height: getPercentageHeight(2, context)),
                      Text(
                        'No plant data available',
                        style: textTheme.titleMedium?.copyWith(
                          color: kLightGrey,
                        ),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: EdgeInsets.all(getPercentageWidth(4, context)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Summary Card
                      Container(
                        alignment: Alignment.center,
                        padding: EdgeInsets.all(getPercentageWidth(4, context)),
                        decoration: BoxDecoration(
                          color: isDarkMode ? kDarkGrey : kWhite,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: kAccent.withValues(alpha: 0.3),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: isDarkMode
                                  ? kWhite.withValues(alpha: 0.1)
                                  : kDarkGrey.withValues(alpha: 0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            // Large Count
                            Container(
                              width: getPercentageWidth(30, context),
                              height: getPercentageWidth(30, context),
                              decoration: BoxDecoration(
                                color: _getLevelColor(_diversityScore!.level > 0
                                        ? _diversityScore!.level
                                        : 1)
                                    .withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: _getLevelColor(
                                      _diversityScore!.level > 0
                                          ? _diversityScore!.level
                                          : 1),
                                  width: 3,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  '${_diversityScore!.uniquePlants}',
                                  style: textTheme.headlineLarge?.copyWith(
                                    fontSize: getTextScale(15, context),
                                    fontWeight: FontWeight.bold,
                                    color: _getLevelColor(
                                        _diversityScore!.level > 0
                                            ? _diversityScore!.level
                                            : 1),
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(height: getPercentageHeight(2, context)),
                            Text(
                              'Unique Plants This Week',
                              style: textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: isDarkMode ? kWhite : kBlack,
                              ),
                            ),
                            SizedBox(height: getPercentageHeight(1, context)),
                            if (_diversityScore!.level > 0)
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: getPercentageWidth(3, context),
                                  vertical: getPercentageHeight(1, context),
                                ),
                                decoration: BoxDecoration(
                                  color: _getLevelColor(_diversityScore!.level)
                                      .withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  _getLevelName(_diversityScore!.level),
                                  style: textTheme.titleMedium?.copyWith(
                                    color:
                                        _getLevelColor(_diversityScore!.level),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            SizedBox(height: getPercentageHeight(2, context)),
                            // Progress Bar
                            if (_diversityScore!.level < 3) ...[
                              Text(
                                'Progress to ${_getLevelName(_diversityScore!.level + 1)}',
                                style: textTheme.bodyMedium?.copyWith(
                                  color: isDarkMode ? kLightGrey : kDarkGrey,
                                ),
                              ),
                              SizedBox(height: getPercentageHeight(1, context)),
                              LinearProgressIndicator(
                                value: _diversityScore!.progress,
                                backgroundColor:
                                    kLightGrey.withValues(alpha: 0.3),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  _getLevelColor(_diversityScore!.level + 1),
                                ),
                                minHeight: 8,
                              ),
                              SizedBox(
                                  height: getPercentageHeight(0.5, context)),
                              Text(
                                '${((_diversityScore!.progress * 100).toInt())}%',
                                style: textTheme.bodySmall?.copyWith(
                                  color: isDarkMode ? kLightGrey : kDarkGrey,
                                ),
                              ),
                            ] else
                              Text(
                                '🎉 You\'ve reached Gut Hero level!',
                                style: textTheme.bodyLarge?.copyWith(
                                  color: kAccent,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                          ],
                        ),
                      ),

                      SizedBox(height: getPercentageHeight(3, context)),

                      // Previous Weeks Summary
                      if (_previousWeeksSummary.isNotEmpty) ...[
                        Text(
                          'Previous Weeks',
                          style: textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: isDarkMode ? kWhite : kBlack,
                          ),
                        ),
                        SizedBox(height: getPercentageHeight(2, context)),
                        Container(
                          padding:
                              EdgeInsets.all(getPercentageWidth(3, context)),
                          decoration: BoxDecoration(
                            color: isDarkMode
                                ? kDarkGrey.withValues(alpha: 0.5)
                                : kBackgroundColor.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: kAccent.withValues(alpha: 0.2),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            children: _previousWeeksSummary.map((weekData) {
                              final weekStart =
                                  weekData['weekStart'] as DateTime;
                              final plantCount = weekData['plantCount'] as int;
                              final level = weekData['level'] as int;

                              // Format week range (Monday to Sunday)
                              final weekEnd =
                                  weekStart.add(const Duration(days: 6));
                              final weekRange =
                                  '${weekStart.day}/${weekStart.month} - ${weekEnd.day}/${weekEnd.month}/${weekStart.year}';

                              return Container(
                                margin: EdgeInsets.only(
                                  bottom: getPercentageHeight(1, context),
                                ),
                                padding: EdgeInsets.all(
                                  getPercentageWidth(3, context),
                                ),
                                decoration: BoxDecoration(
                                  color: isDarkMode ? kDarkGrey : kWhite,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            weekRange,
                                            style:
                                                textTheme.bodyMedium?.copyWith(
                                              fontWeight: FontWeight.w600,
                                              color:
                                                  isDarkMode ? kWhite : kBlack,
                                            ),
                                          ),
                                          SizedBox(
                                            height: getPercentageHeight(
                                                0.5, context),
                                          ),
                                          Text(
                                            '$plantCount unique plants',
                                            style:
                                                textTheme.bodySmall?.copyWith(
                                              color: kAccent,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (level > 0)
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal:
                                              getPercentageWidth(2.5, context),
                                          vertical:
                                              getPercentageHeight(0.8, context),
                                        ),
                                        decoration: BoxDecoration(
                                          color: _getLevelColor(level)
                                              .withValues(alpha: 0.2),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          _getLevelName(level),
                                          style: textTheme.bodySmall?.copyWith(
                                            color: _getLevelColor(level),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        SizedBox(height: getPercentageHeight(3, context)),
                      ],

                      // Category Breakdown
                      if (_diversityScore!.categoryBreakdown.isNotEmpty) ...[
                        Text(
                          'Category Breakdown',
                          style: textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: isDarkMode ? kWhite : kBlack,
                          ),
                        ),
                        SizedBox(height: getPercentageHeight(2, context)),
                        Wrap(
                          spacing: getPercentageWidth(2, context),
                          runSpacing: getPercentageHeight(1.5, context),
                          children: _diversityScore!.categoryBreakdown.entries
                              .map((entry) {
                            final isSelected = _selectedCategory == entry.key;
                            return InkWell(
                              onTap: () {
                                setState(() {
                                  // Toggle: if already selected, clear filter; otherwise set filter
                                  _selectedCategory =
                                      isSelected ? null : entry.key;
                                });
                              },
                              child: Container(
                                padding: EdgeInsets.all(
                                    getPercentageWidth(3, context)),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? kAccent.withValues(alpha: 0.2)
                                      : kAccent.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected
                                        ? kAccent
                                        : kAccent.withValues(alpha: 0.3),
                                    width: isSelected ? 2 : 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _getCategoryIcon(entry.key),
                                      color: kAccent,
                                      size: getIconScale(4, context),
                                    ),
                                    SizedBox(
                                        width: getPercentageWidth(2, context)),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _getCategoryName(entry.key),
                                          style: textTheme.bodyMedium?.copyWith(
                                            fontWeight: FontWeight.w600,
                                            color: isDarkMode ? kWhite : kBlack,
                                          ),
                                        ),
                                        Text(
                                          '${entry.value} plants',
                                          style: textTheme.bodySmall?.copyWith(
                                            color: kAccent,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        SizedBox(height: getPercentageHeight(3, context)),
                      ],

                      // All Plants List
                      Text(
                        _selectedCategory == null
                            ? 'All Plants (${_plants.length})'
                            : '${_getCategoryName(_selectedCategory!)} (${_getFilteredPlants().length})',
                        style: textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isDarkMode ? kWhite : kBlack,
                        ),
                      ),
                      if (_selectedCategory != null) ...[
                        SizedBox(height: getPercentageHeight(1, context)),
                        InkWell(
                          onTap: () {
                            setState(() {
                              _selectedCategory = null;
                            });
                          },
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: getPercentageWidth(3, context),
                              vertical: getPercentageHeight(1, context),
                            ),
                            decoration: BoxDecoration(
                              color: kAccent.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: kAccent.withValues(alpha: 0.3),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.clear,
                                  size: getIconScale(3.5, context),
                                  color: kAccent,
                                ),
                                SizedBox(width: getPercentageWidth(1, context)),
                                Text(
                                  'Clear Filter',
                                  style: textTheme.bodySmall?.copyWith(
                                    color: kAccent,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      SizedBox(height: getPercentageHeight(2, context)),
                      if (_getFilteredPlants().isEmpty)
                        Container(
                          padding:
                              EdgeInsets.all(getPercentageWidth(4, context)),
                          decoration: BoxDecoration(
                            color: isDarkMode
                                ? kDarkGrey.withValues(alpha: 0.5)
                                : kLightGrey.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(
                              _selectedCategory == null
                                  ? 'No plants tracked yet this week.\nLog meals with vegetables, fruits, and other plants to start tracking!'
                                  : 'No ${_getCategoryName(_selectedCategory!).toLowerCase()} tracked this week.',
                              textAlign: TextAlign.center,
                              style: textTheme.bodyMedium?.copyWith(
                                color: isDarkMode ? kLightGrey : kDarkGrey,
                              ),
                            ),
                          ),
                        )
                      else
                        ..._getFilteredPlants().map((plant) {
                          final isTrigger = _isTriggerIngredient(plant);
                          return Container(
                            margin: EdgeInsets.only(
                                bottom: getPercentageHeight(1, context)),
                            padding:
                                EdgeInsets.all(getPercentageWidth(3, context)),
                            decoration: BoxDecoration(
                              color: isTrigger
                                  ? (isDarkMode
                                      ? Colors.orange.withValues(alpha: 0.2)
                                      : Colors.orange.withValues(alpha: 0.1))
                                  : (isDarkMode
                                      ? kDarkGrey.withValues(alpha: 0.5)
                                      : kBackgroundColor.withValues(
                                          alpha: 0.1)),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isTrigger
                                    ? Colors.orange.withValues(alpha: 0.6)
                                    : kAccent.withValues(alpha: 0.2),
                                width: isTrigger ? 2 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(
                                      getPercentageWidth(2, context)),
                                  decoration: BoxDecoration(
                                    color: isTrigger
                                        ? Colors.orange.withValues(alpha: 0.2)
                                        : kAccent.withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    _getCategoryIcon(plant.category),
                                    color: isTrigger ? Colors.orange : kAccent,
                                    size: getIconScale(4, context),
                                  ),
                                ),
                                SizedBox(width: getPercentageWidth(3, context)),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              capitalizeFirstLetter(plant.name),
                                              style:
                                                  textTheme.bodyLarge?.copyWith(
                                                fontWeight: FontWeight.w600,
                                                color: isDarkMode
                                                    ? kWhite
                                                    : kBlack,
                                              ),
                                            ),
                                          ),
                                          if (isTrigger)
                                            Padding(
                                              padding: EdgeInsets.only(
                                                  left: getPercentageWidth(
                                                      2, context)),
                                              child: Icon(
                                                Icons.warning_amber_rounded,
                                                color: Colors.orange,
                                                size: getIconScale(4, context),
                                              ),
                                            ),
                                        ],
                                      ),
                                      SizedBox(
                                          height: getPercentageHeight(
                                              0.3, context)),
                                      Row(
                                        children: [
                                          Text(
                                            _getCategoryName(plant.category),
                                            style:
                                                textTheme.bodySmall?.copyWith(
                                              color: isTrigger
                                                  ? Colors.orange
                                                  : kAccent,
                                            ),
                                          ),
                                          if (isTrigger) ...[
                                            SizedBox(
                                                width: getPercentageWidth(
                                                    2, context)),
                                            Text(
                                              '• Trigger',
                                              style:
                                                  textTheme.bodySmall?.copyWith(
                                                color: Colors.orange,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                    ],
                  ),
                ),
    );
  }
}
