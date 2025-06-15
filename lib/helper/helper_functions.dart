import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tasteturner/helper/utils.dart';
import '../constants.dart';
import '../data_models/meal_model.dart';
import '../screens/buddy_screen.dart';
import '../screens/premium_screen.dart';
import '../themes/theme_provider.dart';
import '../widgets/optimized_image.dart';
import 'package:crop_your_image/crop_your_image.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'dart:async';

Widget buildTastyFloatingActionButton({
  required BuildContext context,
  required Key? buttonKey,
  required ThemeProvider themeProvider,
  required bool isInFreeTrial,
}) {
  return FloatingActionButton(
    key: buttonKey,
    onPressed: () {
      if (isInFreeTrial || userService.currentUser!.isPremium) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const TastyScreen(screen: 'message'),
          ),
        );
      } else {
        showDialog(
          context: context,
          builder: (context) => showPremiumDialog(
              context,
              themeProvider.isDarkMode,
              'Premium Feature',
              'Upgrade to premium to chat with your AI buddy Tasty 👋 and get personalized nutrition advice!'),
        );
      }
    },
    backgroundColor: kPrimaryColor,
    child: Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: kAccentLight.withOpacity(0.5),
        shape: BoxShape.circle,
        image: const DecorationImage(
          image: AssetImage(tastyImage),
          fit: BoxFit.cover,
        ),
      ),
    ),
  );
}

// Add this class before the MessageScreen class
class CustomFloatingActionButtonLocation extends FloatingActionButtonLocation {
  final double verticalOffset;
  final double horizontalOffset;

  const CustomFloatingActionButtonLocation({
    this.verticalOffset = 0,
    this.horizontalOffset = 0,
  });

  @override
  Offset getOffset(ScaffoldPrelayoutGeometry scaffoldGeometry) {
    final Offset offset =
        FloatingActionButtonLocation.endFloat.getOffset(scaffoldGeometry);
    return Offset(offset.dx - horizontalOffset, offset.dy - verticalOffset);
  }
}

Widget buildProfileAvatar({
  required String imageUrl,
  double outerRadius = 25,
  double innerRadius = 23,
  double imageSize = 100,
  Color? backgroundColor,
  required BuildContext context,
}) {
  return CircleAvatar(
    radius: getResponsiveBoxSize(context, outerRadius, outerRadius),
    backgroundColor: backgroundColor ?? kAccent.withOpacity(kOpacity),
    child: CircleAvatar(
      radius: getResponsiveBoxSize(context, innerRadius, innerRadius),
      child: ClipOval(
        child: OptimizedImage(
          imageUrl: imageUrl,
          width: getPercentageHeight(imageSize, context),
          height: getPercentageHeight(imageSize, context),
          isProfileImage: true,
        ),
      ),
    ),
  );
}

ImageProvider getAvatarImage(String? imageUrl) {
  if (imageUrl != null &&
      imageUrl.isNotEmpty &&
      imageUrl.startsWith("http") &&
      imageUrl != "null") {
    return NetworkImage(imageUrl);
  }
  return const AssetImage(intPlaceholderImage);
}

String getMealTimeOfDay() {
  final now = DateTime.now();
  final hour = now.hour;

  if (hour >= 5 && hour < 11) {
    return 'Breakfast';
  } else if (hour >= 11 && hour < 16) {
    return 'Lunch';
  } else {
    return 'Dinner';
  }
}

String getSharedCalendarHeader(String userName, String friendName) {
  // Handle null or empty names
  userName = userName.trim();
  friendName = friendName.trim();

  if (userName.isEmpty || friendName.isEmpty) {
    return 'Shared Calendar';
  }

  // Get initials from names
  String userInitial = userName[0].toUpperCase();

  return '$userInitial & $friendName';
}

