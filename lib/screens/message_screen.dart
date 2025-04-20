import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import '../data_models/user_data_model.dart';
import '../helper/utils.dart';
import '../themes/theme_provider.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/icon_widget.dart';
import '../constants.dart';
import 'buddy_screen.dart';
import 'chat_screen.dart';
import 'friend_screen.dart';
import 'premium_screen.dart';

class MessageScreen extends StatefulWidget {
  const MessageScreen({super.key});

  @override
  State<MessageScreen> createState() => _MessageScreenState();
}

class _MessageScreenState extends State<MessageScreen>
    with TickerProviderStateMixin {
  int currentPage = 0;
  Timer? _tastyPopupTimer;
  late ScrollController _scrollController;

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
    chatController.loadUserChats(userService.userId ?? '');
    friendController.getAllFriendData(userService.userId ?? '');

    _tastyPopupTimer = Timer(const Duration(milliseconds: 8000), () {
      if (mounted) {
        tastyPopupService.showTastyPopup(context, 'message', [], []);
      }
    });
    super.initState();
  }

  @override
  void dispose() {
    _tastyPopupTimer?.cancel();
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
                    padding: const EdgeInsets.all(10.0),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        icon: const Icon(Icons.add, size: 28),
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
                          "Start a conversation with your friends.",
                          context,
                          false,
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

                              return MessageItem(
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
                              );
                            }),
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            if (userService.currentUser?.isPremium ?? false) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const TastyScreen(),
                ),
              );
            } else {
              showDialog(
                context: context,
                builder: (BuildContext context) => AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  backgroundColor:
                      themeProvider.isDarkMode ? kDarkGrey : kWhite,
                  title: const Text('Premium Feature',
                      style: TextStyle(
                        color: kAccent,
                      )),
                  content: Text(
                    'Upgrade to premium to chat with your AI buddy Tasty 👋 and get personalized nutrition advice!',
                    style: TextStyle(
                      color: themeProvider.isDarkMode ? kWhite : kBlack,
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: themeProvider.isDarkMode ? kWhite : kBlack,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context); // Close dialog
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const PremiumScreen(),
                          ),
                        );
                      },
                      child: const Text(
                        'Upgrade',
                        style: TextStyle(color: kAccentLight),
                      ),
                    ),
                  ],
                ),
              );
            }
          },
          backgroundColor: kPrimaryColor,
          child: Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              image: DecorationImage(
                image: AssetImage(tastyImage),
                fit: BoxFit.cover,
              ),
            ),
          ),
        ));
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
          child: Row(
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
        ),
      );
    });
  }
}
