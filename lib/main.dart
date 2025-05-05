import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:audioplayers/audioplayers.dart';

import 'constants.dart';
import 'data_models/message_screen_data.dart';
import 'data_models/profilescreen_data.dart';
import 'screens/splash_screen.dart';
import 'service/auth_controller.dart';
import 'service/battle_management.dart';
import 'service/chat_controller.dart';
import 'service/firebase_data.dart';
import 'service/friend_controller.dart';
import 'service/meal_manager.dart';
import 'service/notification_service.dart';
import 'service/nutrition_controller.dart';
import 'service/post_manager.dart';
import 'service/helper_controller.dart';
import 'service/battle_service.dart';
import 'themes/theme_provider.dart';

import 'package:firebase_core/firebase_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set text input options at the app level
  await SystemChannels.textInput.invokeMethod('TextInput.setOptions', {
    'enableStylus': false,
    'enableHandwriting': false,
  });

  // Initialize AudioPlayer with default settings
  AudioPlayer();

  await dotenv.load(fileName: 'assets/env/.env');

  await Firebase.initializeApp().then((value) {
    Get.put(AuthController());
    Get.put(HelperController());
    Get.put(FirebaseService());
    // Get.put(HealthService());
    Get.put(BattleService());

    Get.lazyPut(() => MealManager());
    Get.lazyPut(() => PostController());
    Get.lazyPut(() => NutritionController());
    Get.lazyPut(() => ChatController());
    Get.lazyPut(() => ChatSummaryController());
    Get.lazyPut(() => BadgeController());
    Get.lazyPut(() => FriendController());
  });

  await firebaseService.fetchGeneralData();
  await macroManager.getIngredientsByCategory("All");
  BattleManagement.instance.startBattleManagement();
  // Initialize notification service
  final notificationService = NotificationService();
  await notificationService.initNotification();

  // Set up daily reminders
  await notificationService.scheduleMultipleDailyReminders(
    reminders: [
      DailyReminder(
        id: 5001,
        title: "Morning Check-in 🌅",
        body: "Plan your meals and set your goals for today!",
        hour: 7,
        minute: 0,
      ),
      DailyReminder(
        id: 5002,
        title: "Water Reminder 💧",
        body: "Stay hydrated! Don't forget to track your water intake.",
        hour: 11,
        minute: 0,
      ),
      DailyReminder(
        id: 5003,
        title: "Evening Review 🌙",
        body: "Review your goals and plan for tomorrow!",
        hour: 21,
        minute: 0,
      ),
    ],
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => ThemeProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      title: appName,
      home: const SplashScreen(),
      theme: Provider.of<ThemeProvider>(context).themeData,
    );
  }
}
