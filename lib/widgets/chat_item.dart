import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:tasteturner/data_models/meal_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../constants.dart';
import '../detail_screen/challenge_detail_screen.dart';
import '../detail_screen/recipe_detail.dart';
import '../helper/utils.dart';
import '../pages/program_progress_screen.dart';
import '../service/chat_controller.dart';
import '../service/meal_manager.dart';
import '../service/program_service.dart';
import '../service/meal_planning_service.dart';
import '../widgets/bottom_nav.dart';

class ChatItem extends StatelessWidget {
  final ChatScreenData dataSrc;
  final bool isMe;
  final ChatController chatController;
  final String chatId;

  const ChatItem({
    super.key,
    required this.dataSrc,
    required this.isMe,
    required this.chatController,
    required this.chatId,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    final textTheme = Theme.of(context).textTheme;
    double screenWidth = MediaQuery.of(context).size.width;
    List<String> extractedItems = extractSlashedItems(dataSrc.messageContent);
    if (extractedItems.isEmpty) {
      extractedItems.add(dataSrc.messageId);
      extractedItems.add('name');
      extractedItems.add('post');
    }
    return Container(
      padding: EdgeInsets.only(
          left: getPercentageWidth(4, context),
          right: getPercentageWidth(2, context),
          bottom: getPercentageHeight(1.6, context)),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: BoxConstraints(maxWidth: screenWidth * 0.9),
          padding: EdgeInsets.all(getPercentageWidth(1.2, context)),
          decoration: BoxDecoration(
            color: isMe
                ? kAccentLight.withValues(alpha: 0.2)
                : (isDarkMode
                    ? Colors.white12
                    : Colors.black.withValues(alpha: 0.05)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment:
                isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              // Display Images if any
              if (dataSrc.imageUrls.isNotEmpty)
                Column(
                  children: dataSrc.imageUrls.map((url) {
                    return Padding(
                      padding: EdgeInsets.only(
                          bottom: getPercentageHeight(0.8, context)),
                      child: GestureDetector(
                        onTap: () {
                          if (extractedItems.isNotEmpty &&
                              extractedItems.last == 'share_recipe') {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (context) => RecipeDetailScreen(
                                  mealData:
                                      Meal.fromJson(extractedItems[0], {}),
                                  screen: extractedItems.last,
                                ),
                              ),
                            );
                          } else if (extractedItems.isNotEmpty &&
                              extractedItems.last == 'post') {
                            // Navigate to PostDetailScreen
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ChallengeDetailScreen(
                                  dataSrc: dataSrc.toMap(),
                                  screen: 'myPost',
                                ),
                              ),
                            );
                          } else {
                            // Navigate to ChallengeDetailScreen
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ChallengeDetailScreen(
                                  screen: extractedItems.isNotEmpty
                                      ? extractedItems.last
                                      : 'post',
                                  dataSrc: dataSrc.toMap(),
                                  isMessage: true,
                                ),
                              ),
                            );
                          }
                        },
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(
                              getPercentageWidth(1, context)),
                          child: url.contains('http')
                              ? buildOptimizedNetworkImage(
                                  imageUrl: url,
                                  height: getPercentageHeight(20, context),
                                  width: getPercentageWidth(60, context),
                                  fit: BoxFit.cover,
                                  borderRadius: BorderRadius.circular(
                                      getPercentageWidth(1, context)),
                                )
                              : Image.asset(
                                  height: getPercentageHeight(30, context),
                                  width: getPercentageWidth(70, context),
                                  getAssetImageForItem(url),
                                  fit: BoxFit.cover,
                                ),
                        ),
                      ),
                    );
                  }).toList(),
                ),

              // Show Text if Available
              if (dataSrc.messageContent.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(
                      bottom: dataSrc.actionButtons != null &&
                              dataSrc.actionButtons!.isNotEmpty
                          ? getPercentageHeight(0.5, context)
                          : 0),
                  child: Text(
                    // Show full content for buddy messages (AI responses) to prevent truncation
                    // Only use getTextBeforeSlash for special formatted messages (with navigation)
                    // For regular messages with action buttons or buddy messages, show full content
                    (dataSrc.actionButtons != null &&
                                dataSrc.actionButtons!.isNotEmpty) ||
                            dataSrc.senderId == 'buddy'
                        ? dataSrc.messageContent.replaceAll('00:00:00.000 ', '')
                        : getTextBeforeSlash(dataSrc.messageContent
                            .replaceAll('00:00:00.000 ', '')),
                    style: textTheme.bodyMedium?.copyWith(),
                    softWrap: true,
                    overflow: TextOverflow.visible,
                  ),
                ),

              // Show Action Buttons if available
              if (dataSrc.actionButtons != null)
                _buildActionButtons(
                    context, dataSrc.actionButtons!, isDarkMode),

              // Show Calendar Share Request if available
              if (dataSrc.shareRequest != null)
                _buildShareRequest(context, isDarkMode, textTheme),

              // Show Friend Request if available
              if (dataSrc.friendRequest != null)
                _buildFriendRequest(
                    context, isDarkMode, chatId, dataSrc.messageId, textTheme),

              SizedBox(height: getPercentageHeight(0.5, context)),

              // Timestamp & Read Status
              Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    DateFormat('hh:mm a').format(dataSrc.timestamp.toDate()),
                    style: textTheme.bodySmall?.copyWith(color: kAccentLight),
                  ),
                  if (isMe) SizedBox(width: getPercentageWidth(1, context)),
                  if (isMe)
                    Icon(
                      Icons.done_all,
                      size: getPercentageWidth(3, context),
                      color: kAccent,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Parse and format date string safely
  String _formatDateString(String? dateString) {
    if (dateString == null || dateString.isEmpty) {
      return 'Unknown date';
    }
    try {
      return DateFormat('MMM d, yyyy').format(DateTime.parse(dateString));
    } catch (e) {
      debugPrint('Error parsing date: $e');
      return dateString; // Return original string if parsing fails
    }
  }

  Widget _buildFriendRequest(BuildContext context, bool isDarkMode,
      String chatId, String messageId, TextTheme textTheme) {
    final friendRequest = dataSrc.friendRequest!;
    final status = friendRequest['status'] as String? ?? 'pending';
    final friendName = userService.currentUser.value?.displayName ?? 'Friend';
    final date = friendRequest['date'] as String?;
    final formattedDate = _formatDateString(date);

    return Container(
      margin: EdgeInsets.symmetric(
          vertical: getPercentageHeight(0.8, context), horizontal: 0),
      padding: EdgeInsets.all(getPercentageWidth(1.2, context)),
      decoration: BoxDecoration(
        color: isDarkMode ? kDarkGrey : kAccentLight.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kAccent.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.person_add_alt_1_outlined,
                  size: getPercentageWidth(2, context), color: kAccent),
              SizedBox(width: getPercentageWidth(1, context)),
              Expanded(
                child: Text(
                  '$friendName wants to be your friend',
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: kAccent,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (status == 'pending')
                TextButton(
                  onPressed: () async {
                    // Accept friend request logic
                    await ChatController.instance.acceptFriendRequest(
                      chatId,
                      messageId,
                    );
                  },
                  child: Text('Accept', style: textTheme.bodySmall?.copyWith()),
                  style: TextButton.styleFrom(
                      foregroundColor: isDarkMode ? kWhite : kDarkGrey),
                ),
              if (status == 'accepted')
                Padding(
                  padding:
                      EdgeInsets.only(left: getPercentageWidth(1, context)),
                  child: Text('Accepted',
                      style: textTheme.bodySmall?.copyWith(color: kAccent)),
                ),
            ],
          ),
          if (date != null && date.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(top: getPercentageHeight(1, context)),
              child: Text(
                'Requested on $formattedDate',
                style: textTheme.bodySmall?.copyWith(),
              ),
            ),
        ],
      ),
    );
  }

  /// Parse share request date with multiple format support
  String _parseShareRequestDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) {
      return '';
    }
    try {
      // If date is in ISO format (yyyy-MM-dd), parse and format it
      if (RegExp(r'\d{4}-\d{2}-\d{2}').hasMatch(dateString)) {
        return DateFormat('MMM d, yyyy').format(DateTime.parse(dateString));
      } else {
        // Already in display format, return as is
        return dateString;
      }
    } catch (e) {
      debugPrint('Error parsing share request date: $e');
      return dateString; // Fallback to raw string
    }
  }

  Widget _buildShareRequest(
      BuildContext context, bool isDarkMode, TextTheme textTheme) {
    final shareRequest = dataSrc.shareRequest!;
    final status = shareRequest['status'] as String;
    final type = shareRequest['type'] as String;
    final date = shareRequest['date'] as String?;
    final formattedDate = _parseShareRequestDate(date);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              type == 'entire_calendar' ? Icons.calendar_month : Icons.today,
              size: getPercentageWidth(3, context),
              color: kAccent,
            ),
            SizedBox(width: getPercentageWidth(1, context)),
            Text(
              type == 'entire_calendar' ? 'Calendar Share' : 'Day Share',
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: kAccent,
              ),
            ),
          ],
        ),
        if (date != null)
          Padding(
            padding: EdgeInsets.only(top: getPercentageHeight(1, context)),
            child: Text(
              'Date: $formattedDate',
              style: textTheme.bodySmall?.copyWith(),
            ),
          ),
        if (!isMe && status == 'pending')
          Padding(
            padding: EdgeInsets.only(top: getPercentageHeight(1, context)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  onPressed: () {
                    try {
                      chatController.acceptCalendarShare(dataSrc.messageId);
                    } catch (e) {
                      debugPrint('Error accepting calendar share: $e');
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              'Failed to accept calendar share. Please try again.'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                  style: TextButton.styleFrom(
                    backgroundColor: kAccent.withValues(alpha: 0.1),
                    padding: EdgeInsets.symmetric(
                        horizontal: getPercentageWidth(1.2, context),
                        vertical: getPercentageHeight(0.6, context)),
                  ),
                  child: Text(
                    'Accept',
                    style: textTheme.bodySmall?.copyWith(color: kAccent),
                  ),
                ),
              ],
            ),
          ),
        if (status == 'accepted')
          Padding(
            padding: EdgeInsets.only(top: getPercentageHeight(1, context)),
            child: Text(
              'Accepted',
              style: textTheme.bodySmall?.copyWith(
                color: Colors.green[400],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context,
      Map<String, dynamic> actionButtons, bool isDarkMode) {
    return Container(
      margin: EdgeInsets.only(top: getPercentageHeight(1, context)),
      child: Wrap(
        spacing: getPercentageWidth(2, context),
        runSpacing: getPercentageHeight(0.8, context),
        children: [
          if (actionButtons['viewPlan'] != null)
            _buildViewPlanButton(context, actionButtons, isDarkMode),
          if (actionButtons['viewMealPlan'] != null)
            _buildViewMealPlanButton(context, isDarkMode),
          if (actionButtons['viewMeals'] == true ||
              actionButtons['viewMeals'] == 'true')
            _buildViewMealsButton(context, actionButtons, isDarkMode),
          if (actionButtons['saveToCalendar'] == true ||
              actionButtons['saveToCalendar'] == 'true')
            _buildSaveToCalendarButton(context, actionButtons, isDarkMode),
        ],
      ),
    );
  }

  Widget _buildViewPlanButton(BuildContext context,
      Map<String, dynamic> actionButtons, bool isDarkMode) {
    return ElevatedButton.icon(
      onPressed: () {
        // Ensure ProgramService is initialized before navigating
        try {
          Get.find<ProgramService>();
        } catch (e) {
          Get.put(ProgramService());
        }

        final programId = actionButtons['viewPlan'] as String;
        Get.to(() => ProgramProgressScreen(
              programId: programId,
            ));
      },
      icon: const Icon(Icons.fitness_center, size: 16),
      label: const Text('View Plan'),
      style: ElevatedButton.styleFrom(
        backgroundColor: kAccent,
        foregroundColor: kWhite,
        padding: EdgeInsets.symmetric(
          horizontal: getPercentageWidth(3, context),
          vertical: getPercentageHeight(0.8, context),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }

  Widget _buildViewMealPlanButton(BuildContext context, bool isDarkMode) {
    return ElevatedButton.icon(
      onPressed: () {
        try {
          // Navigate to MealDesignScreen (index 4) and switch to buddy tab (tab index 1)
          Get.offAll(() =>
              const BottomNavSec(selectedIndex: 4, foodScreenTabIndex: 1));
        } catch (e) {
          debugPrint('Error navigating to meal plan: $e');
          // Fallback: navigate to meal design screen without specifying tab
          try {
            Get.offAll(() => const BottomNavSec(selectedIndex: 4));
          } catch (e2) {
            debugPrint('Error with fallback navigation: $e2');
            Get.snackbar(
              'Navigation Error',
              'Unable to open meal plan. Please navigate manually.',
              backgroundColor: Colors.red,
              colorText: Colors.white,
            );
          }
        }
      },
      icon: const Icon(Icons.restaurant_menu, size: 16),
      label: const Text('View Meal Plan'),
      style: ElevatedButton.styleFrom(
        backgroundColor: kAccentLight,
        foregroundColor: kWhite,
        padding: EdgeInsets.symmetric(
          horizontal: getPercentageWidth(3, context),
          vertical: getPercentageHeight(0.8, context),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }

  Widget _buildViewMealsButton(BuildContext context,
      Map<String, dynamic> actionButtons, bool isDarkMode) {
    return Builder(
      builder: (context) {
        // Check if we have mealIds and if it's a single meal
        final mealIds = actionButtons['mealIds'] as List<dynamic>?;
        final isSingleMeal = mealIds != null && mealIds.length == 1;

        return ElevatedButton.icon(
          onPressed: () async {
            try {
              if (isSingleMeal) {
                // Single meal: Navigate to recipe detail screen
                final mealId = mealIds[0].toString();
                // Extract meal ID if it has suffix (e.g., "mealId/bf" -> "mealId")
                final cleanMealId = mealId.split('/').first;

                // Get meal data
                final meal =
                    await MealManager.instance.getMealbyMealID(cleanMealId);
                if (meal != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => RecipeDetailScreen(
                        mealData: meal,
                      ),
                    ),
                  );
                } else {
                  Get.snackbar(
                    'Error',
                    'Meal not found. Please try again.',
                    backgroundColor: Colors.red,
                    colorText: Colors.white,
                  );
                }
              } else {
                // Multiple meals: Navigate to buddy tab (index 4 in bottom nav, tab index 1 for buddy tab)
                Get.offAll(() => const BottomNavSec(
                      selectedIndex: 4,
                      foodScreenTabIndex: 1,
                    ));
              }
            } catch (e) {
              debugPrint('Error navigating: $e');
              // Fallback: navigate to meal design screen without specifying tab
              try {
                Get.offAll(() => const BottomNavSec(selectedIndex: 4));
              } catch (e2) {
                debugPrint('Error with fallback navigation: $e2');
                Get.snackbar(
                  'Navigation Error',
                  'Unable to open meal. Please navigate manually.',
                  backgroundColor: Colors.red,
                  colorText: Colors.white,
                );
              }
            }
          },
          icon: Icon(isSingleMeal ? Icons.restaurant : Icons.restaurant_menu,
              size: 16),
          label: Text(isSingleMeal ? 'View Recipe' : 'View Meals'),
          style: ElevatedButton.styleFrom(
            backgroundColor: kAccent,
            foregroundColor: kWhite,
            padding: EdgeInsets.symmetric(
              horizontal: getPercentageWidth(3, context),
              vertical: getPercentageHeight(0.8, context),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSaveToCalendarButton(BuildContext context,
      Map<String, dynamic> actionButtons, bool isDarkMode) {
    return Builder(
      builder: (context) {
        return ElevatedButton.icon(
          onPressed: () async {
            try {
              final remixedMealId = actionButtons['remixedMealId'] as String?;
              final remixResponse = actionButtons['remixResponse'] as String?;
              final originalMealTitle =
                  actionButtons['originalMealTitle'] as String? ?? 'Meal';

              if (remixedMealId == null || remixResponse == null) {
                showTastySnackbar(
                  'Error',
                  'Missing meal information. Please try again.',
                  context,
                  backgroundColor: Colors.red,
                );
                return;
              }

              // Get original meal data
              final originalMeal =
                  await MealManager.instance.getMealbyMealID(remixedMealId);
              if (originalMeal == null) {
                showTastySnackbar(
                  'Error',
                  'Original meal not found. Please try again.',
                  context,
                  backgroundColor: Colors.red,
                );
                return;
              }

              // Use today's date automatically
              final today = DateTime.now();

              // Show meal type selection dialog
              final textTheme = Theme.of(context).textTheme;
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
                          style: TextStyle(
                            color: isDarkMode ? kWhite : kBlack,
                          ),
                        ),
                        onTap: () => Navigator.pop(context, 'breakfast'),
                      ),
                      ListTile(
                        title: Text(
                          'Lunch',
                          style: TextStyle(
                            color: isDarkMode ? kWhite : kBlack,
                          ),
                        ),
                        onTap: () => Navigator.pop(context, 'lunch'),
                      ),
                      ListTile(
                        title: Text(
                          'Dinner',
                          style: TextStyle(
                            color: isDarkMode ? kWhite : kBlack,
                          ),
                        ),
                        onTap: () => Navigator.pop(context, 'dinner'),
                      ),
                      ListTile(
                        title: Text(
                          'Snack',
                          style: TextStyle(
                            color: isDarkMode ? kWhite : kBlack,
                          ),
                        ),
                        onTap: () => Navigator.pop(context, 'snack'),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: isDarkMode ? kLightGrey : kDarkGrey,
                        ),
                      ),
                    ),
                  ],
                ),
              );

              if (mealType == null || !context.mounted) return;

              // Create new remixed meal
              final newMealId = const Uuid().v4();
              final remixedMealData = {
                'mealId': newMealId,
                'userId': userService.userId ?? '',
                'title': 'Remixed: $originalMealTitle',
                'description': remixResponse,
                'createdAt': FieldValue.serverTimestamp(),
                'mediaPaths': originalMeal.mediaPaths.isNotEmpty
                    ? originalMeal.mediaPaths
                    : [],
                'serveQty': originalMeal.serveQty,
                'calories': originalMeal.calories,
                'ingredients': originalMeal.ingredients,
                'nutritionalInfo': originalMeal.nutritionalInfo,
                'instructions': [remixResponse],
                'categories': ['remix', ...originalMeal.categories],
                'mealType': mealType,
                'source': 'remix',
                'originalMealId': remixedMealId,
                'type': mealType,
              };

              // Save remixed meal to Firestore
              await firestore
                  .collection('meals')
                  .doc(newMealId)
                  .set(remixedMealData);

              // Save to calendar (using today's date)
              final mealPlanningService = MealPlanningService.instance;
              final success = await mealPlanningService.addMealToCalendar(
                [newMealId],
                today,
                mealType: mealType,
              );

              if (success && context.mounted) {
                showTastySnackbar(
                  'Success',
                  'Remixed meal saved to today\'s calendar!',
                  context,
                  backgroundColor: Colors.green,
                );
              } else if (context.mounted) {
                showTastySnackbar(
                  'Error',
                  'Failed to save to calendar. Please try again.',
                  context,
                  backgroundColor: Colors.red,
                );
              }
            } catch (e) {
              debugPrint('Error saving remixed meal to calendar: $e');
              if (context.mounted) {
                showTastySnackbar(
                  'Error',
                  'Failed to save meal. Please try again.',
                  context,
                  backgroundColor: Colors.red,
                );
              }
            }
          },
          icon: const Icon(Icons.calendar_today, size: 16),
          label: const Text('Save to Calendar'),
          style: ElevatedButton.styleFrom(
            backgroundColor: kAccent,
            foregroundColor: kWhite,
            padding: EdgeInsets.symmetric(
              horizontal: getPercentageWidth(3, context),
              vertical: getPercentageHeight(0.8, context),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        );
      },
    );
  }
}
