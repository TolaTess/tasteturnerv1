import 'package:get/get.dart';
import '../data_models/message_screen_data.dart';
import '../data_models/profilescreen_data.dart';
import 'auth_controller.dart';
import 'battle_service.dart';
import 'calendar_sharing_service.dart';
import 'chat_controller.dart';
import 'firebase_data.dart';
import 'friend_controller.dart';
import 'helper_controller.dart';
import 'macro_manager.dart';
import 'meal_manager.dart';
import 'nutrition_controller.dart';
import 'post_manager.dart';
import 'user_service.dart';

class AppBindings extends Bindings {
  @override
  void dependencies() {
    // Core services - immediate initialization
    Get.put(AuthController(), permanent: true);
    Get.put(HelperController(), permanent: true);
    Get.put(FirebaseService(), permanent: true);
    Get.put(UserService(), permanent: true);
    Get.put(MacroManager(), permanent: true);

    // Feature services - lazy initialization with fenix
    Get.lazyPut(() => BattleService(), fenix: true);
    Get.lazyPut(() => CalendarSharingService(), fenix: true);
    Get.lazyPut(() => MealManager(), fenix: true);
    Get.lazyPut(() => PostController(), fenix: true);
    Get.lazyPut(() => NutritionController(), fenix: true);
    Get.lazyPut(() => ChatController(), fenix: true);
    Get.lazyPut(() => ChatSummaryController(), fenix: true);
    Get.lazyPut(() => BadgeController(), fenix: true);
    Get.lazyPut(() => FriendController(), fenix: true);
  }

  // Helper method to ensure a service is initialized
  static T ensureInitialized<T>() {
    if (!Get.isRegistered<T>()) {
      // This will trigger the lazy initialization if needed
      return Get.find<T>();
    }
    return Get.find<T>();
  }
}
