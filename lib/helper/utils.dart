// dot navigator build method
import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../constants.dart';
import '../data_models/macro_data.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../pages/photo_manager.dart';
import '../screens/buddy_screen.dart';
import '../screens/friend_screen.dart';
import '../tabs_screen/recipe_screen.dart';
import '../themes/theme_provider.dart';
import '../widgets/bottom_nav.dart';

int currentPage = 0;
List<MacroData> fullLabelsList = [];
final Set<String> headerSet = {};

AnimatedContainer buildDot(int? index) {
  return AnimatedContainer(
    duration: const Duration(milliseconds: 200),
    margin: const EdgeInsets.only(right: 8),
    height: 8,
    width: 8,
    decoration: BoxDecoration(
      color: currentPage == index ? kAccent : kWhite.withOpacity(0.50),
      borderRadius: BorderRadius.circular(50),
    ),
  );
}

String capitalizeFirstLetter(String input) {
  if (input.isEmpty) return '';
  return input[0].toUpperCase() + input.substring(1).toLowerCase();
}

List<String> extractSlashedItems(String messageContent) {
  RegExp regex = RegExp(r'/([^/]+)');
  return regex
      .allMatches(messageContent)
      .map((match) => match.group(1)!.trim())
      .toList();
}

String removeDashWithSpace(String messageContent) {
  List<String> words = messageContent.split('_');
  List<String> capitalizedWords =
      words.map((word) => capitalizeFirstLetter(word.trim())).toList();
  return capitalizedWords.join(' ');
}

String getTextBeforeSlash(String input) {
  int slashIndex = input.indexOf('/');
  return slashIndex != -1 ? input.substring(0, slashIndex).trim() : input;
}

String getNumberBeforeSpace(String input) {
  int spaceIndex = input.indexOf(' ');
  return spaceIndex != -1 ? input.substring(0, spaceIndex).trim() : input;
}

String timeAgo(Timestamp timestamp) {
  final DateTime dateTime = timestamp.toDate();
  final Duration difference = DateTime.now().difference(dateTime);

  if (difference.inSeconds < 60) {
    return '${difference.inSeconds} sec ago';
  } else if (difference.inMinutes < 60) {
    return '${difference.inMinutes} min ago';
  } else if (difference.inHours < 24) {
    return '${difference.inHours} hr ago';
  } else if (difference.inDays < 7) {
    return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
  } else if (difference.inDays < 30) {
    return '${(difference.inDays / 7).floor()} week${(difference.inDays / 7).floor() > 1 ? 's' : ''} ago';
  } else if (difference.inDays < 365) {
    return '${(difference.inDays / 30).floor()} month${(difference.inDays / 30).floor() > 1 ? 's' : ''} ago';
  } else {
    return '${(difference.inDays / 365).floor()} year${(difference.inDays / 365).floor() > 1 ? 's' : ''} ago';
  }
}

//search bar outline
OutlineInputBorder outlineInputBorder(
  double radius,
) {
  return OutlineInputBorder(
    borderRadius: BorderRadius.circular(radius),
    borderSide: BorderSide(color: kAccent.withValues(alpha: kMidOpacity)),
  );
}

