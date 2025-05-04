import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import '../constants.dart';
import '../data_models/post_model.dart';
import '../data_models/profilescreen_data.dart';
import '../detail_screen/challenge_detail_screen.dart';
import '../helper/utils.dart';
import '../themes/theme_provider.dart';
import '../widgets/follow_button.dart';
import '../widgets/helper_widget.dart';
import '../widgets/icon_widget.dart';
import '../widgets/title_section.dart';
import 'badges_screen.dart';
import 'chat_screen.dart';

class UserProfileScreen extends StatefulWidget {
  final String userId;
  const UserProfileScreen({super.key, required this.userId});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  bool lastStatus = true;
  bool showAll = false;
  List<Post> searchContentDatas = [];
  List<BadgeAchievementData> myBadge = [];

  late ScrollController _scrollController;

  _scrollListener() {
    if (isShrink != lastStatus) {
      setState(() {
        lastStatus = isShrink;
      });
    }
  }

  bool get isShrink {
    return _scrollController.hasClients &&
        _scrollController.offset > (260 - kToolbarHeight);
  }

  @override
  void initState() {
    _scrollController = ScrollController();
    _scrollController.addListener(_scrollListener);
    friendController.updateUserData(widget.userId);
    friendController.fetchFollowing(userService.userId ?? '');
    badgeController.fetchBadges();
    _fetchContent(widget.userId);
    super.initState();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    super.dispose();
  }

