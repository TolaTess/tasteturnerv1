import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';
import '../data_models/user_data_model.dart';
import '../helper/utils.dart';
import '../screens/onboarding_screen.dart';
import '../screens/splash_screen.dart';
import '../widgets/bottom_nav.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'badge_service.dart';

class AuthController extends GetxController {
  static AuthController instance = Get.find();

  StreamSubscription? _userDataSubscription;

  // Shared Preferences key for login state
  final String _isLoggedInKey = 'isLoggedIn';

  @override
  void onReady() async {
    super.onReady();

    Rx<User?> authState = Rx<User?>(null);
    authState.bindStream(firebaseAuth.authStateChanges());

    // Listen for auth state changes
    ever(authState, _handleAuthState);
  }

  void _handleAuthState(User? user) async {
    if (user == null) {
      // User not authenticated
      await _setLoggedIn(false);
      _userDataSubscription?.cancel();
      userService.clearUser();
      Get.offAll(() => const SplashScreen());
      return;
    }

    // Set the stable User ID as soon as authentication is confirmed.
    userService.setUserId(user.uid);

    try {
      final userDoc = await _fetchUserDocWithRetry(user.uid);

      if (!userDoc.exists) {
        // New user - needs onboarding
        await _setLoggedIn(true);
        Get.offAll(() => OnboardingScreen(userId: user.uid));
      } else {
        // Existing user - load data and proceed to main app
        try {
          // Start listening to user data instead of one-time fetch
          listenToUserData(user.uid);

          // Check and assign user number if needed (for first 100 users badge)
          await BadgeService.instance.assignUserNumberToExistingUser(user.uid);

          await _setLoggedIn(true);
          Get.offAll(() => const BottomNavSec());
        } catch (e) {
          debugPrint("Failed to load user data: $e");
          // Handle the error appropriately - maybe show an error screen
          Get.snackbar(
            'Please try again',
            'Failed to load user data. Please try again.',
            backgroundColor: Colors.red,
            colorText: Colors.white,
            snackPosition: SnackPosition.BOTTOM,
          );
        }
      }
    } catch (e) {
      debugPrint("Error checking user existence: $e");
      // Check for Firestore unavailable error
      if (e.toString().contains('cloud_firestore/unavailable')) {
        // Optionally, you could retry here with a delay/backoff
        Get.snackbar(
          'Network Issue',
          'We`re having trouble connecting. Please check your connection and try again.',
          backgroundColor: kAccentLight,
          colorText: kWhite,
          snackPosition: SnackPosition.BOTTOM,
        );
      } else {
        // Handle other errors as before
        Get.snackbar(
          'Please try again.',
          'Something went wrong. Please try again.',
          backgroundColor: Colors.red,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    }
  }

  void listenToUserData(String userId) {
    // Cancel any existing listener
    _userDataSubscription?.cancel();

    _userDataSubscription =
        firestore.collection('users').doc(userId).snapshots().listen(
      (doc) async {
        if (doc.exists) {
          final userDataMap = doc.data()!;

          List<String> following = [];
          final followingSnapshot =
              await firestore.collection('friends').doc(userId).get();

          if (followingSnapshot.exists) {
            final data = followingSnapshot.data()!;
            final followingData = data['following'] as List<dynamic>? ?? [];
            following = followingData.map((id) => id.toString()).toList();
          }

          DateTime? createdAt;
          if (userDataMap['created_At'] is Timestamp) {
            createdAt = (userDataMap['created_At'] as Timestamp).toDate();
          } else if (userDataMap['created_At'] is String) {
            createdAt = DateTime.tryParse(userDataMap['created_At']);
          }
          DateTime? freeTrialDate;
          if (userDataMap['freeTrialDate'] is Timestamp) {
            freeTrialDate =
                (userDataMap['freeTrialDate'] as Timestamp).toDate();
          } else if (userDataMap['freeTrialDate'] is String) {
            freeTrialDate = DateTime.tryParse(userDataMap['freeTrialDate']);
          }

          final familyMembersRaw =
              userDataMap['familyMembers'] as List<dynamic>? ?? [];
          final familyMembers = familyMembersRaw
              .map((e) => FamilyMember.fromMap(e as Map<String, dynamic>))
              .toList();

          final user = UserModel(
            userId: doc.id,
            displayName: userDataMap['displayName']?.toString() ?? '',
            profileImage: userDataMap['profileImage']?.toString() ?? '',
            bio: userDataMap['bio']?.toString() ?? getRandomBio(bios),
            dob: userDataMap['dob']?.toString() ?? '',
            settings: userDataMap['settings'] != null
                ? Map<String, String>.from(
                    (userDataMap['settings'] as Map).map(
                      (key, value) =>
                          MapEntry(key.toString(), value?.toString() ?? ''),
                    ),
                  )
                : {},
            following: following,
            userType: userDataMap['userType']?.toString() ?? 'user',
            isPremium: userDataMap['isPremium'] as bool? ?? false,
            created_At: createdAt,
            freeTrialDate: freeTrialDate,
            familyMode: userDataMap['familyMode'] as bool? ?? false,
            familyMembers: familyMembers,
          );
          userService.setUser(user);
        } else {
          debugPrint("User document does not exist, clearing user data.");
          userService.clearUser();
        }
      },
      onError: (error) {
        debugPrint("Error listening to user data: $error");
        // Optionally handle error, e.g., clear user data
        userService.clearUser();
      },
    );
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> _fetchUserDocWithRetry(
      String userId,
      {int maxRetries = 3}) async {
    int attempt = 0;
    int delayMs = 500;
    while (true) {
      try {
        return await firestore.collection('users').doc(userId).get();
      } catch (e) {
        if (e.toString().contains('cloud_firestore/unavailable') &&
            attempt < maxRetries) {
          attempt++;
          await Future.delayed(Duration(milliseconds: delayMs));
          delayMs *= 2; // Exponential backoff
          continue;
        }
        rethrow;
      }
    }
  }

  Future<void> _setLoggedIn(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isLoggedInKey, value);
  }

  Future<void> registerUser(
      BuildContext context, String email, String password) async {
    try {
      if (email.isNotEmpty && password.isNotEmpty) {
        UserCredential cred =
            await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );

        String userId = cred.user!.uid;
        await _setLoggedIn(true);
        Get.offAll(() => OnboardingScreen(userId: userId));
      } else {
        showTastySnackbar(
          'Please try again.',
          'Please fill in all fields.',
          context,
        );
      }
    } catch (e) {
      showTastySnackbar(
        'Please try again.',
        'Error Creating Account: $e',
        context,
        backgroundColor: Colors.red,
      );
    }
  }

  /// ✅ Google Sign-In Function
  Future<void> signInWithGoogle(BuildContext context) async {
    try {
      // Trigger Google Sign-In Popup
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();

      if (googleUser == null) {
        debugPrint("Google sign-in canceled");
        return;
      }

      // Get authentication credentials
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with Google credentials
      await FirebaseAuth.instance.signInWithCredential(credential);

      // The auth state listener will handle the rest via _handleAuthState
      // No need to manually navigate or set up user data here
    } catch (e) {
      debugPrint("Error signing in with Google: $e");
      showTastySnackbar(
        'Please try again.',
        'Failed to sign in with Google. Please try again.',
        context,
        backgroundColor: Colors.red,
      );
    }
  }

  /// ✅ Apple Sign-In Function
  Future<void> signInWithApple(BuildContext context) async {
    try {
      // Begin sign in process
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      // Create OAuthCredential for Firebase
      final oauthCredential = OAuthProvider("apple.com").credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );

      // Sign in to Firebase with the Apple credentials
      final userCredential =
          await FirebaseAuth.instance.signInWithCredential(oauthCredential);

      // If this is a new user, update their profile with the name from Apple
      if (userCredential.additionalUserInfo?.isNewUser ?? false) {
        final displayName =
            '${appleCredential.givenName ?? ''} ${appleCredential.familyName ?? ''}'
                .trim();
        if (displayName.isNotEmpty) {
          await userCredential.user?.updateDisplayName(displayName);
        }
      }

      // The auth state listener will handle the rest via _handleAuthState
    } catch (e) {
      debugPrint("Error signing in with Apple: $e");
      showTastySnackbar(
        'Please try again.',
        'Failed to sign in with Apple. Please try again.',
        context,
        backgroundColor: Colors.red,
      );
    }
  }

