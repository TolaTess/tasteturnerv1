import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import '../constants.dart';
import '../helper/utils.dart';
import '../themes/theme_provider.dart';
import '../widgets/icon_widget.dart';
import 'chat_screen.dart';

class FriendScreen extends StatefulWidget {
  final Map<String, dynamic>? dataSrc;
  final String? screen;
  const FriendScreen({super.key, this.dataSrc, this.screen});

  @override
  State<FriendScreen> createState() => _FriendScreenState();
}

class _FriendScreenState extends State<FriendScreen> {
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    friendController.getAllFriendData(userService.userId ?? '');
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
        title: const Text('Friends List'),
      ),
      body: Obx(() {
        if (friendController.friendsMap.isEmpty) {
          return noItemTastyWidget(
            "No friends yet.",
            "Add friends to see them here.",
            context,
            false,
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.all(8.0),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3, // Adjust based on your preference
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.85, // Adjust for the image and text ratio
          ),
          itemCount: friendController.friendsMap.length,
          itemBuilder: (context, index) {
            final friendId = friendController.friendsMap.keys.elementAt(index);
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
                  CircleAvatar(
                    radius: 40,
                    backgroundImage:
                        friend.profileImage?.contains('http') ?? false
                            ? NetworkImage(friend.profileImage!)
                            : AssetImage(intPlaceholderImage) as ImageProvider,
                  ),
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
        );
      }),
    );
  }
}
