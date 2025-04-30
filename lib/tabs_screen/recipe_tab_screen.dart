import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import '../bottom_nav/profile_screen.dart';
import '../constants.dart';
import '../helper/helper_functions.dart';
import '../screens/createrecipe_screen.dart';
import '../widgets/icon_widget.dart';
import 'recipe_screen.dart';
import 'spin_screen.dart';
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
    final themeProvider = Provider.of<ThemeProvider>(context);
    return Scaffold(
      appBar: AppBar(
          leading: GestureDetector(
          onTap: () => Get.to(() => const ProfileScreen()),
          child: Padding(
            padding: const EdgeInsets.only(left: 15),
            child: buildProfileAvatar(
              imageUrl: userService.currentUser!.profileImage ??
                  intPlaceholderImage,
              outerRadius: 20,
              innerRadius: 18,
              imageSize: 20,
            ),
          ),
        ),
        title: Text(
          'Food and Recipes',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w400,
            color: themeProvider.isDarkMode ? Colors.white : Colors.black,
          ),
        ),
        centerTitle: true,
        actions: [
          // Add new recipe button
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: InkWell(
              onTap: () => Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const CreateRecipeScreen(
                    screenType: recipes,
                  ),
                ),
              ),
              child: const IconCircleButton(
                icon: Icons.add,
                isRemoveContainer: false,
              ),
            ),
          ),
        ],
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
                      Text('Recipes'),
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
                  SpinScreen(), // Chats tab content
                  const RecipeScreen(), // Calls tab content
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
