// dot navigator build method
import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tasteturner/helper/helper_functions.dart';
import 'package:flutter/material.dart' show debugPrint;
import 'package:tasteturner/screens/buddy_screen.dart';
import 'package:tasteturner/tabs_screen/recipe_screen.dart';
import '../constants.dart';
import '../data_models/macro_data.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../data_models/post_model.dart';
import '../pages/photo_manager.dart';
import '../screens/friend_screen.dart';
import '../screens/food_analysis_results_screen.dart';
import '../service/chat_controller.dart';
import '../themes/theme_provider.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/optimized_image.dart';
import 'package:cached_network_image/cached_network_image.dart';

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
      color: currentPage == index ? kAccent : kWhite.withValues(alpha: 0.50),
      borderRadius: BorderRadius.circular(50),
    ),
  );
}

String capitalizeFirstLetter(String input) {
  if (input.isEmpty) return '';
  List<String> words = input.split(' ');
  List<String> capitalizedWords = words.map((word) {
    if (word.isNotEmpty) {
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }
    return word;
  }).toList();
  return capitalizedWords.join(' ');
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

String removeAllTextJustNumbers(String value) {
  // Remove all non-numeric characters except hyphen
  String cleanValue = value.replaceAll(RegExp(r'[^0-9\-]'), '');

  // Check if there's a range (contains hyphen)
  if (cleanValue.contains('-')) {
    List<String> range = cleanValue.split('-');
    if (range.length == 2) {
      // Return the higher number in the range
      return range[1];
    }
  }

  // If no range, just return the cleaned number
  return cleanValue.replaceAll('-', '');
}

String normaliseMacrosText(String value) {
  if (value.toLowerCase().contains('carbohydrates')) {
    return value.replaceAll('carbohydrates', 'Carbs');
  }
  return value;
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

Future<bool> loadShowCaloriesPref() async {
  final prefs = await SharedPreferences.getInstance();
  const String _showCaloriesPrefKey = 'showCaloriesAndGoal';
  return prefs.getBool(_showCaloriesPrefKey) ?? true;
}

Future<void> saveShowCaloriesPref(bool value) async {
  final prefs = await SharedPreferences.getInstance();
  const String _showCaloriesPrefKey = 'showCaloriesAndGoal';
  await prefs.setBool(_showCaloriesPrefKey, value);
}

//search bar outline
OutlineInputBorder outlineInputBorder(
  double radius,
) {
  return OutlineInputBorder(
    borderRadius: BorderRadius.circular(radius),
    borderSide: BorderSide(color: kAccent.withValues(alpha: 0.2)),
  );
}

Future<void> handleImageSend(List<File> images, String? caption, String chatId,
    ScrollController scrollController, ChatController chatController) async {
  List<String> uploadedUrls = [];

  for (File image in images) {
    try {
      final String fileName =
          'chats/$chatId/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final Reference storageRef = firebaseStorage.ref().child(fileName);

      final uploadTask = storageRef.putFile(image);
      final snapshot = await uploadTask;
      final imageUrl = await snapshot.ref.getDownloadURL();

      uploadedUrls.add(imageUrl);
    } catch (e, stack) {
      debugPrint('Error uploading image: $e');
      debugPrint(stack.toString());
    }
  }

  // Check if this is a buddy chat (AI chat)
  final isBuddyChat = chatId == userService.buddyId;

  if (isBuddyChat) {
    // For buddy chat, send image and trigger AI analysis
    final messageContent = caption?.isNotEmpty == true ? caption : '';
    await chatController.sendMessage(
      messageContent: messageContent,
      imageUrls: uploadedUrls,
      isPrivate: true,
    );

    // Trigger AI analysis of the image
    await _triggerAIImageAnalysis(
        uploadedUrls, caption, chatId, chatController, scrollController);
  } else {
    // For regular chats, create a post and send the message
    final postRef = firestore.collection('posts').doc();
    final postId = postRef.id;
    final messageContent =
        'Shared caption: ${capitalizeFirstLetter(caption ?? '')} /${postId} /${'post'} /${'private'}';

    final post = Post(
      id: postId,
      userId: userService.userId ?? '',
      mediaPaths: uploadedUrls,
      name: userService.currentUser.value?.displayName ?? '',
      category: 'general',
      createdAt: DateTime.now(),
    );

    // Ensure usersPosts document exists before updating
    final usersPostsDoc =
        firestore.collection('usersPosts').doc(userService.userId);
    final usersPostsSnapshot = await usersPostsDoc.get();

    if (!usersPostsSnapshot.exists) {
      await usersPostsDoc.set({
        'posts': [],
        'userId': userService.userId,
        'createdAt': DateTime.now().toIso8601String(),
      });
    }

    WriteBatch batch = firestore.batch();
    batch.set(postRef, post.toFirestore());

    // Now we can safely update the usersPosts document
    batch.update(usersPostsDoc, {
      'posts': FieldValue.arrayUnion([postRef.id]),
    });

    await batch.commit();

    await chatController.sendMessage(
      messageContent: messageContent,
      imageUrls: uploadedUrls,
      isPrivate: true,
    );
  }

  onNewMessage(scrollController);
}

// Store the last food analysis ID for reference
String? _lastFoodAnalysisId;

/// Triggers AI analysis of uploaded images in buddy chat
Future<void> _triggerAIImageAnalysis(
    List<String> imageUrls,
    String? caption,
    String chatId,
    ChatController chatController,
    ScrollController scrollController) async {
  if (imageUrls.isEmpty) return;

  try {
    // Send loading message
    await ChatController.saveMessageToFirestore(
      chatId: chatId,
      content:
          "🔍 Tasting your dish, Chef... This will help me give you better suggestions!",
      senderId: 'buddy',
    );

    // Download the image from URL to create a File object
    final response = await http.get(Uri.parse(imageUrls.first));
    final bytes = response.bodyBytes;

    // Create a temporary file
    final tempDir = await getTemporaryDirectory();
    final tempFile = File('${tempDir.path}/buddy_tasty_analysis.jpg');
    await tempFile.writeAsBytes(bytes);

    // Analyze the image using GeminiService
    final analysisResult = await geminiService.analyzeFoodImageWithContext(
      imageFile: tempFile,
      additionalContext: caption,
    );

    // Clean up temp file
    await tempFile.delete();

    // Store analysis in Firestore
    final analysisId = await _storeFoodAnalysisInFirestore(
        analysisResult, imageUrls.first, caption);
    _lastFoodAnalysisId = analysisId;

    // Get user context for personalized response
    final userContext = _getBuddyUserContext();

    // Create a summary response based on the actual analysis
    final summaryResponse =
        _createAnalysisSummaryResponse(analysisResult, userContext);

    // Send analysis summary with the analysis ID attached
    await ChatController.saveMessageToFirestore(
      chatId: chatId,
      content: summaryResponse,
      senderId: 'buddy',
    );

    // Send follow-up with action options
    await Future.delayed(const Duration(milliseconds: 1500));
    final optionsMessage = _createActionOptionsMessage(userContext);
    await ChatController.saveMessageToFirestore(
      chatId: chatId,
      content: optionsMessage,
      senderId: 'buddy',
    );

    onNewMessage(scrollController);
  } catch (e) {
    debugPrint('Error in AI image analysis: $e');
    // Send fallback response as buddy
    await ChatController.saveMessageToFirestore(
      chatId: chatId,
      content:
          "I can see your delicious food! While I had trouble with the detailed analysis, I'm here to help you optimize your nutrition. What would you like to know about this meal? 🍽️",
      senderId: 'buddy',
    );
    onNewMessage(scrollController);
  }
}

/// Get user context for personalized food analysis
Map<String, dynamic> _getBuddyUserContext() {
  return {
    'displayName': userService.currentUser.value?.displayName ?? 'there',
    'fitnessGoal': userService.currentUser.value?.settings['fitnessGoal'] ??
        'Healthy Eating',
    'currentWeight':
        userService.currentUser.value?.settings['currentWeight'] ?? 0.0,
    'goalWeight': userService.currentUser.value?.settings['goalWeight'] ?? 0.0,
    'foodGoal': userService.currentUser.value?.settings['foodGoal'] ?? 0.0,
    'dietPreference':
        userService.currentUser.value?.settings['dietPreference'] ?? 'Balanced',
  };
}

/// Store food analysis results in Firestore
Future<String> _storeFoodAnalysisInFirestore(
    Map<String, dynamic> analysisResult,
    String imageUrl,
    String? caption) async {
  final analysisRef = firestore.collection('tastyanalysis').doc();
  final analysisId = analysisRef.id;

  // Follow the existing tastyanalysis collection structure
  final analysisData = {
    'analysis':
        analysisResult, // Match existing structure: 'analysis' not 'analysisResult'
    'imagePath':
        imageUrl, // Match existing structure: 'imagePath' not 'imageUrl'
    'timestamp': FieldValue
        .serverTimestamp(), // Match existing structure: 'timestamp' not 'createdAt'
    'userId': userService.userId,
    // Additional fields for buddy chat tracking
    'caption': caption ?? '',
    'source': 'buddy_chat',
  };

  await analysisRef.set(analysisData);
  return analysisId;
}

/// Create analysis summary response based on actual food analysis
String _createAnalysisSummaryResponse(
    Map<String, dynamic> analysisResult, Map<String, dynamic> userContext) {
  final buffer = StringBuffer();

  // Extract key info from analysis
  final foods = analysisResult['foodItems'] as List?;
  final totalNutrition =
      analysisResult['totalNutrition'] as Map<String, dynamic>? ?? {};
  final totalCalories = totalNutrition['calories'];
  final totalProtein = totalNutrition['protein'];

  buffer.write("Great choice! I can see ");

  if (foods != null && foods.isNotEmpty) {
    final foodNames = foods.take(3).map((food) => food['name']).join(", ");
    buffer.write("$foodNames ");
  } else {
    buffer.write("your delicious meal ");
  }

  if (totalCalories != null) {
    buffer.write("(~$totalCalories calories");
    if (totalProtein != null) {
      buffer.write(", ${totalProtein}g protein");
    }
    buffer.write(") ");
  }

  buffer.write(
      "which looks perfect for your ${userContext['fitnessGoal']} goals! ");

  // Add personalized encouragement based on their diet
  final diet = userContext['dietPreference'] as String;
  if (diet.toLowerCase().contains('keto')) {
    buffer.write("The low-carb focus aligns well with your keto approach. ");
  } else if (diet.toLowerCase().contains('protein')) {
    buffer.write("Great protein content for your fitness journey! ");
  } else {
    buffer.write("This balanced meal fits your nutrition style perfectly. ");
  }

  buffer.write("Ready to optimize it further? 💪");

  return buffer.toString();
}

/// Create action options message
String _createActionOptionsMessage(Map<String, dynamic> userContext) {
  final goal = userContext['fitnessGoal'] as String;
  final isWeightLoss = goal.toLowerCase().contains('weight loss') ||
      goal.toLowerCase().contains('lose');
  final isMuscleBuild = goal.toLowerCase().contains('muscle') ||
      goal.toLowerCase().contains('gain');

  return """
🎯 What would you like me to help you with?

Option 1: 🔄 **Remix these ingredients** to better match your ${userContext['dietPreference']} diet and ${userContext['fitnessGoal']} goals

Option 2: 💪 **${isWeightLoss ? 'Reduce calories while keeping protein high' : isMuscleBuild ? 'Add more protein for muscle building' : 'Optimize the nutritional balance'}**

Option 3: 🔍 **Detailed Food Analysis** - Get comprehensive nutritional breakdown, calories, and macro analysis

Just let me know which option interests you, or ask me anything else about this meal! 😊
""";
}

/// Handle detailed food analysis for Option 3
Future<void> handleDetailedFoodAnalysis(
    BuildContext context, String chatId) async {
  if (_lastFoodAnalysisId == null) {
    // Send error message as buddy
    await ChatController.saveMessageToFirestore(
      chatId: chatId,
      content:
          "Sorry, I snoozed for a moment. Please upload the image again! 📸",
      senderId: 'buddy',
    );
    return;
  }

  try {
    // Get the stored analysis from Firestore
    final analysisDoc = await firestore
        .collection('tastyanalysis')
        .doc(_lastFoodAnalysisId!)
        .get();

    if (!analysisDoc.exists) {
      throw Exception('Analysis not found');
    }

    final analysisData = analysisDoc.data()!;
    final analysisResult = analysisData['analysis']
        as Map<String, dynamic>; // Use 'analysis' field
    final imageUrl =
        analysisData['imagePath'] as String; // Use 'imagePath' field

    // Send message indicating we're opening detailed view
    await ChatController.saveMessageToFirestore(
      chatId: chatId,
      content:
          "📊 Opening detailed food analysis for you! You'll see comprehensive nutritional breakdown, calories, and personalized recommendations.",
      senderId: 'buddy',
    );

    // Download the image to create a File object for the screen
    final response = await http.get(Uri.parse(imageUrl));
    final bytes = response.bodyBytes;

    // Create a temporary file
    final tempDir = await getTemporaryDirectory();
    final tempFile = File('${tempDir.path}/detailed_analysis_view.jpg');
    await tempFile.writeAsBytes(bytes);

    // Navigate to FoodAnalysisResultsScreen
    if (context.mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => FoodAnalysisResultsScreen(
            imageFile: tempFile,
            analysisResult: analysisResult,
            isAnalyzeAndUpload: false,
            date: DateTime.now(),
            mealType: getMealTimeOfDay(), // Default meal type
            skipAnalysisSave:
                true, // Skip saving since it's already saved in buddy chat
          ),
        ),
      );

      // Send completion message when user returns to chat
      await ChatController.saveMessageToFirestore(
        chatId: chatId,
        content:
            "Great! Hope the detailed analysis was helpful. Feel free to ask me any questions about your meal or nutrition goals! 😊",
        senderId: 'buddy',
      );
    }
  } catch (e) {
    debugPrint('Error in detailed food analysis: $e');
    // Send error message as buddy
    await ChatController.saveMessageToFirestore(
      chatId: chatId,
      content:
          "Sorry, I had trouble opening the detailed analysis. The basic analysis showed it looks nutritious though! Feel free to ask me any specific questions about your meal. 😊",
      senderId: 'buddy',
    );
  }
}

