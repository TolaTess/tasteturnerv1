import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:tasteturner/screens/user_profile_screen.dart';
import '../constants.dart';
import '../helper/utils.dart';
import '../themes/theme_provider.dart';
import '../widgets/icon_widget.dart';
import '../widgets/search_button.dart';
import 'buddy_screen.dart';
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
        title: Center(
          child: Text(
            textAlign: TextAlign.center,
            'Friends',
            style: TextStyle(fontSize: getPercentageWidth(4, context), fontWeight: FontWeight.w500),
          ),
        ),
      ),
      body: Column(
        children: [
            SizedBox(height: getPercentageHeight(1, context)),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: getPercentageWidth(2, context)),
            child: SearchButton2(
              controller: _searchController,
              onChanged: _onSearchChanged,
              kText: searchFriendHint,
            ),
          ),
          SizedBox(height: getPercentageHeight(1, context)),
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
                padding: EdgeInsets.all(getPercentageWidth(1, context)),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: getPercentageWidth(1, context),
                  mainAxisSpacing: getPercentageWidth(1, context),
                  childAspectRatio: 0.5,
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
                        if (friend.userId == userService.userId) {
                          showTastySnackbar(
                            'Cannot Chat with Yourself',
                            'You cannot chat with yourself.',
                            context,
                          );
                          return;
                        } else if (friendId == tastyId) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const TastyScreen(
                                screen: 'message',
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
                      }
                    },
                    child: Column(
                      children: [
                        buildFriendAvatar(friend.profileImage, context),
                        SizedBox(height: getPercentageHeight(0.5, context)),
                        Flexible(
                          child: Text(
                            friend.displayName ?? '',
                            style: TextStyle(
                              color: themeProvider.isDarkMode ? kWhite : kBlack,
                              fontWeight: FontWeight.w500,
                              fontSize: getPercentageWidth(3, context),
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
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
