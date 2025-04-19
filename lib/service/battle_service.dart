import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import '../constants.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

class BattleService extends GetxController {
  static final BattleService instance = Get.put(BattleService());

  // Collection reference
  CollectionReference get battlesRef => firestore.collection('battles');

  // Create a new battle
  Future<String> createBattle({
    required String category,
    required List<String> ingredients,
  }) async {
    try {
      // Create battle document with auto-generated ID
      final battleRef = battlesRef.doc();

      // Get the next week's date for battle end
      final now = DateTime.now();
      final startDate = now.toString().substring(0, 10); // YYYY-MM-DD format
      final endDate =
          now.add(const Duration(days: 7)).toString().substring(0, 10);

      await battleRef.set({
        'category': category,
        'dates': {
          startDate: {
            'status': 'active',
            'created_at': FieldValue.serverTimestamp(),
            'ended_at': endDate,
            'ingredients': ingredients,
            'voted': [],
            'participants': {}
          }
        }
      });

      return battleRef.id;
    } catch (e) {
      print('Error creating battle: $e');
      throw Exception('Failed to create battle');
    }
  }

  // Join a battle
  Future<void> joinBattle({
    required String battleId,
    required String userId,
    required String userName,
    required String userImage,
  }) async {
    try {
      final battleDoc = await battlesRef.doc(battleId).get();
      if (!battleDoc.exists) throw Exception('Battle not found');

      final data = battleDoc.data() as Map<String, dynamic>;
      final dates = data['dates'] as Map<String, dynamic>;

      // Get current week's date key
      final currentDate = DateTime.now().toString().substring(0, 10);
      final currentBattle = dates[currentDate];

      if (currentBattle == null) throw Exception('No active battle found');

      // Update participants for current week
      await battlesRef.doc(battleId).update({
        'dates.$currentDate.participants.$userId': {
          'name': userName,
          'image': userImage,
          'votes': []
        }
      });

      // Update user's battles
      await firestore.collection('users').doc(userId).set({
        'battles': {
          'ongoing': FieldValue.arrayUnion([battleId])
        }
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error joining battle: $e');
      throw Exception('Failed to join battle');
    }
  }

  // Cast a vote in a battle
  Future<void> castVote({
    required String battleId,
    required String voterId,
    required String votedForUserId,
  }) async {
    try {
      final battleDoc = await battlesRef.doc(battleId).get();
      if (!battleDoc.exists) throw Exception('Battle not found');

      final data = battleDoc.data() as Map<String, dynamic>;
      final dates = data['dates'] as Map<String, dynamic>;

      // Get current week's date key
      final currentDate = DateTime.now().toString().substring(0, 10);
      final currentBattle = dates[currentDate];

      if (currentBattle == null) throw Exception('No active battle found');

      // Update voted array and participant's votes
      await battlesRef.doc(battleId).update({
        'dates.$currentDate.voted': FieldValue.arrayUnion([voterId]),
        'dates.$currentDate.participants.$votedForUserId.votes':
            FieldValue.arrayUnion([voterId])
      });

      // Update user's battle status
      await firestore.collection('users').doc(voterId).update({
        'battles.ongoing': FieldValue.arrayRemove([battleId]),
        'battles.voted': FieldValue.arrayUnion([battleId])
      });
    } catch (e) {
      print('Error casting vote: $e');
      throw Exception('Failed to cast vote');
    }
  }

  // Get active battles
  Future<List<Map<String, dynamic>>> getActiveBattles() async {
    try {
      final snapshot = await battlesRef.get();
      final List<Map<String, dynamic>> activeBattles = [];

      final currentDate = DateTime.now().toString().substring(0, 10);

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final dates = data['dates'] as Map<String, dynamic>;

        if (dates.containsKey(currentDate)) {
          final currentBattle = dates[currentDate];
          if (currentBattle['status'] == 'active') {
            activeBattles.add({
              'id': doc.id,
              'category': data['category'],
              'currentBattle': currentBattle,
            });
          }
        }
      }

      return activeBattles;
    } catch (e) {
      print('Error getting active battles: $e');
      return [];
    }
  }

  // Get battle by category
  Future<List<Map<String, dynamic>>> getBattlesByCategory(
      String category) async {
    try {
      final snapshot = await battlesRef
          .where('category', isEqualTo: category.toLowerCase())
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();
    } catch (e) {
      print('Error getting battles by category: $e');
      return [];
    }
  }

  // Check if user has voted
  Future<bool> hasUserVoted(String battleId, String userId) async {
    try {
      final battleDoc = await battlesRef.doc(battleId).get();
      if (!battleDoc.exists) return false;

      final data = battleDoc.data() as Map<String, dynamic>;
      final dates = data['dates'] as Map<String, dynamic>;

      final currentDate = DateTime.now().toString().substring(0, 10);
      final currentBattle = dates[currentDate];

      if (currentBattle == null) return false;

      final voted = List<String>.from(currentBattle['voted'] ?? []);
      return voted.contains(userId);
    } catch (e) {
      print('Error checking if user voted: $e');
      return false;
    }
  }

  // Check if user has joined battle
  Future<bool> hasUserJoinedBattle(String battleId, String userId) async {
    try {
      final battleDoc = await battlesRef.doc(battleId).get();
      if (!battleDoc.exists) return false;

      final data = battleDoc.data() as Map<String, dynamic>;
      final dates = data['dates'] as Map<String, dynamic>;

      final currentDate = DateTime.now().toString().substring(0, 10);
      final currentBattle = dates[currentDate];

      if (currentBattle == null) return false;

      // Check if user is in participants map
      final participants =
          currentBattle['participants'] as Map<String, dynamic>?;
      return participants != null && participants.containsKey(userId);
    } catch (e) {
      print('Error checking if user joined battle: $e');
      return false;
    }
  }

  // Get user's ongoing battles
  Future<List<Map<String, dynamic>>> getUserOngoingBattles(
      String userId) async {
    try {
      final userDoc = await firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return [];

      final userData = userDoc.data() as Map<String, dynamic>;
      final ongoingBattles =
          List<String>.from(userData['battles']?['ongoing'] ?? []);

      final List<Map<String, dynamic>> battleDetails = [];
      for (String battleId in ongoingBattles) {
        final battleDoc = await battlesRef.doc(battleId).get();
        if (battleDoc.exists) {
          final data = battleDoc.data() as Map<String, dynamic>;
          battleDetails.add({
            'id': battleId,
            ...data,
          });
        }
      }

      return battleDetails;
    } catch (e) {
      print('Error getting user ongoing battles: $e');
      return [];
    }
  }

  // Remove user from battle
  Future<void> removeUserFromBattle(String userId, String battleId) async {
    try {
      final battleDoc = await battlesRef.doc(battleId).get();
      if (!battleDoc.exists) throw Exception('Battle not found');

      final data = battleDoc.data() as Map<String, dynamic>;
      final dates = data['dates'] as Map<String, dynamic>;

      // Get current week's date key
      final currentDate = DateTime.now().toString().substring(0, 10);
      final currentBattle = dates[currentDate];

      if (currentBattle == null) throw Exception('No active battle found');

      // Remove user from participants
      await battlesRef.doc(battleId).update(
          {'dates.$currentDate.participants.$userId': FieldValue.delete()});

      // Remove battle from user's ongoing battles
      await firestore.collection('users').doc(userId).update({
        'battles.ongoing': FieldValue.arrayRemove([battleId])
      });
    } catch (e) {
      print('Error removing user from battle: $e');
      throw Exception('Failed to remove user from battle');
    }
  }

  // Upload battle images and update battle status
  Future<void> uploadBattleImages({
    required String battleId,
    required String userId,
    required List<String> imageUrls,
  }) async {
    try {
      final battleDoc = await battlesRef.doc(battleId).get();
      if (!battleDoc.exists) throw Exception('Battle not found');


      // Step 1: Extract data and dates
      final data = battleDoc.data() as Map<String, dynamic>;
      final dates = data['dates'] as Map<String, dynamic>;

      // Step 2: Check if dates is empty
      if (dates.isEmpty) {
        print('No date data available.');
        return;
      }
      // Step 3: Get the first date key
      final firstDateKey =
          dates.keys.first; // Gets the first key (e.g., "2025-04-14")

      final dateData = dates[firstDateKey] as Map<String, dynamic>;

      // Step 4: Access ended_at
      final endedAtRaw = dateData['ended_at'];

      // Step 5: Convert ended_at to DateTime
      DateTime endedAt;
      if (endedAtRaw is Timestamp) {
        endedAt = endedAtRaw.toDate();
      } else if (endedAtRaw is String) {
        endedAt = DateTime.parse(endedAtRaw);
      } else {
        throw Exception('Invalid ended_at format');
      }
      if (endedAt.isBefore(DateTime.now())) {
        throw Exception('Battle has ended');
      }

      // Update participant's media in the battle
      await battlesRef.doc(battleId).update(
          {'dates.$firstDateKey.participants.$userId.mediaPaths': imageUrls});

      // Move battle from ongoing to voted for the user
      await firestore.collection('users').doc(userId).update({
        'battles.ongoing': FieldValue.arrayRemove([battleId]),
        'battles.voted': FieldValue.arrayUnion([battleId])
      });

      // Create or update battle post
      await firestore.collection('battle_post').doc(battleId).set({
        'mediaPaths': imageUrls,
        'category': data['category'],
        'name': dateData['participants'][userId]['name'] ?? 'Unknown',
        'favorites': [],
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error uploading battle images: $e');
      throw Exception('Failed to upload battle images');
    }
  }

  // Upload image to Firebase Storage
  Future<String> uploadBattleImage({
    required String battleId,
    required String userId,
    required File imageFile,
  }) async {
    try {
      final String filePath =
          'battles/$battleId/${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = FirebaseStorage.instance.ref(filePath);
      final uploadTask = await ref.putFile(imageFile);
      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      print('Error uploading image to storage: $e');
      throw Exception('Failed to upload image to storage');
    }
  }

  // Calculate vote percentage for a user in a category
  Future<double> calculateUserVotePercentage(
      String userId, String category) async {
    try {
      final snapshot = await battlesRef
          .where('category', isEqualTo: category.toLowerCase())
          .get();

      int totalVotes = 0;
      int userVotes = 0;
      final currentDate = DateTime.now().toString().substring(0, 10);

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final dates = data['dates'] as Map<String, dynamic>;

        if (dates.containsKey(currentDate)) {
          final currentBattle = dates[currentDate];
          final participants =
              currentBattle['participants'] as Map<String, dynamic>;

          // Calculate total votes in this battle
          for (var participant in participants.values) {
            final votes = List<String>.from(participant['votes'] ?? []);
            totalVotes += votes.length;
          }

          // Get this user's votes in this battle
          if (participants.containsKey(userId)) {
            final userParticipant = participants[userId];
            final votes = List<String>.from(userParticipant['votes'] ?? []);
            userVotes += votes.length;
          }
        }
      }

      return totalVotes == 0
          ? 0.0
          : ((userVotes / totalVotes) * 100).clamp(0.0, 100.0);
    } catch (e) {
      print('Error calculating vote percentage: $e');
      return 0.0;
    }
  }
}