  Future<void> _fetchContent(String userId) async {
    try {
      List<Post> fetchedData;
      fetchedData = await postController.getUserPosts(widget.userId);
      if (mounted) {
        setState(() {
          searchContentDatas = fetchedData;
        });
      }
    } catch (e) {
      print('Error fetching content: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      body: Obx(() {
        final user = friendController.userProfileData.value;
        if (user != null) {
        } else {
          print("User is null or not loaded yet.");
        }

        String newUserid = widget.userId;

        myBadge = badgeController.badgeAchievements
            .where((badge) => badge.userids.contains(newUserid))
            .toList();

        return SafeArea(
          child: CustomScrollView(controller: _scrollController, slivers: [
            // AppBar
            SliverAppBar(
              backgroundColor: themeProvider.isDarkMode ? kDarkGrey : kWhite,
              pinned: true,
              automaticallyImplyLeading: false,
              expandedHeight: 220,
              title: isShrink
                  ? Text(
                      user?.displayName ?? '',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: themeProvider.isDarkMode ? kWhite : kBlack,
                      ),
                    )
                  : const Text(emptyString),
              systemOverlayStyle: SystemUiOverlayStyle(
                statusBarIconBrightness:
                    isShrink ? Brightness.dark : Brightness.light,
              ),
              iconTheme: IconThemeData(
                color: isShrink
                    ? themeProvider.isDarkMode
                        ? kWhite.withOpacity(0.80)
                        : kBlack
                    : themeProvider.isDarkMode
                        ? kLightGrey
                        : kPrimaryColor,
              ),
              leading: // Back arrow
                  InkWell(
                onTap: () => Navigator.pop(context),
                child: const IconCircleButton(
                  isRemoveContainer: true,
                ),
              ),
              flexibleSpace: FlexibleSpaceBar(
                background: Column(
                  children: [
                    // Header and Follow Buttons
                    Stack(
                      alignment: Alignment.topCenter,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Container(
                            margin: const EdgeInsets.only(top: 74),
                            padding: const EdgeInsets.only(top: 70),
                            decoration: BoxDecoration(
                              color: kPrimaryColor,
                              borderRadius: BorderRadius.circular(20),
                              image: DecorationImage(
                                image: getImageProvider(user?.profileImage),
                                fit: BoxFit.cover,
                              ),
                            ),
                            child: Column(
                              children: [
                                const SizedBox(height: 24),
                                Center(
                                  child: Container(
                                    padding: const EdgeInsets.all(5),
                                    decoration: BoxDecoration(
                                      color: kLightGrey.withOpacity(0.4),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      user?.displayName ?? '',
                                      style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w600,
                                          color: kBackgroundColor),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        CircleAvatar(
                          radius: 52,
                          backgroundColor: kBackgroundColor,
                          child: CircleAvatar(
                            backgroundImage:
                                getImageProvider(user?.profileImage),
                            radius: 50,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Badges Section
            SliverToBoxAdapter(
              child: Column(
                children: [
                  Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          // Follow Button

                          Obx(() {
                            bool isFollowing =
                                friendController.isFollowing(newUserid);

                            if (!isFollowing) {
                              isFollowing = friendController.followingList
                                  .contains(newUserid);
                            }

                            return FollowButton(
                              h: 40,
                              w: 120,
                              title: isFollowing ? 'Unfollow' : follow,
                              press: () {
                                if (isFollowing) {
                                  friendController.unfollowFriend(
                                      userService.userId ?? '',
                                      newUserid,
                                      context);
                                } else {
                                  friendController.followFriend(
                                      userService.userId ?? '',
                                      newUserid,
                                      user?.displayName ?? '',
                                      context);
                                }

                                // Update the UI immediately
                                friendController.toggleFollowStatus(newUserid);
                              },
                            );
                          }),

                          // Message Button
                          Obx(() {
                            bool isFollowing = friendController.followingList
                                .contains(newUserid);
                            return FollowButton(
                              h: 40,
                              w: 120,
                              press: () async {
                                if (isFollowing) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ChatScreen(
                                        friendId: widget.userId,
                                        friend: user,
                                      ),
                                    ),
                                  );
                                } else {
                                  showTastySnackbar(
                                    'Follow Required',
                                    "You need to follow this user to start a chat.",
                                    context,
                                    backgroundColor: Colors.redAccent,
                                  );
                                }
                              },
                              title: 'Message',
                            );
                          }),
                        ],
                      ),
                      const SizedBox(
                        height: 20,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (myBadge.isNotEmpty)
                    TitleSection(
                      title: badges,
                      more: seeAll,
                      press: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => BadgesScreen(),
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),

                  // Badges Slider
                  if (myBadge.isNotEmpty)
                    SizedBox(
                      height: 130,
                      child: ListView.builder(
                        itemCount: myBadge.length > 5
                            ? 5
                            : myBadge.length, // Limit to 5 items
                        padding: const EdgeInsets.only(right: 10),
                        scrollDirection: Axis.horizontal,
                        itemBuilder: (context, index) {
                          if (index < myBadge.length) {
                            // Display badges for non-user
                            return Padding(
                              padding: const EdgeInsets.only(left: 10),
                              child: StorySlider(
                                dataSrc: myBadge[index],
                                press: () {
                                  // Handle badge click here
                                },
                              ),
                            );
                          }
                          return const SizedBox
                              .shrink(); // Safety fallback (should not be reached)
                        },
                      ),
                    ),

                  // Search Content Section
                  Builder(
                    builder: (context) {
                      final itemCount = showAll
                          ? searchContentDatas.length
                          : (searchContentDatas.length > 9
                              ? 9
                              : searchContentDatas.length);

                      return Column(
                        children: [
                          if (searchContentDatas.isEmpty)
                            const Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Text(
                                "No Posts yet.",
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            )
                          else
                            GridView.builder(
                              physics: const NeverScrollableScrollPhysics(),
                              shrinkWrap: true,
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                mainAxisSpacing: 4,
                                crossAxisSpacing: 4,
                              ),
                              padding: const EdgeInsets.only(top: 4, bottom: 4),
                              itemCount: itemCount,
                              itemBuilder: (BuildContext ctx, index) {
                                final data = searchContentDatas[index];
                                return SearchContentPost(
                                  dataSrc: data,
                                  press: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            ChallengeDetailScreen(
                                          dataSrc: data.toFirestore(),
                                          screen: 'myPost',
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                          if (searchContentDatas.isNotEmpty &&
                              searchContentDatas.length > 9)
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  showAll = !showAll;
                                });
                              },
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 1.0),
                                child: Icon(
                                  showAll
                                      ? Icons.keyboard_arrow_up
                                      : Icons.keyboard_arrow_down,
                                  size: 36,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 72),
                ],
              ),
            ),
          ]),
        );
      }),
    );
  }
}