String getAssetImageForItem(String itemType) {
  switch (itemType.toLowerCase()) {
    case 'fruit':
      return 'assets/images/fruit.jpg';
    case 'honey':
      return 'assets/images/honey.jpg';
    case 'milk':
      return 'assets/images/milk.jpg';
    case 'vegetables':
      return 'assets/images/vegetable.jpg';
    case 'vegetable':
      return 'assets/images/vegetable.jpg';
    case 'meat':
      return 'assets/images/meat.jpg';
    case 'grain':
      return 'assets/images/grain.jpg';
    case 'fish':
      return 'assets/images/fish.jpg';
    case 'egg':
      return 'assets/images/egg.jpg';
    case 'nut':
      return 'assets/images/nut.jpg';
    case 'herb':
      return 'assets/images/herb.jpg';
    case 'spice':
      return 'assets/images/spice.jpg';
    case 'legume':
      return 'assets/images/legume.jpg';
    case 'oil':
      return 'assets/images/oil.jpg';
    case 'dairy':
      return 'assets/images/dairy.jpg';
    case 'salad':
      return 'assets/images/salad.jpg';
    case 'pastry':
      return 'assets/images/pastry.jpg';
    case 'poultry':
      return 'assets/images/poultry.jpg';
    case 'protein':
      return 'assets/images/meat.jpg';
    case 'carbs':
      return 'assets/images/grain.jpg';
    case 'fats':
      return 'assets/images/butter.jpg';
    case 'breakfast':
    case 'keto':
      return 'assets/images/keto.jpg';
    case 'lunch':
    case 'paleo':
    case 'carnivore':
      return 'assets/images/paleo.jpg';
    case 'dinner':
    case 'low-carb':
      return 'assets/images/low-carb.jpg';
    case 'all':
      return 'assets/images/none_diet.jpg';
    case 'vegan':
      return 'assets/images/vegan.jpg';
    case 'vegetarian':
      return 'assets/images/vegetarian.jpg';
    case 'pescatarian':
      return 'assets/images/pescatarian.jpg';
    case 'snack':
      return 'assets/images/pastry.jpg';
    case 'dessert':
      return 'assets/images/dessert.jpg';
    default:
      return intPlaceholderImage;
  }
}

String getRandomAssetImage() {
  // Define a list of 10 generic images to choose from randomly
  final List<String> randomImages = [
    'assets/images/egg.jpg',
    'assets/images/meat.jpg',
    'assets/images/grain.jpg',
    'assets/images/butter.jpg',
    'assets/images/fruit.jpg',
    'assets/images/dairy.jpg',
    'assets/images/milk.jpg',
    'assets/images/salad.jpg',
    'assets/images/pastry.jpg',
    'assets/images/honey.jpg',
    'assets/images/nut.jpg',
    'assets/images/herb.jpg',
    'assets/images/spice.jpg',
    'assets/images/legume.jpg',
    'assets/images/oil.jpg',
    'assets/images/poultry.jpg',
    'assets/images/fish.jpg',
  ];

  // First check for specific item types
  final random = Random();
  return randomImages[random.nextInt(randomImages.length)];
}

String featureCheck(String featureName) {
  switch (featureName.toLowerCase()) {
    case 'water content':
      return intPlaceholderImage;

    case 'season':
      return intPlaceholderImage;

    case 'vitamins':
      return intPlaceholderImage;

    case 'rainbow grow':
      return intPlaceholderImage;

    case 'origin':
      return intPlaceholderImage;

    default:
      return intPlaceholderImage;
  }
}

// Helper method to get current week number
int getCurrentWeek() {
  final now = DateTime.now();
  final firstDayOfYear = DateTime(now.year, 1, 1);
  final days = now.difference(firstDayOfYear).inDays;
  return (days / 7).ceil();
}

String getRandomBio(List<String> type) {
  // Generate a random index
  final random = Random();
  final index = random.nextInt(type.length);

  return type[index];
}

String getRandomMealTypeBio(String mealType) {
  final List<String> mealTypeBios = [
    "Feast Mode: Your Special ${capitalizeFirstLetter(mealType)} Meal Plan",
    "Bite the Day: A ${capitalizeFirstLetter(mealType)} Meal Plan Adventure",
    "Dish It Up: Your ${capitalizeFirstLetter(mealType)} Meal Plan Masterpiece",
    "Chow Down Champion: A ${capitalizeFirstLetter(mealType)} focused Meal Plan",
    "Savor the Win: Your ${capitalizeFirstLetter(mealType)} Meal Plan Gameplan"
  ];
  // Generate a random index
  final random = Random();
  final index = random.nextInt(mealTypeBios.length);

  return mealTypeBios[index];
}

