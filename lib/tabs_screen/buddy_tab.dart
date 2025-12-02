import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../constants.dart';
import '../data_models/meal_model.dart';
import '../detail_screen/recipe_detail.dart';
import '../helper/helper_files.dart';
import '../helper/notifications_helper.dart';
import '../helper/utils.dart';
import '../screens/buddy_screen.dart';
import '../widgets/info_icon_widget.dart';
import '../widgets/premium_widget.dart';
import '../helper/helper_functions.dart';
import '../widgets/category_selector.dart';

class BuddyTab extends StatefulWidget {
  const BuddyTab({super.key});

  @override
  State<BuddyTab> createState() => _BuddyTabState();
}

class _BuddyTabState extends State<BuddyTab> {
  Future<QuerySnapshot<Map<String, dynamic>>?>? _buddyDataFuture;

  // State for meal type filtering
  final ValueNotifier<Set<String>> selectedMealTypesNotifier =
      ValueNotifier({});

  // Family mode state
  bool familyMode = false;
  int selectedUserIndex = 0;
  List<Map<String, dynamic>> _familyMemberCategories = [];

  // Generation navigation state
  int currentGenerationIndex = 0; // 0 = most recent
  List<Map<String, dynamic>> allAvailableGenerations = [];

  // Toggle meal type selection
  void toggleMealTypeSelection(String mealType) {
    final currentSelection = Set<String>.from(selectedMealTypesNotifier.value);
    if (currentSelection.contains(mealType)) {
      currentSelection.remove(mealType);
    } else {
      currentSelection.add(mealType);
    }
    selectedMealTypesNotifier.value = currentSelection;
  }

