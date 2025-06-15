import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tasteturner/tabs_screen/food_challenge_screen.dart';
import '../constants.dart';
import '../helper/helper_functions.dart';
import '../helper/utils.dart';
import '../pages/upload_battle.dart';
import '../screens/createrecipe_screen.dart';
import '../widgets/custom_drawer.dart';
import '../widgets/icon_widget.dart';
import 'recipe_screen.dart';
import '../themes/theme_provider.dart';

class FoodTabScreen extends StatefulWidget {
  final int initialTabIndex;
  const FoodTabScreen({super.key, this.initialTabIndex = 0});

  @override
  State<FoodTabScreen> createState() => _FoodTabScreenState();
}

class _FoodTabScreenState extends State<FoodTabScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
        length: 2, vsync: this, initialIndex: widget.initialTabIndex);
    _tabController.addListener(_handleTabIndex);
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabIndex);
    _tabController.dispose();
    super.dispose();
  }

  void _handleTabIndex() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final avatarUrl =
        userService.currentUser?.profileImage ?? intPlaceholderImage;
    final themeProvider = Provider.of<ThemeProvider>(context);
    return Scaffold(
      key: _scaffoldKey,
      drawer: const CustomDrawer(),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Profile image that opens drawer
            GestureDetector(
              onTap: () => _scaffoldKey.currentState?.openDrawer(),
              child: CircleAvatar(
                radius: MediaQuery.of(context).size.height > 1100
                    ? getResponsiveBoxSize(context, 14, 14)
                    : getResponsiveBoxSize(context, 18, 18),
                backgroundColor: kAccent.withOpacity(kOpacity),
                child: CircleAvatar(
                  backgroundImage: getAvatarImage(avatarUrl),
                  radius: MediaQuery.of(context).size.height > 1100
                      ? getResponsiveBoxSize(context, 12, 12)
                      : getResponsiveBoxSize(context, 16, 16),
                ),
              ),
            ),

            Center(
              child: Text(
                'Food and Recipes',
                style: TextStyle(
                  fontSize: getTextScale(4.5, context),
                  fontWeight: FontWeight.w400,
                  color: themeProvider.isDarkMode ? Colors.white : Colors.black,
                ),
              ),
            ),
            // Add new recipe button
            InkWell(
              onTap: () {
                if (_tabController.index == 0) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const UploadBattleImageScreen(
                        battleId: battleIdConstant,
                        isMainPost: true,
                      ),
                    ),
                  );
                } else if (_tabController.index == 1) {
                  // Replace with your desired screen for tab 1
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CreateRecipeScreen(),
                    ),
                  );
                }
              },
              child: const IconCircleButton(
                icon: Icons.add,
                colorD: kAccent,
                isRemoveContainer: false,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
                height: MediaQuery.of(context).size.height > 1100
                    ? getPercentageHeight(2.5, context)
                    : getPercentageHeight(0.5, context)),
            // TabBar at the top
            TabBar(
              controller: _tabController,
              tabs: [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Food Insta'),
                      SizedBox(width: getPercentageWidth(1, context)),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Recipes'),
                      SizedBox(width: getPercentageWidth(1, context)),
                    ],
                  ),
                ),
              ],
              indicatorColor: themeProvider.isDarkMode ? kWhite : kBlack,
              labelStyle: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: getTextScale(4, context),
              ),
              labelColor: themeProvider.isDarkMode ? kWhite : kBlack,
              unselectedLabelColor: kLightGrey,
            ),

            // TabBarView below the TabBar
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: const [
                  FoodChallengeScreen(), // Chats tab content
                  RecipeScreen(), // Calls tab content
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
