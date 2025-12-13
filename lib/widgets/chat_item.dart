import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../constants.dart';
import '../detail_screen/challenge_detail_screen.dart';
import '../detail_screen/recipe_detail.dart';
import '../helper/utils.dart';
import '../pages/program_progress_screen.dart';
import '../service/chat_controller.dart';
import '../service/chat_utilities.dart';
import '../service/buddy_chat_controller.dart';
import '../service/meal_manager.dart';
import '../service/program_service.dart';
import '../service/meal_planning_service.dart';
import '../widgets/bottom_nav.dart';

class ChatItem extends StatelessWidget {
  final ChatScreenData dataSrc;
  final bool isMe;
  final dynamic chatController; // Can be ChatController or BuddyChatController
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

    // Detect chat type: buddy chat (AI) vs friend chat
    final isBuddyChat = chatController is BuddyChatController;

    List<String> extractedItems = extractSlashedItems(dataSrc.messageContent);

    if (extractedItems.isEmpty) {
      extractedItems.add(dataSrc.messageId);
      extractedItems.add('name');
      extractedItems.add('post');
    }

    // Recipe share logic ONLY applies to friend chats, not buddy chats
    // Recipe share: last item is 'share_recipe' AND 'private' is NOT in items
    // If 'private' is present, it's a regular post share, not a recipe share
    final isRecipeShare = !isBuddyChat && // Only check for friend chats
        extractedItems.isNotEmpty &&
        extractedItems.last == 'share_recipe' &&
        !extractedItems.contains('private');

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
              // Display Images if any OR fetch recipe image for recipe shares (friend chats only)
              // For buddy chats: only show if imageUrls exist (no recipe share logic)
              // For friend chats: show if imageUrls exist OR it's a recipe share
              if (dataSrc.imageUrls.isNotEmpty ||
                  (!isBuddyChat && isRecipeShare))
                _buildRecipeImage(context, extractedItems),

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

              // Display message text content
              // For buddy chats: always show text
              // For friend chats: show text unless it's a recipe share
              if (dataSrc.messageContent.isNotEmpty &&
                  (isBuddyChat || !isRecipeShare))
                _buildMessageText(context, isDarkMode, textTheme,
                    extractedItems, isBuddyChat),

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

