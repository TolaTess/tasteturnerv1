import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';

class OnboardingPromptHelper {
  static const String PROMPT_GOALS_SHOWN = 'prompt_goals_shown';
  static const String PROMPT_DIETARY_SHOWN = 'prompt_dietary_shown';
  static const String PROMPT_WEIGHT_SHOWN = 'prompt_weight_shown';
  static const String PROMPT_PROFILE_SHOWN = 'prompt_profile_shown';

  /// Check if goals prompt should be shown
  static Future<bool> shouldShowGoalsPrompt() async {
    final prefs = await SharedPreferences.getInstance();
    final hasShown = prefs.getBool(PROMPT_GOALS_SHOWN) ?? false;

    if (hasShown) return false;

    final user = userService.currentUser.value;
    if (user == null) return false;

    final settings = user.settings;
    final fitnessGoal = settings['fitnessGoal']?.toString() ?? '';
    final foodGoal = settings['foodGoal']?.toString() ?? '';

    // Show prompt if using default values
    return fitnessGoal == 'Healthy Eating' && foodGoal == '2000';
  }

  /// Check if dietary prompt should be shown
  static Future<bool> shouldShowDietaryPrompt() async {
    final prefs = await SharedPreferences.getInstance();
    final hasShown = prefs.getBool(PROMPT_DIETARY_SHOWN) ?? false;

    if (hasShown) return false;

    final user = userService.currentUser.value;
    if (user == null) return false;

    final preferences = user.preferences;
    final diet = preferences['diet']?.toString() ?? '';
    final allergies = preferences['allergies'] as List<dynamic>? ?? [];

    // Show prompt if using default values
    return diet == 'None' && allergies.isEmpty;
  }

  /// Check if weight prompt should be shown
  static Future<bool> shouldShowWeightPrompt() async {
    final prefs = await SharedPreferences.getInstance();
    final hasShown = prefs.getBool(PROMPT_WEIGHT_SHOWN) ?? false;

    if (hasShown) return false;

    final user = userService.currentUser.value;
    if (user == null) return false;

    final settings = user.settings;
    final currentWeight = settings['currentWeight']?.toString() ?? '';
    final goalWeight = settings['goalWeight']?.toString() ?? '';

    // Show prompt if weight fields are empty
    return currentWeight.isEmpty && goalWeight.isEmpty;
  }

  /// Check if profile prompt should be shown
  static Future<bool> shouldShowProfilePrompt() async {
    final prefs = await SharedPreferences.getInstance();
    final hasShown = prefs.getBool(PROMPT_PROFILE_SHOWN) ?? false;

    if (hasShown) return false;

    final user = userService.currentUser.value;
    if (user == null) return false;

    final dob = user.dob ?? '';
    final gender = user.settings['gender'];

    // Show prompt if DOB is empty or gender is null
    return dob.isEmpty || gender == null;
  }

  /// Mark goals prompt as shown
  static Future<void> markGoalsPromptShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(PROMPT_GOALS_SHOWN, true);
  }

  /// Mark dietary prompt as shown
  static Future<void> markDietaryPromptShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(PROMPT_DIETARY_SHOWN, true);
  }

  /// Mark weight prompt as shown
  static Future<void> markWeightPromptShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(PROMPT_WEIGHT_SHOWN, true);
  }

  /// Mark profile prompt as shown
  static Future<void> markProfilePromptShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(PROMPT_PROFILE_SHOWN, true);
  }

  /// Reset all prompts (for testing purposes)
  static Future<void> resetAllPrompts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(PROMPT_GOALS_SHOWN);
    await prefs.remove(PROMPT_DIETARY_SHOWN);
    await prefs.remove(PROMPT_WEIGHT_SHOWN);
    await prefs.remove(PROMPT_PROFILE_SHOWN);
  }
}