Widget getBirthdayTextContainer(
    String birthdayName, bool isShrink, BuildContext context) {
  return Container(
    padding: EdgeInsets.symmetric(horizontal: isShrink ? 5 : 10),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(10),
      border: isShrink
          ? Border.all(color: kAccentLight, width: 1)
          : Border.all(color: kAccentLight, width: 0),
    ),
    child: Text(
      birthdayName.toLowerCase() == 'you'
          ? 'Happy Birthday to you!'
          : '${birthdayName}s birthday is today! 🎂',
      style: TextStyle(
        color: kAccentLight,
        fontSize: isShrink
            ? getTextScale(2.5, context)
            : getTextScale(3, context),
        fontWeight: isShrink ? FontWeight.normal : FontWeight.w400,
        overflow: isShrink ? TextOverflow.ellipsis : TextOverflow.visible,
      ),
    ),
  );
}

// Returns a string like 'Today', 'Yesterday', 'Tomorrow', or the weekday name for the given date
String getRelativeDayString(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final target = DateTime(date.year, date.month, date.day);
  final diff = target.difference(today).inDays;
  if (diff == 0) {
    return 'Today';
  } else if (diff == -1) {
    return 'Yesterday';
  } else if (diff == 1) {
    return 'Tomorrow';
  } else {
    return _weekdayName(target.weekday);
  }
}

String _weekdayName(int weekday) {
  switch (weekday) {
    case DateTime.monday:
      return 'Mon';
    case DateTime.tuesday:
      return 'Tues';
    case DateTime.wednesday:
      return 'Wed';
    case DateTime.thursday:
      return 'Thur';
    case DateTime.friday:
      return 'Fri';
    case DateTime.saturday:
      return 'Sat';
    case DateTime.sunday:
      return 'Sun';
    default:
      return '';
  }
}

// Add this helper method for nutritional info validation
bool _validateNutritionalInfo(Map<String, String> nutritionalInfo) {
  try {
    // Check if all required fields are present and can be parsed as numbers
    final requiredFields = ['calories', 'protein', 'carbs', 'fat'];
    for (final field in requiredFields) {
      if (!nutritionalInfo.containsKey(field) ||
          nutritionalInfo[field] == null ||
          nutritionalInfo[field]!.isEmpty ||
          int.tryParse(nutritionalInfo[field]!) == null) {
        print(
            'Validation failed for field: $field with value: ${nutritionalInfo[field]}');
        return false;
      }
    }
    return true;
  } catch (e) {
    print('Error during nutritional info validation: $e');
    return false;
  }
}

Future<List<String>> saveMealsToFirestore(String userId,
    Map<String, dynamic>? mealPlan, String selectedCuisine) async {
  if (mealPlan == null ||
      mealPlan['meals'] == null ||
      mealPlan['meals'] is! List) {
    print('Invalid mealPlan: $mealPlan');
    return [];
  }

  final List<String> mealIds = [];
  final mealCollection = firestore.collection('meals');
  final meals = mealPlan['meals'] as List<dynamic>;

  for (final mealData in meals) {
    if (mealData is! Map<String, dynamic>) {
      continue;
    }

    final mealId = mealCollection.doc().id;
    final nutritionalInfo =
        mealData['nutritionalInfo'] as Map<String, dynamic>? ?? {};

    // Process data
    final ingredients = _convertToStringMap(mealData['ingredients'] ?? []);
    final steps = _convertToStringList(mealData['instructions'] ?? []);
    final categories = [
      ..._convertToStringList(mealData['categories'] ?? []),
      selectedCuisine
    ];
    final type = _parseStringOrDefault(mealData['type'], '');

    final processedNutritionalInfo = {
      'calories': (nutritionalInfo['calories']?.toString() ?? '0').trim(),
      'protein': (nutritionalInfo['protein']?.toString() ?? '0').trim(),
      'carbs': (nutritionalInfo['carbs']?.toString() ?? '0').trim(),
      'fat': (nutritionalInfo['fat']?.toString() ?? '0').trim(),
    };

    if (!_validateNutritionalInfo(processedNutritionalInfo)) {
      print(
          'Error: Invalid nutritional information: $processedNutritionalInfo');
      continue;
    }

    final title = mealData['title']?.toString() ?? 'Untitled Meal';

    // Explicitly construct JSON to avoid Meal class serialization issues
    final mealJson = {
      'userId': tastyId,
      'title': title,
      'calories': int.parse(processedNutritionalInfo['calories'] ?? '0'),
      'mealId': mealId,
      'createdAt': Timestamp.fromDate(DateTime.now()), // Use server timestamp
      'ingredients': ingredients,
      'steps': steps,
      'mediaPaths': [type],
      'serveQty': mealData['serveQty'] is int ? mealData['serveQty'] : 1,
      'macros': {
        'protein': processedNutritionalInfo['protein'],
        'carbs': processedNutritionalInfo['carbs'],
        'fat': processedNutritionalInfo['fat'],
      },
      'category': type,
      'categories': categories,
      'mediaType': 'image',
    };

    try {
      await mealCollection.doc(mealId).set(mealJson);
      mealIds.add(mealId);
    } catch (e) {
      print('Error saving meal $mealId: $e');
      continue;
    }
  }
  return mealIds;
}

