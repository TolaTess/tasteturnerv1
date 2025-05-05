import '../data_models/user_data_model.dart';

class UserService {
  static final UserService _instance = UserService._internal();

  factory UserService() => _instance;

  UserService._internal();

  String? userId;
  String? buddyId;
  UserModel? currentUser;

  void setUserId(String? id) => userId = id;
  void setBuddyChatId(String? id) => buddyId = id;
  void setUser(UserModel? user) => currentUser = user;

  void clearUser() {
    userId = null;
    buddyId = null;
    currentUser = null;
  }
}
