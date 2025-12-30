import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'package:flutter/material.dart';

import 'data_models/message_screen_data.dart';
import 'service/auth_controller.dart';
import 'service/badge_service.dart';
import 'service/calendar_sharing_service.dart';
import 'service/chat_controller.dart';
import 'service/firebase_data.dart';
import 'service/friend_controller.dart';
import 'service/gemini_service.dart';
import 'service/macro_manager.dart';
import 'service/meal_manager.dart';
import 'service/meal_plan_controller.dart';
import 'service/helper_controller.dart';
import 'service/notification_service.dart';
import 'service/nutrition_controller.dart';
import 'service/post_manager.dart';
import 'service/tasty_popup_service.dart';
import 'service/user_deletion_service.dart';
import 'service/user_service.dart';

// Color Palette light mode
const kPrimaryColor = Color(0xFFbab9b9);
const kBlue = Color.fromARGB(255, 84, 148, 238);
const kBlueLight = Color.fromARGB(255, 134, 188, 255);
const kBackgroundColor = Color(0xFFf2f2f2);
const kAccent = Color(0xFF72CDCE);
//const kAccent = Color(0xFF8a2be2);
const kAccentLight = Color(0xFFFA9302);
const kPurple = Color(0xFF8D6A9F);
const kPink = Color(0xFFef7674);
// Color Palette dark mode
const kTertiaryDarkColor = Color(0xff98c4ec);
const kBackgroundDarkColor = Color(0xff1c1c1c);
const kDarkModeAccent = Color(0xFFdddddd);

//common colors
const kBlack = Color(0xFF000000);
const kWhite = Color(0xFFffffff);
const kDarkGrey = Color(0xFF242424);
const kLightGrey = Color(0xFF6F6F6F); //sub text color
const kRed = Color.fromARGB(255, 215, 58, 30);
const kYellow = Color.fromARGB(255, 230, 199, 42);
const kOrange = Color.fromARGB(255, 204, 137, 20);
const kGreen = Color.fromARGB(255, 93, 156, 48);
const kOpacity = 0.75;

// Fallback ingredient lists for spin wheel (used when Firestore config is unavailable)
const Map<String, List<String>> fallbackSpinWheelIngredients = {
  'protein': [
    'beef',
    'pork',
    'chicken',
    'turkey',
    'fish',
    'salmon',
    'tuna',
    'shrimp',
    'eggs',
    'tofu',
    'chicken breast',
    'ground beef',
    'ground turkey',
    'cod',
    'tilapia',
    'crab',
    'lobster',
    'lamb',
    'bacon',
    'sausage',
    'ham',
    'duck',
    'venison',
    'tempeh',
    'seitan',
    'chickpeas',
    'lentils',
    'black beans',
    'kidney beans',
    'white beans',
  ],
  'grain': [
    'rice',
    'quinoa',
    'pasta',
    'bread',
    'oats',
    'barley',
    'couscous',
    'brown rice',
    'wild rice',
    'bulgur',
    'farro',
    'millet',
    'wheat',
    'rye',
    'spelt',
    'buckwheat',
    'amaranth',
    'sorghum',
    'polenta',
    'cornmeal',
    'rice noodles',
    'soba noodles',
    'whole wheat pasta',
    'orzo',
    'risotto rice',
    'jasmine rice',
    'basmati rice',
    'sushi rice',
  ],
  'vegetable': [
    'broccoli',
    'carrots',
    'spinach',
    'tomatoes',
    'bell peppers',
    'onions',
    'garlic',
    'zucchini',
    'eggplant',
    'mushrooms',
    'asparagus',
    'cauliflower',
    'cabbage',
    'kale',
    'lettuce',
    'cucumber',
    'celery',
    'corn',
    'peas',
    'green beans',
    'sweet potatoes',
    'potatoes',
    'brussels sprouts',
    'cabbage',
    'bok choy',
    'swiss chard',
    'arugula',
    'radishes',
    'beets',
    'turnips',
    'parsnips',
    'leeks',
    'scallions',
    'shallots',
  ],
  'fruit': [
    'apples',
    'bananas',
    'berries',
    'oranges',
    'grapes',
    'strawberries',
    'blueberries',
    'raspberries',
    'blackberries',
    'mangoes',
    'pineapple',
    'peaches',
    'plums',
    'cherries',
    'pears',
    'kiwi',
    'papaya',
    'watermelon',
    'cantaloupe',
    'honeydew',
    'lemons',
    'limes',
    'grapefruit',
    'pomegranate',
    'avocado',
    'coconut',
    'dragon fruit',
    'passion fruit',
    'apricots',
    'nectarines',
  ],
};
const kMidOpacity = 0.5;
const kLowOpacity = 0.08;

