import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants.dart';
import 'vote_screen.dart';
import '../themes/theme_provider.dart';
import 'food_challenge_screen.dart';

class ChallengeTabScreen extends StatefulWidget {
  final int initialTabIndex;
  const ChallengeTabScreen({super.key, this.initialTabIndex = 0});

  @override
  State<ChallengeTabScreen> createState() => _ChallengeTabScreenState();
}

class _ChallengeTabScreenState extends State<ChallengeTabScreen>
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
        automaticallyImplyLeading: false,
        title: Text(
          challenges,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w400,
            color: themeProvider.isDarkMode ? Colors.white : Colors.black,
          ),
        ),
        centerTitle: true,
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
                      Text(food),
                      SizedBox(width: 8),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(vote),
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
                  const FoodChallengeScreen(), // Chats tab content
                  VoteScreen(
                    isDarkMode: themeProvider.isDarkMode,
                  ), // Calls tab content
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