  Widget _buildRecipeImage(BuildContext context, List<String> extractedItems) {
    // Detect chat type: buddy chat (AI) vs friend chat
    final isBuddyChat = chatController is BuddyChatController;

    // Recipe share logic ONLY applies to friend chats, not buddy chats
    // Recipe share: last item is 'share_recipe' AND 'private' is NOT in items
    // If 'private' is present, it's a regular post share, not a recipe share
    final isRecipeShare = !isBuddyChat && // Only check for friend chats
        extractedItems.isNotEmpty &&
        extractedItems.last == 'share_recipe' &&
        extractedItems.last != 'private';

    // Helper function to get mealId with fallback
    String? getMealId() {
      final messageContent = dataSrc.messageContent;

      // Message format: "Shared caption: Title /mealId /Title /share_recipe"
      // The mealId is the alphanumeric segment between slashes that appears after the title
      // We need to handle cases where the title itself contains slashes

      // First, try to extract from extractedItems if available
      if (extractedItems.isNotEmpty) {
        // The mealId should be an alphanumeric string (typically looks like an ID)
        // It's usually the first or second item that matches the pattern
        for (var item in extractedItems) {
          final trimmed = item.trim();
          // MealId is typically alphanumeric, 10-30 chars, no spaces
          if (trimmed.isNotEmpty &&
              trimmed.length >= 10 &&
              trimmed.length <= 30 &&
              !trimmed.contains(' ') &&
              RegExp(r'^[a-zA-Z0-9]+$').hasMatch(trimmed) &&
              trimmed != 'share_recipe') {
            return trimmed;
          }
        }
      }

      // Fallback: Use regex to find mealId pattern
      // Look for pattern: /[alphanumeric-id] / where the id is between 10-30 chars
      // This should match the mealId even if title has slashes
      final mealIdPattern = RegExp(r' /([a-zA-Z0-9]{10,30}) /');
      final mealIdMatch = mealIdPattern.firstMatch(messageContent);
      if (mealIdMatch != null && mealIdMatch.group(1) != null) {
        final extracted = mealIdMatch.group(1)!.trim();
        return extracted;
      }

      // Last resort: Try to find the segment that looks like an ID
      // Split by space-slash-space pattern to handle titles with slashes
      final segments = messageContent.split(RegExp(r' /'));
      for (var segment in segments) {
        final trimmed = segment.trim();
        // Check if it looks like a mealId (alphanumeric, 10-30 chars, no spaces)
        if (trimmed.isNotEmpty &&
            trimmed.length >= 10 &&
            trimmed.length <= 30 &&
            !trimmed.contains(' ') &&
            RegExp(r'^[a-zA-Z0-9]+$').hasMatch(trimmed) &&
            trimmed != 'share_recipe' &&
            !trimmed.toLowerCase().contains('shared caption')) {
          return trimmed;
        }
      }

      return null;
    }

    // Cache the mealId to prevent multiple extractions and continuous rebuilds
    final cachedMealId = getMealId();

    // If we have image URLs for non-recipe shares, display them
    // Recipe shares will show a button instead
    if (dataSrc.imageUrls.isNotEmpty && !isRecipeShare) {
      return Column(
        children: dataSrc.imageUrls.map((url) {
          return Padding(
            padding: EdgeInsets.only(bottom: getPercentageHeight(0.8, context)),
            child: GestureDetector(
              onTap: () {
                if (isRecipeShare) {
                  final mealId = getMealId();
                  if (mealId == null || mealId.isEmpty) {
                    return;
                  }
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => RecipeDetailScreen(
                        mealId: mealId,
                        screen: extractedItems.isNotEmpty
                            ? extractedItems.last
                            : 'share_recipe',
                      ),
                    ),
                  );
                } else if (extractedItems.isNotEmpty &&
                    extractedItems.last == 'post') {
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
                borderRadius:
                    BorderRadius.circular(getPercentageWidth(1, context)),
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
                        filterQuality:
                            FilterQuality.high, // High quality rendering
                        color: null, // No color tinting
                      ),
              ),
            ),
          );
        }).toList(),
      );
    }

    // For recipe shares, show a simple button with caption
    if (isRecipeShare) {
      if (cachedMealId == null || cachedMealId.isEmpty) {
        return const SizedBox.shrink();
      }

      // Extract recipe title from message (text before first slash)
      final recipeTitle = getTextBeforeSlash(dataSrc.messageContent)
          .replaceAll('Shared caption:', '')
          .trim();

      final isDarkMode = getThemeProvider(context).isDarkMode;
      final textTheme = Theme.of(context).textTheme;

      return Padding(
        padding: EdgeInsets.only(bottom: getPercentageHeight(0.8, context)),
        child: Container(
          decoration: BoxDecoration(
            color: isDarkMode
                ? kAccentLight.withValues(alpha: 0.15)
                : kAccentLight.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(getPercentageWidth(2, context)),
            border: Border.all(
              color: kAccent.withValues(alpha: 0.3),
              width: 1.5,
            ),
          ),
          child: Padding(
            padding: EdgeInsets.all(getPercentageWidth(3, context)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Recipe icon and title
                Row(
                  children: [
                    Icon(
                      Icons.restaurant_menu,
                      color: kAccent,
                      size: getPercentageWidth(6, context),
                    ),
                    SizedBox(width: getPercentageWidth(2, context)),
                    Expanded(
                      child: Text(
                        recipeTitle.isNotEmpty ? recipeTitle : 'Shared Recipe',
                        style: textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isDarkMode ? kWhite : kBlack,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: getPercentageHeight(2, context)),
                // View Recipe button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => RecipeDetailScreen(
                            mealId: cachedMealId,
                            screen: extractedItems.isNotEmpty
                                ? extractedItems.last
                                : 'share_recipe',
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kAccent,
                      foregroundColor: kWhite,
                      padding: EdgeInsets.symmetric(
                        vertical: getPercentageHeight(1.5, context),
                        horizontal: getPercentageWidth(4, context),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                            getPercentageWidth(2, context)),
                      ),
                      elevation: 2,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.visibility,
                          size: getPercentageWidth(5, context),
                        ),
                        SizedBox(width: getPercentageWidth(2, context)),
                        Text(
                          'View Recipe',
                          style: textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: kWhite,
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
    }

    return const SizedBox.shrink();
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
                      // Only ChatController has acceptCalendarShare (for friend chats)
                      if (chatController is ChatController) {
                        chatController.acceptCalendarShare(dataSrc.messageId);
                      }
                    } catch (e) {
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

  Widget _buildMessageText(BuildContext context, bool isDarkMode,
      TextTheme textTheme, List<String> extractedItems, bool isBuddyChat) {
    // For buddy chats: always show message text (no recipe share logic)
    // For friend chats: check if it's a recipe share
    if (!isBuddyChat) {
      // Recipe share logic ONLY for friend chats
      // Recipe share: last item is 'share_recipe' AND 'private' is NOT in items
      final isRecipeShare = extractedItems.isNotEmpty &&
          extractedItems.last == 'share_recipe' &&
          !extractedItems.contains('private');

      // For recipe shares in friend chats, hide the text (show button only)
      if (isRecipeShare) {
        return const SizedBox.shrink();
      }
    }

    // Get the message content
    String messageText = dataSrc.messageContent;

    // If message is empty, don't display anything
    if (messageText.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: EdgeInsets.only(
        bottom: getPercentageHeight(0.8, context),
      ),
      child: SelectableText(
        messageText,
        style: textTheme.bodyMedium?.copyWith(
          color: isDarkMode ? Colors.white : Colors.black87,
        ),
      ),
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
        // ProgramService instance getter handles registration
        ProgramService.instance;

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
          // Fallback: navigate to meal design screen without specifying tab
          try {
            Get.offAll(() => const BottomNavSec(selectedIndex: 4));
          } catch (e2) {
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
              // Fallback: navigate to meal design screen without specifying tab
              try {
                Get.offAll(() => const BottomNavSec(selectedIndex: 4));
              } catch (e2) {
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
