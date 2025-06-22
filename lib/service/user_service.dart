import 'package:get/get.dart';
import '../data_models/user_data_model.dart';

class UserService extends GetxController {
  static final UserService _instance = UserService._internal();

  factory UserService() => _instance;

  UserService._internal();

  // A stable, non-reactive ID for the current session.
  String? userId;
  String? buddyId;
  // A reactive object for all other user data that can change.
  final Rx<UserModel?> currentUser = Rx<UserModel?>(null);

  void setUserId(String? id) {
    userId = id;
  }

  void setBuddyChatId(String? id) => buddyId = id;

  void setUser(UserModel? user) {
    currentUser.value = user;
    // Also update the stable userId to ensure it's always in sync
    // when the user object is first set.
    if (user != null) {
      setUserId(user.userId);
    }
  }

  void clearUser() {
    userId = null;
    buddyId = null;
    currentUser.value = null;
  }
}
