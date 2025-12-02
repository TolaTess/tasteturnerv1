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
  // Initialize MacroManager instance early to ensure it's registered before use
  MacroManager.instance;
  Get.put(UserService(), permanent: true);
  Get.put(NotificationHandlerService(), permanent: true);
  Get.lazyPut(() => HybridNotificationService()); // Lazy load - can be deferred
  // print('Registering ChallengeService...');
  // // Get.put(ChallengeService(), permanent: true);
  // print('ChallengeService registered successfully');

  // Register NotificationService with GetX (but don't auto-initialize)
  // Users will enable notifications through onboarding or settings
  final notificationService = NotificationService();
  Get.put(notificationService, permanent: true);

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
