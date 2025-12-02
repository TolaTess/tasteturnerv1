import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import '../data_models/user_data_model.dart';
import '../helper/helper_functions.dart';
import '../helper/utils.dart';
import '../service/chat_controller.dart';
import '../service/tasty_popup_service.dart';
import '../themes/theme_provider.dart';
import '../widgets/icon_widget.dart';
import '../constants.dart';
import 'chat_screen.dart';
import 'friend_screen.dart';

class MessageScreen extends StatefulWidget {
  const MessageScreen({super.key});

  @override
  State<MessageScreen> createState() => _MessageScreenState();
}

class _MessageScreenState extends State<MessageScreen>
    with TickerProviderStateMixin {
  late ScrollController _scrollController;
  final GlobalKey _addBuddyKey = GlobalKey();
  final GlobalKey _addFriendButtonKey = GlobalKey();
  final GlobalKey _addArchiveButtonKey = GlobalKey();

  bool lastStatus = true;

  _scrollListener() {
    if (isShrink != lastStatus) {
      setState(() {
        lastStatus = isShrink;
      });
    }
  }

  bool get isShrink {
    return _scrollController.hasClients &&
        _scrollController.offset > (12 - kToolbarHeight);
  }

  @override
  void initState() {
    _scrollController = ScrollController();
    _scrollController.addListener(_scrollListener);

    // Initialize ChatController and load user chats
    try {
      final userId = userService.userId ?? '';
      if (userId.isNotEmpty) {
        try {
          Get.find<ChatController>().loadUserChats(userId);
        } catch (e) {
          // If controller is not found, initialize it
          Get.put(ChatController()).loadUserChats(userId);
        }

        try {
          friendController.getAllFriendData(userId);
        } catch (e) {
          debugPrint('Error loading friend data: $e');
        }
      }
    } catch (e) {
      debugPrint('Error initializing message screen: $e');
    }
    super.initState();
    // Show tutorial popup after the widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showAddFriendTutorial();
    });
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

  /// Navigate to chat screen with friend data loading
  Future<void> _navigateToChat(
    BuildContext context,
    String chatId,
    String friendId,
  ) async {
    if (friendId.isEmpty || chatId.isEmpty) {
      _handleError('Invalid chat or friend ID');
      return;
    }

    try {
      // Load friend data first
      final friend = await friendController.getFriendData(friendId);
      if (friend != null && mounted && context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              chatId: chatId,
              friendId: friendId,
              friend: friend,
            ),
          ),
        );
      } else {
        _handleError('Friend data not found');
      }
    } catch (e) {
      debugPrint('Error loading friend data for navigation: $e');
      _handleError('Failed to load chat. Please try again.',
          details: e.toString());
    }
  }

  void _showAddFriendTutorial() {
// In your widget build or initState:
    tastyPopupService.showSequentialTutorials(
      context: context,
      sequenceKey: 'message_screen_tutorial',
      tutorials: [
        TutorialStep(
          tutorialId: 'add_archive_button',
          message:
              'When you swipe left on a friend\'s message, it will be archived here!',
          targetKey: _addArchiveButtonKey,
        ),
        TutorialStep(
          tutorialId: 'add_friend_button',
          message:
              'Tap here to view your friends and start sharing your food journey together!',
          targetKey: _addFriendButtonKey,
        ),
        TutorialStep(
          tutorialId: 'add_buddy_button',
          message: 'Tap here to speak to your digital Sous Chef!',
          targetKey: _addBuddyKey,
        ),
      ],
    );
  }

  /// Filters disabled chats to show only archived/inactive conversations
  Future<List<Map<String, dynamic>>> _getFilteredDisabledChats(
    List<Map<String, dynamic>> disabledChats,
    String userId,
  ) async {
    try {
      // Filter out any chats that might have become active again
      // and ensure we only show truly disabled/archived chats
      final filteredChats = disabledChats
          .where((chat) =>
              chat['isActive'] == false &&
              chat['chatId'] != null &&
              chat['participants'] != null &&
              (chat['participants'] as List).contains(userId))
          .toList();

      // Filter out chats where the friend has no display name
      final validChats = <Map<String, dynamic>>[];

      for (final chat in filteredChats) {
        final participants = List<String>.from(chat['participants'] ?? []);
        final friendId = participants.firstWhere(
          (id) => id != userId,
          orElse: () => '',
        );

        if (friendId.isNotEmpty) {
          try {
            // Fetch friend data to check if they have a display name
            final friend = await friendController.getFriendData(friendId);
            if (friend != null &&
                friend.displayName != null &&
                friend.displayName!.isNotEmpty) {
              // Add the friend data to the chat for easier access later
              chat['friendData'] = friend;
              validChats.add(chat);
            }
          } catch (e) {
            debugPrint("Error fetching friend data for $friendId: $e");
            // Skip this chat if we can't fetch friend data
            continue;
          }
        }
      }

      // Sort by last message time (most recent first)
      validChats.sort((a, b) {
        final aTime = a['lastMessageTime'] as Timestamp?;
        final bTime = b['lastMessageTime'] as Timestamp?;

        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;

        return bTime.compareTo(aTime); // Most recent first
      });

      return validChats;
    } catch (e) {
      debugPrint("Error filtering disabled chats: $e");
      return [];
    }
  }

  void _showDisabledChatsModal(BuildContext context) async {
    final userId = userService.userId ?? '';
    final disabledChats = (await chatController.fetchUserChats(userId))
        .where((chat) => chat['isActive'] == false)
        .toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor:
          Provider.of<ThemeProvider>(context, listen: false).isDarkMode
              ? kDarkGrey
              : kWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SizedBox(
          height: MediaQuery.of(context).size.height * 0.6,
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _getFilteredDisabledChats(disabledChats, userId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final filteredChats = snapshot.data ?? [];

              if (filteredChats.isEmpty) {
                return Center(
                  child: Text(
                    'No archived chats',
                    style: TextStyle(
                      fontSize: getPercentageHeight(2, context),
                      fontWeight: FontWeight.w500,
                      color: Provider.of<ThemeProvider>(context, listen: false)
                              .isDarkMode
                          ? kWhite
                          : kBlack,
                    ),
                  ),
                );
              }

              return ListView.builder(
                itemCount: filteredChats.length,
                itemBuilder: (context, index) {
                  final chat = filteredChats[index];
                  return ListTile(
                    tileColor: kAccent.withValues(alpha: 0.2),
                    leading: Icon(
                      Icons.chat_bubble_outline,
                      size: getPercentageWidth(6, context),
                      color: Provider.of<ThemeProvider>(context, listen: false)
                              .isDarkMode
                          ? kWhite
                          : kBlack,
                    ),
                    title: Text(
                      (chat['friendData'] as UserModel?)?.displayName ??
                          'Unknown',
                      style: TextStyle(
                        fontSize: getPercentageHeight(2, context),
                        fontWeight: FontWeight.w500,
                        color:
                            Provider.of<ThemeProvider>(context, listen: false)
                                    .isDarkMode
                                ? kWhite
                                : kBlack,
                      ),
                    ),
                    subtitle: Text(
                      chat['lastMessage'] ?? '',
                      style: TextStyle(
                        fontSize: getPercentageHeight(1.8, context),
                        color:
                            Provider.of<ThemeProvider>(context, listen: false)
                                    .isDarkMode
                                ? kWhite
                                : kBlack,
                      ),
                    ),
                    onTap: () async {
                      try {
                        final chatId = chat['chatId'] as String?;
                        if (chatId == null || chatId.isEmpty) {
                          throw Exception('Invalid chat ID');
                        }
                        await chatController.disableChats(chatId, true);
                      await chatController.loadUserChats(userId);
                        if (mounted && context.mounted) {
                          Navigator.pop(context);
                      showTastySnackbar(
                        'Success',
                        'Chat was restored',
                        context,
                      );
                        }
                      } catch (e) {
                        debugPrint('Error restoring chat: $e');
                        if (mounted && context.mounted) {
                          showTastySnackbar(
                            'Error',
                            'Failed to restore chat. Please try again.',
                            context,
                            backgroundColor: Colors.red,
                          );
                        }
                      }
                    },
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
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
        child: SafeArea(
          child: CustomScrollView(
            controller: _scrollController,
            slivers: [
            SliverAppBar(
              expandedHeight: MediaQuery.of(context).size.height > 1100
                  ? getPercentageHeight(6, context)
                  : getPercentageHeight(4, context),
              backgroundColor: themeProvider.isDarkMode ? kDarkGrey : kWhite,
              title: Text(
                inbox,
                style: textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              pinned: true,
              leading: Padding(
                padding: EdgeInsets.only(
                  right: getPercentageWidth(2, context),
                  left: getPercentageWidth(2.5, context),
                ),
                child: GestureDetector(
                  onTap: () => Get.back(),
                  child: IconCircleButton(
                    isRemoveContainer: true,
                    size: getIconScale(6, context),
                  ),
                ),
              ),
              actions: [
                Padding(
                  padding:
                      EdgeInsets.only(right: getPercentageWidth(1, context)),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      key: _addArchiveButtonKey,
                      icon: Icon(
                        Icons.archive_outlined,
                        size: getIconScale(7, context),
                        color: kAccent,
                      ),
                      onPressed: () {
                        _showDisabledChatsModal(context);
                      },
                    ),
                  ),
                ),
                SizedBox(
                    width: MediaQuery.of(context).size.height > 1100
                        ? getPercentageWidth(5, context)
                        : getPercentageWidth(1, context)),

                Padding(
                  padding:
                      EdgeInsets.only(right: getPercentageWidth(4, context)),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      key: _addFriendButtonKey,
                      icon: Icon(
                        Icons.people_outlined,
                        size: getIconScale(7, context),
                        color: kAccent,
                      ),
                      onPressed: () {
                        try {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const FriendScreen(),
                          ),
                        );
                        } catch (e) {
                          debugPrint('Error navigating to friend screen: $e');
                          if (context.mounted) {
                            showTastySnackbar(
                              'Error',
                              'Failed to open friends screen. Please try again.',
                              context,
                              backgroundColor: Colors.red,
                            );
                          }
                        }
                      },
                    ),
                  ),
                ),
                // Show tutorial for this button
              ],
            ),
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Message List
                  SizedBox(height: getPercentageHeight(1, context)),

                  Obx(() {
                    final nonBuddyChats = chatController.userChats
                        .where((chat) =>
                            !(chat['participants'] as List).contains('buddy'))
                        .toList();

                    if (nonBuddyChats.isEmpty) {
                      return noItemTastyWidget(
                        "No messages yet.",
                        "start a conversation with a friend.",
                        context,
                        false,
                        'friend',
                      );
                    }

                    return Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: ListView.builder(
                        scrollDirection: Axis.vertical,
                        physics: const NeverScrollableScrollPhysics(),
                        shrinkWrap: true,
                        itemCount: nonBuddyChats.length,
                        itemBuilder: (context, index) {
                          final chatSummary = nonBuddyChats[index];
                          final participants = List<String>.from(
                              chatSummary['participants'] ?? []);
                          final friendId = participants.firstWhere(
                            (id) => id != userService.userId,
                            orElse: () => '',
                          );
                          final chatId = chatSummary['chatId'] as String;

                          return Dismissible(
                            key: Key(chatId),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: EdgeInsets.symmetric(
                                  horizontal: getPercentageWidth(2, context)),
                              color: Colors.red,
                              child:
                                  const Icon(Icons.delete, color: Colors.white),
                            ),
                            onDismissed: (direction) async {
                              try {
                              await chatController.disableChats(chatId, false);
                                // Update reactive list instead of modifying local list
                              chatController.userChats.removeWhere(
                                  (chat) => chat['chatId'] == chatId);
                                if (mounted && context.mounted) {
                              showTastySnackbar(
                                'Chat Disabled',
                                'You can enable it in archived chats',
                                context,
                              );
                                }
                              } catch (e) {
                                debugPrint('Error disabling chat: $e');
                                if (mounted && context.mounted) {
                                  showTastySnackbar(
                                    'Error',
                                    'Failed to archive chat. Please try again.',
                                    context,
                                    backgroundColor: Colors.red,
                                  );
                                }
                              }
                            },
                            child: MessageItem(
                              dataSrc: chatSummary,
                              friendId: friendId,
                              press: () {
                                _navigateToChat(
                                      context,
                                  chatSummary['chatId'],
                                  friendId,
                                        );
                              },
                            ),
                          );
                        },
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
          ),
        ),
      ),
      floatingActionButtonLocation: CustomFloatingActionButtonLocation(
        verticalOffset: getPercentageHeight(5, context),
        horizontalOffset: getPercentageWidth(2, context),
      ),
      floatingActionButton: buildTastyFloatingActionButton(
        context: context,
        buttonKey: _addBuddyKey,
        themeProvider: themeProvider,
      ),
    );
  }
}

