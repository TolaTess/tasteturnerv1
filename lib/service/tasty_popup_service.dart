import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../constants.dart';
import '../data_models/macro_data.dart';
import '../data_models/meal_model.dart';
import '../helper/utils.dart';
import '../screens/buddy_screen.dart';
import '../themes/theme_provider.dart';
import '../screens/add_food_screen.dart';
import '../widgets/bottom_model.dart';
import '../widgets/bottom_nav.dart';

class TastyPopupService {
  static final TastyPopupService _instance = TastyPopupService._internal();
  factory TastyPopupService() => _instance;
  TastyPopupService._internal();

  // SharedPreferences keys
  final String _homeScreenKey = 'tasty_home_shown';
  final String _recipeScreenKey = 'tasty_recipe_shown';
  final String _challengeScreenKey = 'tasty_challenge_shown';
  final String _mealDesignScreenKey = 'tasty_meal_design_shown';
  final String _messageScreenKey = 'tasty_message_shown';

  ThemeProvider getThemeProvider(BuildContext context) {
    return Provider.of<ThemeProvider>(context, listen: false);
  }

  void _handleNavigation(BuildContext context, String screen,
      List<MacroData> fullLabelsList, List<Meal> mealList, String message) {
    Navigator.of(context).pop(); // Close the popup first

    switch (screen) {
      case 'home':
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const AddFoodScreen()),
        );
        break;
      case 'recipe':
        if (context.mounted) {
          showSpinWheel(
            context,
            'Carbs',
            fullLabelsList,
            mealList,
            fullLabelsList.map((label) => label.title).toSet().toList(),
            'All',
            false,
          );
        }
        break;
      case 'meal_design':
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
              builder: (context) => const BottomNavSec(
                    selectedIndex: 4,
                    foodScreenTabIndex:
                        2, // Keep tab 2 for meal design from popup
                  )),
        );
        break;
      case 'message':
        if (message.isNotEmpty &&
            message.contains('plot Your Plates together!')) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
                builder: (context) => const BottomNavSec(
                      selectedIndex: 4,
                      foodScreenTabIndex:
                          2, // Specific tab for challenge from popup
                    )),
          );
        } else {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const TastyScreen()),
          );
        }
        break;
    }
  }

  Future<void> showTastyPopup(BuildContext context, String screen,
      List<MacroData> fullLabelsList, List<Meal> mealList) async {
    final prefs = await SharedPreferences.getInstance();
    String message = '';
    String prefKey = '';
    String callToAction = '';

    // Determine message and key based on screen
    switch (screen) {
      case 'home':
        prefKey = _homeScreenKey;
        message = getRandomBio(TastyHomeBios);
        callToAction = 'Add Food';
        break;
      case 'recipe':
        prefKey = _recipeScreenKey;
        message = getRandomBio(TastyRecipeBios);
        callToAction = 'Spin the wheel';
        break;
      case 'food_challenge':
        prefKey = _challengeScreenKey;
        message = getRandomBio(TastyChallengeBios);
        callToAction = '';
        break;
      case 'meal_design':
        prefKey = _mealDesignScreenKey;
        message = getRandomBio(TastyMealDesignBios);
        callToAction = 'Tasty\'s Design';
        break;
      case 'message':
        prefKey = _messageScreenKey;
        message = getRandomBio(TastyMessageBios);
        callToAction = 'Chat with Tasty';
        break;
      default:
        return;
    }

    // Check if popup has been shown before
    bool hasShown = prefs.getBool(prefKey) ?? false;
    if (!hasShown && context.mounted) {
      // Show the popup
      await showDialog(
        context: context,
        barrierDismissible: true,
        builder: (BuildContext context) {
          return Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color:
                    getThemeProvider(context).isDarkMode ? kDarkGrey : kWhite,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0, end: 1),
                    duration: const Duration(seconds: 15),
                    curve: Curves.easeInOut,
                    builder: (context, value, child) {
                      return Transform.translate(
                        offset: Offset(
                            value * 200 - 100, 0), // Moves from -100 to +100
                        child: const CircleAvatar(
                          radius: 25,
                          backgroundImage:
                              AssetImage('assets/images/tasty_cheerful.jpg'),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  Text(
                    message,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => _handleNavigation(
                        context, screen, fullLabelsList, mealList, message),
                    child: Text(callToAction),
                  ),
                ],
              ),
            ),
          );
        },
      );

      // Mark as shown
      await prefs.setBool(prefKey, true);
      await prefs.setString(
          'tasty_popup_shown_date', DateTime.now().toString().split(' ')[0]);
    }
  }

  // Reset all popups
  Future<void> resetAllPopups() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString('tasty_popup_shown_date') !=
        DateTime.now().toString().split(' ')[0]) {
      await prefs.setBool(_homeScreenKey, false);
      await prefs.setBool(_recipeScreenKey, false);
      await prefs.setBool(_challengeScreenKey, false);
      await prefs.setBool(_mealDesignScreenKey, false);
      await prefs.setBool(_messageScreenKey, false);
      await prefs.setString(
          'tasty_popup_shown_date', DateTime.now().toString().split(' ')[0]);
    }
  }
}