Map<String, String> _convertToStringMap(dynamic input) {
  if (input is List<dynamic>) {
    // Convert list of strings to a map with indexed keys
    return {
      for (int i = 0; i < input.length; i++)
        'ingredient${i + 1}': input[i].toString()
    };
  } else if (input is Map) {
    // Handle case where input is already a map
    return input
        .map((key, value) => MapEntry(key.toString(), value.toString()));
  }
  return {}; // Fallback for invalid input
}

String _parseStringOrDefault(dynamic value, String defaultValue) {
  if (value == null) return defaultValue;
  return value.toString();
}

List<String> _convertToStringList(dynamic value) {
  if (value is List) {
    return value.map((item) => item.toString()).toList();
  }
  return [];
}

Future<void> saveMealPlanToFirestore(
    String userId,
    String date,
    List<String> mealIds,
    Map<String, dynamic>? mealPlan,
    String selectedDiet) async {
  final docRef = firestore
      .collection('mealPlans')
      .doc(userId)
      .collection('buddy')
      .doc(date);

  // Fetch the existing document (if it exists)
  List<Map<String, dynamic>> existingGenerations = [];
  try {
    final existingDoc = await docRef.get();
    if (existingDoc.exists) {
      final existingData = existingDoc.data() as Map<String, dynamic>?;
      final generations = existingData?['generations'] as List<dynamic>?;
      if (generations != null) {
        existingGenerations =
            generations.map((gen) => gen as Map<String, dynamic>).toList();
      }
    }
  } catch (e) {
    print('Error fetching existing document: $e');
  }

  // Create a new generation object
  final newGeneration = {
    'mealIds': mealIds,
    'timestamp':
        Timestamp.fromDate(DateTime.now()), // Use client-side Timestamp
    'diet': selectedDiet ?? 'general',
  };

  // Add nutritionSummary and tips if they exist in mealPlan
  if (mealPlan != null) {
    if (mealPlan['nutritionalSummary'] != null) {
      newGeneration['nutritionalSummary'] = mealPlan['nutritionalSummary'];
    }
    if (mealPlan['tips'] != null) {
      newGeneration['tips'] = mealPlan['tips'];
    }
  }

  // Append the new generation to the list
  existingGenerations.add(newGeneration);

  // Prepare the data to save
  final mealPlanData = {
    'date': date,
    'generations': existingGenerations,
  };

  // Save the updated document
  try {
    await docRef.set(mealPlanData);
  } catch (e) {
    print('Error saving meal plan: $e');
  }
}

