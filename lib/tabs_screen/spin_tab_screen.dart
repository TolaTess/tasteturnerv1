import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tasteturner/tabs_screen/spin_screen.dart';
import '../constants.dart';
import '../helper/helper_functions.dart';
import '../helper/utils.dart';
import '../widgets/custom_drawer.dart';
import '../widgets/icon_widget.dart';
import '../widgets/ingredient_features.dart';
import 'shopping_tab.dart';
import '../themes/theme_provider.dart';

class RecipeTabScreen extends StatefulWidget {
  final int initialTabIndex;
  const RecipeTabScreen({super.key, this.initialTabIndex = 0});

  @override
  State<RecipeTabScreen> createState() => _RecipeTabScreenState();
}

class _RecipeTabScreenState extends State<RecipeTabScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
        length: 2, vsync: this, initialIndex: widget.initialTabIndex);
    _tabController.addListener(_handleTabIndex);
    _setupDataListeners();
  }

  void _setupDataListeners() {
    _onRefresh();
  }

  Future<void> _onRefresh() async {
    setState(() {
      final currentWeek = getCurrentWeek();
      macroManager.fetchShoppingList(userService.userId ?? '', currentWeek);
    });
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
        userService.currentUser.value?.profileImage ?? intPlaceholderImage;
    final themeProvider = Provider.of<ThemeProvider>(context);
    return Scaffold(
      key: _scaffoldKey,
      drawer: const CustomDrawer(),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Profile image that opens drawer
            GestureDetector(
              onTap: () => _scaffoldKey.currentState?.openDrawer(),
              child: CircleAvatar(
                radius: MediaQuery.of(context).size.height > 1100
                    ? getResponsiveBoxSize(context, 14, 14)
                    : getResponsiveBoxSize(context, 18, 18),
                backgroundColor: kAccent.withValues(alpha: kOpacity), 
                child: CircleAvatar(
                  backgroundImage: getAvatarImage(avatarUrl),
                  radius: MediaQuery.of(context).size.height > 1100
                      ? getResponsiveBoxSize(context, 12, 12)
                      : getResponsiveBoxSize(context, 16, 16),
                ),
              ),
            ),

            Flexible(
              child: Center(
                child: Text(
                  'Spin and Shop',
                  style: TextStyle(
                    fontSize: getTextScale(4.5, context),
                    fontWeight: FontWeight.w400,
                    color:
                        themeProvider.isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
              ),
            ),
            // Add new recipe button
            InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => IngredientFeatures(
                      items: macroManager.ingredient,
                    ),
                  ),
                );
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
                    ? getPercentageHeight(1.5, context)
                    : getPercentageHeight(0.5, context)),
            // TabBar at the top
            TabBar(
              controller: _tabController,
              tabs: [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(spin),
                      SizedBox(width: getPercentageWidth(1, context)),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Shopping List'),
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
            SizedBox(
                height: MediaQuery.of(context).size.height > 1100
                    ? getPercentageHeight(1.5, context)
                    : getPercentageHeight(0.5, context)),

            // TabBarView below the TabBar
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  SpinScreen(), // Calls tab content
                  const ShoppingTab(), // Chats tab content
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
