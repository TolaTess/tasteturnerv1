import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants.dart';
import '../data_models/user_data_model.dart';
import '../helper/utils.dart';
import 'chat_controller.dart';

class FriendController extends GetxController {
  static FriendController instance = Get.find();
  final RxSet<String> followingList = <String>{}.obs;

  var friendsMap = <String, UserModel>{}.obs;
  var userProfileData = Rxn<UserModel>();

  final RxSet<String> followingUsers = <String>{}.obs;

  bool isFollowing(String profileId) {
    return followingUsers.contains(profileId);
  }

  void toggleFollowStatus(String profileId) {
    if (followingUsers.contains(profileId)) {
      followingUsers.remove(profileId);
    } else {
      followingUsers.add(profileId);
    }
  }

  Future<UserModel?> getFriendData(String friendId) async {
    try {
      final doc = await firestore.collection('users').doc(friendId).get();

      if (doc.exists) {
        final data = doc.data();
        return UserModel.fromMap({
          'userId': friendId,
          ...?data,
        });
      }
    } catch (e) {
      print('Failed to load friend data: $e');
    }
    return null;
  }

  Future<void> getAllFriendData(String userId) async {
    try {
      final docSnapshot =
          await firestore.collection('friends').doc(userId).get();
      if (docSnapshot.exists) {
        final data = docSnapshot.data();
        final following = data?['following'] as List<dynamic>? ?? [];

        Map<String, UserModel> tempMap = {};

        for (var friendId in following) {
          final friendDoc =
              await firestore.collection('users').doc(friendId).get();

          if (friendDoc.exists) {
            final friendData = friendDoc.data() as Map<String, dynamic>;
            tempMap[friendId] = UserModel.fromMap(friendData);
          }
        }

        friendsMap.value = tempMap;
      } else {
        friendsMap.clear();
      }
    } catch (e) {
      print("Error fetching friends: $e");
      friendsMap.clear(); // Clear the map in case of an error
    }
  }

  /// Fetch the list of friends the user is following
  Future<void> fetchFollowing(String userId) async {
    try {
      // Fetch user document
      final userDoc = await firestore.collection('friends').doc(userId).get();

      if (userDoc.exists) {
        final data = userDoc.data()!;

        // Get following array
        final following = data['following'] as List<dynamic>? ?? [];
        followingList.assignAll(following.map((id) => id.toString()).toSet());
      }
    } catch (e) {
      print('Error fetching following list: $e');

      // Clear the sets if there's an error
      followingList.clear();
    }
  }

  /// Follow a friend
  Future<void> followFriend(String currentUserId, String friendUserId,
      String friendName, BuildContext context) async {
    try {
      final followingDoc =
          await firestore.collection('friends').doc(currentUserId).get();

      if (followingDoc.exists) {
        final data = followingDoc.data();
        final following = data?['following'] as List<dynamic>? ?? [];

        if (following.contains(friendUserId)) {
          showTastySnackbar(
            'Already Following',
            'You are already following this user.',
            context,
          );
          return;
        }
      }

      sendFriendRequest(currentUserId, friendUserId, friendName, context);
    } catch (e) {
      showTastySnackbar(
        'Please try again.',
        'Failed to follow user: $e',
        context,
      );
    }
  }

  Future<void> getUserData(String userId) async {
    try {
      final doc = await firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        final user = UserModel.fromMap(doc.data()!);
        userProfileData.value = user;

        // Save fetched data to SharedPreferences
      } else {
        print("User not found in Firestore.");
      }
    } catch (e) {
      print("Error fetching user data: $e");
    }
  }

  Future<void> updateUserData(String userId) async {
    try {
      // Fetch user document
      final userDoc = await firestore.collection('users').doc(userId).get();

      if (userDoc.exists) {
        final userData = userDoc.data();
        if (userData != null) {
          // Create user model
          final user = UserModel.fromMap(userData);

          // Fetch friends document
          final friendsDoc =
              await firestore.collection('friends').doc(userId).get();

          if (friendsDoc.exists) {
            final friendsData = friendsDoc.data();
            if (friendsData != null) {
              // Get following and follower lists
              final following =
                  friendsData['following'] as List<dynamic>? ?? [];
              // Update UserModel with friends data
              user.following = following.map((id) => id.toString()).toList();

              // Update local lists
              followingList.assignAll(following.map((id) => id.toString()));
            }
          }

          // Update state
          userProfileData.value = user;
        }
      }
    } catch (e) {
      print("Error updating user data: $e");
    }
  }

  /// Unfollow a friend
  Future<void> unfollowFriend(
      String currentUserId, String friendUserId, BuildContext context) async {
    try {
      // Update 'friends' collection for unfollowing
      await firestore.collection('friends').doc(currentUserId).set({
        'following': FieldValue.arrayRemove([friendUserId])
      }, SetOptions(merge: true));

      // Update local list
      followingList.remove(friendUserId);

      showTastySnackbar(
        'Success',
        'You have unfollowed this user.',
        context,
      );
    } catch (e) {
      showTastySnackbar(
        'Please try again.',
        'Failed to unfollow user: $e',
        context,
      );
    }
  }

  Future<void> sendFriendRequest(String currentUserId, String friendUserId,
      String friendName, BuildContext context) async {
    try {
      // Use ChatController to send a friend request message
      await ChatController.instance.sendFriendRequestMessage(
        senderId: currentUserId,
        recipientId: friendUserId,
        friendName: friendName,
        date: DateTime.now().toIso8601String(),
      );

      showTastySnackbar(
        'Request Sent',
        'Friend request sent. Awaiting acceptance.',
        context,
      );
    } catch (e) {
      showTastySnackbar(
        'Please try again.',
        'Failed to send friend request: $e',
        context,
      );
    }
  }
}
