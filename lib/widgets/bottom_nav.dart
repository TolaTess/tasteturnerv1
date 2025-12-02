import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';
import 'package:tasteturner/helper/utils.dart';
import '../constants.dart';
import '../tabs_screen/home_screen.dart';
import '../tabs_screen/inspiration_screen.dart';
import '../tabs_screen/meal_design_screen.dart';
import '../tabs_screen/program_screen.dart';
import '../tabs_screen/spin_screen.dart';
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

    final List<Widget> pages = [
      const HomeScreen(),
      const ProgramScreen(),
      const InspirationScreen(),
      SpinScreen(),
      MealDesignScreen(initialTabIndex: _currentTabIndex),
    ];

    return Scaffold(
      body: pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        unselectedLabelStyle: TextStyle(fontSize: getTextScale(2.9, context), fontWeight: FontWeight.w500),
        selectedLabelStyle: TextStyle(fontSize: getTextScale(3.3, context), fontWeight: FontWeight.w500),
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
            _currentTabIndex = 0; // Reset tab index when changing main screen
          });
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: themeProvider.isDarkMode ? kDarkGrey : kWhite,
        selectedItemColor: kAccent,
        unselectedItemColor: themeProvider.isDarkMode
            ? kWhite.withValues(alpha: 0.7)
            : kBlack.withValues(alpha: 0.7),
        items: [
          BottomNavigationBarItem(
            icon: SvgPicture.asset(
              'assets/images/svg/home-outline.svg',
              width: getPercentageWidth(3, context),
              height: getPercentageHeight(3, context),
              colorFilter: ColorFilter.mode(
                  themeProvider.isDarkMode
                      ? kWhite.withValues(alpha: 0.7)
                      : kBlack.withValues(alpha: 0.7),
                  BlendMode.srcIn),
            ),
            activeIcon: SvgPicture.asset('assets/images/svg/home.svg',
                width: getPercentageWidth(3, context),
                height: getPercentageHeight(3, context),
                colorFilter: const ColorFilter.mode(kAccent, BlendMode.srcIn)),
            label: 'Kitchen',
          ),
          BottomNavigationBarItem(
            icon: SvgPicture.asset(
              'assets/images/svg/book-outline.svg',
              width: getPercentageWidth(3, context),
              height: getPercentageHeight(3, context),
              colorFilter: ColorFilter.mode(
                  themeProvider.isDarkMode
                      ? kWhite.withValues(alpha: 0.7)
                      : kBlack.withValues(alpha: 0.7),
                  BlendMode.srcIn),
            ),
            activeIcon: SvgPicture.asset('assets/images/svg/book.svg',
                width: getPercentageWidth(3, context),
                height: getPercentageHeight(3, context),
                colorFilter: const ColorFilter.mode(kAccent, BlendMode.srcIn)),
            label: 'Programs',
          ),
          BottomNavigationBarItem(
            icon: SvgPicture.asset(
              'assets/images/svg/explore-outline.svg',
              width: getPercentageWidth(3, context),
              height: getPercentageHeight(3, context),
              colorFilter: ColorFilter.mode(
                  themeProvider.isDarkMode
                      ? kWhite.withValues(alpha: 0.7)
                      : kBlack.withValues(alpha: 0.7),
                  BlendMode.srcIn),
            ),
            activeIcon: SvgPicture.asset('assets/images/svg/explore.svg',
                width: getPercentageWidth(3, context),
                height: getPercentageHeight(3, context),
                colorFilter: const ColorFilter.mode(kAccent, BlendMode.srcIn)),
            label: 'Inspiration',
          ),
          BottomNavigationBarItem(
            icon: SvgPicture.asset(
              'assets/images/svg/spin-outline.svg',
              width: getPercentageWidth(3, context),
              height: getPercentageHeight(3, context),
              colorFilter: ColorFilter.mode(
                  themeProvider.isDarkMode
                        ? kWhite.withValues(alpha: 0.7)
                      : kBlack.withValues(alpha: 0.7),
                  BlendMode.srcIn),
            ),
            activeIcon: SvgPicture.asset('assets/images/svg/spin.svg',
                width: getPercentageWidth(3, context),
                height: getPercentageHeight(3, context),
                colorFilter: const ColorFilter.mode(kAccent, BlendMode.srcIn)),
            label: 'Spin',
          ),
          BottomNavigationBarItem(
            icon: SvgPicture.asset(
              'assets/images/svg/cal-outline.svg',
              width: getPercentageWidth(3, context),
              height: getPercentageHeight(3, context),
              colorFilter: ColorFilter.mode(
                  themeProvider.isDarkMode
                        ? kWhite.withValues(alpha: 0.7)
                      : kBlack.withValues(alpha: 0.7),
                  BlendMode.srcIn),
            ),
            activeIcon: SvgPicture.asset('assets/images/svg/cal.svg',
                width: getPercentageWidth(3, context),
                height: getPercentageHeight(3, context),
                colorFilter: const ColorFilter.mode(kAccent, BlendMode.srcIn)),
            label: 'Schedule',
          ),
        ],
      ),
    );
  }
}
