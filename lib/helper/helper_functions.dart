import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:tasteturner/helper/utils.dart';
import '../constants.dart';
import '../screens/buddy_screen.dart';
import '../screens/premium_screen.dart';
import '../service/user_service.dart';
import '../themes/theme_provider.dart';
import '../widgets/optimized_image.dart';

Widget buildTastyFloatingActionButton({
  required BuildContext context,
  required Key? buttonKey,
  required UserService userService,
  required ThemeProvider themeProvider,
}) {
  return FloatingActionButton(
    key: buttonKey,
    onPressed: () {
      if (userService.currentUser?.isPremium ?? false) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const TastyScreen(),
          ),
        );
      } else {
        showDialog(
          context: context,
          builder: (context) => showPremiumDialog(context, themeProvider.isDarkMode, 'Premium Feature', 'Upgrade to premium to chat with your AI buddy Tasty 👋 and get personalized nutrition advice!'),
        );
      }
    },
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
  double outerRadius = 5,
  double innerRadius = 4.5,
  double imageSize = 50,
  Color? backgroundColor,
  required BuildContext context,
}) {
  return CircleAvatar(
    radius: getPercentageHeight(outerRadius, context),
    backgroundColor: backgroundColor ?? kAccent.withOpacity(kOpacity),
    child: CircleAvatar(
      radius: getPercentageHeight(innerRadius, context),
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

Widget getBirthdayTextContainer(String birthdayName, bool isShrink) {
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
        fontSize: isShrink ? 12 : 14,
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

Future<void> saveMealPlanToFirestore(String userId, String date,
    List<String> mealIds, Map<String, dynamic>? mealPlan) async {
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

Widget showPremiumDialog(BuildContext context, bool isDarkMode, String title, String message) {
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