/// Get stored food analysis data
Future<Map<String, dynamic>?> getFoodAnalysisData(String analysisId) async {
  try {
    final doc =
        await firestore.collection('tastyanalysis').doc(analysisId).get();
    if (doc.exists) {
      return doc.data()!['analysis']
          as Map<String, dynamic>; // Use 'analysis' field
    }
  } catch (e) {
    showTastySnackbar(
        'Something went wrong', 'Please try again later', Get.context!,
        backgroundColor: kRed);
  }
  return null;
}

/// Get the last food analysis ID for use in buddy screen
String? getLastFoodAnalysisId() {
  return _lastFoodAnalysisId;
}

void onNewMessage(ScrollController scrollController) {
  WidgetsBinding.instance
      .addPostFrameCallback((_) => scrollToBottom(scrollController));
}

void scrollToBottom(ScrollController scrollController) {
  if (scrollController.hasClients) {
    scrollController.animateTo(
      scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }
}

String getAssetImageForItem(String itemType) {
  switch (itemType.toLowerCase()) {
    case 'fruit':
    case 'raw':
    case '8+8+8 rule':
      return 'assets/images/fruit.jpg';
    case 'honey':
    case 'grilling':
      return 'assets/images/honey.jpg';
    case 'milk':
    case 'steaming':
      return 'assets/images/milk.jpg';
    case 'vegetables':
    case 'soup':
    case 'Intermittent fasting':
      return 'assets/images/vegetable.jpg';
    case 'vegetable':
    case 'sautéing':
      return 'assets/images/vegetable.jpg';
    case 'meat':
    case 'roasting':
    case 'gut health':
      return 'assets/images/meat.jpg';
    case 'grain':
    case 'baking':
      return 'assets/images/grain.jpg';
    case 'fish':
    case 'poaching':
    case 'hormonal health':
      return 'assets/images/fish.jpg';
    case 'egg':
    case 'boiling':
    case 'balanced':
      return 'assets/images/egg.jpg';
    case 'nut':
    case 'mashing':
    case 'no sugar':
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
// Matches the cloud function's ISO week calculation exactly
// Cloud function: finds Thursday of the week, then calculates week from year start using Math.ceil
String getCurrentWeek() {
  final now = DateTime.now();

  // Use UTC dates to match cloud function
  final d = DateTime.utc(now.year, now.month, now.day);

  // Get day of week: Dart's weekday is 1=Monday, 7=Sunday
  // Convert to cloud function format: 1=Monday, 7=Sunday (same as Dart!)
  int dayNum = d.weekday; // Already 1-7, where 7 is Sunday

  // Move to Thursday of this week: add (4 - dayNum) days
  // Monday=1 -> add 3 days to get Thursday
  // Sunday=7 -> add -3 days (go back 3 days to Thursday)
  final thursday = d.add(Duration(days: 4 - dayNum));

  // Calculate week number: (days from year start + 1) / 7, rounded up
  // This matches JavaScript's Math.ceil((d - yearStart) / 86400000 + 1) / 7)
  final yearStart = DateTime.utc(thursday.year, 1, 1);
  final daysFromYearStart = thursday.difference(yearStart).inDays + 1;
  final weekNumber = ((daysFromYearStart) / 7)
      .ceil(); // Equivalent to Math.ceil((days + 1) / 7)

  return 'week_${thursday.year}-${weekNumber.toString().padLeft(2, '0')}';
}

/// Get the start of the week (Monday) for a given date
DateTime getWeekStart(DateTime date) {
  final daysFromMonday = date.weekday - 1; // Monday = 1, so subtract 1
  return DateTime(date.year, date.month, date.day)
      .subtract(Duration(days: daysFromMonday));
}

String getRandomBio(List<String> type) {
  // Generate a random index
  final random = Random();
  final index = random.nextInt(type.length);

  return type[index];
}

String getRandomMealTypeBio(String mealType, String diet) {
  if (diet == mealType) {
    final List<String> mealTypeBios = [
      "Feast Mode",
      "Bite the Day",
      "Dish It Up",
      "Chow Down Champion",
      "Savor the Win"
    ]
        .map((title) =>
            "$title: Meals generated for your ${capitalizeFirstLetter(mealType)} \n7 day Meal Plan/ (Mix and match and add meals to your Calendar)")
        .toList();
    final random = Random();
    return mealTypeBios[random.nextInt(mealTypeBios.length)];
  }

  if (mealType.toLowerCase() == 'lose weight') {
    mealType = 'weight loss';
  } else if (mealType.toLowerCase() == 'gain muscle') {
    mealType = 'muscle gain';
  } else if (mealType.toLowerCase() == 'healthy eating') {
    mealType = 'healthy eating';
  }

  final String suffix =
      "Meals generated for your ${capitalizeFirstLetter(mealType)} - ${capitalizeFirstLetter(diet)} \n7 day Meal Plan/ (Mix and match and add them to your Calendar)";
  final List<String> mealTypeBios = [
    "Feast Mode: $suffix",
    "Bite the Day: $suffix",
    "Dish It Up: $suffix",
    "Calorie Champion: $suffix",
    "Savor the Win: $suffix"
  ];
  final random = Random();
  return mealTypeBios[random.nextInt(mealTypeBios.length)];
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
  ).then((_) {
    // When modal is dismissed (user clicked back or swipe down)
    if (!completer.isCompleted) {
      completer.complete([]); // Return empty list when cancelled
    }
  });

  return completer.future;
}

ThemeProvider getThemeProvider(BuildContext context) {
  return Provider.of<ThemeProvider>(context, listen: false);
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
  final textTheme = Theme.of(context).textTheme;

  return CupertinoPicker(
    scrollController: FixedExtentScrollController(initialItem: selectedValue),
    itemExtent: getPercentageHeight(7, context),
    onSelectedItemChanged: onChanged,
    children: List.generate(
      itemCount,
      (index) => Center(
        child: Text(
          textAlign: TextAlign.center,
          capitalizeFirstLetter(
              labels != null ? labels[index] : index.toString()),
          style: textTheme.bodyMedium?.copyWith(
            color: isColorChange ? kWhite : kDarkGrey,
          ),
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
    backgroundColor: backgroundColor ?? kAccentLight.withValues(alpha: 0.5),
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

// For scaling text based on screen size
double getTextScale(double inputTextSize, BuildContext context) {
  final screenWidth = MediaQuery.of(context).size.width;
  final blockSizeHorizontal = screenWidth / 100;
  if (screenWidth >= 800) {
    return (blockSizeHorizontal * inputTextSize) - 10;
  }
  return blockSizeHorizontal * inputTextSize;
}

double getIconScale(double inputIconSize, BuildContext context) {
  final screenWidth = MediaQuery.of(context).size.width;
  final blockSizeHorizontal = screenWidth / 100;
  if (screenWidth >= 800) {
    return (blockSizeHorizontal * inputIconSize) - 10;
  }
  return blockSizeHorizontal * inputIconSize;
}

// Example of how you can calculate a responsive box size
double getResponsiveBoxSize(
    BuildContext context, double heightFactor, double widthFactor) {
  double calculatedHeight = getProportionalHeight(heightFactor, context);
  double calculatedWidth = getProportionalWidth(widthFactor, context);
  return calculatedHeight > calculatedWidth
      ? calculatedHeight
      : calculatedWidth;
}

// Get the proportionate width as per screen size
double getProportionalWidth(double inputWidth, BuildContext context) {
  double screenWidth = MediaQuery.of(context).size.width;
  // 432 is the layout width of the design mockup
  return (inputWidth / 432.0) * screenWidth;
}

// Get the proportionate height as per screen size
double getProportionalHeight(double inputHeight, BuildContext context) {
  double screenHeight = MediaQuery.of(context).size.height;
  // 840 is the layout height of the design mockup
  return (inputHeight / 840.0) * screenHeight;
}

// Define list of ingredients to exclude (common seasonings, herbs, spices)

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

const excludeIngredients = [
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
  'lemon juice',
  'olive oil',
  'vegetable oil',
  'red onion',
  'oil',
  'butter',
  'ghee',
  'margarine',
  'broth',
  'chicken broth',
  'beef broth',
  'vegetable broth',
  'fish broth',
  'chicken stock',
  'beef stock',
  'vegetable stock',
  'vinegar',
  'soy sauce',
  'ketchup',
  'mustard',
  'mayonnaise',
  'hot sauce',
  'bbq sauce',
  'barbecue sauce',
  'cream',
  'cheese',
  'yogurt',
  'sour cream',
  'sauce',
  'gravy',
  'syrup',
  'jam',
  'avocado oil',
  'sesame oil',
  'peanut oil',
  'coconut oil',
  'peanut butter',
  'almond butter',
  'cashew butter',
  'hazelnut butter',
  'walnut butter',
  'macadamia nut butter',
  'peanut',
  'spices',
  'spice',
  'herbs',
  'herb',
  'water',
  'milk',
  'juice',
  'juices',
  'yeast',
  'amino',
  'chili',
  'chilli',
  'mirin',
  'sugar',
  'tahini',
  'nut',
  'wine',
  'paste',
  'flake',
  'pesto',
  'shallot',
  'scallion',
  'bayleaf',
  'clove',
  'fennel',
  'anise',
  'sesame',
  'miso',
  'fishsauce',
  'hoisin',
  'mayo',
  'relish',
  'blackpepper',
  'whitepepper',
  'saffron',
  'garammasala',
  'five-spice',
  'zaatar',
  'harissa',
  'chutney',
  'pickle',
  'tamarind',
  'molasses',
  'honey',
  'maple',
  'misopaste',
  'wasabi',
  'horseradish',
  'lemongrass',
  'galangal',
  'kaffirlime',
  'pandan',
  'dillseed',
  'fenugreek',
  'sumac',
  'mace',
  'cocoa',
  'vanilla',
  'almond',
  'cashew',
  'pistachio',
  'walnut',
  'pecan',
  'hazelnut',
  'lard',
  'shortening',
  'oliveoil',
  'sesameoil',
  'coconutmilk',
  'seed',
  'seeds',
  'nut'
];

Widget noItemTastyWidget(String message, String subtitle, BuildContext context,
    bool isLinked, String screen) {
  final themeProvider = getThemeProvider(context);
  final textTheme = Theme.of(context).textTheme;
  final isDarkMode = themeProvider.isDarkMode;
  return Center(
    child: GestureDetector(
      onTap: () {
        if (isLinked) {
          if (screen == 'buddy') {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const TastyScreen(
                  screen: 'buddy',
                ),
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
          } else if (screen == 'calendar') {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const BottomNavSec(
                  selectedIndex: 4,
                ),
              ),
            );
          }
        }
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(height: getPercentageHeight(10, context)),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: 1),
            duration: const Duration(seconds: 15),
            curve: Curves.easeInOut,
            builder: (context, value, child) {
              return Transform.translate(
                offset: Offset(value * 200 - 100, 0), // Moves from -100 to +100
                child: CircleAvatar(
                  backgroundColor: isDarkMode ? kWhite : kBlack,
                  radius: getResponsiveBoxSize(context, 18, 18),
                  backgroundImage: AssetImage(tastyImage),
                ),
              );
            },
          ),
          const SizedBox(height: 5),
          Text(
            message,
            style: textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.w400,
              fontSize: getTextScale(6, context),
              color: kAccentLight,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          if (subtitle.isNotEmpty)
            Text(
              subtitle,
              style: textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: isLinked
                    ? kAccent
                    : themeProvider.isDarkMode
                        ? kWhite
                        : kBlack,
              ),
              textAlign: TextAlign.center,
            ),
        ],
      ),
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
      colorScheme: const ColorScheme.light(
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

Widget buildFriendAvatar(String? profileImage, BuildContext context) {
  return Container(
    width: getPercentageWidth(15, context),
    height: getPercentageWidth(15, context),
    child: ClipPath(
      clipper: HexagonClipper(),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          image: DecorationImage(
            image: profileImage?.contains('http') ?? false
                ? CachedNetworkImageProvider(profileImage!)
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
    return CachedNetworkImageProvider(imageUrl);
  }
  return const AssetImage(intPlaceholderImage);
}

IconData getDayTypeIcon(String type) {
  switch (type.toLowerCase()) {
    case 'cheat day':
      return Icons.fastfood;
    case 'diet day':
      return Icons.restaurant;
    case 'family dinner':
      return Icons.people;
    case 'workout boost':
      return Icons.fitness_center;
    case 'add your own':
      return Icons.add;
    case 'chef tasty':
    case 'sous chef':
      return Icons.restaurant;
    case 'welcome day':
      return Icons.check_circle;
    case 'spin special':
      return Icons.restaurant;
    case 'regular day':
      return Icons.restaurant;
    default:
      return Icons.celebration;
  }
}

Color getDayTypeColor(String type, bool isDarkMode) {
  switch (type.toLowerCase()) {
    case 'cheat day':
      return Colors.purple;
    case 'diet day':
      return kAccent;
    case 'family dinner':
      return Colors.green;
    case 'workout boost':
      return Colors.blue;
    case 'add your own':
      return Colors.blueGrey;
    case 'chef tasty':
    case 'sous chef':
      return Colors.red;
    case 'welcome day':
      return Colors.deepPurpleAccent;
    case 'spin special':
      return Colors.red;
    case 'regular day':
      return Colors.grey.withValues(alpha: 0.7);
    default:
      return Colors.orange;
  }
}

List<String> appendMealTypes(List<String> mealIds) {
  final mealTypes = ['breakfast', 'lunch', 'dinner', 'snack'];
  final List<String> result = [];

  for (var i = 0; i < mealIds.length; i++) {
    // Get meal type based on index, cycling through the types
    final mealType = mealTypes[i % mealTypes.length];
    result.add('${mealIds[i]}/$mealType');
  }

  return result;
}

String getRandomWelcomeMessage() {
  final List<String> welcomeMessages = [
    "Welcome! \nReady to plan your next delicious meal?",
    "Hello there! \nLet's make your meal planning journey easier and tastier.",
    "Welcome! \nYour personalized meal planner is ready to inspire your next creation.",
    "Great to see you! \nDiscover new recipes and plan your perfect menu.",
    "Welcome! \nTurn meal planning into an enjoyable experience.",
  ];
  final random = Random();
  return welcomeMessages[random.nextInt(welcomeMessages.length)];
}

String getMealTypeLabel(String type) {
  switch (type.toLowerCase()) {
    case 'bf':
    case 'breakfast':
      return 'Breakfast';
    case 'lh':
    case 'lunch':
      return 'Lunch';
    case 'dn':
    case 'dinner':
      return 'Dinner';
    case 'sk':
    case 'snacks':
      return 'Snacks';
    default:
      return 'Meal';
  }
}

String getMealTypeSubtitle(String type) {
  switch (type.toLowerCase()) {
    case 'breakfast':
      return 'BF';
    case 'lunch':
      return 'LH';
    case 'dinner':
      return 'DN';
    case 'snack':
      return 'SK';
    default:
      return 'BF';
  }
}

appendMealType(String mealId, String mealType) {
  if (mealType == 'breakfast') {
    return '${mealId}/bf';
  } else if (mealType == 'lunch') {
    return '${mealId}/lh';
  } else if (mealType == 'dinner') {
    return '${mealId}/dn';
  } else if (mealType == 'snack') {
    return '${mealId}/sk';
  }
  return mealId;
}

/// Builds a network image with graceful error handling for 403 errors
Widget buildNetworkImage({
  required String imageUrl,
  double? width,
  double? height,
  BoxFit fit = BoxFit.cover,
  Widget? placeholder,
  Widget? errorWidget,
  BorderRadius? borderRadius,
}) {
  // Handle empty or invalid URLs
  if (imageUrl.isEmpty || !imageUrl.startsWith('http')) {
    return errorWidget ??
        Image.asset(
          intPlaceholderImage,
          width: width,
          height: height,
          fit: fit,
        );
  }

  Widget imageWidget = Image.network(
    imageUrl,
    width: width,
    height: height,
    fit: fit,
    loadingBuilder: (context, child, loadingProgress) {
      if (loadingProgress == null) return child;
      return placeholder ??
          Container(
            width: width,
            height: height,
            color: Colors.grey[300],
            child: const Center(
              child: CircularProgressIndicator(
                color: kAccent,
                strokeWidth: 2,
              ),
            ),
          );
    },
    errorBuilder: (context, error, stackTrace) {
      // Log the error for debugging but don't spam the console
      if (error.toString().contains('403')) {
        debugPrint(
            '🚫 Image access denied (403): ${imageUrl.split('?').first}');
      } else {
        debugPrint('❌ Image load error: ${error.toString().split('\n').first}');
      }

      return errorWidget ??
          Image.asset(
            intPlaceholderImage,
            width: width,
            height: height,
            fit: fit,
          );
    },
  );

  // Apply border radius if provided
  if (borderRadius != null) {
    imageWidget = ClipRRect(
      borderRadius: borderRadius,
      child: imageWidget,
    );
  }

  return imageWidget;
}

/// Builds a network image with caching and better error handling
Widget buildOptimizedNetworkImage({
  required String imageUrl,
  double? width,
  double? height,
  BoxFit fit = BoxFit.cover,
  Widget? placeholder,
  Widget? errorWidget,
  BorderRadius? borderRadius,
  bool isProfileImage = false,
}) {
  // Handle empty or invalid URLs
  if (imageUrl.isEmpty || !imageUrl.startsWith('http')) {
    return errorWidget ??
        Image.asset(
          intPlaceholderImage,
          width: width,
          height: height,
          fit: fit,
        );
  }

  return OptimizedImage(
    imageUrl: imageUrl,
    width: width,
    height: height,
    fit: fit,
    borderRadius: borderRadius,
    isProfileImage: isProfileImage,
    placeholder: placeholder,
    errorWidget: errorWidget,
  );
}

/// Date navigation utilities for home screen
class DateNavigationUtils {
  /// Get the date 7 days ago from now
  static DateTime getSevenDaysAgo() {
    return DateTime.now().subtract(const Duration(days: 7));
  }

  /// Check if a date can be navigated backward (not more than 7 days ago)
  static bool canNavigateBackward(DateTime currentDate) {
    return currentDate.isAfter(getSevenDaysAgo());
  }

  /// Get the previous date (one day before current date)
  static DateTime getPreviousDate(DateTime currentDate) {
    return DateTime(
      currentDate.year,
      currentDate.month,
      currentDate.day,
    ).subtract(const Duration(days: 1));
  }

  /// Get the next date (one day after current date)
  static DateTime getNextDate(DateTime currentDate) {
    return DateTime(
      currentDate.year,
      currentDate.month,
      currentDate.day,
    ).add(const Duration(days: 1));
  }

  /// Check if next date would be in the future (beyond today)
  static bool isNextDateInFuture(DateTime currentDate) {
    final now = DateTime.now();
    final nextDate = getNextDate(currentDate);
    return nextDate.isAfter(DateTime(now.year, now.month, now.day));
  }

  /// Get today's date (without time component)
  static DateTime getTodayDate() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  /// Check if date is today
  static bool isToday(DateTime date) {
    final today = getTodayDate();
    final dateOnly = DateTime(date.year, date.month, date.day);
    return dateOnly.isAtSameMomentAs(today);
  }

  /// Show "86'd" dialog when user is missing an ingredient
  /// This implements the chef persona feature for ingredient substitutions
  static Future<bool?> show86dDialog(
    BuildContext context,
    String missingIngredient,
    String suggestedSubstitution, {
    String? calorieInfo,
  }) async {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    final textTheme = Theme.of(context).textTheme;

    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        backgroundColor: isDarkMode ? kDarkGrey : kWhite,
        title: Row(
          children: [
            Icon(
              Icons.restaurant_menu,
              color: kAccent,
              size: getIconScale(5, context),
            ),
            SizedBox(width: getPercentageWidth(2, context)),
            Expanded(
              child: Text(
                '86\'d Alert',
                style: textTheme.titleLarge?.copyWith(
                  color: isDarkMode ? kWhite : kBlack,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Chef, we\'re 86\'d on ${capitalizeFirstLetter(missingIngredient)}.',
              style: textTheme.bodyLarge?.copyWith(
                color: isDarkMode ? kWhite : kBlack,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: getPercentageHeight(1, context)),
            Text(
              'I can sub in ${capitalizeFirstLetter(suggestedSubstitution)}${calorieInfo != null ? ' to save $calorieInfo calories' : ''} and keep the texture. Approved?',
              style: textTheme.bodyMedium?.copyWith(
                color: isDarkMode ? kWhite.withValues(alpha: 0.8) : kDarkGrey,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              discard,
              style: TextStyle(
                color: isDarkMode ? kWhite.withValues(alpha: 0.7) : kDarkGrey,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: kAccent,
              foregroundColor: kWhite,
            ),
            child: Text(approve),
          ),
        ],
      ),
    );
  }
}