// Handle errors
void handleError(dynamic e, BuildContext context) {
  print('Error: $e');
  Navigator.of(context).pop(); // Hide loading
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        backgroundColor:
            getThemeProvider(context).isDarkMode ? kDarkGrey : kWhite,
        title: const Text(
          '$appNameBuddy',
          style: TextStyle(color: kAccent),
        ),
        content: Text(
          'Unable to generate meal plan at present. Please try again later.',
          style: TextStyle(
            color: getThemeProvider(context).isDarkMode ? kWhite : kDarkGrey,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'OK',
              style: TextStyle(
                color:
                    getThemeProvider(context).isDarkMode ? kWhite : kDarkGrey,
              ),
            ),
          ),
        ],
      );
    },
  );
}

Widget showPremiumDialog(
    BuildContext context, bool isDarkMode, String title, String message) {
  return AlertDialog(
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(15),
    ),
    backgroundColor: isDarkMode ? kDarkGrey : kWhite,
    title: Text(
      title,
      style: TextStyle(color: kAccent),
    ),
    content: Text(
      message,
      style: TextStyle(
        color: isDarkMode ? kWhite : kBlack,
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(
          'Cancel',
          style: TextStyle(
            color: isDarkMode ? kWhite : kBlack,
          ),
        ),
      ),
      TextButton(
        onPressed: () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const PremiumScreen(),
            ),
          );
        },
        child: const Text(
          'Upgrade',
          style: TextStyle(color: kAccentLight),
        ),
      ),
    ],
  );
}

String getFeatureDescription(String key, dynamic value) {
  switch (key.toLowerCase()) {
    case 'season':
      return 'Best harvested and consumed during $value season.\nThis is when the ingredient is at its peak freshness and flavor.';
    case 'water':
      return 'Contains $value water content.\nThis affects the ingredient\'s texture, cooking properties, and nutritional density.';
    case 'rainbow':
      return 'Natural color: $value\nColor indicates presence of different phytonutrients and antioxidants.';
    case 'fiber':
      return 'Contains $value fiber content in 100g.\nThis affects the ingredient\'s texture, cooking properties, and nutritional density.';
    case 'g_i':
      return 'Glycemic Index: $value\nGlycemic index measures how quickly a food raises blood sugar levels.';
    case 'freezer':
      return 'Store in freezer for $value.\nThis helps preserve the ingredient\'s freshness and flavor.';
    case 'fridge':
      return 'Store in refrigerator for $value.\nThis helps preserve the ingredient\'s freshness and flavor.';
    case 'countertop':
      return 'Store at room temperature for $value.\nThis helps preserve the ingredient\'s freshness and flavor.';
    default:
      return '$key: $value';
  }
}

String getFeatureIcon(String key) {
  switch (key.toLowerCase()) {
    case 'season':
      return '🌱';
    case 'water':
      return '💧';
    case 'rainbow':
      return '🎨';
    case 'fiber':
      return '⚖️';
    case 'g_i':
      return '🍬';
    case 'freezer':
      return '🧊';
    case 'fridge':
      return '❄️';
    case 'countertop':
      return '🍽️';
    default:
      return '📌';
  }
}

Future<void> showFeatureDialog(
    BuildContext context, bool isDarkMode, String key, String value) async {
  await showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        backgroundColor: isDarkMode ? kDarkGrey : kWhite,
        title: Row(
          children: [
            Text(
              getFeatureIcon(key),
              style: TextStyle(fontSize: getTextScale(3, context)),
            ),
            const SizedBox(width: 8),
            Text(
              key.toUpperCase(),
              style: TextStyle(
                color: kAccent,
                fontWeight: FontWeight.bold,
                fontSize: getTextScale(3, context),
              ),
            ),
          ],
        ),
        content: Text(
          getFeatureDescription(key, value),
          style: TextStyle(
            height: 1.5,
            color: isDarkMode ? kWhite : kBlack,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Close',
              style: TextStyle(color: kAccent),
            ),
          ),
        ],
      );
    },
  );
}

