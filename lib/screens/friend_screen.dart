import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:tasteturner/screens/user_profile_screen.dart';
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
    friendController.fetchAllUsers();
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
            // If searching, use all users; otherwise, use only friends
            final isSearching = searchQuery.trim().isNotEmpty;
            final List<dynamic> baseList = isSearching
                ? friendController.allUsersList
                : friendController.friendsMap.values.toList();

            if (baseList.isEmpty) {
              return noItemTastyWidget(
                isSearching ? "No friends found." : "No friends yet.",
                isSearching
                    ? "Try a different search."
                    : "Use search bar to find friends.",
                context,
                false,
                '',
              );
            }

            // Filter by search query if searching
            final filteredFriends = isSearching
                ? baseList
                    .where((entry) => (entry.displayName ?? '')
                        .toLowerCase()
                        .contains(searchQuery.toLowerCase()))
                    .toList()
                : baseList;

            if (filteredFriends.isEmpty) {
              return noItemTastyWidget(
                "No friends found.",
                "Try a different search.",
                context,
                false,
                '',
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
                itemCount: filteredFriends.length,
                itemBuilder: (context, index) {
                  final friendId = filteredFriends[index].userId;
                  final friend = filteredFriends[index];

                  return GestureDetector(
                    onTap: () {
                      if (isSearching) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => UserProfileScreen(
                              userId: friendId,
                            ),
                          ),
                        );
                      } else {
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
                      }
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