Color checkRainbowGroup(String rainbow) {
  switch (rainbow.toLowerCase()) {
    case 'red':
      return kRed;

    case 'yellow':
      return kYellow;

    case 'green':
      return kGreen;

    case 'purple':
      return kAccent;

    case 'orange':
      return kOrange;

    default:
      return kBlue;
  }
}

Color checkSeason(String season) {
  switch (season.toLowerCase()) {
    case 'fall':
      return kBlue;
    case 'fall-winter':
      return kBlue;
    case 'spring-summer':
      return kAccent;
    case 'spring-fall':
      return kBlue;
    case 'spring':
      return kAccent;
    case 'summer':
      return kOrange;
    case 'autumn':
      return kRed;
    case 'all-year':
      return kGreen;
    default:
      return kWhite;
  }
}

Future<List<XFile>> openMultiImagePickerModal({
  required BuildContext context,
}) async {
  final Completer<List<XFile>> completer = Completer();

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      return MultiImagePickerModal(
        onImagesSelected: (List<File> selectedFiles) {
          // Convert File to XFile before completing
          List<XFile> xFiles =
              selectedFiles.map((file) => XFile(file.path)).toList();
          completer.complete(xFiles);
        },
      );
    },
  );

  return completer.future;
}

ThemeProvider getThemeProvider(BuildContext context) {
  return Provider.of<ThemeProvider>(context);
}

// Unit options
List<String> unitOptions = [
  'g',
  'ml',
  'cup',
  'servings',
];

Widget buildPicker(BuildContext context, int itemCount, int selectedValue,
    Function(int) onChanged, bool isColorChange,
    [List<String>? labels]) {
  final isDarkMode = getThemeProvider(context).isDarkMode;

  return CupertinoPicker(
    scrollController: FixedExtentScrollController(initialItem: selectedValue),
    itemExtent: 40,
    onSelectedItemChanged: onChanged,
    children: List.generate(
      itemCount,
      (index) => Center(
        child: Text(
          textAlign: TextAlign.center,
          labels != null ? labels[index] : index.toString(),
          style: TextStyle(
              color: isDarkMode
                  ? isColorChange
                      ? kBlack
                      : kWhite
                  : kBlack,
              fontSize: 16),
        ),
      ),
    ),
  );
}

/// Shows a success snackbar with a custom message
void showTastySnackbar(String title, String message, BuildContext context,
    {Color? backgroundColor}) {
  Get.snackbar(
    title,
    message,
    snackPosition: SnackPosition.BOTTOM,
    backgroundColor: backgroundColor ?? kAccentLight.withOpacity(0.5),
  );
}

/// ✅ Function to Get Next Occurrence of a Specific Day (e.g., Tuesday)
DateTime getNextWeekday(String dueDateString) {
  // Parse the due date string to get a DateTime
  DateTime dueDate;
  try {
    // Try to parse the date string (expected format: yyyy-MM-dd)
    dueDate = DateTime.parse(dueDateString);
    // Set the time to 12:00 PM
    dueDate = DateTime(dueDate.year, dueDate.month, dueDate.day, 12, 0, 0);
  } catch (e) {
    // If parsing fails, default to one week from now
    DateTime now = DateTime.now();
    dueDate = DateTime(now.year, now.month, now.day + 7, 12, 0, 0);
  }

  // If the due date is in the past, move it to next week
  DateTime now = DateTime.now();
  if (dueDate.isBefore(now)) {
    dueDate = DateTime(
      dueDate.year,
      dueDate.month,
      dueDate.day + 7,
      12, // Set to 12:00 PM
      0,
      0,
    );
  }

  return dueDate;
}

double getPercentageHeight(double percentage, BuildContext context) {
  final screenHeight = MediaQuery.of(context).size.height;
  final blockSizeVertical = screenHeight / 100;
  return blockSizeVertical * percentage;
}

// Get width based on a percentage of the screen
double getPercentageWidth(double percentage, BuildContext context) {
  final screenWidth = MediaQuery.of(context).size.width;
  final blockSizeHorizontal = screenWidth / 100;
  return blockSizeHorizontal * percentage;
}

