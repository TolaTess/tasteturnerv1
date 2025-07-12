import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import '../constants.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import '../helper/notifications_helper.dart';

import '../data_models/post_model.dart';

class BattleService extends GetxController {
  static final BattleService instance = Get.put(BattleService());

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Collection reference
  CollectionReference get battlesRef => _firestore.collection('battles');

  // Get current battle date data
  Map<String, dynamic>? _getCurrentBattleData(DocumentSnapshot battleDoc) {
    // Step 1: Extract data and dates
    final data = battleDoc.data() as Map<String, dynamic>;
    if (!data.containsKey('dates')) return null;

    final dates = data['dates'] as Map<String, dynamic>;

    // Step 2: Check if dates is empty
    if (dates.isEmpty) {
      print('No date data available.');
      return null;
    }
    // Step 3: Get the first date key
    final firstDateKey = dates.keys.first;
    if (!dates.containsKey(firstDateKey)) return null;

    return dates[firstDateKey] as Map<String, dynamic>;
  }

  // Note: joinBattle is now handled by MacroManager to match the backend structure

  // Cast a vote in a battle
  Future<void> castVote({
    required String battleId,
    required String voterId,
    required String votedForUserId,
  }) async {
    try {
      // Use nested structure: battles/general/dates/{battleId}
      final battleRef = _firestore.collection('battles').doc('general');
      final battleDoc = await battleRef.get();
      if (!battleDoc.exists) throw Exception('Battle document not found');

      final battleData = battleDoc.data() as Map<String, dynamic>;

      if (!battleData.containsKey('dates') ||
          battleData['dates'] is! Map<String, dynamic>) {
        throw Exception('No dates structure found');
      }

      final datesMap = battleData['dates'] as Map<String, dynamic>;
      if (!datesMap.containsKey(battleId)) {
        throw Exception('Battle not found: $battleId');
      }

      // Update voted array and participant's votes
      await battleRef.update({
        'dates.$battleId.voted': FieldValue.arrayUnion([voterId]),
        'dates.$battleId.participants.$votedForUserId.votes':
            FieldValue.arrayUnion([voterId])
      });

      // Check if userBattles document exists
      final userBattlesRef = _firestore.collection('userBattles').doc(voterId);
      final userBattleDoc = await userBattlesRef.get();

      if (!userBattleDoc.exists) {
        // Create the document with initial data
        await userBattlesRef.set({
          'dates': {
            battleId: {
              'voted': ['general'],
              'ongoing': []
            }
          }
        });
      } else {
        // Update existing document
        await userBattlesRef.update({
          'dates.$battleId.voted': FieldValue.arrayUnion(['general']),
          'dates.$battleId.ongoing': FieldValue.arrayRemove(['general'])
        });
      }
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
      final now = DateTime.now();

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        if (!data.containsKey('dates')) continue;

        final dates = data['dates'] as Map<String, dynamic>;
        if (dates.isEmpty) continue;

        // Get the first date entry
        final firstDateKey = dates.keys.first;
        final battleData = dates[firstDateKey] as Map<String, dynamic>;

        // Check if battle is active and not ended
        if (battleData['status'] != 'active') continue;

        // Parse and check end date
        final endedAtRaw = battleData['ended_at'];
        DateTime? endDate;

        if (endedAtRaw is Timestamp) {
          endDate = endedAtRaw.toDate();
        } else if (endedAtRaw is String) {
          endDate = DateTime.parse(endedAtRaw);
        }

        if (endDate == null || endDate.isBefore(now)) continue;

        // Battle is active and not ended
        final currentBattle = dates[firstDateKey] as Map<String, dynamic>;
        activeBattles.add({
          'id': doc.id,
          'category': data['category'], // Category at root level
          'currentBattle': currentBattle
        });
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

  Future<List<Map<String, dynamic>>> getBattleParticipants(
      String battleId) async {
    try {
      // In the new structure, battleId is the date key
      // We need to get participants from battles/general/dates/{battleId}
      final battleDoc =
          await _firestore.collection('battles').doc('general').get();
      if (!battleDoc.exists) {
        print('General battle document not found');
        return [];
      }

      final battleData = battleDoc.data() as Map<String, dynamic>;

      // Read from the nested dates structure: dates.{battleId}.participants
      if (!battleData.containsKey('dates') ||
          battleData['dates'] is! Map<String, dynamic>) {
        print('No dates structure found');
        return [];
      }

      final datesMap = battleData['dates'] as Map<String, dynamic>;
      if (!datesMap.containsKey(battleId)) {
        print('Battle not found: $battleId');
        return [];
      }

      final currentBattle = datesMap[battleId] as Map<String, dynamic>;
      final participants =
          currentBattle['participants'] as Map<String, dynamic>? ?? {};

      final List<Map<String, dynamic>> participantList = [];
      participants.forEach((userId, userData) {
        final data = userData as Map<String, dynamic>;
        participantList.add({
          'userid': userId,
          'name': data['name'] ?? '',
          'image': data['image'] ?? '',
          'votes': data['votes'] ?? [],
          'mediaPaths': data['mediaPaths'] ?? [],
        });
      });

      print(
          'Found ${participantList.length} participants for battle: $battleId');
      return participantList;
    } catch (e) {
      print('Error getting battle participants: $e');
      return [];
    }
  }

  // Check if user has voted
  Future<bool> hasUserVoted(String battleId, String userId) async {
    try {
      // Use nested structure: battles/general/dates/{battleId}
      final battleDoc =
          await _firestore.collection('battles').doc('general').get();
      if (!battleDoc.exists) return false;

      final battleData = battleDoc.data() as Map<String, dynamic>;

      if (!battleData.containsKey('dates') ||
          battleData['dates'] is! Map<String, dynamic>) {
        return false;
      }

      final datesMap = battleData['dates'] as Map<String, dynamic>;
      if (!datesMap.containsKey(battleId)) {
        return false;
      }

      final currentBattle = datesMap[battleId] as Map<String, dynamic>;
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
      // Use nested structure: battles/general/dates/{battleId}
      final battleDoc =
          await _firestore.collection('battles').doc('general').get();
      if (!battleDoc.exists) return false;

      final battleData = battleDoc.data() as Map<String, dynamic>;

      if (!battleData.containsKey('dates') ||
          battleData['dates'] is! Map<String, dynamic>) {
        return false;
      }

      final datesMap = battleData['dates'] as Map<String, dynamic>;
      if (!datesMap.containsKey(battleId)) {
        return false;
      }

      final currentBattle = datesMap[battleId] as Map<String, dynamic>;
      final participants =
          currentBattle['participants'] as Map<String, dynamic>? ?? {};
      return participants.containsKey(userId);
    } catch (e) {
      print('Error checking if user joined battle: $e');
      return false;
    }
  }

  // Get user's ongoing battles
  Future<List<Map<String, dynamic>>> getUserOngoingBattles(
      String userId) async {
    try {
      final userDoc =
          await _firestore.collection('userBattles').doc(userId).get();
      if (!userDoc.exists) return [];

      final userData = userDoc.data() as Map<String, dynamic>;
      if (!userData.containsKey('dates')) return [];

      final dates = userData['dates'] as Map<String, dynamic>;
      final List<Map<String, dynamic>> battleDetails = [];

      // Iterate through each date entry
      for (var dateKey in dates.keys) {
        final dateData = dates[dateKey] as Map<String, dynamic>;
        if (!dateData.containsKey('ongoing')) continue;

        final ongoingBattles = List<String>.from(dateData['ongoing'] ?? []);

        // Get details for each ongoing battle
        for (String battleId in ongoingBattles) {
          final battleDoc = await battlesRef.doc('general').get();
          if (!battleDoc.exists) continue;

          final data = battleDoc.data() as Map<String, dynamic>;

          if (!data.containsKey('dates')) continue;

          final battleDates = data['dates'] as Map<String, dynamic>;

          if (!battleDates.containsKey(dateKey)) continue;

          final battleData = battleDates[dateKey];
          battleDetails.add({
            'id': battleId,
            'category': 'general',
            'currentBattle': battleData,
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
      // Use nested structure: battles/general/dates/{battleId}
      final battleRef = _firestore.collection('battles').doc('general');
      final battleDoc = await battleRef.get();
      if (!battleDoc.exists) throw Exception('Battle document not found');

      final battleData = battleDoc.data() as Map<String, dynamic>;

      if (!battleData.containsKey('dates') ||
          battleData['dates'] is! Map<String, dynamic>) {
        throw Exception('No dates structure found');
      }

      final datesMap = battleData['dates'] as Map<String, dynamic>;
      if (!datesMap.containsKey(battleId)) {
        throw Exception('Battle not found: $battleId');
      }

      // Remove user from participants
      await battleRef.update(
          {'dates.$battleId.participants.$userId': FieldValue.delete()});

      // Remove battle from user's ongoing battles
      await _firestore.collection('userBattles').doc(userId).update({
        'dates.$battleId.ongoing': FieldValue.arrayRemove(['general'])
      });
    } catch (e) {
      print('Error removing user from battle: $e');
      throw Exception('Failed to remove user from battle');
    }
  }

  // Upload battle images and update battle status
  Future<void> uploadBattleImages({
    required Post post,
  }) async {
    try {
      // Access the general battle document, not the battle date as document ID
      final battleDoc = await battlesRef.doc('general').get();
      if (!battleDoc.exists) throw Exception('Battle not found');
      final data = battleDoc.data() as Map<String, dynamic>;

      if (!data.containsKey('dates') ||
          data['dates'] is! Map<String, dynamic>) {
        throw Exception('No dates structure found');
      }

      final datesMap = data['dates'] as Map<String, dynamic>;
      // post.id should be the battle date (e.g., "2025-07-11")
      final battleId = post.id;

      if (!datesMap.containsKey(battleId)) {
        throw Exception('Battle not found: $battleId');
      }

      // Update participant's media in the battle using the correct structure
      await battlesRef.doc('general').update({
        'dates.$battleId.participants.${post.userId}.mediaPaths':
            post.mediaPaths
      });

      // Move battle from ongoing to uploaded for the user
      await _firestore.collection('userBattles').doc(post.userId).update({
        'dates.$battleId.ongoing': FieldValue.arrayRemove([battleId]),
        'dates.$battleId.uploaded': FieldValue.arrayUnion([battleId])
      });

      // Create or update battle post
      await postController.uploadPost(post, post.userId, post.mediaPaths);
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
      final ref = _storage.ref(filePath);
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

      int totalVotesInCategory = 0;
      int userVotesReceived = 0;

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        if (!data.containsKey('dates')) continue;

        final dates = data['dates'] as Map<String, dynamic>;
        if (dates.isEmpty) continue;

        // Get the first date entry (current battle)
        final firstDateKey = dates.keys.first;
        final battleData = dates[firstDateKey] as Map<String, dynamic>;
        final participants =
            battleData['participants'] as Map<String, dynamic>?;
        if (participants == null) continue;

        // Calculate total votes in this battle
        int battleTotalVotes = 0;
        for (var participant in participants.values) {
          if (participant is! Map<String, dynamic>) continue;
          final votes = List<String>.from(participant['votes'] ?? []);
          battleTotalVotes += votes.length;
        }
        totalVotesInCategory += battleTotalVotes;

        // Get votes received by this user
        if (participants.containsKey(userId)) {
          final userParticipant = participants[userId] as Map<String, dynamic>;
          final votes = List<String>.from(userParticipant['votes'] ?? []);
          userVotesReceived += votes.length;
        }
      }

      // Calculate percentage
      if (totalVotesInCategory == 0) return 0.0;
      return (userVotesReceived / totalVotesInCategory * 100).clamp(0.0, 100.0);
    } catch (e) {
      print('Error calculating vote percentage: $e');
      return 0.0;
    }
  }

  Future<void> removeBattleImages({
    required String battleId,
    required String userId,
  }) async {
    try {
      final battleDoc = await battlesRef.doc(battleId).get();
      if (!battleDoc.exists) throw Exception('Battle not found');
      final data = battleDoc.data() as Map<String, dynamic>;
      final currentBattle = _getCurrentBattleData(battleDoc);
      if (currentBattle == null) throw Exception('No active battle found');
      final firstDateKey = data['dates'].keys.first;

      // Get participant's mediaPaths
      final participants =
          currentBattle['participants'] as Map<String, dynamic>?;
      final participant = participants != null
          ? participants[userId] as Map<String, dynamic>?
          : null;
      final mediaPaths = participant != null
          ? List<String>.from(participant['mediaPaths'] ?? [])
          : <String>[];

      // Use utility to delete images from storage
      await deleteImagesFromStorage(mediaPaths, folder: 'battles/$battleId');

      // Remove mediaPaths field for this participant in Firestore
      await battlesRef.doc(battleId).update({
        'dates.$firstDateKey.participants.$userId.mediaPaths':
            FieldValue.delete(),
      });

      // Move battle from uploaded to ongoing for the user
      await _firestore.collection('userBattles').doc(userId).update({
        'dates.$firstDateKey.uploaded': FieldValue.arrayRemove([battleId]),
        'dates.$firstDateKey.ongoing': FieldValue.arrayUnion([battleId]),
      });
    } catch (e) {
      print('Error removing battle images: $e');
      rethrow;
    }
  }

  Future<void> updateUserPoints(String userId, int points) async {
    final userPointsRef = _firestore.collection('points').doc(userId);

    try {
      await _firestore.runTransaction((transaction) async {
        final userPointsDoc = await transaction.get(userPointsRef);

        if (userPointsDoc.exists) {
          final currentPoints = userPointsDoc.data()?['points'] as int? ?? 0;
          transaction.update(userPointsRef, {
            'points': currentPoints + points,
          });
        } else {
          transaction.set(userPointsRef, {
            'points': points,
          });
        }
      });
    } catch (e) {
      print('Error updating points for user $userId: $e');
    }
  }

  // Get previous battle participants
  Future<List<Map<String, dynamic>>> getPreviousBattleParticipants(
      String battleId) async {
    try {
      // Get previous battle date from general data
      final prevBattleDate = firebaseService.generalData['prevBattle'];
      if (prevBattleDate == null) {
        print('No previous battle found in general data');
        return [];
      }

      // Get participants from battles/general/dates/{prevBattleDate}
      final battleDoc =
          await _firestore.collection('battles').doc('general').get();
      if (!battleDoc.exists) {
        print('General battle document not found');
        return [];
      }

      final battleData = battleDoc.data() as Map<String, dynamic>;

      if (!battleData.containsKey('dates') ||
          battleData['dates'] is! Map<String, dynamic>) {
        print('No dates structure found');
        return [];
      }

      final datesMap = battleData['dates'] as Map<String, dynamic>;
      if (!datesMap.containsKey(prevBattleDate)) {
        print('Previous battle not found: $prevBattleDate');
        return [];
      }

      final previousBattle = datesMap[prevBattleDate] as Map<String, dynamic>;
      final participants =
          previousBattle['participants'] as Map<String, dynamic>? ?? {};

      final List<Map<String, dynamic>> participantList = [];
      participants.forEach((userId, userData) {
        final data = userData as Map<String, dynamic>;
        participantList.add({
          'userid': userId,
          'name': data['name'] ?? '',
          'image': data['image'] ?? '',
          'votes': data['votes'] ?? [],
        });
      });

      print(
          'Found ${participantList.length} participants for previous battle: $prevBattleDate');
      return participantList;
    } catch (e) {
      print('Error getting previous battle participants: $e');
      return [];
    }
  }

  // Get winners of a battle
  Future<List<String>> getBattleWinners(String battleId) async {
    try {
      // Implementation of getBattleWinners method
      // This method should return a list of winners of the given battle
      // Implementation details are not provided in the original file or the code block
      // This method should be implemented based on the specific requirements of the application
      throw Exception('Method not implemented');
    } catch (e) {
      print('Error getting battle winners: $e');
      return [];
    }
  }

  Future<String> uploadBattleVideo({
    required String battleId,
    required String userId,
    required File videoFile,
  }) async {
    try {
      final String fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${userId}_video.mp4';
      final Reference storageRef = _storage
          .ref()
          .child('battles')
          .child(battleId)
          .child(userId)
          .child(fileName);

      final UploadTask uploadTask = storageRef.putFile(
        videoFile,
        SettableMetadata(contentType: 'video/mp4'),
      );

      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      print('Error uploading battle video: $e');
      rethrow;
    }
  }
}
