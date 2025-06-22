import 'package:get/get.dart';
import '../data_models/user_data_model.dart';

class UserService extends GetxController {
  static final UserService _instance = UserService._internal();

  factory UserService() => _instance;

  UserService._internal();

  String? userId;
  String? buddyId;
  final Rx<UserModel?> currentUser = Rx<UserModel?>(null);

  void setUserId(String? id) => userId = id;
  void setBuddyChatId(String? id) => buddyId = id;

  void setUser(UserModel? user) {
    currentUser.value = user;
    if (user != null) {
      // Keep userId in sync for non-reactive parts of the app that might use it
      setUserId(user.userId);
    }
  }

  void clearUser() {
    userId = null;
    buddyId = null;
    currentUser.value = null;
  }
}