// Define list of ingredients to exclude (common seasonings, herbs, spices)
const excludedIngredients = [
  'salt',
  'pepper',
  'onion',
  'garlic',
  'basil',
  'oregano',
  'thyme',
  'rosemary',
  'parsley',
  'cilantro',
  'cumin',
  'paprika',
  'cinnamon',
  'turmeric',
  'ginger',
  'bay leaf',
  'bay leaves',
  'nutmeg',
  'cloves',
  'cardamom',
  'chili powder',
  'curry powder',
  'allspice',
  'sage',
  'dill',
  'mint',
  'coriander',
  'cayenne',
  'black pepper',
  'lemon',
  'lime',
  'mint',
  'rosemary',
  'thyme',
  'oregano',
  'lemon juice',
  'olive oil',
  'vinegar',
  'soy sauce',
  'ketchup',
  'mustard',
  'mayonnaise',
  'hot sauce',
  'bbq sauce',
  'barbecue sauce',
  'hot sauce',
  'bbq sauce',
  'barbecue sauce',
  'butter',
  'cream',
  'cheese',
  'yogurt',
  'sour cream',
  'sauce',
  'gravy',
  'syrup',
  'jam',
  'avocado oil',
  'olive oil',
  'sesame oil',
  'peanut oil',
  'coconut oil',
  'peanut butter',
  'almond butter',
  'cashew butter',
  'hazelnut butter',
  'walnut butter',
  'macadamia nut butter',
  'peanut'
];

const vegetables = [
  'broccoli',
  'spinach',
  'kale',
  'lettuce',
  'cabbage',
  'carrot',
  'cucumber',
  'tomato',
  'bell pepper',
  'celery'
];

// List of common proteins
const proteins = [
  'chicken',
  'beef',
  'pork',
  'tofu',
  'tempeh',
  'salmon',
  'tuna',
  'eggs',
  'turkey',
  'beans',
  'lentils'
];

Widget noItemTastyWidget(
    String message, String subtitle, BuildContext context, bool isLinked, String screen) {
  final themeProvider = getThemeProvider(context);
  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: 1),
          duration: const Duration(seconds: 15),
          curve: Curves.easeInOut,
          builder: (context, value, child) {
            return Transform.translate(
              offset: Offset(value * 200 - 100, 0), // Moves from -100 to +100
              child: CircleAvatar(
                backgroundColor: kAccentLight.withOpacity(0.5),
                radius: 18,
                backgroundImage: AssetImage(tastyImage),
              ),
            );
          },
        ),
        const SizedBox(height: 5),
        Text(
          message,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w400,
            color: kAccentLight,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        if (subtitle.isNotEmpty)
          GestureDetector(
            onTap: () {
              if (isLinked) {
                if (screen == 'buddy') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const TastyScreen(),
                    ),
                  );
                } else if (screen == 'recipe') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const RecipeScreen(),
                    ),
                  );
                } else if (screen == 'spin') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const BottomNavSec(
                        selectedIndex: 3,
                      ),
                    ),
                  );
                } else if (screen == 'friend') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const FriendScreen(),
                    ),
                  );
                }
              }
            },
            child: Text(
              subtitle,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isLinked
                    ? kAccent
                    : themeProvider.isDarkMode
                        ? kWhite
                        : kBlack,
                decoration:
                    isLinked ? TextDecoration.underline : TextDecoration.none,
              ),
              textAlign: TextAlign.center,
            ),
          ),
      ],
    ),
  );
}

bool getCurrentDate(DateTime date) {
  final today = DateTime.now();
  return date.year == today.year &&
      date.month == today.month &&
      date.day == today.day;
}

