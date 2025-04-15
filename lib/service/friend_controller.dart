import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants.dart';
import '../data_models/user_data_model.dart';
import '../helper/utils.dart';

class FriendController extends GetxController {
  static FriendController instance = Get.find();
  final RxSet<String> followingList = <String>{}.obs;
  final RxSet<String> followerList = <String>{}.obs;

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
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(friendId)
          .get();

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
      final querySnapshot = await firestore
          .collection('users')
          .doc(userId)
          .collection('following')
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        Map<String, UserModel> tempMap = {};

        for (var doc in querySnapshot.docs) {
          final friendId = doc.id;
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
      // Fetch `following` subcollection
      final followingSnapshot = await firestore
          .collection('users')
          .doc(userId)
          .collection('following')
          .get();

      // Assign directly to RxSet
      followingList
          .assignAll(followingSnapshot.docs.map((doc) => doc.id).toSet());

      // Fetch `follower` subcollection
      final followerSnapshot = await firestore
          .collection('users')
          .doc(userId)
          .collection('follower')
          .get();

      // Assign directly to RxSet
      followerList
          .assignAll(followerSnapshot.docs.map((doc) => doc.id).toSet());
    } catch (e) {
      print('Error fetching following list: $e');

      // Clear the sets if there's an error
      followingList.clear();
      followerList.clear();
    }
  }

  /// Follow a friend
  Future<void> followFriend(String currentUserId, String friendUserId, BuildContext context) async {
    try {
      final followingDoc = await firestore
          .collection('users')
          .doc(currentUserId)
          .collection('following')
          .doc(friendUserId)
          .get();

      if (followingDoc.exists) {
        showTastySnackbar(
          'Already Following',
          'You are already following this user.',
          context,
        );
        return;
      }

      await firestore
          .collection('users')
          .doc(currentUserId)
          .collection('following')
          .doc(friendUserId)
          .set({'followedAt': FieldValue.serverTimestamp()});

      await firestore
          .collection('users')
          .doc(friendUserId)
          .collection('follower')
          .doc(currentUserId)
          .set({'followedAt': FieldValue.serverTimestamp()});

      // Update local list
      followingList.add(friendUserId);

      showTastySnackbar(
        'Success',
        'You are now following this user.',
        context,
      );
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

          // Fetch subcollection data (followers)
          final followersSnapshot = await firestore
              .collection('users')
              .doc(userId)
              .collection('follower')
              .get();

          final followers =
              followersSnapshot.docs.map((doc) => doc.id).toList();

          // Fetch subcollection data (following)
          final followingSnapshot = await firestore
              .collection('users')
              .doc(userId)
              .collection('following')
              .get();

          final following =
              followingSnapshot.docs.map((doc) => doc.id).toList();

          // Update UserModel with subcollection data
          user.followers = followers;
          user.following = following;

          // Update state (userProfileData is presumably an Rx<UserModel?>)
          userProfileData.value = user;
        }
      }
    } catch (e) {
      print("Error updating user with subcollection data: $e");
    }
  }

  /// Unfollow a friend
  Future<void> unfollowFriend(String currentUserId, String friendUserId, BuildContext context) async {
    try {
      await firestore
          .collection('users')
          .doc(currentUserId)
          .collection('following')
          .doc(friendUserId)
          .delete();

      await firestore
          .collection('users')
          .doc(friendUserId)
          .collection('follower')
          .doc(currentUserId)
          .delete();

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
}
