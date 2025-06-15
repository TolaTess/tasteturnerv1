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
import '../widgets/helper_widget.dart';
import '../widgets/icon_widget.dart';
import '../widgets/primary_button.dart';
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
              expandedHeight: getPercentageHeight(35, context),
              title: isShrink
                  ? Text(
                      user?.displayName ?? '',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: getTextScale(4.5, context),
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

                    Padding(
                      padding: EdgeInsets.only(
                          top: getPercentageHeight(1, context),
                          left: getPercentageWidth(6, context),
                          right: getPercentageWidth(6, context)),
                      child: Container(
                        padding: EdgeInsets.all(getPercentageWidth(1, context)),
                        decoration: BoxDecoration(
                          color: kLightGrey.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          user?.displayName ?? '',
                          style: TextStyle(
                              fontSize: getTextScale(4.5, context),
                              fontWeight: FontWeight.w600,
                              color: kBackgroundColor),
                        ),
                      ),
                    ),

                    Expanded(
                      child: Container(
                        margin: EdgeInsets.only(
                            top: getPercentageHeight(1, context)),
                        padding: EdgeInsets.only(
                            left: getPercentageWidth(6, context),
                            right: getPercentageWidth(6, context),
                            top: getPercentageHeight(1, context)),
                        decoration: BoxDecoration(
                          color: kPrimaryColor,
                          // borderRadius: BorderRadius.circular(20),
                          image: DecorationImage(
                            image: getImageProvider(user?.profileImage),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: getPercentageHeight(1, context)),
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

                            return AppButton(
                              height: 4.5,
                              width: 30,
                              type: AppButtonType.follow,
                              text: isFollowing ? 'Unfollow' : follow,
                              onPressed: () {
                                if (isFollowing) {
                                  friendController.unfollowFriend(
                                      userService.userId ?? '',
                                      newUserid,
                                      context);
                                } else {
                                  if (userService.userId == newUserid) {
                                    showTastySnackbar(
                                      'Cannot Follow Yourself',
                                      'You cannot follow yourself.',
                                      context,
                                    );
                                    return;
                                  }
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
                            return AppButton(
                              height: 4.5,
                              width: 30,
                              type: AppButtonType.follow,
                              text: 'Message',
                              onPressed: () async {
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
                                    "You need to be friends before you can start a chat.",
                                    context,
                                    backgroundColor: Colors.redAccent,
                                  );
                                }
                              },
                            );
                          }),
                        ],
                      ),
                      SizedBox(
                        height: getPercentageHeight(0.5, context),
                      ),
                    ],
                  ),
                  SizedBox(height: getPercentageHeight(5, context)),
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
                  SizedBox(height: getPercentageHeight(1, context)),

                  // Badges Slider
                  if (myBadge.isNotEmpty)
                    SizedBox(
                      height: getPercentageHeight(13, context),
                      child: ListView.builder(
                        itemCount: myBadge.length > 5
                            ? 5
                            : myBadge.length, // Limit to 5 items
                        padding: EdgeInsets.only(
                            right: getPercentageWidth(2, context)),
                        scrollDirection: Axis.horizontal,
                        itemBuilder: (context, index) {
                          if (index < myBadge.length) {
                            // Display badges for non-user
                            return Padding(
                              padding: EdgeInsets.only(
                                  left: getPercentageWidth(2, context)),
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
                  SizedBox(height: getPercentageHeight(2, context)),

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
                            Padding(
                              padding: EdgeInsets.all(
                                  getPercentageWidth(4, context)),
                              child: Text(
                                "No Posts yet.",
                                style: TextStyle(
                                  fontSize: getTextScale(4, context),
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
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                mainAxisSpacing:
                                    getPercentageWidth(0.5, context),
                                crossAxisSpacing:
                                    getPercentageWidth(0.5, context),
                              ),
                              padding: EdgeInsets.only(
                                  top: getPercentageHeight(1, context),
                                  bottom: getPercentageHeight(1, context)),
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
                                padding: EdgeInsets.symmetric(
                                    vertical: getPercentageHeight(1, context)),
                                child: Icon(
                                  showAll
                                      ? Icons.keyboard_arrow_up
                                      : Icons.keyboard_arrow_down,
                                  size: getPercentageWidth(9, context),
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),

                  SizedBox(height: getPercentageHeight(12, context)),
                ],
              ),
            ),
          ]),
        );
      }),
    );
  }
}
