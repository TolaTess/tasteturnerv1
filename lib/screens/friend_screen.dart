import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import '../constants.dart';
import '../helper/utils.dart';
import '../themes/theme_provider.dart';
import '../widgets/icon_widget.dart';
import '../widgets/search_button.dart';
import 'chat_screen.dart';

class FriendScreen extends StatefulWidget {
  final Map<String, dynamic>? dataSrc;
  final String? screen;
  const FriendScreen({super.key, this.dataSrc, this.screen});

  @override
  State<FriendScreen> createState() => _FriendScreenState();
}

class _FriendScreenState extends State<FriendScreen> {
  final TextEditingController _searchController = TextEditingController();
  String searchQuery = '';
  @override
  void initState() {
    super.initState();
    friendController.getAllFriendData(userService.userId ?? '');
  }

  void _onSearchChanged(String query) {
    setState(() {
      searchQuery = query;
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return Scaffold(
      appBar: AppBar(
        leading: InkWell(
          onTap: () => Navigator.pop(context),
          child: const IconCircleButton(
            isRemoveContainer: true,
          ),
        ),
        title: const Text(
          'Friends List',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
        ),
      ),
      body: Column(
        children: [
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: SearchButton2(
              controller: _searchController,
              onChanged: _onSearchChanged,
              kText: searchFriendHint,
            ),
          ),
          const SizedBox(height: 16),
          Obx(() {
            if (friendController.friendsMap.isEmpty) {
              return noItemTastyWidget(
                "No friends yet.",
                "Add friends to see them here.",
                context,
                false,
              );
            }

            return Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(16.0),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 24,
                  childAspectRatio: 0.75,
                ),
                itemCount: friendController.friendsMap.length,
                itemBuilder: (context, index) {
                  final friendId =
                      friendController.friendsMap.keys.elementAt(index);
                  final friend = friendController.friendsMap[friendId]!;

                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatScreen(
                            friendId: friendId,
                            dataSrc: widget.dataSrc,
                            screen: widget.screen,
                            friend: friend,
                          ),
                        ),
                      );
                    },
                    child: Column(
                      children: [
                        buildFriendAvatar(friend.profileImage),
                        const SizedBox(height: 8),
                        Text(
                          friend.displayName ?? '',
                          style: TextStyle(
                            color: themeProvider.isDarkMode ? kWhite : kBlack,
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  );
                },
              ),
            );
          }),
        ],
      ),
    );
  }
}
