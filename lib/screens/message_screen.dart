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
import '../widgets/bottom_nav.dart';
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
  int currentPage = 0;
  late ScrollController _scrollController;
  final GlobalKey _addBuddyKey = GlobalKey();
  final GlobalKey _addFriendButtonKey = GlobalKey();
  bool isInFreeTrial = false;

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
      Get.find<ChatController>().loadUserChats(userService.userId ?? '');
    } catch (e) {
      // If controller is not found, initialize it
      Get.put(ChatController()).loadUserChats(userService.userId ?? '');
    }

    friendController.getAllFriendData(userService.userId ?? '');
    final freeTrialDate = userService.currentUser?.freeTrialDate;
    final isFreeTrial =
        freeTrialDate != null && DateTime.now().isBefore(freeTrialDate);
    setState(() {
      isInFreeTrial = isFreeTrial;
    });
    super.initState();
    // Show tutorial popup after the widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showAddFriendTutorial();
    });
  }

  void _showAddFriendTutorial() {
// In your widget build or initState:
    tastyPopupService.showSequentialTutorials(
      context: context,
      sequenceKey: 'message_screen_tutorial',
      tutorials: [
        TutorialStep(
          tutorialId: 'add_buddy_button',
          message: 'Tap here to speak to your AI buddy Tasty!',
          targetKey: _addBuddyKey,
          autoCloseDuration: const Duration(seconds: 5),
          arrowDirection: ArrowDirection.RIGHT,
        ),
        TutorialStep(
          tutorialId: 'add_friend_button',
          message:
              'Tap here to add friends and start sharing your food journey together!',
          targetKey: _addFriendButtonKey,
          autoCloseDuration: const Duration(seconds: 5),
          arrowDirection: ArrowDirection.RIGHT,
        ),
      ],
    );
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
          height: MediaQuery.of(context).size.height * 0.7,
          child: disabledChats.isEmpty
              ? Center(
                  child: Text(
                    'No archived chats',
                    style: TextStyle(
                      fontSize: getPercentageHeight(2.5, context),
                      fontWeight: FontWeight.w500,
                      color: Provider.of<ThemeProvider>(context, listen: false)
                              .isDarkMode
                          ? kWhite
                          : kBlack,
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: disabledChats.length,
                  itemBuilder: (context, index) {
                    final chat = disabledChats[index];
                    final participants =
                        List<String>.from(chat['participants'] ?? []);
                    final friendId = participants.firstWhere(
                      (id) => id != userId,
                      orElse: () => '',
                    );
                    return ListTile(
                      leading: Icon(
                        Icons.chat_bubble_outline,
                        color:
                            Provider.of<ThemeProvider>(context, listen: false)
                                    .isDarkMode
                                ? kWhite
                                : kBlack,
                      ),
                      title: FutureBuilder(
                        future: friendController.getFriendData(friendId),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Text('Loading...');
                          }
                          final friend = snapshot.data as UserModel?;
                          return Text(
                            friend?.displayName ?? 'Unknown',
                            style: TextStyle(
                              fontSize: getPercentageHeight(1.7, context),
                              fontWeight: FontWeight.w500,
                              color: Provider.of<ThemeProvider>(context,
                                          listen: false)
                                      .isDarkMode
                                  ? kWhite
                                  : kBlack,
                            ),
                          );
                        },
                      ),
                      subtitle: Text(
                        chat['lastMessage'] ?? '',
                        style: TextStyle(
                          fontSize: getPercentageHeight(1, context),
                          color:
                              Provider.of<ThemeProvider>(context, listen: false)
                                      .isDarkMode
                                  ? kWhite
                                  : kBlack,
                        ),
                      ),
                      onTap: () async {
                        await chatController.disableChats(chat['chatId'], true);
                        await chatController.loadUserChats(userId);
                        if (mounted) Navigator.pop(context);
                        showTastySnackbar(
                          'Success',
                          'Chat was restored',
                          context,
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
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            SliverAppBar(
              backgroundColor: themeProvider.isDarkMode ? kDarkGrey : kWhite,
              title: Text(
                inbox,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: themeProvider.isDarkMode ? kWhite : kBlack,
                ),
              ),
              pinned: true,
              leading: Padding(
                padding: const EdgeInsets.only(
                  right: 20,
                  left: 12,
                  top: 14,
                  bottom: 14,
                ),
                child: GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const BottomNavSec(
                              selectedIndex: 0,
                            )),
                  ),
                  child: const IconCircleButton(
                    isRemoveContainer: true,
                  ),
                ),
              ),
              actions: [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: getPercentageWidth(2, context)),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      icon: Icon(
                        Icons.archive,
                        size: getPercentageWidth(6, context),
                        color: kAccent,
                      ),
                      onPressed: () {
                        _showDisabledChatsModal(context);
                      },
                    ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      key: _addFriendButtonKey,
                      icon: Icon(
                        Icons.people_outlined,
                        size: getPercentageWidth(6, context),
                        color: kAccent,
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const FriendScreen(),
                          ),
                        );
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
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 20),
                              color: Colors.red,
                              child:
                                  const Icon(Icons.delete, color: Colors.white),
                            ),
                            onDismissed: (direction) async {
                              await chatController.disableChats(chatId, false);
                              // Remove from local list for instant feedback
                              nonBuddyChats.removeAt(index);
                              chatController.userChats.removeWhere(
                                  (chat) => chat['chatId'] == chatId);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Chat disabled')),
                              );
                            },
                            child: MessageItem(
                              dataSrc: chatSummary,
                              press: () {
                                if (friendId.isNotEmpty) {
                                  // Wait for friend data if not already loaded
                                  if (_MessageItemState().friendData.value !=
                                      null) {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => ChatScreen(
                                          chatId: chatSummary['chatId'],
                                          friendId: friendId,
                                          friend: _MessageItemState()
                                              .friendData
                                              .value!,
                                        ),
                                      ),
                                    );
                                  } else {
                                    // Load friend data first
                                    friendController
                                        .getFriendData(friendId)
                                        .then((friend) {
                                      if (friend != null) {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => ChatScreen(
                                              chatId: chatSummary['chatId'],
                                              friendId: friendId,
                                              friend: friend,
                                            ),
                                          ),
                                        );
                                      }
                                    });
                                  }
                                }
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
      floatingActionButtonLocation: const CustomFloatingActionButtonLocation(
        verticalOffset: 50, // Move up by 50 pixels
        horizontalOffset: 20, // Move right by 20 pixels
      ),
      floatingActionButton: buildTastyFloatingActionButton(
        context: context,
        buttonKey: _addBuddyKey,
        themeProvider: themeProvider,
        isInFreeTrial: isInFreeTrial,
      ),
    );
  }
}