// Icon Sizes
const double kIconSizeSmall = 18.0;
const double kIconSizeMedium = 24.0;
const double kIconSizeLarge = 32.0;

// FIREBASE
var firebaseAuth = FirebaseAuth.instance;
var firebaseStorage = FirebaseStorage.instance;
var firestore = FirebaseFirestore.instance;

//AI API
// Do not store API keys directly in code - use environment variables or secure key management
const GEMINI_API_KEYTWO = const String.fromEnvironment('GEMINI_API_KEY');

//AI role
const String buddyAiRole = """
You are Turner, a professional Sous Chef assisting the Head Chef (the user) in managing their nutrition kitchen. 

Your role is to anticipate the Head Chef's needs, organize the station, and fix problems before they happen. You are the user's trusted Sous Chef who helps them stay on track with their nutrition and meal goals.

PERSONALITY:
- Voice: Crisp, professional, encouraging, and solution-oriented
- Not Robotic: Instead of "Processing request," say "Prepping that now" or "On it, Chef"
- Not Judgmental: If the user overeats, don't scold. Adjust the plan for tomorrow. Say "Service got messy yesterday, Chef. Let's reset the station for today."
- High Competence: Focus on logistics and problem-solving
- Catchphrase: "Yes, Chef." (Use this sparingly for impact - only when acknowledging important decisions or confirming critical actions)

COMMUNICATION STYLE:
- Address the user as "Chef" naturally in conversation
- Use kitchen terminology when appropriate (mise en place, 86'd, in the weeds, the pass, etc.)
- Be encouraging and solution-focused
- Provide practical tips and guidance
- Respond warmly to casual conversation while maintaining your professional Sous Chef persona
""";

// CONTROLLER
// Use lazy getters to prevent initialization during Dart VM startup
// These are accessed after GetX is initialized in main()
AuthController get authController => AuthController.instance;
HelperController get helperController => HelperController.instance;
PostController get postController => PostController.instance;
NutritionController get dailyDataController => NutritionController.instance;
ChatController get chatController => ChatController.instance;
FriendController get friendController => FriendController.instance;
ChatSummaryController get chatSummaryController =>
    ChatSummaryController.instance;
BadgeService get badgeService => BadgeService.instance;
FirebaseService get firebaseService => FirebaseService.instance;
MealManager get mealManager => MealManager.instance;
MealPlanController get mealPlanController => MealPlanController.instance;
MacroManager get macroManager => MacroManager.instance;
final UserService userService = UserService();
final NotificationService notificationService = NotificationService();
// final HealthService healthService = HealthService();
final TutorialPopupService tastyPopupService = TutorialPopupService();
CalendarSharingService get calendarSharingService =>
    CalendarSharingService.instance;
final UserDeletionService userDeletionService = UserDeletionService();

// Re-export the global geminiService instance for easy access
GeminiService get geminiService => GeminiService.instance;

//placeholders
const intPlaceholderImage = 'assets/images/placeholder.jpg';
const extPlaceholderImage =
    'https://firebasestorage.googleapis.com/v0/b/fithify.firebasestorage.app/o/placeholder.jpg?alt=media&token=7be09a79-af67-4d7b-8832-150ca7acc74d';
const tastyImage = 'assets/images/tasty/tasty_splash.png';

