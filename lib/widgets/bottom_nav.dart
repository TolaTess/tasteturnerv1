import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import '../constants.dart';
import '../pages/upload_battle.dart';
import '../tabs_screen/challenge_tab_screen.dart';
import '../tabs_screen/home_screen.dart';
import '../tabs_screen/meal_design_screen.dart';
import '../bottom_nav/recipe_screen.dart';
import '../themes/theme_provider.dart';

class BottomNavSec extends StatefulWidget {
  final int selectedIndex;
  final int foodScreenTabIndex;

  const BottomNavSec(
      {super.key, this.selectedIndex = 0, this.foodScreenTabIndex = 0});

  @override
  State<BottomNavSec> createState() => _BottomNavSecState();
}

class _BottomNavSecState extends State<BottomNavSec> {
  late int _selectedIndex;
  late int _currentTabIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.selectedIndex;
    _currentTabIndex = widget.foodScreenTabIndex;
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    List<Widget> pages = [
      const HomeScreen(),
      const RecipeScreen(),
      const UploadBattleImageScreen(
        battleId: battleIdConstant,
        isMainPost: true,
      ),
      const ChallengeTabScreen(),
      MealDesignScreen(
        initialTabIndex: _currentTabIndex,
      ),
      // ProfileScreen(uid: authController.user.uid),
    ];

    bool keyboardIsOpen = MediaQuery.of(context).viewInsets.bottom != 0;
    return Scaffold(
      extendBody: true,
      floatingActionButton: Visibility(
        visible: !keyboardIsOpen,
        child: FloatingActionButton(
          heroTag: "uniqueHeroTagfb",
          onPressed: () {
            setState(() {
              _selectedIndex = 2;
              _currentTabIndex = 0;
            });
          },
          backgroundColor: kAccent.withOpacity(0.85),
          child: const Icon(Icons.add),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
          shape: const CircularNotchedRectangle(),
          notchMargin: 6,
          clipBehavior: Clip.antiAlias,
          color: themeProvider.isDarkMode ? kDarkGrey : kWhite,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              createIcon(
                iconActive: "home.svg",
                iconInactive: "home-outline.svg",
                activeIdx: 0,
              ),
              createIcon(
                iconActive: "book.svg",
                iconInactive: "book-outline.svg",
                activeIdx: 1,
              ),
              const SizedBox(
                width: 60,
              ),
              createIcon(
                iconActive: "target.svg",
                iconInactive: "target-outline.svg",
                activeIdx: 3,
              ),
              createIcon(
                iconActive: "cal.svg",
                iconInactive: "cal-outline.svg",
                activeIdx: 4,
              ),
            ],
          )),
      body: pages[_selectedIndex],
    );
  }

//Method to build bottom navigation icon
  GestureDetector createIcon(
      {required String iconActive,
      required String iconInactive,
      required int activeIdx}) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () {
        setState(() {
          _selectedIndex = activeIdx;
          _currentTabIndex = 0;
        });
      },
      child: Container(
        //color: Colors.amber,
        padding: const EdgeInsets.symmetric(
          vertical: 15,
          horizontal: 30,
        ),
        child: _selectedIndex == activeIdx
            ? SvgPicture.asset(
                "assets/images/svg/$iconActive",
                height: 25,
                colorFilter: ColorFilter.mode(
                  kAccent.withOpacity(0.85),
                  BlendMode
                      .srcIn, // Ensures that the color is applied correctly
                ),
              )
            : SvgPicture.asset(
                "assets/images/svg/$iconInactive",
                height: 25,
                colorFilter: ColorFilter.mode(
                  Provider.of<ThemeProvider>(context).isDarkMode
                      ? kWhite.withOpacity(0.70)
                      : kBlack.withOpacity(0.70),
                  BlendMode
                      .srcIn, // Ensures that the color is applied correctly
                ),
              ),
      ),
    );
  }
}
