import 'dart:async';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';

import 'constants.dart';
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
import 'service/user_service.dart';
import 'service/macro_manager.dart';
import 'service/program_service.dart';
import 'service/plant_detection_service.dart';
import 'service/symptom_service.dart';
import 'service/symptom_analysis_service.dart';
import 'data_models/message_screen_data.dart';

void main() async {
  // Set up global error handlers to catch unhandled errors
  // This helps identify what triggers __pthread_kill crashes
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('=== FLUTTER ERROR ===');
    debugPrint('Exception: ${details.exception}');
    debugPrint('Stack: ${details.stack}');
    debugPrint('Library: ${details.library}');
    debugPrint('Context: ${details.context}');
    debugPrint('===================');
  };

  // Handle errors from async operations outside Flutter's error zone
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('=== PLATFORM DISPATCHER ERROR ===');
    debugPrint('Error: $error');
    debugPrint('Stack: $stack');
    debugPrint('================================');
    return true; // Return true to prevent app termination
  };

  // Run app in error zone to catch all errors
  // IMPORTANT: ensureInitialized() must be called in the same zone as runApp()
  runZonedGuarded(() async {
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

    // Load environment variables with error handling
    try {
      await dotenv.load(fileName: 'assets/env/.env');
    } catch (e) {
      debugPrint('Error loading .env file: $e');
      // Continue without .env - app may still work with defaults
    }

    // Initialize Firebase with error handling
    // SIGABRT can occur if Firebase initialization fails on physical devices
    try {
      await Firebase.initializeApp();
      debugPrint('Firebase initialized successfully');
    } catch (e, stackTrace) {
      debugPrint('=== CRITICAL: Firebase initialization failed ===');
      debugPrint('Error: $e');
      debugPrint('Stack: $stackTrace');
      debugPrint('This may cause SIGABRT on physical iOS devices');
      debugPrint('===============================================');
      // Re-throw to let error zone handle it, but log first for debugging
      rethrow;
    }
    // AudioPlayer() - Removed, will be lazy loaded when needed

    // Register controllers/services with error handling
    // These can throw if GetX is not properly initialized or if services fail
    try {
      Get.put(AuthController());
      Get.put(HelperController());
      Get.put(FirebaseService());
    } catch (e) {
      debugPrint('Error registering core services: $e');
      // Re-throw as this is critical for app functionality
      rethrow;
    }
    Get.lazyPut(() =>
        CalendarSharingService()); // Lazy load - only needed for calendar sharing
    Get.lazyPut(() => MealManager());
    Get.lazyPut(() => MealPlanController());
    Get.lazyPut(() =>
        NutritionController()); // Lazy load - only needed for nutrition tracking
    Get.lazyPut(() => ChatSummaryController());
    // Initialize service instances early using MacroManager pattern (auto-registers if needed)
    // These services use Get.isRegistered() check in their instance getters
    BadgeService.instance; // Used in home screen and profile screens
    ChatController.instance; // Accessed in home_screen initState
    FriendController.instance; // Accessed early in message_screen initState
    PostController.instance; // Used for posts
    PostService.instance; // Used for posts
    MacroManager.instance; // Used for macro management
    ProgramService.instance; // Accessed in home_screen initState
    PlantDetectionService.instance; // Accessed early in home_screen
    SymptomService
        .instance; // Accessed early in home_screen and daily_summary_widget
    SymptomAnalysisService
        .instance; // Accessed early in home_screen and daily_summary_widget
    Get.put(UserService(), permanent: true);
    Get.put(NotificationHandlerService(), permanent: true);
    Get.lazyPut(
        () => HybridNotificationService()); // Lazy load - can be deferred
    // print('Registering ChallengeService...');
    // // Get.put(ChallengeService(), permanent: true);
    // print('ChallengeService registered successfully');

    // Register NotificationService with GetX (but don't auto-initialize)
    // Users will enable notifications through onboarding or settings
    // Wrap in try-catch as NotificationService initialization can fail on physical devices
    try {
      final notificationService = NotificationService();
      Get.put(notificationService, permanent: true);
      debugPrint('NotificationService registered - awaiting user preference');
    } catch (e) {
      debugPrint('Error registering NotificationService: $e');
      // Don't rethrow - notifications are not critical for app startup
      // App can continue without notification service
    }

    debugPrint('NotificationService registered - awaiting user preference');

    // Note: fetchGeneralData and ads initialization moved to post-frame callbacks
    // to avoid blocking app startup. They will be initialized after UI is rendered.
    // fetchGeneralData is already called lazily by screens that need it.
    // Ads will be initialized when first ad is requested.

    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (context) => ThemeProvider()),
        ],
        child: const MyApp(),
      ),
    );
  }, (error, stack) {
    // Catch any errors that escape the error zone
    debugPrint('=== ZONE ERROR ===');
    debugPrint('Error: $error');
    debugPrint('Stack: $stack');
    debugPrint('==================');
  });
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
