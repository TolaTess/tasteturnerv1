import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:tasteturner/helper/utils.dart';
import '../constants.dart';
import '../data_models/meal_model.dart';
import '../data_models/user_meal.dart';
import '../screens/buddy_screen.dart';
import '../screens/food_analysis_results_screen.dart';
import '../screens/premium_screen.dart';
import '../themes/theme_provider.dart';
import '../widgets/optimized_image.dart';
import 'package:crop_your_image/crop_your_image.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

Widget buildTastyFloatingActionButton({
  required BuildContext context,
  required Key? buttonKey,
  required ThemeProvider themeProvider,
}) {
  return FloatingActionButton(
    key: buttonKey,
    onPressed: () {
      if (canUseAI()) {
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
              'Upgrade to premium to chat with your AI buddy Tasty 👋 and get personalized nutrition advice! Your free trial ended on ${userService.currentUser.value?.freeTrialDate}.'),
        );
      }
    },
    backgroundColor: themeProvider.isDarkMode ? kWhite : kDarkGrey,
    child: CircleAvatar(
      key:
          buttonKey != null ? ValueKey('avatar_${buttonKey.toString()}') : null,
      backgroundColor: themeProvider.isDarkMode ? kWhite : kDarkGrey,
      child: Icon(
        Icons.auto_awesome,
        color: kAccent,
        size: getIconScale(7, context),
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

Widget buildFullWidthAddMealButton({
  required BuildContext context,
  required Meal meal,
  required DateTime date,
  VoidCallback? onSuccess,
  VoidCallback? onError,
}) {
  final isDarkMode = getThemeProvider(context).isDarkMode;
  final textTheme = Theme.of(context).textTheme;

  Future<void> addMealToTracking() async {
    try {
      final userMeal = UserMeal(
        name: meal.title,
        quantity: '1',
        calories: meal.calories,
        mealId: meal.mealId,
        servings: 'serving',
      );

      await dailyDataController.addUserMeal(
        userService.userId ?? '',
        getMealTimeOfDay(),
        userMeal,
        date,
      );

      if (context.mounted) {
        showTastySnackbar(
          'Success',
          'Added ${meal.title} to today\'s meals',
          context,
        );
      }
      onSuccess?.call();
    } catch (e) {
      if (context.mounted) {
        showTastySnackbar(
          'Error',
          'Failed to add meal: Please try again later',
          context,
          backgroundColor: kRed,
        );
      }
      onError?.call();
    }
  }

  return Container(
    width: MediaQuery.of(context).size.width - getPercentageWidth(9, context),
    height: getPercentageHeight(7, context),
    decoration: BoxDecoration(
      color: isDarkMode ? kBackgroundColor : kDarkGrey,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: kAccent.withValues(alpha: 0.2),
          blurRadius: 5,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: addMealToTracking,
        child: Padding(
          padding:
              EdgeInsets.symmetric(horizontal: getPercentageWidth(4, context)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.add_circle_outline,
                color: kAccent,
                size: getIconScale(6, context),
              ),
              SizedBox(width: getPercentageWidth(3, context)),
              Expanded(
                child: Text(
                  'Add to Today\'s Meals',
                  style: textTheme.titleMedium?.copyWith(
                    color: kAccent,
                    fontWeight: FontWeight.w600,
                    fontSize: getTextScale(4, context),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              Icon(
                Icons.restaurant_menu,
                color: kAccent,
                size: getIconScale(6, context),
              ),
            ],
          ),
        ),
      ),
    ),
  );
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
    backgroundColor: backgroundColor ?? kAccent.withValues(alpha: kOpacity),
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
    return CachedNetworkImageProvider(imageUrl);
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
        fontSize:
            isShrink ? getTextScale(2.5, context) : getTextScale(3, context),
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
    return '${_weekdayName(target.weekday)},';
  }
}

String shortMonthName(int month) {
  switch (month) {
    case DateTime.january:
      return 'Jan';
    case DateTime.tuesday:
      return 'Feb';
    case DateTime.march:
      return 'Mar';
    case DateTime.april:
      return 'Apr';
    case DateTime.may:
      return 'May';
    case DateTime.june:
      return 'Jun';
    case DateTime.july:
      return 'Jul';
    case DateTime.august:
      return 'Aug';
    case DateTime.september:
      return 'Sep';
    case DateTime.october:
      return 'Oct';
    case DateTime.november:
      return 'Nov';
    case DateTime.december:
      return 'Dec';
    default:
      return '';
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
        debugPrint(
            'Validation failed for field: $field with value: ${nutritionalInfo[field]}');
        return false;
      }
    }
    return true;
  } catch (e) {
    showTastySnackbar(
        'Something went wrong', 'Please try again later', Get.context!,
        backgroundColor: kRed);
    return false;
  }
}