  // Filter meals based on selected meal types (breakfast, lunch, dinner, snacks)
  // The mealType comes from parsing the meal ID suffix (bf, lh, dn, sn, etc.)
  List<MealWithType> filterMealsByType(
      List<MealWithType> meals, Set<String> selectedMealTypes) {
    if (selectedMealTypes.isEmpty) return meals; // Show all if none selected

    // Map selected meal types to possible mealType values from meal ID suffixes
    final Map<String, List<String>> mealTypeMapping = {
      'breakfast': ['bf', 'breakfast', 'b'],
      'lunch': ['lh', 'lunch', 'l'],
      'dinner': ['dn', 'dinner', 'd'],
      'snacks': ['sn', 'snacks', 'snack', 's'],
    };

    return meals.where((mealWithType) {
      final mealTypeFromId = mealWithType.mealType.toLowerCase();

      // Check if the meal's mealType matches any selected meal type
      bool matches = selectedMealTypes.any((selectedType) {
        final normalizedSelectedType = selectedType.toLowerCase();
        final possibleValues =
            mealTypeMapping[normalizedSelectedType] ?? [normalizedSelectedType];

        // Check if mealTypeFromId matches any of the possible values for this selected type
        return possibleValues
            .any((value) => mealTypeFromId == value.toLowerCase());
      });

      return matches;
    }).toList();
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

  // Update selected family member
  void _updateSelectedUser(String userId, String userName) {
    if (!mounted) return;
    final currentUser = userService.currentUser.value;
    if (currentUser == null) return;

    // Find the index of the selected user
    int index = 0; // Default to main user
    if (userId != (currentUser.userId ?? '')) {
      // Check if it's a family member ID
      if (userId.startsWith('family_')) {
        final familyIndex = int.tryParse(userId.replaceFirst('family_', ''));
        if (familyIndex != null) {
          index = familyIndex + 1; // +1 because index 0 is the main user
        }
      }
    }

    if (mounted) {
    setState(() {
      selectedUserIndex = index;
      currentGenerationIndex = 0; // Reset to most recent when switching users
    });
    }

    // Refresh buddy data for the selected user
    _initializeBuddyData();
  }

  @override
  void dispose() {
    selectedMealTypesNotifier.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _initializeFamilyMode();
    _initializeBuddyData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _initializeFamilyMode();
    _initializeBuddyData();
  }

  void _initializeFamilyMode() {
    if (!mounted) return;
    final currentUser = userService.currentUser.value;
    if (currentUser != null) {
      if (mounted) {
      setState(() {
        familyMode = currentUser.familyMode ?? false;
        _buildFamilyMemberCategories();
      });
      }
    }
  }

  void _buildFamilyMemberCategories() {
    if (!mounted) return;
    final currentUser = userService.currentUser.value;
    if (currentUser == null) return;

    final categories = <Map<String, dynamic>>[];

    // Add main user
    categories.add({
      'id': currentUser.userId ?? '',
      'name': currentUser.displayName ?? 'You',
    });

    // Add family members
    final familyMembers = currentUser.familyMembers ?? [];
    for (int i = 0; i < familyMembers.length; i++) {
      final member = familyMembers[i];
      categories.add({
        'id':
            'family_$i', // Use index-based ID since FamilyMember doesn't have userId
        'name': member.name,
      });
    }

    if (mounted) {
    setState(() {
      _familyMemberCategories = categories;
    });
    }
  }

  void _initializeBuddyData() {
    final currentUser = userService.currentUser.value;
    if (currentUser == null) {
      _buddyDataFuture = Future.value(null);
      return;
    }

    // Determine which user's data to fetch
    String targetUserId = currentUser.userId ?? '';
    if (familyMode && selectedUserIndex > 0) {
      // For family members, we'll use the main user's ID since family members don't have separate meal plans
      // The meal plan will be filtered based on the selected family member's preferences
      targetUserId = currentUser.userId ?? '';
    }

    if (targetUserId.isEmpty) {
      _buddyDataFuture = Future.value(null);
      return;
    }

    // Reset generation index when refreshing data
    if (mounted) {
    setState(() {
      currentGenerationIndex = 0;
      allAvailableGenerations = [];
    });
    }

    // Fetch multiple documents to collect enough generations
    // Document IDs are dates in 'yyyy-MM-dd' format, so ordering descending gives most recent
    _buddyDataFuture = _fetchBuddyData(targetUserId);
  }

  // Separate async method to properly handle errors and return null on failure
  // Fetch multiple documents to collect enough generations (up to 3)
  Future<QuerySnapshot<Map<String, dynamic>>?> _fetchBuddyData(
      String userId) async {
    try {
      // Fetch up to 5 documents (dates) to ensure we have enough generations
      return await firestore
          .collection('mealPlans')
          .doc(userId)
          .collection('buddy')
          .orderBy(FieldPath.documentId, descending: true)
          .limit(5)
          .get();
    } catch (e) {
      debugPrint('Error loading buddy data: $e');
      if (mounted) {
        _handleError('Failed to load meal plans. Please try again.',
            details: e.toString());
      }
      return null;
    }
  }

  // Collect and sort all generations from multiple documents
  List<Map<String, dynamic>> _collectAllGenerations(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
      bool isFamilyMode,
      String? familyMemberName) {
    final allGenerations = <Map<String, dynamic>>[];

    // Collect all generations from all documents
    for (final doc in docs) {
      final mealPlan = doc.data();
      final generations = (mealPlan['generations'] as List<dynamic>?)
              ?.map((gen) => gen as Map<String, dynamic>)
              .toList() ??
          [];

      // Filter by family member if in family mode
      List<Map<String, dynamic>> filteredGenerations = generations;
      if (isFamilyMode && familyMemberName != null && familyMemberName.isNotEmpty) {
        filteredGenerations = generations.where((gen) {
          final genFamilyName = gen['familyMemberName'] as String?;
          return genFamilyName == familyMemberName;
        }).toList();
      } else {
        // For main user, show generations without family member name or with null family member name
        filteredGenerations = generations.where((gen) {
          final genFamilyName = gen['familyMemberName'] as String?;
          return genFamilyName == null || genFamilyName.isEmpty;
        }).toList();
      }

      allGenerations.addAll(filteredGenerations);
    }

    // Sort by timestamp (newest first)
    allGenerations.sort((a, b) {
      final timestampA = a['timestamp'] as Timestamp?;
      final timestampB = b['timestamp'] as Timestamp?;
      if (timestampA == null && timestampB == null) return 0;
      if (timestampA == null) return 1;
      if (timestampB == null) return -1;
      return timestampB.compareTo(timestampA); // Descending (newest first)
    });

    // Take only first 3 generations (current + 2 previous)
    return allGenerations.take(3).toList();
  }

  Future<dynamic> _navigateToMealPlanChat(BuildContext context) async {
    final currentUser = userService.currentUser.value;

    // Get the selected family member info
    String? familyMemberName;
    String? familyMemberKcal;
    String? familyMemberGoal;
    String? familyMemberType;

    if (currentUser != null && familyMode && selectedUserIndex > 0) {
      final familyMembers = currentUser.familyMembers ?? [];
      if (selectedUserIndex - 1 < familyMembers.length) {
        familyMemberName = familyMembers[selectedUserIndex - 1].name;
        familyMemberKcal = familyMembers[selectedUserIndex - 1].foodGoal;
        familyMemberGoal = familyMembers[selectedUserIndex - 1].fitnessGoal;
        familyMemberType = familyMembers[selectedUserIndex - 1].ageGroup;
      }
    }

    // Navigate to meal plan chat mode in BuddyScreen
    Get.to(
      () => const TastyScreen(screen: 'buddy'),
      arguments: {
        'mealPlanMode': true,
        'familyMemberName': familyMemberName,
        'familyMemberKcal': familyMemberKcal,
        'familyMemberGoal': familyMemberGoal,
        'familyMemberType': familyMemberType,
      },
    );
    return null;
  }

  Future<List<Map<String, dynamic>>> _fetchMealsFromIds(
      List<dynamic> mealIds) async {
    if (mealIds.isEmpty) return [];

    try {
      final List<MealWithType> mealWithTypes = [];
      for (final mealId in mealIds) {
        if (mealId is String && mealId.contains('/')) {
          final parts = mealId.split('/');
          final id = parts[0];
          String mealType = parts.length > 1 ? parts[1] : '';
          String familyMember = parts.length > 2 ? parts[2] : '';

          // Defensive parsing: Handle edge case where format is mealId/familyMemberName (2 parts)
          // Check if second part is a known suffix (bf, lh, dn, sn) or a family member name
          if (parts.length == 2) {
            final secondPart = parts[1].toLowerCase();
            final knownSuffixes = [
              'bf',
              'lh',
              'dn',
              'sn',
              'breakfast',
              'lunch',
              'dinner',
              'snack'
            ];
            if (!knownSuffixes.contains(secondPart)) {
              // Second part is likely a family member name, not a suffix
              // Default to 'bf' (breakfast) as per user comment
              mealType = 'bf';
              familyMember = parts[1];
            } else {
              // Second part is a suffix
              mealType = secondPart;
              familyMember = '';
            }
          } else if (mealType.isEmpty) {
            // If mealType is empty, default to 'bf' (breakfast) as per user comment
            mealType = 'bf';
          }

          final meal = await mealManager.getMealbyMealID(id);
          if (meal != null) {
            mealWithTypes.add(MealWithType(
              meal: meal,
              mealType: mealType,
              familyMember: familyMember,
              fullMealId: mealId,
            ));
          }
        } else if (mealId is String) {
          // Handle mealIds without meal type (just the meal ID)
          // Default to 'bf' (breakfast) when suffix is missing as per user comment
          final meal = await mealManager.getMealbyMealID(mealId);
          if (meal != null) {
            mealWithTypes.add(MealWithType(
              meal: meal,
              mealType:
                  'bf', // Default to 'bf' (breakfast) when suffix is missing
              familyMember: '',
              fullMealId: mealId,
            ));
          }
        }
      }

      // Group meals by type with more flexible matching
      final groupedMeals = {
        'breakfast': mealWithTypes
            .where((m) =>
                m.mealType.toLowerCase() == 'bf' ||
                m.mealType.toLowerCase() == 'breakfast' ||
                m.mealType.toLowerCase() == 'b')
            .toList(),
        'lunch': mealWithTypes
            .where((m) =>
                m.mealType.toLowerCase() == 'lh' ||
                m.mealType.toLowerCase() == 'lunch' ||
                m.mealType.toLowerCase() == 'l')
            .toList(),
        'dinner': mealWithTypes
            .where((m) =>
                m.mealType.toLowerCase() == 'dn' ||
                m.mealType.toLowerCase() == 'dinner' ||
                m.mealType.toLowerCase() == 'd')
            .toList(),
        'snacks': mealWithTypes
            .where((m) =>
                m.mealType.toLowerCase() == 'sk' ||
                m.mealType.toLowerCase() == 'snacks' ||
                m.mealType.toLowerCase() == 's')
            .toList(),
        'general': mealWithTypes
            .where((m) => m.mealType.toLowerCase() == 'general')
            .toList(),
      };

      // Add any unmatched meals to a "other" category
      final matchedMealTypes =
          groupedMeals.values.expand((meals) => meals).toList();
      final unmatchedMeals =
          mealWithTypes.where((m) => !matchedMealTypes.contains(m)).toList();

      if (unmatchedMeals.isNotEmpty) {
        groupedMeals['other'] = unmatchedMeals;
      }

      groupedMeals.forEach((type, meals) {});

      return [
        {'groupedMeals': groupedMeals}
      ];
    } catch (e) {
      debugPrint('Error fetching meals: $e');
      if (mounted) {
        _handleError('Failed to load meals. Please try again.',
            details: e.toString());
      }
      return [];
    }
  }


  Widget _buildDefaultView(BuildContext context, bool mealEmpty) {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    final textTheme = Theme.of(context).textTheme;
    final isPremium = userService.currentUser.value?.isPremium ?? false;
    final freeTrialDate = userService.currentUser.value?.freeTrialDate;
    final isInFreeTrial =
        freeTrialDate != null && DateTime.now().isBefore(freeTrialDate);

    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          children: [
            // Premium/Ads Section
            getAdsWidget(isPremium, isDiv: false),

            SizedBox(height: getPercentageHeight(4, context)),

            // Main Content Container
            Container(
              margin: EdgeInsets.symmetric(
                  horizontal: getPercentageWidth(4, context)),
              padding: EdgeInsets.all(getPercentageWidth(5, context)),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isPremium
                      ? [
                          kAccent.withValues(alpha: 0.1),
                          kAccentLight.withValues(alpha: 0.05)
                        ]
                      : [
                          isDarkMode
                              ? kDarkGrey.withValues(alpha: 0.3)
                              : kLightGrey.withValues(alpha: 0.3),
                          isDarkMode
                              ? kDarkGrey.withValues(alpha: 0.1)
                              : kLightGrey.withValues(alpha: 0.1)
                        ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isPremium
                      ? kAccent.withValues(alpha: 0.3)
                      : kLightGrey.withValues(alpha: 0.5),
                  width: 1.5,
                ),
              ),
              child: Column(
                children: [
                  // Animated Tasty Avatar
                  TweenAnimationBuilder(
                    tween:
                        Tween<double>(begin: 0.8, end: isPremium ? 1.2 : 1.0),
                    duration: const Duration(seconds: 2),
                    curve: Curves.elasticOut,
                    builder: (context, double scale, child) {
                      return Transform.scale(
                        scale: scale,
                        child: Container(
                          width: isPremium
                              ? getPercentageWidth(20, context)
                              : getPercentageWidth(15, context),
                          height: isPremium
                              ? getPercentageWidth(20, context)
                              : getPercentageWidth(15, context),
                          decoration: BoxDecoration(
                            gradient: RadialGradient(
                              colors: [
                                kAccentLight.withValues(alpha: 0.8),
                                kAccent.withValues(alpha: 0.6),
                              ],
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: kAccent.withValues(alpha: 0.3),
                                blurRadius: 20,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: Container(
                            margin:
                                EdgeInsets.all(getPercentageWidth(1, context)),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              image: const DecorationImage(
                                image: AssetImage(tastyImage),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  SizedBox(height: getPercentageHeight(4, context)),

                  // Title Section
                  Text(
                    isPremium
                        ? "It's $appNameBuddy Time!"
                        : "$appNameBuddy, at your service",
                    textAlign: TextAlign.center,
                    style: textTheme.headlineMedium?.copyWith(
                      fontSize: getTextScale(5.5, context),
                      fontWeight: FontWeight.bold,
                      color: isPremium
                          ? kAccent
                          : (isDarkMode ? kWhite : kDarkGrey),
                    ),
                  ),

                  SizedBox(height: getPercentageHeight(2, context)),

                  // Description Section
                  Container(
                    padding: EdgeInsets.all(getPercentageWidth(3, context)),
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? kDarkGrey.withValues(alpha: 0.5)
                          : kWhite.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: isPremium
                            ? kAccent.withValues(alpha: 0.2)
                            : kLightGrey.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      children: [
                        if (isPremium && !mealEmpty) ...[
                          _buildFeatureItem(context, Icons.restaurant_menu,
                              "Personalized Meal Plans"),
                          _buildFeatureItem(context, Icons.psychology,
                              "AI-Powered Recommendations"),
                          _buildFeatureItem(context, Icons.trending_up,
                              "Track Your Progress"),
                        ] else if (mealEmpty) ...[
                          Text(
                            "No meal plans available \n\nTry generating a meal plan!",
                            style: textTheme.displaySmall?.copyWith(
                              color: isDarkMode ? kWhite : kDarkGrey,
                              fontSize: getTextScale(5.5, context),
                              fontWeight: FontWeight.w200,
                            ),
                          ),
                        ] else ...[
                          if (isInFreeTrial && !mealEmpty) ...[
                            Text(
                              "Free Trial Active",
                              style: textTheme.titleMedium?.copyWith(
                                color: kAccent,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(height: getPercentageHeight(1, context)),
                            Text(
                              "Enjoy premium features until ${DateFormat('MMM d, yyyy').format(freeTrialDate)}",
                              textAlign: TextAlign.center,
                              style: textTheme.bodyMedium?.copyWith(
                                color: isDarkMode
                                    ? kLightGrey
                                    : kDarkGrey.withValues(alpha: 0.7),
                              ),
                            ),
                          ] else ...[
                            Text(
                              "AI-Powered Food Coach",
                              style: textTheme.titleMedium?.copyWith(
                                color: kAccent,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(height: getPercentageHeight(1, context)),
                            Text(
                              freeTrialDate != null
                                  ? "Crafting the perfect plan for a fitter you \n\nYour free trial ended on ${DateFormat('MMM d, yyyy').format(freeTrialDate)}"
                                  : "Crafting the perfect plan for a fitter you",
                              textAlign: TextAlign.center,
                              style: textTheme.bodyMedium?.copyWith(
                                color: isDarkMode
                                    ? kLightGrey
                                    : kDarkGrey.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),

                  SizedBox(height: getPercentageHeight(4, context)),

                  // Action Button
                  Container(
                    width: double.infinity,
                    height: getPercentageHeight(6, context),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isPremium
                            ? [kAccent, kAccent.withValues(alpha: 0.5)]
                            : [
                                kAccent.withValues(alpha: 0.8),
                                kAccent.withValues(alpha: 0.6)
                              ],
                      ),
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: kAccent.withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(15),
                        onTap: () async {
                          if (canUseAI()) {
                            await _navigateToMealPlanChat(context);
                          } else {
                            showPremiumRequiredDialog(context, isDarkMode);
                          }
                        },
                        child: Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                isPremium ? Icons.auto_awesome : Icons.star,
                                color: kWhite,
                                size: getIconScale(6, context),
                              ),
                              SizedBox(width: getPercentageWidth(2, context)),
                              Text(
                                canUseAI() ? 'Get Meal Plan' : goPremium,
                                style: textTheme.titleMedium?.copyWith(
                                  color: kWhite,
                                  fontWeight: FontWeight.w600,
                                  fontSize: getTextScale(4, context),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Premium Badge for Premium Users
                  if (isPremium) ...[
                    SizedBox(height: getPercentageHeight(2, context)),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: getPercentageWidth(3, context),
                        vertical: getPercentageHeight(1, context),
                      ),
                      decoration: BoxDecoration(
                        color: kAccentLight.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: kAccentLight),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.verified,
                            color: kAccentLight,
                            size: getIconScale(5, context),
                          ),
                          SizedBox(width: getPercentageWidth(1, context)),
                          Text(
                            'Premium Member',
                            style: textTheme.bodyMedium?.copyWith(
                              color: kAccentLight,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            SizedBox(height: getPercentageHeight(6, context)),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureItem(BuildContext context, IconData icon, String text) {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding:
          EdgeInsets.symmetric(vertical: getPercentageHeight(0.5, context)),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(getPercentageWidth(1.5, context)),
            decoration: BoxDecoration(
              color: kAccent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: kAccent,
              size: getIconScale(5, context),
            ),
          ),
          SizedBox(width: getPercentageWidth(2, context)),
          Expanded(
            child: Text(
              text,
              style: textTheme.bodyMedium?.copyWith(
                color: isDarkMode ? kWhite : kDarkGrey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isDarkMode = getThemeProvider(context).isDarkMode;
    if (_buddyDataFuture == null) {
      _initializeBuddyData();
    }

    String? familyMemberGoal;
    if (familyMode && selectedUserIndex > 0) {
      final familyMembers = userService.currentUser.value?.familyMembers ?? [];
      if (selectedUserIndex - 1 < familyMembers.length) {
        familyMemberGoal = familyMembers[selectedUserIndex - 1].fitnessGoal;
      }
    }

    return Scaffold(
      floatingActionButtonLocation: CustomFloatingActionButtonLocation(
        verticalOffset: getPercentageHeight(5, context),
        horizontalOffset: getPercentageWidth(2, context),
      ),
      floatingActionButton: buildTastyFloatingActionButton(
        context: context,
        buttonKey: ValueKey('buddy_tab_button'),
        themeProvider: getThemeProvider(context),
      ),
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage(
              isDarkMode
                  ? 'assets/images/background/imagedark.jpeg'
                  : 'assets/images/background/imagelight.jpeg',
            ),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              isDarkMode
                  ? Colors.black.withOpacity(0.5)
                  : Colors.white.withOpacity(0.5),
              isDarkMode ? BlendMode.darken : BlendMode.lighten,
            ),
          ),
        ),
        child: Column(
        children: [
          // Family member selector at the top
          if (familyMode && _familyMemberCategories.isNotEmpty) ...[
            SizedBox(height: getPercentageHeight(2, context)),
            CategorySelector(
              categories: _familyMemberCategories,
              selectedCategoryId: _familyMemberCategories.isNotEmpty
                  ? _familyMemberCategories[selectedUserIndex]['id']
                  : '',
              onCategorySelected: _updateSelectedUser,
              isDarkMode: isDarkMode,
              accentColor: kAccentLight,
              darkModeAccentColor: kDarkModeAccent,
            ),
          ],

          Expanded(
            child: FutureBuilder<QuerySnapshot<Map<String, dynamic>>?>(
              future: _buddyDataFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator(color: kAccent));
                }

                // Handle errors gracefully
                if (snapshot.hasError) {
                  debugPrint('Error loading buddy data: ${snapshot.error}');
                  return _buildDefaultView(context, false);
                }

                // Handle null data (from catchError) or empty docs
                if (snapshot.data == null) {
                  return _buildDefaultView(context, false);
                }

                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return _buildDefaultView(context, false);
                }

                final isDarkMode = getThemeProvider(context).isDarkMode;
                final currentUser = userService.currentUser.value;

                // Get family member name if in family mode
                String? familyMemberName;
                if (familyMode && selectedUserIndex > 0) {
                  final familyMembers = currentUser?.familyMembers ?? [];
                  if (selectedUserIndex - 1 < familyMembers.length) {
                    familyMemberName = familyMembers[selectedUserIndex - 1].name;
                  }
                }

                // Collect all generations from all documents and filter
                allAvailableGenerations = _collectAllGenerations(
                    docs, familyMode, familyMemberName);

                if (allAvailableGenerations.isEmpty) {
                  return _buildDefaultView(context, false);
                }

                // Ensure currentGenerationIndex is within bounds
                if (currentGenerationIndex >= allAvailableGenerations.length) {
                  currentGenerationIndex = 0;
                }

                // Get the selected generation based on current index
                final selectedGeneration = allAvailableGenerations[currentGenerationIndex];

                // Fetch meals regardless of nutritional summary (summary can be calculated client-side)
                final diet =
                    selectedGeneration['diet']?.toString() ?? 'general';
                final mealsFuture =
                    _fetchMealsFromIds(selectedGeneration['mealIds']);

                return FutureBuilder<List<Map<String, dynamic>>>(
                  future: mealsFuture,
                  builder: (context, mealsSnapshot) {
                    if (mealsSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(
                          child: CircularProgressIndicator(color: kAccent));
                    }

                    if (mealsSnapshot.hasError) {
                      return Center(
                        child: Text(
                          'Error loading meals: ${mealsSnapshot.error}',
                          style:
                              TextStyle(color: isDarkMode ? kWhite : kDarkGrey),
                        ),
                      );
                    }

                    final meals = mealsSnapshot.data ?? [];
                    final nutritionalSummary =
                        geminiService.calculateNutritionalSummary(meals);

                    if (meals.isEmpty) {
                      return _buildDefaultView(context, true);
                    }

                    final groupedMeals = meals.first['groupedMeals']
                        as Map<String, List<MealWithType>>;

                    return SingleChildScrollView(
                      child: Column(
                        children: [
                          SizedBox(height: getPercentageHeight(2, context)),
                          Builder(
                            builder: (context) {
                              // final goal = userService.currentUser.value
                              //         ?.settings['fitnessGoal'] ??
                              //     'Healthy Eating';
                              String bio = getRandomMealTypeBio(
                                  familyMemberGoal ??
                                      userService.currentUser.value
                                          ?.settings['fitnessGoal'] ??
                                      'Healthy Eating',
                                  diet);
                              List<String> parts = bio.split(': ');
                              List<String> parts2 = parts[1].split('/');
                              return Column(
                                children: [
                                  Text(
                                    parts[0] + ':',
                                    textAlign: TextAlign.center,
                                    style: textTheme.displaySmall?.copyWith(
                                      color: kAccent,
                                    ),
                                  ),
                                  SizedBox(
                                      height:
                                          getPercentageHeight(0.5, context)),
                                  Center(
                                    child: Text(
                                      maxLines: 2,
                                      textAlign: TextAlign.center,
                                      overflow: TextOverflow.ellipsis,
                                      parts2.length > 1 ? parts2[0] : '',
                                      style: textTheme.bodyMedium?.copyWith(
                                        color: kLightGrey,
                                      ),
                                    ),
                                  ),
                                  Center(
                                    child: Text(
                                      maxLines: 2,
                                      textAlign: TextAlign.center,
                                      overflow: TextOverflow.ellipsis,
                                      parts2.length > 1 ? parts2[1] : '',
                                      style: textTheme.bodyMedium?.copyWith(
                                        color: kLightGrey,
                                        fontSize: getTextScale(3, context),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                          SizedBox(height: getPercentageHeight(2, context)),
                          // Generation navigation controls
                          if (allAvailableGenerations.length > 1)
                            Padding(
                              padding: EdgeInsets.symmetric(
                                  horizontal: getPercentageWidth(4, context)),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // Previous button
                                  IconButton(
                                    onPressed: currentGenerationIndex <
                                            allAvailableGenerations.length - 1
                                        ? () {
                                            setState(() {
                                              currentGenerationIndex++;
                                            });
                                          }
                                        : null,
                                    icon: Icon(
                                      Icons.arrow_back_ios,
                                      color: currentGenerationIndex <
                                              allAvailableGenerations.length - 1
                                          ? kAccent
                                          : Colors.grey,
                                    ),
                                    tooltip: 'Previous generation',
                                  ),
                                  SizedBox(width: getPercentageWidth(2, context)),
                                  // Generation indicator
                                  Text(
                                    'Generation ${currentGenerationIndex + 1} of ${allAvailableGenerations.length}',
                                    style: textTheme.bodyMedium?.copyWith(
                                      color: isDarkMode ? kWhite : kDarkGrey,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  SizedBox(width: getPercentageWidth(2, context)),
                                  // Next button
                                  IconButton(
                                    onPressed: currentGenerationIndex > 0
                                        ? () {
                                            setState(() {
                                              currentGenerationIndex--;
                                            });
                                          }
                                        : null,
                                    icon: Icon(
                                      Icons.arrow_forward_ios,
                                      color: currentGenerationIndex > 0
                                          ? kAccent
                                          : Colors.grey,
                                    ),
                                    tooltip: 'Next generation',
                                  ),
                                ],
                              ),
                            ),
                          SizedBox(height: getPercentageHeight(1, context)),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              TextButton(
                                style: TextButton.styleFrom(
                                  backgroundColor:
                                      kAccentLight.withValues(alpha: kOpacity),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                onPressed: () async {
                                  if (canUseAI()) {
                                    await _navigateToMealPlanChat(context);
                                  } else {
                                    showPremiumRequiredDialog(
                                        context, isDarkMode);
                                  }
                                },
                                child: Text(
                                  canUseAI() ? 'Generate New Meals' : goPremium,
                                  style: textTheme.labelLarge?.copyWith(
                                    color: isDarkMode ? kWhite : kBlack,
                                  ),
                                ),
                              ),
                              SizedBox(width: getPercentageWidth(2, context)),
                              const InfoIconWidget(
                                title: 'Meal Generator',
                                description:
                                    'Generate personalized 7-day meal plans',
                                details: [
                                  {
                                    'icon': Icons.calendar_month,
                                    'title': 'Weekly Planning',
                                    'description':
                                        'Generate 7 days of balanced meals',
                                    'color': kAccentLight,
                                  },
                                  {
                                    'icon': Icons.restaurant_menu,
                                    'title': 'Complete Meals',
                                    'description':
                                        'Includes protein, grain, vegetables, fruits and snacks',
                                    'color': kAccentLight,
                                  },
                                  {
                                    'icon': Icons.family_restroom,
                                    'title': 'Family Mode',
                                    'description':
                                        'Generate personalized meals for each family member',
                                    'color': kAccentLight,
                                  },
                                  {
                                    'icon': Icons.add_task,
                                    'title': 'Easy Calendar Add',
                                    'description':
                                        'Add generated meals directly to your calendar',
                                    'color': kAccentLight,
                                  },
                                ],
                                iconColor: kAccentLight,
                                tooltip: 'Meal Generator Information',
                              ),
                              SizedBox(width: getPercentageWidth(2, context)),
                            ],
                          ),
                          userService.currentUser.value?.isPremium ?? false
                              ? const SizedBox.shrink()
                              : SizedBox(
                                  height: getPercentageHeight(1, context)),
                          userService.currentUser.value?.isPremium ?? false
                              ? const SizedBox.shrink()
                              : PremiumSection(
                                  isPremium: userService
                                          .currentUser.value?.isPremium ??
                                      false,
                                  titleOne: joinChallenges,
                                  titleTwo: premium,
                                  isDiv: false,
                                ),
                          userService.currentUser.value?.isPremium ?? false
                              ? const SizedBox.shrink()
                              : SizedBox(
                                  height: getPercentageHeight(0.5, context)),

                          // ------------------------------------Premium / Ads-------------------------------------
                          SizedBox(height: getPercentageHeight(2, context)),
                          if (nutritionalSummary['totalCalories'] != 0) ...[
                            Container(
                              margin: EdgeInsets.symmetric(
                                  horizontal: getPercentageWidth(4, context)),
                              padding: EdgeInsets.symmetric(
                                  vertical: getPercentageHeight(1, context)),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: kAccentLight),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  Column(
                                    children: [
                                      Text(
                                        '${nutritionalSummary['totalCalories']}',
                                        style: textTheme.bodyLarge?.copyWith(),
                                      ),
                                      Text(
                                        'Calories',
                                        style: textTheme.bodyMedium?.copyWith(
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Column(
                                    children: [
                                      Text(
                                        '${nutritionalSummary['totalProtein']}g',
                                        style: textTheme.bodyLarge?.copyWith(),
                                      ),
                                      Text(
                                        'Protein',
                                        style: textTheme.bodyMedium?.copyWith(
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Column(
                                    children: [
                                      Text(
                                        '${nutritionalSummary['totalCarbs']}g',
                                        style: textTheme.bodyLarge?.copyWith(),
                                      ),
                                      Text(
                                        'Carbs',
                                        style: textTheme.bodyMedium?.copyWith(
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Column(
                                    children: [
                                      Text(
                                        '${nutritionalSummary['totalFat']}g',
                                        style: textTheme.bodyLarge?.copyWith(),
                                      ),
                                      Text(
                                        'Fat',
                                        style: textTheme.bodyMedium?.copyWith(
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                          SizedBox(height: getPercentageHeight(2, context)),
                          ValueListenableBuilder<Set<String>>(
                            valueListenable: selectedMealTypesNotifier,
                            builder: (context, selectedMealTypes, child) {
                              return Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  GestureDetector(
                                    onTap: () =>
                                        toggleMealTypeSelection('breakfast'),
                                    child: buildAddMealTypeLegend(
                                      context,
                                      'breakfast',
                                      isSelected: selectedMealTypes
                                          .contains('breakfast'),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () =>
                                        toggleMealTypeSelection('lunch'),
                                    child: buildAddMealTypeLegend(
                                      context,
                                      'lunch',
                                      isSelected:
                                          selectedMealTypes.contains('lunch'),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () =>
                                        toggleMealTypeSelection('dinner'),
                                    child: buildAddMealTypeLegend(
                                      context,
                                      'dinner',
                                      isSelected:
                                          selectedMealTypes.contains('dinner'),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () =>
                                        toggleMealTypeSelection('snacks'),
                                    child: buildAddMealTypeLegend(
                                      context,
                                      'snacks',
                                      isSelected:
                                          selectedMealTypes.contains('snacks'),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                          // Filterable meal lists section
                          ValueListenableBuilder<Set<String>>(
                            valueListenable: selectedMealTypesNotifier,
                            builder: (context, selectedMealTypes, child) {
                              final totalMeals =
                                  (groupedMeals['breakfast']?.length ?? 0) +
                                      (groupedMeals['lunch']?.length ?? 0) +
                                      (groupedMeals['dinner']?.length ?? 0) +
                                      (groupedMeals['snacks']?.length ?? 0) +
                                      (groupedMeals['general']?.length ?? 0) +
                                      (groupedMeals['other']?.length ?? 0);

                              final filteredBreakfast = filterMealsByType(
                                  groupedMeals['breakfast'] ?? [],
                                  selectedMealTypes);
                              final filteredLunch = filterMealsByType(
                                  groupedMeals['lunch'] ?? [],
                                  selectedMealTypes);
                              final filteredDinner = filterMealsByType(
                                  groupedMeals['dinner'] ?? [],
                                  selectedMealTypes);
                              final filteredSnacks = filterMealsByType(
                                  groupedMeals['snacks'] ?? [],
                                  selectedMealTypes);
                              final filteredGeneral = filterMealsByType(
                                  groupedMeals['general'] ?? [],
                                  selectedMealTypes);
                              final filteredOther = filterMealsByType(
                                  groupedMeals['other'] ?? [],
                                  selectedMealTypes);

                              final filteredMealsCount =
                                  filteredBreakfast.length +
                                      filteredLunch.length +
                                      filteredDinner.length +
                                      filteredSnacks.length +
                                      filteredGeneral.length +
                                      filteredOther.length;

                              final hasAnyFilteredMeals =
                                  filteredMealsCount > 0;

                              return Column(
                                children: [
                                  SizedBox(
                                      height:
                                          getPercentageHeight(0.5, context)),
                                  // Show filter status
                                  if (selectedMealTypes.isNotEmpty &&
                                      totalMeals > 0)
                                    Padding(
                                      padding: EdgeInsets.symmetric(
                                          horizontal:
                                              getPercentageWidth(4, context)),
                                      child: Text(
                                        'Showing $filteredMealsCount of $totalMeals meals',
                                        textAlign: TextAlign.center,
                                        style: textTheme.bodySmall?.copyWith(
                                          color: Colors.grey[600],
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ),
                                  SizedBox(
                                      height: getPercentageHeight(1, context)),
                                  // Meal lists
                                  if (filteredBreakfast.isNotEmpty)
                                    _buildMealsList(filteredBreakfast,
                                        'Breakfast', context),
                                  if (filteredLunch.isNotEmpty)
                                    _buildMealsList(
                                        filteredLunch, 'Lunch', context),
                                  if (filteredDinner.isNotEmpty)
                                    _buildMealsList(
                                        filteredDinner, 'Dinner', context),
                                  if (filteredSnacks.isNotEmpty)
                                    _buildMealsList(
                                        filteredSnacks, 'Snacks', context),
                                  if (filteredGeneral.isNotEmpty)
                                    _buildMealsList(filteredGeneral,
                                        'General Meals', context),
                                  if (filteredOther.isNotEmpty)
                                    _buildMealsList(
                                        filteredOther, 'Other Meals', context),
                                  // Show message when no meals match the filter
                                  if (!hasAnyFilteredMeals &&
                                      selectedMealTypes.isNotEmpty)
                                    Padding(
                                      padding: EdgeInsets.all(
                                          getPercentageWidth(4, context)),
                                      child: Center(
                                        child: Column(
                                          children: [
                                            SizedBox(
                                                height: getPercentageHeight(
                                                    2, context)),
                                            Icon(
                                              Icons.restaurant_menu,
                                              size: getPercentageWidth(
                                                  12, context),
                                              color: Colors.grey,
                                            ),
                                            SizedBox(
                                                height: getPercentageHeight(
                                                    1, context)),
                                            Text(
                                              'No meals match the current filter',
                                              textAlign: TextAlign.center,
                                              style: textTheme.bodyMedium
                                                  ?.copyWith(
                                                color: Colors.grey,
                                              ),
                                            ),
                                            SizedBox(
                                                height: getPercentageHeight(
                                                    1, context)),
                                            Text(
                                              'Try selecting different meal types above',
                                              textAlign: TextAlign.center,
                                              style:
                                                  textTheme.bodySmall?.copyWith(
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              );
                            },
                          ),
                          SizedBox(height: getPercentageHeight(13, context)),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
          ),
      ),
    );
  }

  Widget _buildMealsList(
      List<MealWithType> meals, String mealType, BuildContext context) {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    final textTheme = Theme.of(context).textTheme;

    if (meals.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.all(getPercentageWidth(4, context)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                mealType,
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isDarkMode ? kWhite : kBlack,
                ),
              ),
              Text(
                '(${meals.length})',
                style: textTheme.displaySmall?.copyWith(
                  fontSize: getTextScale(4.5, context),
                  color: kAccent,
                ),
              ),
            ],
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: meals.length,
          itemBuilder: (context, index) {
            final mealWithType = meals[index];
            final mealType = mealWithType.mealType;
            final meal = mealWithType.meal;
            final mealCategory = (meal.category?.isNotEmpty == true)
                ? meal.category!.toLowerCase()
                : (meal.type?.isNotEmpty == true)
                    ? meal.type!.toLowerCase()
                    : '';
            return Container(
              margin: EdgeInsets.symmetric(
                horizontal: getPercentageWidth(4, context),
                vertical: getPercentageHeight(1, context),
              ),
              decoration: BoxDecoration(
                color: getMealTypeColor(mealType),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                contentPadding: EdgeInsets.all(getPercentageWidth(2, context)),
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
                      getMealTypeImage(
                        mealCategory,
                      ),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                title: Text(
                  meal.title,
                  style: textTheme.bodyLarge?.copyWith(
                    color: Colors.white,
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
                      '${meal.calories} kcal',
                      style: textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
                trailing: IconButton(
                  icon: Icon(
                    Icons.add_circle_outline,
                    color: Colors.white,
                    size: getPercentageWidth(6, context),
                  ),
                  onPressed: () => _showAddToMealPlanDialog(
                      context, meal, mealType, isDarkMode),
                ),
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
              ),
            );
          },
        ),
      ],
    );
  }

  Future<void> _showAddToMealPlanDialog(BuildContext context, Meal meal,
      String mealTypeVariable, bool isDarkMode) async {
    final textTheme = Theme.of(context).textTheme;
    final DateTime now = DateTime.now();

    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: getDatePickerTheme(context, isDarkMode),
          child: child!,
        );
      },
    );

    if (pickedDate != null && context.mounted) {
      final formattedDate = DateFormat('yyyy-MM-dd').format(pickedDate);

      // Show meal type selection dialog
      final mealType = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          backgroundColor: isDarkMode ? kDarkGrey : kWhite,
          title: Text(
            'Select Meal Type',
            style: textTheme.titleLarge?.copyWith(
              color: isDarkMode ? kWhite : kBlack,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(
                  'Breakfast',
                  style: textTheme.bodyMedium?.copyWith(
                    color: mealTypeVariable.toLowerCase() == 'breakfast'
                        ? kAccent
                        : null,
                  ),
                ),
                onTap: () => Navigator.pop(context, 'breakfast'),
              ),
              ListTile(
                title: Text(
                  'Lunch',
                  style: textTheme.bodyMedium?.copyWith(
                    color: mealTypeVariable.toLowerCase() == 'lunch'
                        ? kAccent
                        : null,
                  ),
                ),
                onTap: () => Navigator.pop(context, 'lunch'),
              ),
              ListTile(
                title: Text(
                  'Dinner',
                  style: textTheme.bodyMedium?.copyWith(
                    color: mealTypeVariable.toLowerCase() == 'dinner'
                        ? kAccent
                        : null,
                  ),
                ),
                onTap: () => Navigator.pop(context, 'dinner'),
              ),
              ListTile(
                title: Text(
                  'Snacks',
                  style: textTheme.bodyMedium?.copyWith(
                    color: mealTypeVariable.toLowerCase() == 'snacks'
                        ? kAccent
                        : null,
                  ),
                ),
                onTap: () => Navigator.pop(context, 'snacks'),
              ),
            ],
          ),
        ),
      );

      if (mealType != null && context.mounted) {
        // Get family member name if in family mode
        String familyMemberName = '';
        if (familyMode &&
            selectedUserIndex > 0 &&
            _familyMemberCategories.isNotEmpty) {
          familyMemberName =
              _familyMemberCategories[selectedUserIndex]['name'] ?? '';
        }

        // Create meal ID with format: "mealid/mealtype/familyname"
        String mealId;
        if (familyMode && familyMemberName.isNotEmpty) {
          mealId = '${meal.mealId}/$mealType/$familyMemberName';
        } else {
          mealId = '${meal.mealId}/$mealType';
        }

        try {
        await helperController.saveMealPlanBuddy(
          userService.userId ?? '',
          formattedDate,
          'chef_tasty',
          [mealId],
        );

        if (context.mounted) {
          String successMessage =
              'Meal added to ${DateFormat('MMM d').format(pickedDate)} as ${getMealTypeLabel(mealType)}';
          if (familyMode && familyMemberName.isNotEmpty) {
            successMessage += ' for $familyMemberName';
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(successMessage),
                backgroundColor: kAccent,
            ),
          );
          }
        } catch (e) {
          debugPrint('Error saving meal to calendar: $e');
          if (context.mounted) {
            _handleError('Failed to add meal to calendar. Please try again.',
                details: e.toString());
          }
        }
      }
    }
  }
}
