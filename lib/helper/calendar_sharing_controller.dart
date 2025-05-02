import 'package:get/get.dart';

class CalendarSharingController extends GetxController {
  final RxString selectedSharedCalendarId = ''.obs;
  final Rx<DateTime> selectedSharedDate = DateTime.now().obs;

  void selectSharedCalendar(String calendarId) {
    selectedSharedCalendarId.value = calendarId;
  }

  void selectSharedDate(DateTime date) {
    selectedSharedDate.value = date;
  }
}