Future<void> saveMealPlanToFirestore(String userId, String date,
    List<String> mealIds, Map<String, dynamic>? mealPlan, String selectedDiet,
    {String? familyMemberName}) async {
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
      final existingData = existingDoc.data();
      final generations = existingData?['generations'] as List<dynamic>?;
      if (generations != null) {
        existingGenerations =
            generations.map((gen) => gen as Map<String, dynamic>).toList();
      }
    }
  } catch (e) {
    showTastySnackbar(
        'Something went wrong', 'Please try again later', Get.context!,
        backgroundColor: kRed);
  }

  // Create a new generation object
  final newGeneration = {
    'mealIds': mealIds,
    'timestamp':
        Timestamp.fromDate(DateTime.now()), // Use client-side Timestamp
    'diet': selectedDiet,
    'familyMemberName': familyMemberName, // Add family member name if provided
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
    showTastySnackbar(
        'Something went wrong', 'Please try again later', Get.context!,
        backgroundColor: kRed);
  }
}

// Handle errors
void handleError(dynamic e, BuildContext context) {
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
      message +
          '\n\nYour free trial ended on ${userService.currentUser.value?.freeTrialDate.toString().split(' ')[0]}.',
      style: TextStyle(
        color: isDarkMode
            ? kWhite.withValues(alpha: 0.8)
            : kBlack.withValues(alpha: 0.7),
        fontSize: getTextScale(3.5, context),
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
  if (value.toString().toLowerCase() == 'na' ||
      value.toString().toLowerCase() == 'not recommended') {
    return '${capitalizeFirstLetter(key)}: Not Suitable';
  }
  switch (key.toLowerCase()) {
    case 'season':
      return 'Best harvested and consumed during $value season.\nThis is when the ingredient is at its peak freshness and flavor.';
    case 'water':
      return 'Contains $value water content.\nThis affects the ingredient\'s texture, cooking properties, and nutritional density.';
    case 'rainbow':
      return getRainbowDescription(value);
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

String getRainbowDescription(dynamic value) {
  switch (value.toLowerCase()) {
    case 'red':
      return 'Natural color: ${value.toUpperCase()}\nRich in phytonutrients, which helps fight off infections and diseases. Prevents damage that alters gene expression, which can help reduce inflammation and improve heart health.';
    case 'orange':
    case 'yellow':
      return 'Natural color: ${value.toUpperCase()}\nRich in antioxidants, which promotes collagen production, which helps lower risk of reproductive diseases. High in beta-carotene. ';
    case 'green':
      return 'Natural color: ${value.toUpperCase()}\nRich in antioxidants which promotes health and healing. Anti-inflammatory, lowers risk of heart disease and a natural detoxifying with gut-healthy fiber and electrolytes.';
    case 'purple':
    case 'blue':
      return 'Natural color: ${value.toUpperCase()}\nRich in polyphenols, which is high in anthocyanins that repair cell damage with an anti-inflammatory, resveratrol for skin and heart health, support healthy aging and improve cognitive function.';
    default:
      return 'Natural color: ${value.toUpperCase()}\nColor indicates presence of different phytonutrients and antioxidants.';
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

Future<XFile?> cropImage(
    XFile imageFile, BuildContext context, bool isDarkMode) async {
  final Completer<XFile?> completer = Completer<XFile?>();
  final CropController controller = CropController();

  // Preprocess the image to fix orientation issues for gallery images (especially on iOS)
  Uint8List imageBytes;
  try {
    // iOS has more EXIF orientation issues than Android, so preprocess more aggressively on iOS
    final bool needsPreprocessing = Platform.isIOS;

    if (needsPreprocessing) {
      // Use flutter_image_compress to normalize the image and fix orientation
      final compressedFile = await FlutterImageCompress.compressWithFile(
        imageFile.path,
        quality: 95, // High quality to preserve crop interface clarity
        format: CompressFormat.jpeg,
        autoCorrectionAngle: true, // This fixes orientation issues
        keepExif: false, // Remove EXIF data that can cause display issues
      );

      if (compressedFile != null) {
        imageBytes = compressedFile;
      } else {
        // Fallback to original if compression fails
        imageBytes = await imageFile.readAsBytes();
      }
    } else {
      // Android typically handles orientation better, use original
      imageBytes = await imageFile.readAsBytes();
    }
  } catch (e) {
    imageBytes = await imageFile.readAsBytes();
  }

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      final textTheme = Theme.of(context).textTheme;
      return AlertDialog(
        backgroundColor: isDarkMode ? kDarkGrey : kWhite,
        contentPadding: EdgeInsets.zero,
        content: SizedBox(
          width: 350,
          height: 450,
          child: Crop(
            controller: controller,
            image: imageBytes,
            aspectRatio: null, // Allow free aspect ratio
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
            maskColor: Colors.black.withValues(alpha: 0.5),
            cornerDotBuilder: (size, edgeAlignment) => Container(
              width: size,
              height: size,
              decoration: const BoxDecoration(
                color: kAccent,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: Text('Cancel',
                style: textTheme.bodyMedium?.copyWith(
                    color: getThemeProvider(context).isDarkMode
                        ? kWhite
                        : kDarkGrey)),
          ),
          TextButton(
            onPressed: () => controller.crop(),
            child: Text('Crop',
                style: textTheme.bodyMedium?.copyWith(color: kAccent)),
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

  bool isCurrentUser = personalMeals.any((meal) =>
      meal.familyMember.toLowerCase() == userService.userId?.toLowerCase());

  if (isCurrentUser &&
      familyName.toLowerCase() ==
          userService.currentUser.value?.displayName?.toLowerCase()) {
    return personalMeals
        .where((meal) =>
            meal.familyMember.toLowerCase() ==
            userService.userId?.toLowerCase())
        .toList();
  }

  // If no matches found, only show meals if family name matches current user
  if (!hasCategoryMatch) {
    if (familyName.toLowerCase() ==
        userService.currentUser.value?.displayName?.toLowerCase()) {
      return personalMeals.where((meal) => meal.familyMember.isEmpty).toList();
    }
    return [];
  }

  // For family members, only show meals that specifically belong to them
  // Meals without family name should only be shown to the main user
  if (familyName.toLowerCase() ==
      userService.currentUser.value?.displayName?.toLowerCase()) {
    // Main user sees their own meals (with family name) and meals without family name
    return personalMeals
        .where((meal) =>
            meal.familyMember.toLowerCase() == familyName.toLowerCase() ||
            meal.familyMember.isEmpty)
        .toList();
  } else {
    // Family members only see meals that specifically belong to them
    return personalMeals
        .where((meal) =>
            meal.familyMember.toLowerCase() == familyName.toLowerCase())
        .toList();
  }
}

final colors = [
  kAccent.withValues(alpha: kMidOpacity),
  kBlue.withValues(alpha: kMidOpacity),
  kAccentLight.withValues(alpha: kMidOpacity),
  kPurple.withValues(alpha: kMidOpacity),
  kPink.withValues(alpha: kMidOpacity)
];

// Check if user can use AI features (premium or free trial)
bool canUseAI() {
  final freeTrialDate = userService.currentUser.value?.freeTrialDate;
  final isFreeTrial =
      freeTrialDate != null && DateTime.now().isBefore(freeTrialDate);
  final isPremium = userService.currentUser.value?.isPremium ?? false;
  return isPremium || isFreeTrial;
}

/// Check camera permission status and request if needed
Future<bool> checkAndRequestCameraPermission(
    BuildContext context, bool isDarkMode) async {
  final status = await Permission.camera.status;

  if (status.isGranted) {
    return true;
  }

  if (status.isDenied) {
    // Show explanation dialog before requesting
    final shouldRequest =
        await _showCameraPermissionExplanation(context, isDarkMode);
    if (!shouldRequest) {
      return false;
    }

    // Request permission
    final result = await Permission.camera.request();
    if (result.isGranted) {
      return true;
    } else if (result.isPermanentlyDenied) {
      await _showCameraPermissionPermanentlyDeniedDialog(context, isDarkMode);
      return false;
    }
    return false;
  }

  if (status.isPermanentlyDenied) {
    await _showCameraPermissionPermanentlyDeniedDialog(context, isDarkMode);
    return false;
  }

  if (status.isRestricted) {
    showTastySnackbar(
      'Camera Unavailable',
      'Camera access is restricted on this device.',
      context,
      backgroundColor: kRed,
    );
    return false;
  }

  return false;
}

/// Show camera permission explanation dialog
Future<bool> _showCameraPermissionExplanation(
    BuildContext context, bool isDarkMode) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (BuildContext context) {
      return AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        backgroundColor: isDarkMode ? kDarkGrey : kWhite,
        title: Row(
          children: [
            Icon(Icons.camera_alt,
                color: kAccent, size: getIconScale(8, context)),
            SizedBox(width: getPercentageWidth(2, context)),
            Expanded(
              child: Text(
                'Camera Access Needed',
                style: TextStyle(
                  color: isDarkMode ? kWhite : kDarkGrey,
                  fontSize: getTextScale(4.5, context),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'Camera access helps analyze your meals for accurate nutrition tracking and better dietary insights.',
          style: TextStyle(
            color: isDarkMode ? kWhite.withOpacity(0.9) : kDarkGrey,
            fontSize: getTextScale(3.5, context),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: isDarkMode ? kWhite.withOpacity(0.7) : kLightGrey,
                fontSize: getTextScale(3.5, context),
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: kAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'Allow',
              style: TextStyle(
                color: kWhite,
                fontSize: getTextScale(3.5, context),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      );
    },
  );

  return result ?? false;
}

/// Show dialog when camera permission is permanently denied
Future<void> _showCameraPermissionPermanentlyDeniedDialog(
    BuildContext context, bool isDarkMode) async {
  await showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        backgroundColor: isDarkMode ? kDarkGrey : kWhite,
        title: Text(
          'Camera Permission Required',
          style: TextStyle(
            color: isDarkMode ? kWhite : kDarkGrey,
            fontSize: getTextScale(4.5, context),
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'Camera access was denied. To use this feature, please enable camera permission in Settings → TasteTurner → Camera.',
          style: TextStyle(
            color: isDarkMode ? kWhite.withOpacity(0.9) : kDarkGrey,
            fontSize: getTextScale(3.5, context),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: isDarkMode ? kWhite.withOpacity(0.7) : kLightGrey,
                fontSize: getTextScale(3.5, context),
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: kAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () async {
              Navigator.of(context).pop();
              await openAppSettings();
            },
            child: Text(
              'Open Settings',
              style: TextStyle(
                color: kWhite,
                fontSize: getTextScale(3.5, context),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      );
    },
  );
}

// Consolidated camera action function with optional mealType
Future<void> handleCameraAction({
  required BuildContext context,
  required DateTime date,
  required bool isDarkMode,
  String? mealType,
  VoidCallback? onSuccess,
  VoidCallback? onError,
}) async {
  // Check if user can use AI features
  if (!canUseAI()) {
    showPremiumRequiredDialog(context, isDarkMode);
    return;
  }

  try {
    // Show media selection dialog first
    final selectedOption = await showMediaSelectionDialog(
      isCamera: true,
      context: context,
      isVideo: false,
    );

    if (selectedOption == null) {
      return; // User cancelled the dialog
    }

    // Check camera permission if user selected camera option
    if (selectedOption == 'photo') {
      final hasPermission =
          await checkAndRequestCameraPermission(context, isDarkMode);
      if (!hasPermission) {
        return; // Permission denied or user cancelled
      }
    }

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: kAccent),
      ),
    );

    List<XFile> pickedImages = [];

    if (selectedOption == 'photo') {
      // Take photo with camera
      final ImagePicker picker = ImagePicker();
      final XFile? photo = await picker.pickImage(source: ImageSource.camera);
      if (photo != null) {
        pickedImages = [photo];
      }
    } else if (selectedOption == 'gallery') {
      // Pick image from gallery using the existing modal
      pickedImages = await openMultiImagePickerModal(context: context);
    }

    if (pickedImages.isEmpty) {
      hideLoadingDialog(context); // Close loading dialog
      return;
    }

    // Crop the first image
    XFile? croppedImage =
        await cropImage(pickedImages.first, context, isDarkMode);
    if (croppedImage == null) {
      hideLoadingDialog(context); // Close loading dialog
      return;
    }

    hideLoadingDialog(context); // Close loading dialog

    // Ask user about posting before starting analysis
    bool isPosting = await showPostDialog(context);

    // Show loading dialog for analysis
    showLoadingDialog(context);

    try {
      // Check premium access for AI analysis
      if (!canUseAI()) {
        hideLoadingDialog(context); // Close analysis loading dialog
        showPremiumRequiredDialog(context, isDarkMode);
        onError?.call();
        return;
      }

      // Analyze the image
      final analysisResult = await geminiService.analyzeFoodImageWithContext(
        imageFile: File(croppedImage.path),
        mealType: mealType,
      );

      hideLoadingDialog(context);

      // Navigate to results screen for review and editing
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => FoodAnalysisResultsScreen(
            imageFile: File(croppedImage.path),
            analysisResult: analysisResult,
            isAnalyzeAndUpload: isPosting,
            date: date,
            mealType: mealType,
          ),
        ),
      );
    } catch (e) {
      debugPrint('Food analysis error (catch 1): $e');
      debugPrint('Stack trace: ${StackTrace.current}');
      hideLoadingDialog(context); // Close analysis loading dialog
      showTastySnackbar(
        'Error',
        'Analysis failed: ${e.toString()}',
        context,
        backgroundColor: kRed,
      );
      onError?.call();
      return;
    }

    onSuccess?.call();
  } catch (e) {
    debugPrint('Food analysis error (catch 2): $e');
    debugPrint('Stack trace: ${StackTrace.current}');
    hideLoadingDialog(context); // Close loading dialog

    // Check if error is permission-related
    String errorMessage = 'Analysis failed: ${e.toString()}';
    if (e.toString().contains('permission') ||
        e.toString().contains('Permission')) {
      errorMessage =
          'Camera permission denied. Please enable camera access in Settings → TasteTurner → Camera.';
    } else if (e.toString().contains('camera')) {
      errorMessage = 'Camera not available. Please try using gallery instead.';
    }

    showTastySnackbar(
      'Error',
      errorMessage,
      context,
      backgroundColor: kRed,
    );
    onError?.call();
  }
}

Widget buildFullWidthHomeButton({
  required BuildContext context,
  required GlobalKey key,
  required DateTime date,
  VoidCallback? onSuccess,
  VoidCallback? onError,
}) {
  final isDarkMode = getThemeProvider(context).isDarkMode;
  final textTheme = Theme.of(context).textTheme;

  Future<void> navigateToTasty() async {
    if (canUseAI()) {
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
            isDarkMode,
            'Premium Feature',
            'Upgrade to premium to chat with your AI buddy Tasty 👋 and get personalized nutrition advice!'),
      );
    }
  }

  return Container(
    width: getPercentageWidth(100, context) - getPercentageWidth(9, context),
    height: getPercentageHeight(7, context),
    decoration: BoxDecoration(
      color: isDarkMode ? kBackgroundColor : kDarkGrey,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: kAccent.withValues(alpha: 0.2),
          blurRadius: 5,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Row(
      children: [
        // Left side - Analyse meal
        Expanded(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                bottomLeft: Radius.circular(16),
              ),
              key: key,
              onTap: () => handleCameraAction(
                context: context,
                date: date,
                isDarkMode: isDarkMode,
                onSuccess: onSuccess,
                onError: onError,
              ),
              child: Container(
                height: double.infinity,
                padding: EdgeInsets.symmetric(
                    vertical: getPercentageHeight(1, context),
                    horizontal: getPercentageWidth(15, context)),
                child: Stack(
                  children: [
                    Text(
                      'Analyze\n Your Meal',
                      style: textTheme.displaySmall?.copyWith(
                        color: canUseAI() ? kAccentLight : Colors.grey,
                        fontWeight: FontWeight.w600,
                        fontSize: getTextScale(3.8, context),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (!canUseAI())
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: kAccentLight.withValues(alpha: 0.5),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.lock,
                            color: Colors.grey,
                            size: getIconScale(3, context),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        // Divider
        Container(
          width: 1,
          height: getPercentageHeight(4, context),
          color: isDarkMode ? Colors.grey[700] : Colors.grey[300],
        ),
        // Right side - Tasty screen navigation
        Expanded(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
              onTap: navigateToTasty,
              child: Container(
                height: double.infinity,
                padding: EdgeInsets.symmetric(
                    vertical: getPercentageHeight(1, context),
                    horizontal: getPercentageWidth(15, context)),
                child: Stack(
                  children: [
                    Text(
                      'Chat with\nTasty AI',
                      style: textTheme.displaySmall?.copyWith(
                        color: canUseAI() ? kAccentLight : Colors.grey,
                        fontWeight: FontWeight.w600,
                        fontSize: getTextScale(3.8, context),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (!canUseAI())
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: kAccentLight.withValues(alpha: 0.5),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.lock,
                            color: Colors.grey,
                            size: getIconScale(3, context),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

Future<String?> showMediaSelectionDialog(
    {required bool isCamera,
    required BuildContext context,
    bool isVideo = false}) async {
  return await showDialog<String>(
    context: context,
    builder: (BuildContext context) {
      final isDarkMode = getThemeProvider(context).isDarkMode;
      final textTheme = Theme.of(context).textTheme;

      final title = isCamera ? 'Choose Camera mode' : 'Choose Media type';
      final options = isCamera
          ? [
              {
                'icon': Icons.photo_camera,
                'title': 'Take Photo',
                'value': 'photo'
              },
              if (isVideo)
                {
                  'icon': Icons.video_library,
                  'title': 'Take Video',
                  'value': 'video'
                },
              if (!isVideo)
                {
                  'icon': Icons.photo_library,
                  'title': 'Pick from Gallery',
                  'value': 'gallery'
                },
            ]
          : [
              {'icon': Icons.photo, 'title': 'Photos', 'value': 'photos'},
              {'icon': Icons.video_library, 'title': 'Video', 'value': 'video'},
            ];

      return AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        backgroundColor: isDarkMode ? kDarkGrey : kWhite,
        title: Text(
          title,
          style: textTheme.titleLarge?.copyWith(color: kAccentLight),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: options
              .map((option) => ListTile(
                    leading: Icon(
                      option['icon'] as IconData,
                      color: isDarkMode ? kWhite : kDarkGrey,
                    ),
                    title: Text(
                      option['title'] as String,
                      style: textTheme.titleMedium?.copyWith(
                        color: isDarkMode ? kWhite : kDarkGrey,
                      ),
                    ),
                    onTap: () =>
                        Navigator.pop(context, option['value'] as String),
                  ))
              .toList(),
        ),
      );
    },
  );
}

// Helper function for premium dialog
void showPremiumRequiredDialog(BuildContext context, bool isDarkMode) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      backgroundColor: isDarkMode ? kDarkGrey : kWhite,
      title: Text(
        'Premium Feature',
        style: TextStyle(
          color: isDarkMode ? kWhite : kBlack,
          fontWeight: FontWeight.w600,
          fontSize: getTextScale(4.5, context),
        ),
      ),
      content: Text(
        'AI food analysis is a premium feature. Update to premium to unlock this and many other amazing features! \n\nYour free trial ended on ${userService.currentUser.value?.freeTrialDate.toString().split(' ')[0]}.',
        style: TextStyle(
          color: isDarkMode
              ? kWhite.withValues(alpha: 0.8)
              : kBlack.withValues(alpha: 0.7),
          fontSize: getTextScale(3.5, context),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Maybe Later',
            style: TextStyle(
              color: Colors.grey,
              fontSize: getTextScale(3.5, context),
            ),
          ),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            // Navigate to premium screen
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const PremiumScreen()),
            );
          },
          child: Text(
            'Premium',
            style: TextStyle(
              color: kAccent,
              fontWeight: FontWeight.w600,
              fontSize: getTextScale(3.5, context),
            ),
          ),
        ),
      ],
    ),
  );
}

Future<bool> showPostDialog(BuildContext context) async {
  return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor:
              getThemeProvider(context).isDarkMode ? kDarkGrey : kWhite,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: const Text(
            'Also Add to Explore?',
            style: TextStyle(color: kAccent),
          ),
          content: const Text(
            'Sharing your meal with the community will help others learn and improve their nutrition.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: const Text(
                'No',
                style: TextStyle(color: kAccentLight),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              child: const Text(
                'Yes',
                style: TextStyle(color: kAccent),
              ),
            ),
          ],
        ),
      ) ??
      false; // Default to false if dialog is dismissed
}

Future<Map<String, dynamic>?> showCategoryInputDialog(BuildContext context,
    {required String label}) async {
  // Validate the label parameter and use 'general' as fallback if empty
  final sanitizedLabel = label.trim().isEmpty ? 'general' : label.trim();

  final isDarkMode = getThemeProvider(context).isDarkMode;
  final textTheme = Theme.of(context).textTheme;

  // Check if in family mode
  final isFamilyMode = userService.currentUser.value?.familyMode ?? false;

  if (!isFamilyMode) {
    // In non-family mode, return immediately with just the category
    return {
      'categories': [sanitizedLabel],
      'familyMember': null,
      'ageGroup': null,
    };
  }

  // In family mode, show family member selection
  String? selectedFamilyMember;
  String? selectedAgeGroup;

  // Get family members
  final familyMembers = userService.currentUser.value?.familyMembers ?? [];

  return await showDialog<Map<String, dynamic>>(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: isDarkMode ? kDarkGrey : kWhite,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(30),
                topRight: Radius.circular(30),
              ),
            ),
            title: Text(
              'Select Family Member',
              style: textTheme.displaySmall?.copyWith(
                fontSize: getPercentageWidth(7, context),
                color: kAccent,
                fontWeight: FontWeight.w500,
              ),
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Generate $label meals',
                    style: textTheme.bodyMedium?.copyWith(
                      color: isDarkMode
                          ? kWhite.withValues(alpha: 0.8)
                          : kBlack.withValues(alpha: 0.7),
                      fontSize: getTextScale(3.5, context),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: getPercentageHeight(2, context)),

                  // Family member selection
                  if (familyMembers.isNotEmpty) ...[
                    Text(
                      'Select Family Member:',
                      style: textTheme.bodyMedium?.copyWith(
                        color: kAccent,
                        fontWeight: FontWeight.w600,
                        fontSize: getTextScale(3.5, context),
                      ),
                    ),
                    SizedBox(height: getPercentageHeight(1, context)),
                    SizedBox(
                      height: getPercentageHeight(15, context),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: familyMembers.length,
                        itemBuilder: (context, index) {
                          final member = familyMembers[index];
                          final isSelected =
                              selectedFamilyMember == member.name;

                          return Card(
                            color: isSelected
                                ? kAccent.withValues(alpha: 0.2)
                                : kAccent.withValues(alpha: 0.1),
                            child: ListTile(
                              title: Text(
                                capitalizeFirstLetter(member.name ?? 'Unknown'),
                                style: textTheme.bodyMedium?.copyWith(
                                  color: isDarkMode ? kWhite : kBlack,
                                  fontSize: getTextScale(3.5, context),
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                              ),
                              subtitle: Text(
                                'Age Group: ${member.ageGroup ?? 'Unknown'}',
                                style: textTheme.bodySmall?.copyWith(
                                  color: isDarkMode
                                      ? kWhite.withValues(alpha: 0.7)
                                      : kBlack.withValues(alpha: 0.7),
                                  fontSize: getTextScale(3, context),
                                ),
                              ),
                              onTap: () {
                                setState(() {
                                  selectedFamilyMember = member.name;
                                  selectedAgeGroup = member.ageGroup;
                                });
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ] else ...[
                    Text(
                      'No family members found',
                      style: textTheme.bodyMedium?.copyWith(
                        color: Colors.grey,
                        fontSize: getTextScale(3.5, context),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: getTextScale(3.5, context),
                  ),
                ),
              ),
              TextButton(
                onPressed: selectedFamilyMember == null
                    ? null
                    : () {
                        Navigator.of(context).pop({
                          'categories': [sanitizedLabel],
                          'familyMember': selectedFamilyMember,
                          'ageGroup': selectedAgeGroup,
                        });
                      },
                child: Text(
                  'Generate Meals',
                  style: TextStyle(
                    color: selectedFamilyMember == null ? Colors.grey : kAccent,
                    fontWeight: FontWeight.w600,
                    fontSize: getTextScale(3.5, context),
                  ),
                ),
              ),
            ],
          );
        },
      );
    },
  );
}

Future<List<String>?> showIngredientInputDialog(BuildContext context,
    {String? initialIngredient}) async {
  final isDarkMode = getThemeProvider(context).isDarkMode;
  final textTheme = Theme.of(context).textTheme;
  final TextEditingController ingredientController = TextEditingController();
  List<String> ingredients = [];

  // Add initial ingredient if provided and not empty/generic
  if (initialIngredient != null &&
      initialIngredient.trim().isNotEmpty &&
      initialIngredient.toLowerCase() != 'general' &&
      initialIngredient.toLowerCase() != 'all' &&
      initialIngredient != 'myMeals') {
    // Sanitize the ingredient to prevent issues
    final sanitizedIngredient = initialIngredient.trim();
    if (sanitizedIngredient.isNotEmpty) {
      ingredients.add(sanitizedIngredient);
    }
  }

  return await showDialog<List<String>>(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: isDarkMode ? kDarkGrey : kWhite,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(30),
                topRight: Radius.circular(30),
              ),
            ),
            title: Text(
              'Add Ingredients',
              style: textTheme.displaySmall?.copyWith(
                fontSize: getPercentageWidth(7, context),
                color: kAccent,
                fontWeight: FontWeight.w500,
              ),
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Enter ingredients you want in your meal (one at a time)',
                    style: textTheme.bodyMedium?.copyWith(
                      color: isDarkMode
                          ? kWhite.withValues(alpha: 0.8)
                          : kBlack.withValues(alpha: 0.7),
                      fontSize: getTextScale(3.5, context),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: getPercentageHeight(2, context)),

                  // Input field for new ingredient
                  TextField(
                    controller: ingredientController,
                    style: TextStyle(
                      color: isDarkMode ? kWhite : kBlack,
                      fontSize: getTextScale(3.5, context),
                    ),
                    decoration: InputDecoration(
                      hintText: 'Enter ingredient...',
                      hintStyle: TextStyle(
                        color: isDarkMode
                            ? kWhite.withValues(alpha: 0.5)
                            : kBlack.withValues(alpha: 0.5),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            BorderSide(color: kAccent.withValues(alpha: 0.3)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: kAccent),
                      ),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.add, color: kAccent),
                        onPressed: () {
                          final ingredient = ingredientController.text.trim();
                          if (ingredient.isNotEmpty &&
                              !ingredients.contains(ingredient)) {
                            setState(() {
                              ingredients.add(ingredient);
                              ingredientController.clear();
                            });
                          }
                        },
                      ),
                    ),
                    onSubmitted: (value) {
                      final ingredient = value.trim();
                      if (ingredient.isNotEmpty &&
                          !ingredients.contains(ingredient)) {
                        setState(() {
                          ingredients.add(ingredient);
                          ingredientController.clear();
                        });
                      }
                    },
                  ),

                  SizedBox(height: getPercentageHeight(2, context)),

                  // Display added ingredients
                  if (ingredients.isNotEmpty) ...[
                    Text(
                      'Added Ingredients:',
                      style: textTheme.bodyMedium?.copyWith(
                        color: kAccent,
                        fontWeight: FontWeight.w600,
                        fontSize: getTextScale(3.5, context),
                      ),
                    ),
                    SizedBox(height: getPercentageHeight(1, context)),
                    SizedBox(
                      height: getPercentageHeight(15, context),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: ingredients.length,
                        itemBuilder: (context, index) {
                          return Card(
                            color: kAccent.withValues(alpha: 0.1),
                            child: ListTile(
                              title: Text(
                                ingredients[index],
                                style: textTheme.bodyMedium?.copyWith(
                                  color: isDarkMode ? kWhite : kBlack,
                                  fontSize: getTextScale(3.5, context),
                                ),
                              ),
                              trailing: IconButton(
                                icon: Icon(
                                  Icons.remove_circle,
                                  color: Colors.red.withValues(alpha: 0.7),
                                ),
                                onPressed: () {
                                  setState(() {
                                    ingredients.removeAt(index);
                                  });
                                },
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: getTextScale(3.5, context),
                  ),
                ),
              ),
              TextButton(
                onPressed: ingredients.isEmpty
                    ? null
                    : () {
                        Navigator.of(context).pop(ingredients);
                      },
                child: Text(
                  'Generate Meals',
                  style: TextStyle(
                    color: ingredients.isEmpty ? Colors.grey : kAccent,
                    fontWeight: FontWeight.w600,
                    fontSize: getTextScale(3.5, context),
                  ),
                ),
              ),
            ],
          );
        },
      );
    },
  );
}

/// Shows a loading dialog with rotating messages
/// Returns the dialog context for manual dismissal
BuildContext showLoadingDialog(BuildContext context,
    {List<String> loadingText = const []}) {
  final isDarkMode = getThemeProvider(context).isDarkMode;

  // Use the default rotating messages from constants
  List<String> loadingMessages =
      loadingText.isEmpty ? loadingTextImageAnalysis : loadingText;

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return _RotatingLoadingDialog(
        messages: loadingMessages,
        isDarkMode: isDarkMode,
      );
    },
  );

  return context;
}

/// Hides the loading dialog
void hideLoadingDialog(BuildContext context) {
  Navigator.of(context).pop();
}

/// A widget that shows a loading dialog with rotating messages
class _RotatingLoadingDialog extends StatefulWidget {
  final List<String> messages;
  final bool isDarkMode;

  const _RotatingLoadingDialog({
    required this.messages,
    required this.isDarkMode,
  });

  @override
  State<_RotatingLoadingDialog> createState() => _RotatingLoadingDialogState();
}

class _RotatingLoadingDialogState extends State<_RotatingLoadingDialog> {
  late Timer _timer;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted) {
        setState(() {
          _currentIndex = (_currentIndex + 1) % widget.messages.length;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return AlertDialog(
      backgroundColor: widget.isDarkMode ? kDarkGrey : kWhite,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      content: Row(
        children: [
          const CircularProgressIndicator(color: kAccent),
          SizedBox(width: getPercentageWidth(5, context)),
          Text(
            widget.messages[_currentIndex],
            style: textTheme.displaySmall?.copyWith(
              color: widget.isDarkMode ? kWhite : kBlack,
              fontSize: getTextScale(4.5, context),
            ),
          ),
        ],
      ),
    );
  }
}

/// Get a human-readable description for a day type
String caseDayType(String dayType) {
  switch (dayType.toLowerCase()) {
    case 'welcome_day':
      return 'This was your first day with TastyTurner!';
    case 'family_dinner':
      return 'This was a Family Dinner day.';
    case 'workout_boost':
      return 'This was a Workout Boost day.';
    case 'special_celebration':
      return 'You had a Special Celebration.';
    default:
      return 'This was a ${capitalizeFirstLetter(dayType.replaceAll('_', ' '))}.';
  }
}

/// Helper to get meal type icon
IconData getMealTypeIcon(String? type) {
  switch ((type ?? '').toLowerCase()) {
    case 'breakfast':
      return Icons.emoji_food_beverage_outlined;
    case 'lunch':
      return Icons.lunch_dining_outlined;
    case 'dinner':
      return Icons.dinner_dining_outlined;
    case 'snacks':
      return Icons.cake_outlined;
    default:
      return Icons.question_mark;
  }
}
