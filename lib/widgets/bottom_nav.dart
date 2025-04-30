import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import '../constants.dart';
import '../screens/buddy_screen.dart';
import '../tabs_screen/food_tab_screen.dart';
import '../tabs_screen/recipe_tab_screen.dart';
import '../tabs_screen/food_challenge_screen.dart';
import '../tabs_screen/home_screen.dart';
import '../tabs_screen/meal_design_screen.dart';
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
    final Size screenSize = MediaQuery.of(context).size;

    List<Widget> pages = [
      const HomeScreen(),
      RecipeTabScreen(initialTabIndex: _currentTabIndex),
      const TastyScreen(),
      FoodTabScreen(initialTabIndex: _currentTabIndex),
      MealDesignScreen(
        initialTabIndex: _currentTabIndex,
      ),
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
          // backgroundColor: kAccent.withOpacity(0.85),
          // child: const Icon(Icons.add),
          backgroundColor: kPrimaryColor,
          child: Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: kAccentLight,
              shape: BoxShape.circle,
              image: DecorationImage(
                image: AssetImage(tastyImage),
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: Container(
        height: screenSize.height * 0.1, // Responsive height
        child: BottomAppBar(
          shape: const CircularNotchedRectangle(),
          notchMargin: 6,
          clipBehavior: Clip.antiAlias,
          color: themeProvider.isDarkMode ? kDarkGrey : kWhite,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(
                  child: createIcon(
                iconActive: "home.svg",
                iconInactive: "home-outline.svg",
                activeIdx: 0,
              )),
              Expanded(
                  child: createIcon(
                iconActive: "book.svg",
                iconInactive: "book-outline.svg",
                activeIdx: 1,
              )),
              SizedBox(
                width:
                    screenSize.width * 0.15, // Responsive width for center gap
              ),
              Expanded(
                  child: createIcon(
                iconActive: "target.svg",
                iconInactive: "target-outline.svg",
                activeIdx: 3,
              )),
              Expanded(
                  child: createIcon(
                iconActive: "cal.svg",
                iconInactive: "cal-outline.svg",
                activeIdx: 4,
              )),
            ],
          ),
        ),
      ),
      body: pages[_selectedIndex],
    );
  }

  //Method to build bottom navigation icon
  Widget createIcon({
    required String iconActive,
    required String iconInactive,
    required int activeIdx,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () {
        setState(() {
          _selectedIndex = activeIdx;
          _currentTabIndex = 0;
        });
      },
      child: Container(
        alignment: Alignment.center,
        padding: EdgeInsets.symmetric(
          vertical: MediaQuery.of(context).size.height * 0.015,
          horizontal: MediaQuery.of(context).size.width * 0.02,
        ),
        child: _selectedIndex == activeIdx
            ? SvgPicture.asset(
                "assets/images/svg/$iconActive",
                height: 25,
                colorFilter: ColorFilter.mode(
                  kAccent.withOpacity(0.85),
                  BlendMode.srcIn,
                ),
              )
            : SvgPicture.asset(
                "assets/images/svg/$iconInactive",
                height: 25,
                colorFilter: ColorFilter.mode(
                  Provider.of<ThemeProvider>(context).isDarkMode
                      ? kWhite.withOpacity(0.70)
                      : kBlack.withOpacity(0.70),
                  BlendMode.srcIn,
                ),
              ),
      ),
    );
  }
}
