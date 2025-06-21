import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tasteturner/tabs_screen/recipe_screen.dart';
import 'package:tasteturner/tabs_screen/spin_screen.dart';
import '../constants.dart';
import '../tabs_screen/home_screen.dart';
import '../tabs_screen/inspiration_screen.dart';
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

    final List<Widget> pages = [
      const HomeScreen(),
      const InspirationScreen(),
      const RecipeScreen(),
      SpinScreen(),
      MealDesignScreen(initialTabIndex: _currentTabIndex),
    ];

    return Scaffold(
      body: pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
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
            ? kWhite.withOpacity(0.7)
            : kBlack.withOpacity(0.7),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.search_outlined),
            activeIcon: Icon(Icons.search),
            label: 'Explore',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.book_outlined),
            activeIcon: Icon(Icons.book),
            label: 'Recipes',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.casino_outlined),
            activeIcon: Icon(Icons.casino),
            label: 'Spin',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.edit_calendar_outlined),
            activeIcon: Icon(Icons.edit_calendar),
            label: 'Planner',
          ),
        ],
      ),
    );
  }
}