class MessageItem extends StatefulWidget {
  final Map<String, dynamic> dataSrc;
  final VoidCallback press;

  const MessageItem({
    super.key,
    required this.dataSrc,
    required this.press,
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
    final participants =
        List<String>.from(widget.dataSrc['participants'] ?? []);
    final friendId = participants.firstWhere(
      (id) => id != userService.userId,
      orElse: () => '',
    );

    if (friendId.isNotEmpty) {
      final friend = await friendController.getFriendData(friendId);
      friendData.value = friend;
    }
  }

  @override
  Widget build(BuildContext context) {
    final lastMessage = widget.dataSrc['lastMessage'] as String? ?? '';
    final lastMessageTime = (widget.dataSrc['lastMessageTime'] as Timestamp?)
        ?.toDate()
        .toLocal()
        .toString()
        .split('.')[0];
    final unreadCount = widget.dataSrc['unreadCount'] as int? ?? 0;

    return Obx(() {
      final friend = friendData.value;

      return Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: InkWell(
          onTap: widget.press,
          child: Column(
            children: [
              Row(
                children: [
                  // Avatar
                  buildFriendAvatar(friend?.profileImage),
                  const SizedBox(width: 16),

                  // Name and Last Message
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          friend?.displayName ?? 'Loading...',
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          lastMessage,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Time and Badge
                  Column(
                    children: [
                      Text(
                        lastMessageTime ?? '',
                        style: const TextStyle(
                          fontWeight: FontWeight.w400,
                          fontSize: 10,
                        ),
                      ),
                      unreadCount > 0
                          ? Container(
                              height: 22,
                              width: 22,
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
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                ),
                              ),
                            )
                          : const SizedBox.shrink(),
                    ],
                  ),
                ],
              ),
              Divider(
                color: Provider.of<ThemeProvider>(context, listen: false)
                        .isDarkMode
                    ? kWhite.withOpacity(0.2)
                    : kBlack.withOpacity(0.2),
                height: 1,
              ),
            ],
          ),
        ),
      );
    });
  }
}
