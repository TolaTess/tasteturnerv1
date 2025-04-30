import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tasteturner/tabs_screen/spin_screen.dart';
import '../constants.dart';
import '../helper/helper_functions.dart';
import '../screens/createrecipe_screen.dart';
import '../widgets/custom_drawer.dart';
import '../widgets/icon_widget.dart';
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
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            // Profile image that opens drawer
            GestureDetector(
              onTap: () => _scaffoldKey.currentState?.openDrawer(),
              child: CircleAvatar(
                radius: 20,
                backgroundColor: kAccent.withOpacity(kOpacity),
                child: CircleAvatar(
                  backgroundImage: getAvatarImage(avatarUrl),
                  radius: 18,
                ),
              ),
            ),

            Flexible(
              child: Center(
                child: Text(
                  'Spin and Shop',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w400,
                    color:
                        themeProvider.isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
              ),
            ),
          ],
        ),
       
      ),
      body: SafeArea(
        child: Column(
          children: [
            // TabBar at the top
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(spin),
                      SizedBox(width: 8),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Shopping List'),
                      SizedBox(width: 8),
                    ],
                  ),
                ),
              ],
              indicatorColor: themeProvider.isDarkMode ? kWhite : kBlack,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
              labelColor: themeProvider.isDarkMode ? kWhite : kBlack,
              unselectedLabelColor: kLightGrey,
            ),

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