class MessageItem extends StatefulWidget {
  final Map<String, dynamic> dataSrc;
  final VoidCallback press;
  final String friendId;

  const MessageItem({
    super.key,
    required this.dataSrc,
    required this.press,
    required this.friendId,
  });

  @override
  State<MessageItem> createState() => _MessageItemState();
}

class _MessageItemState extends State<MessageItem> {
  final Rxn<UserModel> friendData = Rxn<UserModel>();

  @override
  void initState() {
    super.initState();
    _loadFriendData();
  }

  void _loadFriendData() async {
    if (widget.friendId.isNotEmpty) {
      try {
        final friend = await friendController.getFriendData(widget.friendId);
        if (mounted) {
      friendData.value = friend;
        }
      } catch (e) {
        debugPrint('Error loading friend data: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final lastMessageTime = (widget.dataSrc['lastMessageTime'] as Timestamp?)
        ?.toDate()
        .toLocal()
        .toString()
        .split('.')[0];
    final unreadCount = widget.dataSrc['unreadCount'] as int? ?? 0;

    return Obx(() {
      final friend = friendData.value;

      return Padding(
        padding: EdgeInsets.only(bottom: getPercentageHeight(2, context)),
        child: InkWell(
          onTap: widget.press,
          child: Column(
            children: [
              Row(
                children: [
                  // Avatar
                  buildFriendAvatar(friend?.profileImage, context),
                  SizedBox(width: getPercentageWidth(2, context)),

                  // Name and Last Message
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        capitalizeFirstLetter(friend?.displayName ?? 'Friend'),
                        style: textTheme.displayMedium?.copyWith(
                          fontWeight: FontWeight.w100,
                          fontSize: getPercentageHeight(2, context),
                        ),
                      ),
                      SizedBox(height: getPercentageHeight(0.5, context)),
                      Text(
                        lastMessageTime ?? '',
                        style: textTheme.bodySmall?.copyWith(
                          fontSize: getPercentageHeight(1, context),
                        ),
                      ),
                    ],
                  ),
                  Spacer(),

                  // Time and Badge
                  unreadCount > 0
                      ? Container(
                          height: getPercentageHeight(6, context),
                          width: getPercentageWidth(6, context),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: kAccent,
                            shape: BoxShape.circle,
                            border: Border.all(
                              width: 1,
                              color: Colors.white,
                            ),
                          ),
                          child: Text(
                            unreadCount.toString(),
                            style: textTheme.displaySmall?.copyWith(
                              fontSize: getPercentageHeight(2.5, context),
                              color: Colors.white,
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ],
              ),
              Divider(
                color: Provider.of<ThemeProvider>(context, listen: false)
                        .isDarkMode
                    ? kWhite.withValues(alpha: 0.2)
                    : kBlack.withValues(alpha: 0.2),
                height: 1,
              ),
            ],
          ),
        ),
      );
    });
  }
}