Future<XFile?> cropImage(XFile imageFile, BuildContext context) async {
  final Completer<XFile?> completer = Completer<XFile?>();
  final CropController controller = CropController();
  final imageBytes = await imageFile.readAsBytes();

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return AlertDialog(
        contentPadding: EdgeInsets.zero,
        content: SizedBox(
          width: 350,
          height: 450,
          child: Crop(
            controller: controller,
            image: imageBytes,
            onCropped: (croppedData) async {
              final tempDir = await getTemporaryDirectory();
              final croppedPath =
                  '${tempDir.path}/cropped_${DateTime.now().millisecondsSinceEpoch}.jpg';
              final croppedFile = File(croppedPath);
              await croppedFile.writeAsBytes(croppedData);
              Navigator.of(context).pop();
              completer.complete(XFile(croppedPath));
            },
            withCircleUi: false,
            initialSize: 0.8,
            baseColor: Colors.black,
            maskColor: Colors.black.withOpacity(0.5),
            cornerDotBuilder: (size, edgeAlignment) => Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => controller.crop(),
            child: const Text('Crop'),
          ),
        ],
      );
    },
  );
  return completer.future;
}

/// Consolidate grocery items by summing amounts for duplicate names.
/// Expects a list of maps: [{'name': 'tomato', 'amount': '100g'}, ...]
/// Returns a map: {'tomato': '200g', ...}
Map<String, String> consolidateGroceryAmounts(List<Map<String, String>> items) {
  final Map<String, num> totals = {};
  final Map<String, String> units = {};
  final Map<String, String> specialAmounts = {};

  for (final item in items) {
    final name = item['name']?.toLowerCase().trim();
    var amountStr = item['amount']?.trim() ?? '';
    if (name == null || name.isEmpty || amountStr.isEmpty) continue;

    // Check for special amounts like 'pinch' or 'to taste'
    if (amountStr.toLowerCase().contains('pinch') ||
        amountStr.toLowerCase().contains('to taste')) {
      specialAmounts[name] = amountStr;
      continue;
    }

    // Extract numeric value and unit (e.g., '100g' -> 100, 'g')
    final match = RegExp(r'([\d.]+)\s*([a-zA-Z]*)').firstMatch(amountStr);
    if (match != null) {
      final value = num.tryParse(match.group(1) ?? '0') ?? 0;
      final unit = match.group(2) ?? '';
      totals[name] = (totals[name] ?? 0) + value;
      units[name] = unit;
    } else {
      // If cannot parse, just keep the last value
      totals[name] = num.tryParse(amountStr) ?? 0;
      units[name] = '';
    }
  }

  // Build consolidated map
  final Map<String, String> consolidated = {};
  totals.forEach((name, total) {
    if (specialAmounts.containsKey(name)) {
      consolidated[name] = specialAmounts[name]!;
    } else {
      final unit = units[name] ?? '';
      consolidated[name] = unit.isNotEmpty ? '$total$unit' : '$total';
    }
  });
  return consolidated;
}

List<MealWithType> updateMealForFamily(List<MealWithType> personalMeals,
    String familyName, List<Map<String, dynamic>> familyList) {
  if (personalMeals.isEmpty) {
    return [];
  }

  // Check if any meals match the selected family name
  bool hasCategoryMatch = personalMeals.any(
      (meal) => meal.familyMember.toLowerCase() == familyName.toLowerCase());

  bool isCurrentUser = personalMeals.any(
      (meal) => meal.familyMember.toLowerCase() == userService.userId?.toLowerCase());

  if (isCurrentUser && familyName.toLowerCase() == userService.currentUser?.displayName?.toLowerCase()) {
    return personalMeals.where((meal) => meal.familyMember.toLowerCase() == userService.userId?.toLowerCase()).toList();
  }

  // If no matches found, only show meals if family name matches current user
  if (!hasCategoryMatch) {
    if (familyName.toLowerCase() == userService.currentUser?.displayName?.toLowerCase()) {
      return personalMeals.where((meal) => meal.familyMember.isEmpty).toList();
    }
    return [];
  }

  // Otherwise return meals matching the selected family name
  return personalMeals
      .where((meal) =>
          meal.familyMember.toLowerCase() == familyName.toLowerCase() ||
          meal.familyMember.isEmpty)
      .toList();
}