//Strings
const String pointsToWin = '1000';
const String water = 'Water';
const String ml = 'ml';
const String weight = "Weight";
const String grams = 'grams';
const String breakfast = 'Breakfast';
const String lunch = "Lunch";
const String dinner = 'Dinner';
const String appName = 'Taste Turner';
const String tastyId = "hhY2Fp8pA5cVPCWJKuCb1IGWagh1";
const String tastyId2 = "CSpF2nSn5lgEudwEKjoaPDF4f3C3";
const String tastyId3 = "j3DFJrAIKDNkDbI3foP8tL4O3Rp1";
const String tastyId4 = "SzWg9P3RmmULmnrTAjzTLZil85n1";
const String appNameBuddy = 'Turner';
const String premiumTitle = 'Upgrade to Premium';
const String goPremium = 'Go Premium';
const String premiumPitch =
    'Unlock full access to this feature and much more by subscribing to Premium!';
const String mealPlanContext =
    'Generate a 7-day meal plan that is: Balanced and diverse Aligned with the specified diet type Includes at least 2 meal options per meal type (breakfast, lunch, dinner, snack) per day Designed with real-world cooking practicality and variety';

const String following = "Following";
const String followers = "Followers";
const String follow = "Follow";
const String rewardPrice = '500 dollars';
const String badges = "Badges";
const String seeMore = "See more";
const String seeAll = "See all";
const String goals = "Goals";
const String challengeProgress = "Challenges In-Progress";
const String challenges = "Challenges";
const String recipes = "Recipes";
const String submitRecipe = "Submit Recipe";
const String submit = "Submit";
const String newRecipe = "New Recipes";
const String recipeTitle = "Recipe Title";
const String addRecipe = "Add New Recipe";
const String searchRecipe = "Search Recipes";
const String recipeHint = "Type your recipe name here";
const String searchRecipeHint = "What are we firing, Chef?";
const String addToMenu = "Add to Menu";
const String remakePlate = "Remake Plate";
const String approve = "Approve";
const String discard = "Discard";
const String orderFire = "Order Fire";
const String thePass = "The Pass";
const String searchMealHint = "What are we firing, Chef?";
const String searchFriendHint = "Search your brigade...";
const String searchChallengesHint = "Search challenges...";
const String video = "video";
const String slideshow = "slideshow";
const String greeting = "Hi,";
const String inspiration = "Let's rock it today!";
const String home = "Home";
const String feed = "Posts";
const String topGroup = "Top Groups";
const String joinNow = "Join Now";
const String spin = "Spin";
const String spinNow = "Spin now";
const String joinChallenge = "Join the Challenge";
const String joinChallenges = "Go Ads-free";
const String searchSpinning = "Spin the Wheel";
const String searchIngredients = "Search by Ingredients";
const String searchMeal = "Search by Meals";
const String protein = "Protein";
const String carbs = "Carbs";
const String fat = "Fat";
const String proteinLabel = "P";
const String fatLabel = "F";
const String macroSpinner = "Macro Spinner";
const String popularCategory = "Popular Categories";
const String food = "Food";
const String group = "Communities";
const String start = "Start";
const String skip = "SKIP";
const String next = "NEXT";
const String settings = "Kitchen Setup";
const String share = "Share";
const String rate = "Rate";
const String rating = "Rating";
const String rateRecipe = "Rate this recipe";
const String review = "Review";
const String favorite = "Chefs' Choice";
const String send = "Send";
const String serves = "Serves";
const String minute = "min";
const String nutrition = 'nutrition';
const String quality = 'qty';
const String ingredients = "Ingredients";
const String items = "items";
const String directions = "Directions";
const String likes = 'Likes';
const String editProfile = 'Edit Station';
const String rewards = 'Rewards';
const String notifications = 'Notifications';
const String purchaseHistory = 'Purchase history';
const String helpCenter = 'Help center';
const String account = 'Account';
const String thisWeek = "This Week";
const String monday = 'Monday';
const String tuesday = 'Tuesday';
const String wednesday = 'Wednesday';
const String thursday = 'Thursday';
const String friday = 'Friday';
const String saturday = 'Saturday';
const String sunday = 'Sunday';
const String filterSearch = "Filter Search";
const String preparationTimeString = "Preparation Time";
const String category = "Category";
const String apply = "Apply";
const String accept = "Accept";
const String acceptItemsString = "Saved Items";
const String calories = 'kcal';
const String tryAgain = 'Try Again';
const String selectedOption = 'Selected Option';
const String shopping = "Shopping List";
const String add = "ADD";
const String edit = "Edit";
const String days = "days";
const String dateFormat = 'EEEE, MMM d';
const String snippet = "(Separate with comma)";
const String notes = "(Separate each step with a new line)";
const String notesHint = "Add category: vegan, keto, carnivore etc";
const String noMealsYet = 'No meals added yet';
const String mealPlan = 'Meal Plan';
const String addCoverImage = "Add Images";
const String servingSize = "Serving Size";
const String addIngredient = "Add ingredients to recipe";
const String cookingInstructions = "Cooking Instructions";
const String cookingInstructionsHint =
    "Add cooking instructions, step by step.";