ThemeData getDatePickerTheme(BuildContext context, bool isDarkMode) {
  if (isDarkMode) {
    return Theme.of(context).copyWith(
      colorScheme: const ColorScheme.dark(
        surface: kDarkGrey,
        primary: kAccent, // Date selction background color
        onPrimary: kDarkGrey, // Header text color
        onSurface: kAccent, // Calendar text colorr
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: kAccent, // Button text color
        ),
      ),
    );
  } else {
    return Theme.of(context).copyWith(
      colorScheme: ColorScheme.light(
        primary: kAccent, // Date selction background color
        onPrimary: kDarkGrey, // Header text color
        onSurface: kDarkGrey, // Calendar text color
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: kAccent, // Button text color
        ),
      ),
    );
  }
}

class HexagonClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    final double radius = size.width / 2;
    final double centerX = size.width / 2;
    final double centerY = size.height / 2;
    final double rotationAngle = 30 * (3.14159 / 180); // 30 degrees in radians
    final double curveRadius = radius * 0.1; // Radius for curved corners

    // Calculate main corner points for the hexagon
    List<Offset> corners = [];
    for (int i = 0; i < 6; i++) {
      double angle = (i * 60) * (3.14159 / 180);
      corners.add(Offset(
        centerX + radius * cos(angle + rotationAngle),
        centerY + radius * sin(angle + rotationAngle),
      ));
    }

    // Helper function to get point at given percentage between two points
    Offset getPointBetween(Offset start, Offset end, double percent) {
      return Offset(
        start.dx + (end.dx - start.dx) * percent,
        start.dy + (end.dy - start.dy) * percent,
      );
    }

    // Start the path
    path.moveTo(
      getPointBetween(corners[0], corners[1], curveRadius / radius).dx,
      getPointBetween(corners[0], corners[1], curveRadius / radius).dy,
    );

    // Draw each side with curved corners
    for (int i = 0; i < 6; i++) {
      final currentCorner = corners[i];
      final nextCorner = corners[(i + 1) % 6];

      // End point of current line (start of curve)
      final lineEnd =
          getPointBetween(currentCorner, nextCorner, 1 - curveRadius / radius);

      // Draw straight line
      path.lineTo(lineEnd.dx, lineEnd.dy);

      // Calculate control points for the curve
      final nextLineStart =
          getPointBetween(nextCorner, currentCorner, curveRadius / radius);

      // Draw the curved corner
      path.quadraticBezierTo(
        nextCorner.dx,
        nextCorner.dy,
        nextLineStart.dx,
        nextLineStart.dy,
      );
    }

    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

Widget buildFriendAvatar(String? profileImage) {
  return Container(
    width: 65,
    height: 65,
    child: ClipPath(
      clipper: HexagonClipper(),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          image: DecorationImage(
            image: profileImage?.contains('http') ?? false
                ? NetworkImage(profileImage!)
                : AssetImage(intPlaceholderImage) as ImageProvider,
            fit: BoxFit.cover,
          ),
        ),
      ),
    ),
  );
}

bool isDateTodayAfterTime(DateTime date, {int hour = 22}) {
  final now = DateTime.now();

  // Create dates without time for proper comparison
  final todayDate = DateTime(now.year, now.month, now.day);
  final inputDate = DateTime(date.year, date.month, date.day);

  // If the date is in the past or future, return false
  if (inputDate.isBefore(todayDate) || inputDate.isAfter(todayDate)) {
    return false;
  }

  // If we get here, the date is today, so check if before 22:00
  return now.hour < hour;
}

bool isDateToday(DateTime date) {
  final now = DateTime.now();

  // Create dates without time for proper comparison
  final todayDate = DateTime(now.year, now.month, now.day);
  final inputDate = DateTime(date.year, date.month, date.day);

  // If the date is in the past or future, return false
  if (inputDate.isBefore(todayDate) || inputDate.isAfter(todayDate)) {
    return false;
  }

  return true;
}

ImageProvider getImageProvider(String? imageUrl) {
  if (imageUrl != null && imageUrl.startsWith('http')) {
    return NetworkImage(imageUrl);
  }
  return const AssetImage(intPlaceholderImage);
}
