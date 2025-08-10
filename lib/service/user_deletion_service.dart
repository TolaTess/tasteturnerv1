import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants.dart';
import '../helper/utils.dart';

class UserDeletionService extends GetxController {
  static final UserDeletionService _instance = UserDeletionService._internal();
  factory UserDeletionService() => _instance;
  UserDeletionService._internal();

  /// Delete all user data from Firebase and local storage
  /// Returns true if successful, false otherwise
  Future<bool> deleteUserData({
    required String userId,
    required BuildContext context,
    bool deleteAccount = false,
  }) async {
    if (userId.isEmpty) {
      print('Error: User ID is empty');
      return false;
    }

    print('Deleting user data for user ID: $userId');

    // Store context for later use
    final navigatorContext = context;

    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Delete data from all collections
      await _deleteUserPosts(userId);
      await _deleteUserMeals(userId);
      await _deleteUserChats(userId);
      await _deleteUserFriends(userId);
      await _deleteUserPrograms(userId);
      await _deleteUserCalendars(userId);
      await _deleteUserPoints(userId);
      await _deleteUserBadges(userId);
      await _deleteUserFromOtherUsers(userId);

      // Clear local storage
      await _clearLocalStorage();

      // Close loading dialog
      Navigator.of(navigatorContext).pop();

      // If deleting account, also delete Firebase Auth account
      if (deleteAccount) {
        final authResult = await _deleteFirebaseAuthAccount(context);
        if (!authResult) {
          // If auth deletion failed, show message but still return true
          // since the data deletion was successful
          return true;
        }
      }

      // Delete user document
      if (deleteAccount) {
        // Clear user service data if deleting account
        userService.clearUser();
        await firestore.collection('users').doc(userId).delete();
      } else {
        // For data-only deletion, don't clear user service
        // The auth controller's real-time listener will automatically
        // reload the user data since the document still exists
        print(
            'Data-only deletion: User service will be updated by auth listener');
      }

      return true;
    } catch (e) {
      // Close loading dialog
      Navigator.of(navigatorContext).pop();
      print('Error deleting user data: $e');
      return false;
    }
  }

  /// Delete all posts created by the user
  Future<void> _deleteUserPosts(String userId) async {
    try {
      // Get all posts by the user
      final postsSnapshot = await firestore
          .collection('posts')
          .where('userId', isEqualTo: userId)
          .get();

      for (var doc in postsSnapshot.docs) {
        final postData = doc.data();
        final mediaPaths = List<String>.from(postData['mediaPaths'] ?? []);

        // Delete media files from storage
        await _deleteImagesFromStorage(mediaPaths);

        // Delete post document
        await doc.reference.delete();
      }

      // Remove user from posts where they are mentioned or involved
      final mentionedPostsSnapshot = await firestore
          .collection('posts')
          .where('mentionedUsers', arrayContains: userId)
          .get();

      for (var doc in mentionedPostsSnapshot.docs) {
        await doc.reference.update({
          'mentionedUsers': FieldValue.arrayRemove([userId])
        });
      }
    } catch (e) {
      print('Error deleting user posts: $e');
    }
  }

  /// Delete all meals created by the user
  Future<void> _deleteUserMeals(String userId) async {
    try {
      // Delete user's meals from the meals collection
      final mealsSnapshot = await firestore
          .collection('meals')
          .where('userId', isEqualTo: userId)
          .get();

      for (var doc in mealsSnapshot.docs) {
        final mealData = doc.data();
        final mediaPaths = List<String>.from(mealData['mediaPaths'] ?? []);

        // Delete media files from storage
        await _deleteImagesFromStorage(mediaPaths);

        // Delete meal document
        await doc.reference.delete();
      }

      // Delete user's userMeals subcollection
      await _deleteUserMealsSubcollection(userId);

      print('Successfully deleted all meals for user: $userId');
    } catch (e) {
      print('Error deleting user meals: $e');
    }
  }

  /// Delete all chat messages and chat documents
  Future<void> _deleteUserChats(String userId) async {
    try {
      // Get all chats where user is a participant
      final chatsSnapshot = await firestore
          .collection('chats')
          .where('participants', arrayContains: userId)
          .get();

      for (var chatDoc in chatsSnapshot.docs) {
        // Delete all messages in the chat
        final messagesSnapshot =
            await chatDoc.reference.collection('messages').get();

        for (var messageDoc in messagesSnapshot.docs) {
          await messageDoc.reference.delete();
        }

        // Delete the chat document
        await chatDoc.reference.delete();
      }
    } catch (e) {
      print('Error deleting user chats: $e');
    }
  }

  /// Delete user's friend relationships
  Future<void> _deleteUserFriends(String userId) async {
    try {
      // Delete user's friends document
      await firestore.collection('friends').doc(userId).delete();
      print('Deleted user\'s friends document');

      // Remove user from other users' following lists
      final friendsSnapshot = await firestore
          .collection('friends')
          .where('following', arrayContains: userId)
          .get();

      for (var doc in friendsSnapshot.docs) {
        print('Removing user from other users\' following lists' + doc.id);
        await doc.reference.update({
          'following': FieldValue.arrayRemove([userId])
        });
      }
    } catch (e) {
      print('Error deleting user friends: $e');
    }
  }

  /// Remove user from all programs
  Future<void> _deleteUserPrograms(String userId) async {
    try {
      final userProgramsSnapshot =
          await firestore.collection('userProgram').get();

      for (var doc in userProgramsSnapshot.docs) {
        print('Removing user from programs' + doc.id);
        final data = doc.data();
        final userIds = List<String>.from(data['userIds'] ?? []);

        if (userIds.contains(userId)) {
          userIds.remove(userId);

          if (userIds.isEmpty) {
            // If no users left, delete the program document
            await doc.reference.delete();
          } else {
            // Update with remaining users
            await doc.reference.update({'userIds': userIds});
          }
        }
      }
    } catch (e) {
      print('Error deleting user programs: $e');
    }
  }

  /// Delete user's shared calendars
  Future<void> _deleteUserCalendars(String userId) async {
    try {
      // Delete user's meal plan subcollection
      await _deleteMealPlansSubcollection(userId);

      // Delete any shared calendars created by this user
      final calendarsSnapshot = await firestore
          .collection('shared_calendars')
          .where('userId', isEqualTo: userId)
          .get();

      for (var doc in calendarsSnapshot.docs) {
        await doc.reference.delete();
      }
    } catch (e) {
      print('Error deleting user calendars: $e');
    }
  }

  /// Delete user's userMeals subcollection
  Future<void> _deleteUserMealsSubcollection(String userId) async {
    try {
      // Get all documents in the userMeals subcollection
      final userMealsDocs = await firestore
          .collection('userMeals')
          .doc(userId)
          .collection('meals')
          .get();

      // Delete all documents in the subcollection
      for (var doc in userMealsDocs.docs) {
        await doc.reference.delete();
      }

      // Delete the user's userMeals document (if it exists)
      try {
        await firestore.collection('userMeals').doc(userId).delete();
      } catch (e) {
        print('User userMeals document might not exist: $e');
      }
    } catch (e) {
      print('Error deleting user userMeals: $e');
    }
  }

  /// Delete user's meal plans subcollection
  Future<void> _deleteMealPlansSubcollection(String userId) async {
    try {
      // Get all documents in the date subcollection
      final dateDocs = await firestore
          .collection('mealPlans')
          .doc(userId)
          .collection('date')
          .get();

      // Delete all documents in the subcollection
      for (var doc in dateDocs.docs) {
        await doc.reference.delete();
      }

      // Delete the user's meal plan document (if it exists)
      try {
        await firestore.collection('mealPlans').doc(userId).delete();
      } catch (e) {
        print('User meal plan document might not exist: $e');
      }
    } catch (e) {
      print('Error deleting user meal plans: $e');
    }
  }

  /// Delete user's points data
  Future<void> _deleteUserPoints(String userId) async {
    try {
      await firestore.collection('points').doc(userId).delete();
    } catch (e) {
      print('Error deleting user points: $e');
    }
  }

  /// Delete user's badges
  Future<void> _deleteUserBadges(String userId) async {
    try {
      final badgesSnapshot = await firestore
          .collection('badges')
          .where('userId', isEqualTo: userId)
          .get();

      for (var doc in badgesSnapshot.docs) {
        await doc.reference.delete();
      }
    } catch (e) {
      print('Error deleting user badges: $e');
    }
  }

  /// Remove user references from other users' data
  Future<void> _deleteUserFromOtherUsers(String userId) async {
    try {
      // Remove from favorites lists
      final usersWithFavorites = await firestore
          .collection('users')
          .where('favorites', arrayContains: userId)
          .get();

      for (var doc in usersWithFavorites.docs) {
        await doc.reference.update({
          'favorites': FieldValue.arrayRemove([userId])
        });
      }

      // Remove from posts arrays
      final usersWithPosts = await firestore
          .collection('users')
          .where('posts', arrayContains: userId)
          .get();

      for (var doc in usersWithPosts.docs) {
        await doc.reference.update({
          'posts': FieldValue.arrayRemove([userId])
        });
      }
    } catch (e) {
      print('Error removing user from other users: $e');
    }
  }

  /// Delete images from Firebase Storage
  Future<void> _deleteImagesFromStorage(List<String> imageUrls) async {
    try {
      for (String url in imageUrls) {
        if (url.isNotEmpty && url.contains('firebasestorage.googleapis.com')) {
          // Extract the file path from the URL
          final uri = Uri.parse(url);
          final pathSegments = uri.pathSegments;

          if (pathSegments.length >= 4) {
            // Construct the storage reference path
            final storagePath = '${pathSegments[3]}/${pathSegments[4]}';
            final storageRef = firebaseStorage.ref().child(storagePath);

            try {
              await storageRef.delete();
            } catch (e) {
              print('Error deleting storage file $storagePath: $e');
            }
          }
        }
      }
    } catch (e) {
      print('Error deleting images from storage: $e');
    }
  }

  /// Clear all local storage data
  Future<void> _clearLocalStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    } catch (e) {
      print('Error clearing local storage: $e');
    }
  }

  /// Delete Firebase Auth account with proper error handling
  Future<bool> _deleteFirebaseAuthAccount(BuildContext context) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('No current user found');
        return true; // No user to delete
      }

      await user.delete();
      print('Firebase Auth account deleted successfully');
      return true;
    } catch (e) {
      print('Error deleting Firebase Auth account: $e');

      String errorMessage = 'Failed to delete account. Please try again.';

      if (e.toString().contains('requires-recent-login')) {
        errorMessage =
            'Account deletion requires recent authentication. Please log out and log back in, then try deleting your account again.';
      } else if (e.toString().contains('network')) {
        errorMessage =
            'Network error. Please check your connection and try again.';
      } else if (e.toString().contains('permission')) {
        errorMessage = 'Permission denied. Please contact support.';
      }

      // Show error message to user
      showTastySnackbar(
        'Authentication Required',
        errorMessage,
        context,
        backgroundColor: Colors.orange,
      );

      return false;
    }
  }

  /// Show confirmation dialog for data deletion
  Future<bool> showDeletionConfirmation(
    BuildContext context,
    bool deleteAccount,
    bool isDarkMode,
  ) async {
    final title = deleteAccount ? 'Delete Account' : 'Delete Data';
    final message = deleteAccount
        ? 'Are you sure you want to delete your account? This will permanently delete your account and all associated data. This action cannot be undone.'
        : 'Are you sure you want to delete all your data? This will remove all your posts, meals, chats, and other data. This action cannot be undone.';

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? kDarkGrey : kWhite,
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: Text(deleteAccount ? 'Delete Account' : 'Delete Data'),
          ),
        ],
      ),
    );

    return result ?? false;
  }
}
