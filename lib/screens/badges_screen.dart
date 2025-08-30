import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../constants.dart';
import '../data_models/badge_system_model.dart' as BadgeModel;
import '../helper/utils.dart';
import '../service/badge_service.dart';

class BadgesScreen extends StatefulWidget {
  BadgesScreen({Key? key}) : super(key: key);

  @override
  State<BadgesScreen> createState() => _BadgesScreenState();
}

class _BadgesScreenState extends State<BadgesScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  final BadgeService badgeService = Get.find<BadgeService>();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();

    // Load user progress if logged in
    if (userService.currentUser.value?.userId != null) {
      badgeService.loadAvailableBadges();
      badgeService.loadUserStreak(userService.userId!);
      badgeService.loadUserPoints(userService.userId!);
      badgeService.loadUserProgress(userService.userId!);
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isDarkMode = getThemeProvider(context).isDarkMode;

    return Scaffold(
      appBar: AppBar(
        title: Text('Achievements',
            style: textTheme.displaySmall?.copyWith(
              color: isDarkMode ? kWhite : kDarkGrey,
              fontWeight: FontWeight.w400,
              fontSize: getTextScale(7, context),
            )),
        centerTitle: true,
        backgroundColor: kAccent,
        toolbarHeight: getPercentageHeight(10, context),
      ),
      body: SafeArea(
        child: Obx(() {
          return FadeTransition(
            opacity: _fadeAnimation,
            child: CustomScrollView(
              slivers: [
                // Stats Cards
                _buildStatsSection(context, isDarkMode, textTheme),

                // Earned Badges
                _buildEarnedBadgesSection(context, isDarkMode, textTheme),

                // Available Badges by Category
                _buildAvailableBadgesSection(context, isDarkMode, textTheme),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildStatsSection(
      BuildContext context, bool isDarkMode, TextTheme textTheme) {
    return SliverToBoxAdapter(
      child: Container(
        margin: EdgeInsets.all(getPercentageWidth(4, context)),
        child: Row(
          children: [
            // Streak Card
            Expanded(
              child: _buildStatCard(
                context: context,
                icon: Icons.local_fire_department,
                iconColor: Colors.orange,
                title: 'Streak',
                value: '${badgeService.streakDays}',
                subtitle: 'days',
                isDarkMode: isDarkMode,
                textTheme: textTheme,
              ),
            ),
            SizedBox(width: getPercentageWidth(2, context)),

            // Points Card
            Expanded(
              child: _buildStatCard(
                context: context,
                icon: Icons.star,
                iconColor: Colors.amber,
                title: 'Points',
                value: '${badgeService.totalPoints}',
                subtitle: 'earned',
                isDarkMode: isDarkMode,
                textTheme: textTheme,
              ),
            ),
            SizedBox(width: getPercentageWidth(2, context)),

            // Badges Card
            Expanded(
              child: _buildStatCard(
                context: context,
                icon: Icons.emoji_events,
                iconColor: Colors.deepPurple,
                title: 'Badges',
                value: '${badgeService.earnedBadges.length}',
                subtitle: 'earned',
                isDarkMode: isDarkMode,
                textTheme: textTheme,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    required String subtitle,
    required bool isDarkMode,
    required TextTheme textTheme,
  }) {
    return Container(
      padding: EdgeInsets.all(getPercentageWidth(3, context)),
      decoration: BoxDecoration(
        color: isDarkMode ? kDarkGrey : kWhite,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: getIconScale(8, context)),
          SizedBox(height: getPercentageHeight(0.5, context)),
          Text(
            value,
            style: textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: isDarkMode ? kWhite : kDarkGrey,
            ),
          ),
          Text(
            title,
            style: textTheme.bodySmall?.copyWith(
              color: isDarkMode ? kLightGrey : kDarkGrey.withValues(alpha: 0.7),
            ),
          ),
          Text(
            subtitle,
            style: textTheme.bodySmall?.copyWith(
              color: isDarkMode ? kLightGrey : kDarkGrey.withValues(alpha: 0.5),
              fontSize: getTextScale(2.5, context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEarnedBadgesSection(
      BuildContext context, bool isDarkMode, TextTheme textTheme) {
    final earnedBadges = badgeService.earnedBadges;

    if (earnedBadges.isEmpty) {
      return SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              getPercentageWidth(4, context),
              getPercentageHeight(2, context),
              getPercentageWidth(4, context),
              getPercentageHeight(1, context),
            ),
            child: Text(
              '🏆 Earned Badges (${earnedBadges.length})',
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: isDarkMode ? kWhite : kDarkGrey,
              ),
            ),
          ),
          Container(
            height: getPercentageHeight(20, context),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(
                  horizontal: getPercentageWidth(4, context)),
              itemCount: earnedBadges.length,
              itemBuilder: (context, index) {
                final badge = earnedBadges[index];
                return _buildEarnedBadgeCard(
                    context, badge, isDarkMode, textTheme);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEarnedBadgeCard(BuildContext context, BadgeModel.Badge badge,
      bool isDarkMode, TextTheme textTheme) {
    return Container(
      width: getPercentageWidth(35, context),
      margin: EdgeInsets.only(right: getPercentageWidth(3, context)),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            kAccent.withValues(alpha: 0.5),
            kGreen.withValues(alpha: 0.5),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: kGreen.withValues(alpha: 0.5), width: 2),
        boxShadow: [
          BoxShadow(
            color: kAccent.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(getPercentageWidth(3, context)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _getIconFromString(badge.icon),
              color: kWhite,
              size: getIconScale(10, context),
            ),
            SizedBox(height: getPercentageHeight(1, context)),
            Text(
              badge.title,
              style: textTheme.titleSmall?.copyWith(
                color: kWhite,
                fontWeight: FontWeight.bold,
                fontSize: getTextScale(3.2, context),
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: getPercentageHeight(0.5, context)),
            Text(
              '+${badge.rewards.points} pts',
              style: textTheme.bodySmall?.copyWith(
                color: kWhite.withValues(alpha: 0.9),
                fontSize: getTextScale(2.8, context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvailableBadgesSection(
      BuildContext context, bool isDarkMode, TextTheme textTheme) {
    final badgesByCategory = _groupBadgesByCategory();

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final category = badgesByCategory.keys.elementAt(index);
          final badges = badgesByCategory[category]!;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  getPercentageWidth(4, context),
                  getPercentageHeight(2, context),
                  getPercentageWidth(4, context),
                  getPercentageHeight(1, context),
                ),
                child: Text(
                  _getCategoryTitle(category),
                  style: textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? kWhite : kDarkGrey,
                  ),
                ),
              ),
              ...badges.map((badge) =>
                  _buildBadgeCard(context, badge, isDarkMode, textTheme)),
              SizedBox(height: getPercentageHeight(2, context)),
            ],
          );
        },
        childCount: badgesByCategory.length,
      ),
    );
  }

  Widget _buildBadgeCard(BuildContext context, BadgeModel.Badge badge,
      bool isDarkMode, TextTheme textTheme) {
    final progress = badgeService.userProgress.firstWhereOrNull(
      (p) => p.badgeId == badge.id,
    );
    final isEarned = progress?.isEarned == true;
    final currentProgress = progress?.currentProgress ?? 0;
    final progressPercentage = currentProgress / badge.criteria.target;

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: getPercentageWidth(4, context),
        vertical: getPercentageHeight(0.5, context),
      ),
      decoration: BoxDecoration(
        color: isDarkMode ? kDarkGrey : kWhite,
        borderRadius: BorderRadius.circular(12),
        border: isEarned
            ? Border.all(color: kGreen.withValues(alpha: 0.5), width: 2)
            : Border.all(color: Colors.transparent, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(getPercentageWidth(4, context)),
        child: Row(
          children: [
            // Badge Icon
            Container(
              padding: EdgeInsets.all(getPercentageWidth(2, context)),
              decoration: BoxDecoration(
                color: isEarned
                    ? kGreen.withValues(alpha: 0.2)
                    : _getDifficultyColor(badge.difficulty)
                        .withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _getIconFromString(badge.icon),
                color:
                    isEarned ? kGreen : _getDifficultyColor(badge.difficulty),
                size: getIconScale(8, context),
              ),
            ),
            SizedBox(width: getPercentageWidth(3, context)),

            // Badge Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          badge.title,
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isDarkMode ? kWhite : kDarkGrey,
                          ),
                        ),
                      ),
                      if (isEarned)
                        Icon(Icons.check_circle,
                            color: kGreen, size: getIconScale(6, context)),
                    ],
                  ),
                  SizedBox(height: getPercentageHeight(0.5, context)),
                  Text(
                    badge.description,
                    style: textTheme.bodySmall?.copyWith(
                      color: isDarkMode
                          ? kLightGrey
                          : kDarkGrey.withValues(alpha: 0.7),
                    ),
                  ),
                  SizedBox(height: getPercentageHeight(1, context)),

                  // Progress Bar
                  if (!isEarned) ...[
                    Row(
                      children: [
                        Expanded(
                          child: LinearProgressIndicator(
                            value: progressPercentage.clamp(0.0, 1.0),
                            backgroundColor:
                                (isDarkMode ? kLightGrey : kDarkGrey)
                                    .withValues(alpha: 0.2),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              _getDifficultyColor(badge.difficulty),
                            ),
                          ),
                        ),
                        SizedBox(width: getPercentageWidth(2, context)),
                        Text(
                          '$currentProgress/${badge.criteria.target}',
                          style: textTheme.bodySmall?.copyWith(
                            color: isDarkMode
                                ? kLightGrey
                                : kDarkGrey.withValues(alpha: 0.7),
                            fontSize: getTextScale(2.8, context),
                          ),
                        ),
                      ],
                    ),
                  ],

                  // Reward Info
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${badge.rewards.points} points',
                        style: textTheme.bodySmall?.copyWith(
                          color: Colors.amber,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: getPercentageWidth(2, context),
                          vertical: getPercentageHeight(0.3, context),
                        ),
                        decoration: BoxDecoration(
                          color: _getDifficultyColor(badge.difficulty)
                              .withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          badge.difficulty.name.toUpperCase(),
                          style: textTheme.bodySmall?.copyWith(
                            color: _getDifficultyColor(badge.difficulty),
                            fontWeight: FontWeight.bold,
                            fontSize: getTextScale(2.5, context),
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
    );
  }

  Map<BadgeModel.BadgeCategory, List<BadgeModel.Badge>>
      _groupBadgesByCategory() {
    final Map<BadgeModel.BadgeCategory, List<BadgeModel.Badge>> grouped = {};

    for (final badge in badgeService.availableBadges) {
      if (!grouped.containsKey(badge.category)) {
        grouped[badge.category] = [];
      }
      grouped[badge.category]!.add(badge);
    }

    // Sort badges within each category by order
    for (final category in grouped.keys) {
      grouped[category]!.sort((a, b) => a.order.compareTo(b.order));
    }

    return grouped;
  }

  String _getCategoryTitle(BadgeModel.BadgeCategory category) {
    switch (category) {
      case BadgeModel.BadgeCategory.consistency:
        return '🔥 Consistency Badges';
      case BadgeModel.BadgeCategory.nutrition:
        return '🥗 Nutrition Badges';
      case BadgeModel.BadgeCategory.social:
        return '👥 Social Badges';
      case BadgeModel.BadgeCategory.exploration:
        return '🎯 Exploration Badges';
      case BadgeModel.BadgeCategory.achievement:
        return '🏆 Achievement Badges';
      case BadgeModel.BadgeCategory.special:
        return '⭐ Special Badges';
    }
  }

  IconData _getIconFromString(String iconName) {
    switch (iconName) {
      case 'restaurant':
        return Icons.restaurant;
      case 'local_fire_department':
        return Icons.local_fire_department;
      case 'celebration':
        return Icons.celebration;
      case 'balance':
        return Icons.balance;
      case 'water_drop':
        return Icons.water_drop;
      case 'eco':
        return Icons.eco;
      case 'menu_book':
        return Icons.menu_book;
      case 'inventory_2':
        return Icons.inventory_2;
      case 'sports_mma':
        return Icons.sports_mma;
      case 'emoji_events':
        return Icons.emoji_events;
      case 'star':
        return Icons.star;
      case 'workspace_premium':
        return Icons.workspace_premium;
      case 'directions_walk':
        return Icons.directions_walk;
      case 'directions_run':
        return Icons.directions_run;
      default:
        return Icons.emoji_events;
    }
  }

  Color _getDifficultyColor(BadgeModel.BadgeDifficulty difficulty) {
    switch (difficulty) {
      case BadgeModel.BadgeDifficulty.easy:
        return kAccent.withValues(alpha: 0.5);
      case BadgeModel.BadgeDifficulty.medium:
        return kBlue.withValues(alpha: 0.5);
      case BadgeModel.BadgeDifficulty.hard:
        return kAccentLight.withValues(alpha: 0.5);
      case BadgeModel.BadgeDifficulty.legendary:
        return kPurple.withValues(alpha: 0.5);
    }
  }
}