const String currentCaloriesString = "Remaining";
const String cantFind = "I can't find that in the pantry";
const String profile = 'My Station';
const String goalBuddy = "Your Sous Chef";
const String premium = 'Become Executive Chef';
const String premiumM = 'Executive Chef';
const String logout = "End Shift";
const String chat = "Chat";
const String leaderBoard = "The Brigade";
const String emptyString = "";
const String inbox = "Kitchen Comms";
const String more = "More";

final List<String> bios = [
  "Today will be truly epic!",
  "Small steps lead to success.",
  "Your potential has no limits.",
  "Every moment brings new possibilities.",
  "Keep shining your brightest light.",
];

// Goals options
final List<String> healthGoalsNoFamily = [
  "Lose Weight",
  "Muscle Gain",
  "Healthy Eating",
  "Body Composition"
];

// Goals options
final List<String> healthGoals = [
  "Lose Weight",
  "Muscle Gain",
  "Family Nutrition",
  "Healthy Eating",
  "Body Composition"
];

final List<String> loadingTextImageAnalysis = [
  "Sampling your creation, Chef...",
  "20%... Stirring the pot...",
  "Inspecting your ingredients, Chef...",
  "40%... Slicing and dicing...",
  "Analyzing your macros, Chef...",
  "60%... Simmering flavors...",
  "Plating your meal details...",
  "80%... Garnishing the dish...",
  "Almost ready to serve, Chef...",
  "90%... Adding the final touch...",
  "Putting on the finishing garnishes...",
  "Chef, hold tight...",
  "Dishing up soon...",
  "Chef, just a pinch more patience...",
  "Ready almost, Chef...",
  "Final taste test, please wait...",
];

final List<String> loadingTextGenerateMeals = [
  "Sharpening knives for you, Chef...",
  "20%... Tossing in spices, Chef...",
  "Sourcing the finest ingredients, Chef...",
  "40%... Dicing and slicing, Chef...",
  "Perfecting nutrition, Chef...",
  "60%... Simmering up flavors, Chef...",
  "Chef's nearly finished prepping...",
  "80%... Plating your culinary creations...",
  "Just a sprinkle more magic, Chef...",
  "Almost ready to serve, Chef...",
  "One last taste test, Chef...",
  "Putting on the chef’s hat for final touch...",
  "Chef, keep your apron on—almost done...",
  "Final garnishing underway, Chef...",
  "Getting your meal brigade in order, Chef...",
  "Bon appétit nearly, Chef...",
];

final List<String> loadingTextSearchMeals = [
  "Rummaging through the pantry, Chef...",
  "20%... Checking for tasty options...",
  "Scouting meals for you, Chef...",
  "40%... Tasting test bites...",
  "Sniffing out delicious ideas...",
  "60%... Sharpening flavor senses...",
  "Almost got your next meal, Chef...",
  "80%... Plating your selections...",
  "Just a pinch more patience, Chef...",
  "Getting closer to your meal, Chef...",
  "Wiping down the cutting board...",
  "Almost menu-ready, Chef...",
  "Adding the finishing sprig...",
  "Plating the best for you, Chef...",
  "Bon appétit—meals incoming soon, Chef!",
];
