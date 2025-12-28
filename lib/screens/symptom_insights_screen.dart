import 'package:flutter/material.dart';
import '../constants.dart';
import '../helper/utils.dart';
import '../service/symptom_analysis_service.dart';
import 'daily_summary_screen.dart';
import 'rainbow_tracker_detail_screen.dart';

class SymptomInsightsScreen extends StatefulWidget {
  const SymptomInsightsScreen({super.key});

  @override
  State<SymptomInsightsScreen> createState() => _SymptomInsightsScreenState();
}

class _SymptomInsightsScreenState extends State<SymptomInsightsScreen> {
  final SymptomAnalysisService _analysisService =
      SymptomAnalysisService.instance;
  bool _isLoading = true;
  Map<String, dynamic>? _patternAnalysis;
  Map<String, dynamic>? _trends;

  @override
  void initState() {
    super.initState();
    _loadInsights();
  }

  Future<void> _loadInsights() async {
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

      // Load pattern analysis and trends in parallel
      final results = await Future.wait([
        _analysisService.analyzeSymptomPatterns(userId, days: 30),
        _analysisService.getSymptomTrends(userId, weeks: 4),
      ]);

      if (mounted) {
        setState(() {
          _patternAnalysis = results[0];
          _trends = results[1];
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading symptom insights: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: kAccent,
        automaticallyImplyLeading: true,
        toolbarHeight: getPercentageHeight(10, context),
        title: Text(
          'Symptom Insights',
          style: textTheme.displaySmall?.copyWith(
            fontSize: getTextScale(7, context),
            color: kWhite,
          ),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: kAccent))
          : RefreshIndicator(
              onRefresh: _loadInsights,
              color: kAccent,
              child: SingleChildScrollView(
                padding: EdgeInsets.all(getPercentageWidth(3, context)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_patternAnalysis?['hasData'] == true) ...[
                      // Check if total symptoms is 0
                      if ((_patternAnalysis?['totalSymptoms'] as int? ?? 0) ==
                          0) ...[
                        _buildEmptyState(context, isDarkMode, textTheme),
                      ] else ...[
                        _buildSummaryCard(context, isDarkMode, textTheme),
                        SizedBox(height: getPercentageHeight(2, context)),
                        _buildTopTriggersCard(context, isDarkMode, textTheme),
                        SizedBox(height: getPercentageHeight(1, context)),
                        _buildAddFoodCard(context, isDarkMode, textTheme),
                        SizedBox(height: getPercentageHeight(2.5, context)),
                        _buildTrendsCard(context, isDarkMode, textTheme),
                        SizedBox(height: getPercentageHeight(2, context)),
                        _buildRecommendationsCard(
                            context, isDarkMode, textTheme),
                      ],
                    ] else ...[
                      _buildEmptyState(context, isDarkMode, textTheme),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildAddFoodCard(
    BuildContext context,
    bool isDarkMode,
    TextTheme textTheme,
  ) {
    return Center(
      child: Container(
        padding: EdgeInsets.all(getPercentageWidth(4, context)),
        decoration: BoxDecoration(
          color: isDarkMode ? kDarkGrey.withValues(alpha: 0.5) : kWhite,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: kAccentLight.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) =>
                      DailySummaryScreen(date: DateTime.now(), instanceId: 'jbjkbjknknk')),
            );
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(
                    Icons.restaurant_menu,
                    color: kAccentLight,
                    size: getIconScale(4, context),
                  ),
                  SizedBox(width: getPercentageWidth(2, context)),
                  Text(
                    'Log Your Symptoms for Today',
                    style: textTheme.displaySmall?.copyWith(
                      color: isDarkMode ? kWhite : kBlack,
                      fontSize: getTextScale(4, context),
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(width: getPercentageWidth(1, context)),
                  Icon(
                    Icons.arrow_forward_ios,
                    color: kAccentLight,
                    size: getIconScale(4, context),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(
    BuildContext context,
    bool isDarkMode,
    TextTheme textTheme,
  ) {
    final totalSymptoms = _patternAnalysis?['totalSymptoms'] as int? ?? 0;
    final daysAnalyzed = _patternAnalysis?['daysAnalyzed'] as int? ?? 30;
    final severityTrends =
        _patternAnalysis?['severityTrends'] as Map<String, dynamic>? ?? {};
    final avgSeverity = severityTrends['averageSeverity'] as double? ?? 0.0;
    final trend = severityTrends['trend'] as String? ?? 'stable';

    return Container(
      padding: EdgeInsets.all(getPercentageWidth(4, context)),
      decoration: BoxDecoration(
        color: isDarkMode ? kDarkGrey.withValues(alpha: 0.5) : kWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: kAccent.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Summary',
            style: textTheme.titleLarge?.copyWith(
              color: isDarkMode ? kWhite : kBlack,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: getPercentageHeight(1, context)),
          Text(
            'Chef, please be aware this is a summary of potential food triggers based on your symptoms. It is not a definitive diagnosis.',
            style: textTheme.bodyMedium?.copyWith(
              color: isDarkMode ? Colors.grey : Colors.blueGrey,
              fontStyle: FontStyle.italic,
              fontSize: getTextScale(2.5, context),
            ),
          ),
          SizedBox(height: getPercentageHeight(2, context)),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  context,
                  'Total Symptoms',
                  totalSymptoms.toString(),
                  Icons.assignment,
                  isDarkMode,
                  textTheme,
                ),
              ),
              SizedBox(width: getPercentageWidth(2, context)),
              Expanded(
                child: _buildStatItem(
                  context,
                  'Days Analyzed',
                  daysAnalyzed.toString(),
                  Icons.calendar_today,
                  isDarkMode,
                  textTheme,
                ),
              ),
            ],
          ),
          SizedBox(height: getPercentageHeight(2, context)),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  context,
                  'Avg Severity',
                  avgSeverity.toStringAsFixed(1),
                  Icons.trending_up,
                  isDarkMode,
                  textTheme,
                ),
              ),
              SizedBox(width: getPercentageWidth(2, context)),
              Expanded(
                child: _buildStatItem(
                  context,
                  'Trend',
                  trend == 'improving'
                      ? '📉 Improving'
                      : trend == 'worsening'
                          ? '📈 Worsening'
                          : '➡️ Stable',
                  Icons.insights,
                  isDarkMode,
                  textTheme,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    bool isDarkMode,
    TextTheme textTheme,
  ) {
    return Container(
      padding: EdgeInsets.all(getPercentageWidth(3, context)),
      decoration: BoxDecoration(
        color: kAccent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: kAccent, size: getIconScale(5, context)),
          SizedBox(height: getPercentageHeight(0.5, context)),
          Text(
            value,
            style: textTheme.titleMedium?.copyWith(
              color: isDarkMode ? kWhite : kBlack,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: getPercentageHeight(0.3, context)),
          Text(
            label,
            style: textTheme.bodySmall?.copyWith(
              color: isDarkMode ? Colors.white70 : Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTopTriggersCard(
    BuildContext context,
    bool isDarkMode,
    TextTheme textTheme,
  ) {
    final topTriggers =
        _patternAnalysis?['topTriggers'] as List<Map<String, dynamic>>? ?? [];

    if (topTriggers.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: EdgeInsets.all(getPercentageWidth(4, context)),
      decoration: BoxDecoration(
        color: isDarkMode ? kDarkGrey.withValues(alpha: 0.5) : kWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.orange.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded,
                  color: Colors.orange, size: getIconScale(5, context)),
              SizedBox(width: getPercentageWidth(2, context)),
              Text(
                'Top Trigger Ingredients',
                style: textTheme.titleLarge?.copyWith(
                  color: isDarkMode ? kWhite : kBlack,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: getPercentageHeight(2, context)),
          ...topTriggers.take(5).map((trigger) {
            final ingredient = trigger['ingredient'] as String;
            final symptom = trigger['mostCommonSymptom'] as String;
            final occurrences = trigger['occurrences'] as int;
            final avgSeverity = trigger['averageSeverity'] as double;
            final correlation = trigger['correlation'] as double;

            return Padding(
              padding:
                  EdgeInsets.only(bottom: getPercentageHeight(1.5, context)),
              child: Container(
                padding: EdgeInsets.all(getPercentageWidth(3, context)),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            capitalizeFirstLetter(ingredient),
                            style: textTheme.titleMedium?.copyWith(
                              color: Colors.orange[700],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          '${(correlation * 100).toStringAsFixed(0)}% correlation',
                          style: textTheme.bodySmall?.copyWith(
                            color: isDarkMode ? Colors.white70 : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: getPercentageHeight(0.5, context)),
                    Text(
                      'Causes $symptom • $occurrences occurrence(s) • Avg severity: ${avgSeverity.toStringAsFixed(1)}/5',
                      style: textTheme.bodySmall?.copyWith(
                        color: isDarkMode ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          // Link to rainbow tracker to see more triggers
          InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => RainbowTrackerDetailScreen(
                    weekStart: getWeekStart(DateTime.now()),
                  ),
                ),
              );
            },
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: getPercentageWidth(4, context),
                vertical: getPercentageHeight(1.5, context),
              ),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.orange.withValues(alpha: 0.5),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.eco,
                    color: Colors.orange[700],
                    size: getIconScale(4, context),
                  ),
                  SizedBox(width: getPercentageWidth(2, context)),
                  Text(
                    'View Rainbow Tracker',
                    style: textTheme.bodyMedium?.copyWith(
                      color: Colors.orange[700],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(width: getPercentageWidth(1, context)),
                  Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.orange[700],
                    size: getIconScale(3, context),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendsCard(
    BuildContext context,
    bool isDarkMode,
    TextTheme textTheme,
  ) {
    final weeklyTrends = _trends?['weeklyTrends'] as List<dynamic>? ?? [];

    if (weeklyTrends.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: EdgeInsets.all(getPercentageWidth(4, context)),
      decoration: BoxDecoration(
        color: isDarkMode ? kDarkGrey.withValues(alpha: 0.5) : kWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: kAccent.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.timeline,
                  color: kAccent, size: getIconScale(5, context)),
              SizedBox(width: getPercentageWidth(2, context)),
              Text(
                'Weekly Trends',
                style: textTheme.titleLarge?.copyWith(
                  color: isDarkMode ? kWhite : kBlack,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: getPercentageHeight(2, context)),
          ...weeklyTrends.map((week) {
            final weekData = week as Map<String, dynamic>;
            final weekKey = weekData['week'] as String? ?? 'Unknown';
            final totalSymptoms = weekData['totalSymptoms'] as int? ?? 0;
            final avgSeverity = weekData['averageSeverity'] as double? ?? 0.0;

            return Padding(
              padding: EdgeInsets.only(bottom: getPercentageHeight(1, context)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      weekKey,
                      style: textTheme.bodyMedium?.copyWith(
                        color: isDarkMode ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  ),
                  Text(
                    '$totalSymptoms symptoms',
                    style: textTheme.bodySmall?.copyWith(
                      color: kAccent,
                    ),
                  ),
                  SizedBox(width: getPercentageWidth(2, context)),
                  Text(
                    'Severity: ${avgSeverity.toStringAsFixed(1)}',
                    style: textTheme.bodySmall?.copyWith(
                      color: isDarkMode ? Colors.white70 : Colors.black87,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildRecommendationsCard(
    BuildContext context,
    bool isDarkMode,
    TextTheme textTheme,
  ) {
    final recommendations =
        _patternAnalysis?['recommendations'] as List<dynamic>? ?? [];

    if (recommendations.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: EdgeInsets.all(getPercentageWidth(4, context)),
      decoration: BoxDecoration(
        color: isDarkMode ? kDarkGrey.withValues(alpha: 0.5) : kWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: kAccent.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline,
                  color: kAccent, size: getIconScale(5, context)),
              SizedBox(width: getPercentageWidth(2, context)),
              Text(
                'Recommendations',
                style: textTheme.titleLarge?.copyWith(
                  color: isDarkMode ? kWhite : kBlack,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: getPercentageHeight(2, context)),
          ...recommendations.map((rec) {
            return Padding(
              padding: EdgeInsets.only(bottom: getPercentageHeight(1, context)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.check_circle_outline,
                      color: kAccent, size: getIconScale(4, context)),
                  SizedBox(width: getPercentageWidth(2, context)),
                  Expanded(
                    child: Text(
                      rec.toString(),
                      style: textTheme.bodyMedium?.copyWith(
                        color: isDarkMode ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    bool isDarkMode,
    TextTheme textTheme,
  ) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(getPercentageWidth(8, context)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.insights_outlined,
              size: getIconScale(15, context),
              color: kAccent.withValues(alpha: 0.5),
            ),
            SizedBox(height: getPercentageHeight(3, context)),
            Text(
              'No Symptoms Logged Yet',
              style: textTheme.titleLarge?.copyWith(
                color: isDarkMode ? kWhite : kBlack,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: getPercentageHeight(2, context)),
            Container(
              padding: EdgeInsets.all(getPercentageWidth(4, context)),
              decoration: BoxDecoration(
                color: kAccent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: kAccent.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.restaurant_menu,
                    color: kAccent,
                    size: getIconScale(8, context),
                  ),
                  SizedBox(height: getPercentageHeight(2, context)),
                  Text(
                    'Log How You Feel After Meals',
                    style: textTheme.titleMedium?.copyWith(
                      color: kAccent,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: getPercentageHeight(1.5, context)),
                  Text(
                    'Chef, to get personalized insights and identify food triggers, please make sure to log how you\'re feeling after each meal. This helps me track patterns and provide you with recommendations. \n\nDont worry, I will remind you to log your symptoms after each meal.',
                    style: textTheme.bodyMedium?.copyWith(
                      color: isDarkMode ? Colors.white70 : Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
