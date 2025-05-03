import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../data_models/meal_plan_model.dart';
import '../data_models/user_meal.dart';
import '../service/calendar_sharing_service.dart';

class CalendarSharingController extends GetxController {
  final CalendarSharingService _sharingService =
      Get.put(CalendarSharingService());

  // Observable lists for UI
  final RxList<ShareRequest> pendingRequests = <ShareRequest>[].obs;
  final RxList<SharedCalendar> sharedCalendars = <SharedCalendar>[].obs;
  final RxMap<String, Map<String, List<UserMeal>>> unifiedMeals =
      <String, Map<String, List<UserMeal>>>{}.obs;

  // Loading states
  final RxBool isLoadingRequests = false.obs;
  final RxBool isLoadingCalendars = false.obs;
  final RxBool isLoadingUnifiedMeals = false.obs;

  @override
  void onInit() {
    super.onInit();
    // Start listening to share requests and shared calendars
    setupListeners();
  }

  void setupListeners() {
    // Get current user ID from your auth service
    final userId = 'current_user_id'; // Replace with actual user ID

    // Listen to pending share requests
    _sharingService.getPendingShareRequests(userId).listen(
      (requests) {
        pendingRequests.value = requests;
        isLoadingRequests.value = false;
      },
      onError: (error) {
        print('Error listening to share requests: $error');
        isLoadingRequests.value = false;
      },
    );

    // Listen to shared calendars
    _sharingService.getSharedCalendars(userId).listen(
      (calendars) {
        sharedCalendars.value = calendars;
        isLoadingCalendars.value = false;
      },
      onError: (error) {
        print('Error listening to shared calendars: $error');
        isLoadingCalendars.value = false;
      },
    );
  }

  // Send a share request
  Future<void> sendShareRequest({
    required String recipientId,
    required String type,
    String? date,
  }) async {
    try {
      final userId = 'current_user_id'; // Replace with actual user ID
      await _sharingService.sendShareRequest(
        senderId: userId,
        recipientId: recipientId,
        type: type,
        date: date,
      );
      Get.snackbar(
        'Success',
        'Share request sent successfully',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      print('Error sending share request: $e');
      Get.snackbar(
        'Error',
        'Failed to send share request',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  // Accept a share request
  Future<void> acceptShareRequest(String requestId) async {
    try {
      await _sharingService.acceptShareRequest(requestId);
      Get.snackbar(
        'Success',
        'Share request accepted',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      print('Error accepting share request: $e');
      Get.snackbar(
        'Error',
        'Failed to accept share request',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  // Load unified calendar for a specific date
  Future<void> loadUnifiedCalendar(String calendarId, DateTime date) async {
    try {
      isLoadingUnifiedMeals.value = true;
      final unifiedMap =
          await _sharingService.getUnifiedCalendar(calendarId, date);
      // unifiedMap: { userId: { meals: [...], ... }, ... }
      final Map<String, List<UserMeal>> userMeals = {};
      unifiedMap.forEach((userId, data) {
        final meals = (data['meals'] as List<dynamic>?)
                ?.map((m) => UserMeal.fromMap(m as Map<String, dynamic>))
                .toList() ??
            [];
        userMeals[userId] = meals;
      });
      unifiedMeals[calendarId] = userMeals;
    } catch (e) {
      print('Error loading unified calendar: $e');
      Get.snackbar(
        'Error',
        'Failed to load shared calendar',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isLoadingUnifiedMeals.value = false;
    }
  }

  // Get chat messages for a request
  Stream<QuerySnapshot> getChatMessages(String chatId) {
    return _sharingService.getChatMessages(chatId);
  }

  @override
  void onClose() {
    // Clean up if needed
    super.onClose();
  }
}
