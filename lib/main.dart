import 'dart:async';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'constants.dart';
import 'helper/utils.dart';
import 'themes/theme_provider.dart';
import 'themes/dark_mode.dart';
import 'themes/light_mode.dart';
import 'screens/splash_screen.dart';
import 'service/auth_controller.dart';
import 'service/badge_service.dart';
import 'service/calendar_sharing_service.dart';
import 'service/chat_controller.dart';
import 'service/firebase_data.dart';
import 'service/friend_controller.dart';
import 'service/meal_manager.dart';
import 'service/meal_plan_controller.dart';
import 'service/notification_service.dart';
import 'service/notification_handler_service.dart';
import 'service/hybrid_notification_service.dart';
import 'service/nutrition_controller.dart';
import 'service/post_manager.dart';
import 'service/post_service.dart';
import 'service/helper_controller.dart';
import 'service/battle_service.dart';
import 'service/user_service.dart';
import 'data_models/message_screen_data.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Platform channel call: wrap in try/catch
  try {
    await SystemChannels.textInput.invokeMethod('TextInput.setOptions', {
      'enableStylus': false,
      'enableHandwriting': false,
    });
  } catch (e) {
    debugPrint('TextInput configuration error: $e');
    // Don't show UI error at startup - silent logging only
  }

  await dotenv.load(fileName: 'assets/env/.env');
  await Firebase.initializeApp();
  // AudioPlayer() - Removed, will be lazy loaded when needed

  // Register controllers/services
  Get.put(AuthController());
  Get.put(HelperController());
  Get.put(FirebaseService());
  Get.lazyPut(() => BattleService()); // Lazy load - only needed for battles
  Get.lazyPut(() =>
      CalendarSharingService()); // Lazy load - only needed for calendar sharing
  Get.lazyPut(
      () => BadgeService()); // Lazy load - only needed for badges/profile
  Get.lazyPut(() => MealManager());
  Get.lazyPut(() => MealPlanController());
  Get.lazyPut(() => PostController());
  Get.lazyPut(() => PostService());
  Get.lazyPut(() =>
      NutritionController()); // Lazy load - only needed for nutrition tracking
  Get.lazyPut(() => ChatController());
  Get.lazyPut(() => ChatSummaryController());
  Get.lazyPut(() => FriendController());
  // MacroManager is already registered in its own file
  Get.put(UserService(), permanent: true);
  Get.put(NotificationHandlerService(), permanent: true);
  Get.lazyPut(() => HybridNotificationService()); // Lazy load - can be deferred
  // print('Registering ChallengeService...');
  // // Get.put(ChallengeService(), permanent: true);
  // print('ChallengeService registered successfully');

  // Register NotificationService with GetX (but don't initialize yet)
  final notificationService = NotificationService();
  Get.put(notificationService, permanent: true);

  // Handle notification taps
  void _handleNotificationTap(String payload) async {
    try {
      // Parse the payload to determine what to show
      if (payload.contains('meal_plan_reminder') ||
          payload.contains('evening_review') ||
          payload.contains('water_reminder')) {
        debugPrint('Notification tapped: $payload');

        // Use the notification handler service to process the payload
        try {
          final handlerService = Get.find<NotificationHandlerService>();
          await handlerService.handleNotificationPayload(payload);
        } catch (e) {
          showTastySnackbar(
              'Something went wrong', 'Please try again later', Get.context!,
              backgroundColor: kRed);
          // The service will be available once the app is fully initialized
        }
      }
    } catch (e) {
      showTastySnackbar(
          'Something went wrong', 'Please try again later', Get.context!,
          backgroundColor: kRed);
    }
  }

  // Initialize notifications in background after app starts
  Future.microtask(() async {
    int retries = 0;
    while (retries < 3) {
      try {
        // Add timeout to prevent hanging
        await notificationService.initNotification(
          onNotificationTapped: (String? payload) {
            if (payload != null) {
              _handleNotificationTap(payload);
            }
          },
        ).timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            debugPrint('Notification initialization timed out');
            throw TimeoutException('Notification initialization timed out',
                const Duration(seconds: 10));
          },
        );
        debugPrint('Notifications service initialized successfully');
        break;
      } catch (e) {
        retries++;
        debugPrint('Notification init attempt $retries failed: $e');
        if (retries >= 3) {
          debugPrint('Notification initialization failed after 3 attempts');
        } else {
          await Future.delayed(Duration(seconds: retries));
        }
      }
    }
  });

  // Initialize Firebase data in background
  Future.microtask(() async {
    try {
      // Stage 1: Essential data only
      await FirebaseService.instance.fetchGeneralData();

    } catch (e) {
      debugPrint('Error initializing Firebase data: $e');
    }
  });

  // Initialize MobileAds in background to avoid blocking startup
  Future.microtask(() async {
    try {
      await MobileAds.instance.initialize();
      debugPrint('Ads initialized successfully');
    } catch (e) {
      debugPrint('Error initializing ads: $e');
    }
  });

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
  static FirebaseAnalytics analytics = FirebaseAnalytics.instance;

  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return GetMaterialApp(
          debugShowCheckedModeBanner: false,
          title: appName,
          home: const SplashScreen(),
          theme: themeProvider.isDarkMode
              ? ThemeDarkManager().mainTheme(context)
              : ThemeManager().mainTheme(context),
        );
      },
    );
  }
}
