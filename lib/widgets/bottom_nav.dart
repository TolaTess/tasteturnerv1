import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import '../constants.dart';
import '../helper/utils.dart';
import '../screens/buddy_screen.dart';
import '../service/tasty_popup_service.dart';
import '../tabs_screen/food_tab_screen.dart';
import '../tabs_screen/spin_tab_screen.dart';
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
  final GlobalKey _tastyButtonKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.selectedIndex;
    _currentTabIndex = widget.foodScreenTabIndex;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showBottomNavTutorial();
    });
  }

  void _showBottomNavTutorial() {
    tastyPopupService.showSequentialTutorials(
      context: context,
      sequenceKey: 'bottom_nav_tutorial',
      tutorials: [
        TutorialStep(
          tutorialId: 'tasty_button',
          message: 'Tap here to go to the home screen!',
          targetKey: _tastyButtonKey,
          autoCloseDuration: const Duration(seconds: 5),
          arrowDirection: ArrowDirection.DOWN,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final Size screenSize = MediaQuery.of(context).size;

    List<Widget> pages = [
      const HomeScreen(),
      FoodTabScreen(initialTabIndex: _currentTabIndex),
      const TastyScreen(),
      RecipeTabScreen(initialTabIndex: _currentTabIndex),
      MealDesignScreen(
        initialTabIndex: _currentTabIndex,
      ),
    ];

    bool keyboardIsOpen = MediaQuery.of(context).viewInsets.bottom != 0;
    return Scaffold(
      extendBody: true,
      floatingActionButton: Visibility(
        visible: !keyboardIsOpen && _selectedIndex != 2,
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: kAccent.withOpacity(0.3),
                spreadRadius: 2,
                blurRadius: 5,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: SizedBox(
            width: getPercentageWidth(11, context),
            height: getPercentageHeight(11, context),
            child: FloatingActionButton(
              heroTag: "uniqueHeroTagfb",
              onPressed: () {
                setState(() {
                  _selectedIndex = 2;
                  _currentTabIndex = 0;
                });
              },
              key: _tastyButtonKey,
              backgroundColor: themeProvider.isDarkMode ? kDarkGrey : kWhite,
              elevation: 5,
              child: Container(
                width: getPercentageWidth(11, context),
                height: getPercentageHeight(11, context),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  image: DecorationImage(
                    image: AssetImage(tastyImage),
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: Container(
        height: getPercentageHeight(9, context), // Responsive height
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
                    screenSize.width * 0.10, // Responsive width for center gap
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
          vertical: getPercentageHeight(1, context),
          horizontal: getPercentageWidth(1, context),
        ),
        child: _selectedIndex == activeIdx
            ? SvgPicture.asset(
                "assets/images/svg/$iconActive",
                height: getPercentageWidth(6, context),
                colorFilter: ColorFilter.mode(
                  kAccent.withOpacity(0.85),
                  BlendMode.srcIn,
                ),
              )
            : SvgPicture.asset(
                "assets/images/svg/$iconInactive",
                height: getPercentageWidth(6, context),
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