  Future<void> loginUser(
      BuildContext context, String email, String password) async {
    try {
      if (email.isNotEmpty && password.isNotEmpty) {
        // Sign in with Firebase
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );

        // The auth state listener will handle the rest via _handleAuthState
        // No need to manually navigate or set up user data here
      } else {
        showTastySnackbar(
          'Please try again.',
          'Please fill in all fields.',
          context,
        );
      }
    } catch (e) {
      showTastySnackbar(
        'Please try again.',
        'Error Logging in: $e',
        context,
        backgroundColor: Colors.red,
      );
    }
  }

  Future<void> updateUserData(Map<String, dynamic> updatedData) async {
    try {
      final userId = userService.userId;
      if (userId == null) {
        debugPrint('No user is logged in.');
        return;
      }

      // If updating settings, merge them to avoid overwriting other settings.
      if (updatedData.containsKey('settings')) {
        final currentUser = userService.currentUser.value;
        if (currentUser != null) {
          final existingSettings =
              Map<String, dynamic>.from(currentUser.settings);
          final newSettings = updatedData['settings'] as Map<String, dynamic>;
          existingSettings.addAll(newSettings);
          updatedData['settings'] = existingSettings;
        }
      }

      // The only job of this function is to write to Firestore.
      // The real-time listener (`listenToUserData`) will automatically
      // pick up the change and update the state in UserService.
      await firestore.collection('users').doc(userId).update(updatedData);
    } catch (e) {
      debugPrint("Error updating user data: $e");
      rethrow; // Rethrow to handle in UI
    }
  }

  Future<void> signOut() async {
    try {
      final today = DateTime.now().toIso8601String();
      final yesterday =
          DateTime.now().subtract(Duration(days: 1)).toIso8601String();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('shopping_day', '');
      await prefs.setString('top_ingredient_1', '');
      await prefs.setString('top_ingredient_2', '');
      await prefs.setInt('count_1', 0);
      await prefs.setInt('count_2', 0);
      await prefs.setBool('ingredient_battle_new_week', true);
      await prefs.setBool('routine_notification_shown_$today', true);
      await prefs.setBool('routine_badge_$yesterday', false);
      // _userDataSubscription is cancelled by the _handleAuthState listener
      await FirebaseAuth.instance.signOut();
    } catch (e) {
      debugPrint("Error signing out: $e");
    }
  }

  // Reset Password
  Future<void> resetPassword(String email) async {
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      Get.snackbar(
        'Password Reset',
        'Password reset link has been sent to your email',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      Get.snackbar(
        'Please try again.',
        'Error Resetting Password: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
      );
    }
  }

  Future<void> updateIsPremiumStatus(
      BuildContext context, String userId, bool isPremium, String plan) async {
    try {
      if (userId.isEmpty) {
        throw Exception("User ID is invalid or empty.");
      }

      // The real-time listener will handle the update automatically.
      await firestore.collection('users').doc(userId).update({
        'isPremium': isPremium,
        'premiumPlan': plan,
      });

      // Notify user of success
      if (isPremium) {
        showTastySnackbar(
          'Success',
          'Premium status updated successfully!',
          context,
        );
      } else {
        showTastySnackbar(
          'Sorry to see you go',
          'You will no longer have access to $appNameBuddy',
          context,
        );
      }
    } catch (e) {
      debugPrint("Error updating premium status: $e");
      showTastySnackbar(
        'Please try again.',
        'Failed to update premium status: $e',
        context,
        backgroundColor: Colors.red,
      );
    }
  }
}
