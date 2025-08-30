import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:tasteturner/data_models/meal_model.dart';
import '../constants.dart';
import '../data_models/user_data_model.dart';
import '../detail_screen/challenge_detail_screen.dart';
import '../detail_screen/recipe_detail.dart';
import '../helper/utils.dart';
import '../pages/photo_manager.dart';
import '../pages/safe_text_field.dart';
import '../service/chat_controller.dart';

import '../widgets/icon_widget.dart';
import 'user_profile_screen.dart';

class ChatScreen extends StatefulWidget {
  final String? chatId;
  final String? friendId;
  final String? screen;
  final Map<String, dynamic>? dataSrc;
  final UserModel? friend;

  const ChatScreen({
    super.key,
    this.chatId,
    this.friendId,
    this.dataSrc,
    this.screen,
    this.friend,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController textController = TextEditingController();
  late final ChatController chatController;

  late String? chatId;
  @override
  void initState() {
    super.initState();
    // Initialize ChatController
    try {
      chatController = Get.find<ChatController>();
    } catch (e) {
      // If controller is not found, initialize it
      chatController = Get.put(ChatController());
    }

    chatId = widget.chatId;

    if (chatId != null && chatId!.isNotEmpty) {
      chatController.chatId = chatId!;
      chatController.listenToMessages();
      chatController.markMessagesAsRead(chatId!, widget.friendId!);

      if (widget.dataSrc != null && widget.dataSrc!.isNotEmpty) {
        if (widget.dataSrc?['screen'] == 'meal_design') {
          _handleCalendarShare(widget.dataSrc!);
        } else if (widget.dataSrc?['mediaPaths'] != null) {
          _shareImage(widget.dataSrc?['mediaPaths'][0]);
        }
      }
    } else if (widget.friendId != null) {
      chatController.initializeChat(widget.friendId!).then((_) {
        setState(() {
          chatId = chatController.chatId;
        });
        chatController.markMessagesAsRead(chatId!, widget.friendId!);

        if (widget.dataSrc != null && widget.dataSrc!.isNotEmpty) {
          if (widget.dataSrc?['screen'] == 'meal_design') {
            _handleCalendarShare(widget.dataSrc!);
          } else if (widget.dataSrc?['mediaPaths'] != null) {
            _shareImage(
                widget.dataSrc?['mediaPaths'][0] ?? widget.dataSrc?['image']);
          }
        }
      });
    }
  }

  void _shareImage(String imageUrl) {
    String message = '';
    if (widget.screen == 'battle_post') {
      message =
          'Shared from ${capitalizeFirstLetter(widget.dataSrc?['name'])} for ${capitalizeFirstLetter(widget.dataSrc?['category'])} Battle /${widget.dataSrc?['id']} /${widget.dataSrc?['name']} /${widget.screen}';
    } else if (widget.screen == 'share_recipe') {
      message =
          'Shared caption: ${capitalizeFirstLetter(widget.dataSrc?['title'])} /${widget.dataSrc?['mealId']} /${widget.dataSrc?['title']} /${widget.screen}';
    } else {
      message =
          'Shared caption: ${capitalizeFirstLetter(widget.dataSrc?['title'])} /${widget.dataSrc?['id']} /${widget.dataSrc?['title']} /${widget.screen}';
    }

    chatController.sendMessage(
      messageContent: message,
      imageUrls: [imageUrl],
    );
  }

  Future<void> _handleCalendarShare(Map<String, dynamic> data) async {
    final type = data['type'] as String;

    String date;
    String message;
    String? calendarId;
    if (type == 'entire_calendar') {
      message = 'I\'d like to share my entire meal calendar with you.';
      date = DateFormat('MMM d, yyyy').format(DateTime.now());
      calendarId = data['calendarId'] as String?;
    } else {
      date = data['date'] as String? ?? 'No date specified';
      message = 'I\'d like to share my meal plan for $date with you.';
      calendarId = data['calendarId'] as String?;
    }

    await chatController.sendMessage(
      messageContent: message,
      shareRequest: {
        'type': type,
        'date': date,
        'name': userService.currentUser.value?.displayName,
        'friendName': widget.friend?.displayName,
        'calendarId': calendarId ?? 'No calendar ID',
        'header': data['header'] as String?,
      },
    );
    // If allowed, increment share count for non-premium users
    if (!(userService.currentUser.value?.isPremium ?? false)) {
      await firestore.collection('users').doc(userService.userId).set(
        {
          'calendarShares': FieldValue.increment(1),
        },
        SetOptions(merge: true),
      );
      FirebaseAnalytics.instance.logEvent(name: 'calendar_share_request');
    }
  }

  // Helper method to get only the date part (without time) for comparison
  String _getDateOnly(DateTime dateTime) {
    return DateFormat('yyyy-MM-dd').format(dateTime);
  }

  // Helper method to build date header widget
  Widget _buildDateHeader(DateTime date, bool isDarkMode, TextTheme textTheme) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(date.year, date.month, date.day);

    String dateText;
    if (messageDate == today) {
      dateText = 'Today';
    } else if (messageDate == yesterday) {
      dateText = 'Yesterday';
    } else {
      // Format as "June 24, 2025" for older dates
      dateText = DateFormat('MMMM d, yyyy').format(date);
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isDarkMode
                ? kLightGrey.withValues(alpha: 0.3)
                : kLightGrey.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            dateText,
            style: textTheme.bodyMedium?.copyWith(),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    final textTheme = Theme.of(context).textTheme;
    // Check if latest message is a pending friend request
    bool isPendingFriendRequest = false;
    if (chatController.messages.isNotEmpty) {
      final lastMsg = chatController.messages.last;
      if (lastMsg.friendRequest != null &&
          (lastMsg.friendRequest?['status'] ?? 'pending') == 'pending') {
        isPendingFriendRequest = true;
      }
    }
    return Scaffold(
      appBar: AppBar(
        backgroundColor: isDarkMode ? kDarkGrey : kWhite,
        automaticallyImplyLeading: true,
        centerTitle: true,
        title: Text(
          widget.friend?.displayName ?? 'Chat',
          style: textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w500),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          GestureDetector(
            onTap: widget.friendId!.isEmpty
                ? () {}
                : () {
                    Navigator.of(context).pop();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            UserProfileScreen(userId: widget.friendId!),
                      ),
                    );
                  },
            child: Padding(
              padding: EdgeInsets.only(
                right: getPercentageWidth(2, context),
              ),
              child: CircleAvatar(
                backgroundImage: widget.friend?.profileImage != null &&
                        widget.friend!.profileImage!.isNotEmpty &&
                        widget.friend!.profileImage!.contains('http')
                    ? NetworkImage(widget.friend!.profileImage!)
                    : AssetImage(intPlaceholderImage) as ImageProvider,
                radius: getResponsiveBoxSize(context, 15, 15),
              ),
            ),
          ),
        ],
      ),
      body: chatId == null
          ? noItemTastyWidget(
              "No chat yet...",
              "",
              context,
              false,
              '',
            )
          : GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                FocusScope.of(context).unfocus();
              },
              child: Column(
                children: [
                  Expanded(
                    child: Obx(() {
                      final messages = chatController.messages;

                      if (messages.isEmpty) {
                        return const Center(
                          child: Text("No messages yet."),
                        );
                      }

                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (_scrollController.hasClients) {
                          _scrollController.jumpTo(
                              _scrollController.position.maxScrollExtent);
                        }
                      });

                      return ListView.builder(
                        controller: _scrollController,
                        itemCount: messages.length,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        itemBuilder: (context, index) {
                          final message = messages[index];

                          // Check if we need to show a date header
                          bool showDateHeader = false;
                          if (index == 0) {
                            // Always show date header for first message
                            showDateHeader = true;
                          } else {
                            // Check if date is different from previous message
                            final previousMessage = messages[index - 1];
                            final currentDate =
                                _getDateOnly(message.timestamp.toDate());
                            final previousDate = _getDateOnly(
                                previousMessage.timestamp.toDate());
                            showDateHeader = currentDate != previousDate;
                          }

                          return Column(
                            children: [
                              if (showDateHeader)
                                _buildDateHeader(message.timestamp.toDate(),
                                    isDarkMode, textTheme),
                              ChatItem(
                                dataSrc: message,
                                isMe: message.senderId == userService.userId,
                                chatController: chatController,
                                chatId: chatId!,
                              ),
                            ],
                          );
                        },
                      );
                    }),
                  ),
                  _buildInputSection(isDarkMode, textTheme,
                      isDisabled: isPendingFriendRequest,
                      hint: isPendingFriendRequest
                          ? 'You can\'t send messages yet'
                          : 'Type your caption...'),
                  SizedBox(height: getPercentageHeight(3, context)),
                ],
              ),
            ),
    );
  }

  Widget _buildInputSection(bool isDarkMode, TextTheme textTheme,
      {bool isDisabled = false, String hint = 'Type your caption...'}) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          getPercentageWidth(2, context),
          getPercentageHeight(0.8, context),
          getPercentageWidth(2, context),
          getPercentageHeight(2.8, context)),
      child: Row(
        children: [
          InkWell(
            onTap: isDisabled
                ? null
                : () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) {
                        return CustomImagePickerModal(
                          onSend: (images, caption) => handleImageSend(
                              images,
                              caption,
                              chatId!,
                              _scrollController,
                              chatController),
                        );
                      },
                    );
                  },
            child: const IconCircleButton(
              icon: Icons.camera_alt,
              size: kIconSizeMedium,
            ),
          ),
          SizedBox(width: getPercentageWidth(1, context)),
          Expanded(
            child: SafeTextFormField(
              controller: textController,
              keyboardType: TextInputType.multiline,
              enabled: !isDisabled,
              style: textTheme.bodyMedium?.copyWith(),
              decoration: InputDecoration(
                filled: true,
                fillColor: isDarkMode ? kLightGrey : kWhite,
                enabledBorder: outlineInputBorder(20),
                focusedBorder: outlineInputBorder(20),
                border: outlineInputBorder(20),
                contentPadding: EdgeInsets.symmetric(
                    vertical: getPercentageHeight(1.2, context),
                    horizontal: getPercentageWidth(1.6, context)),
                hintText: hint,
                hintStyle: textTheme.bodyMedium?.copyWith(),
              ),
            ),
          ),
          SizedBox(width: getPercentageWidth(1, context)),
          InkWell(
            onTap: isDisabled
                ? null
                : () async {
                    final messageText = textController.text.trim();
                    if (messageText.isNotEmpty && chatId != null) {
                      await chatController.sendMessage(
                          messageContent: messageText);
                      textController.clear();
                    }
                  },
            child: const IconCircleButton(
              icon: Icons.send,
              size: kIconSizeMedium,
            ),
          ),
        ],
      ),
    );
  }
}

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
                                      : 'battle_post',
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
                Text(
                  getTextBeforeSlash(
                      dataSrc.messageContent.replaceAll('00:00:00.000 ', '')),
                  style: textTheme.bodyMedium?.copyWith(),
                ),

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

  Widget _buildFriendRequest(BuildContext context, bool isDarkMode,
      String chatId, String messageId, TextTheme textTheme) {
    final friendRequest = dataSrc.friendRequest!;
    final status = friendRequest['status'] as String? ?? 'pending';
    final friendName = userService.currentUser.value?.displayName ?? 'Friend';
    final date = friendRequest['date'] as String?;
    final formattedDate =
        DateFormat('MMM d, yyyy').format(DateTime.parse(date!));

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
          if (date != null)
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

  Widget _buildShareRequest(
      BuildContext context, bool isDarkMode, TextTheme textTheme) {
    final shareRequest = dataSrc.shareRequest!;
    final status = shareRequest['status'] as String;
    final type = shareRequest['type'] as String;
    final date = shareRequest['date'] as String?;
    String formattedDate = '';
    if (date != null && date.isNotEmpty) {
      // Try to parse as ISO, otherwise just display as is
      try {
        // If date is already in display format, just use it
        if (RegExp(r'\d{4}-\d{2}-\d{2}').hasMatch(date)) {
          formattedDate =
              DateFormat('MMM d, yyyy').format(DateTime.parse(date));
        } else {
          formattedDate = date; // Already display format
        }
      } catch (e) {
        formattedDate = date; // Fallback to raw string
      }
    }

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
}
