// dot navigator build method
import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:fit_hify/themes/theme_provider.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../constants.dart';
import '../data_models/macro_data.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../pages/photo_manager.dart';
import '../screens/recipe_screen.dart';
import '../screens/shopping_list.dart';
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
      return 'assets/images/keto.jpg';
    case 'lunch':
      return 'assets/images/paleo.jpg';
    case 'dinner':
      return 'assets/images/low-carb.jpg';
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
    case 'winter':
      return kBlue;

    case 'spring':
      return kAccent.withOpacity(kOpacity);

    case 'summer':
      return kOrange.withOpacity(kOpacity);

    case 'autumn':
      return kRed.withBlue(20);

    case 'year round':
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
List<String> unitOptions = ['servings', 'cup'];

Widget buildPicker(BuildContext context, int itemCount, int selectedValue,
    Function(int) onChanged,
    [List<String>? labels]) {
  final isDarkMode = getThemeProvider(context).isDarkMode;

  return Expanded(
    child: CupertinoPicker(
      scrollController: FixedExtentScrollController(initialItem: selectedValue),
      itemExtent: 40,
      onSelectedItemChanged: onChanged,
      children: List.generate(
        itemCount,
        (index) => Text(
          labels != null ? labels[index] : index.toString(),
          style: TextStyle(color: isDarkMode ? kWhite : kBlack),
        ),
      ),
    ),
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
    String message, String subtitle, BuildContext context, bool isLinked) {
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
              child: const CircleAvatar(
                radius: 20,
                backgroundImage: AssetImage('assets/images/tasty_cheerful.jpg'),
              ),
            );
          },
        ),
        const SizedBox(height: 5),
        Text(
          message,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: themeProvider.isDarkMode ? kLightGrey : kAccent,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        if (subtitle.isNotEmpty)
          GestureDetector(
            onTap: () {
              if (isLinked) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const BottomNavSec(selectedIndex: 1),
                  ),
                );
              } else {
                null;
              }
            },
            child: Text(
              subtitle,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: kBlue,
                decoration: TextDecoration.underline,
              ),
              textAlign: TextAlign.center,
            ),
          ),
      ],
    ),
  );
}

