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
      final firstDateKey = data['dates'].keys.first;
      // Update participants for current week
      await battlesRef.doc(battleId).update({
        'dates.$firstDateKey.participants.$userId': {
          'name': userName,
          'image': userImage,
          'votes': []
        }
      });

      // Update user's battles
      await firestore.collection('userBattles').doc(userId).set({
        'dates': {
          firstDateKey: {
            'ongoing': FieldValue.arrayUnion([battleId])
          }
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
      final firstDateKey = data['dates'].keys.first;

      // Update voted array and participant's votes
      await battlesRef.doc(battleId).update({
        'dates.$firstDateKey.voted': FieldValue.arrayUnion([voterId]),
        'dates.$firstDateKey.participants.$votedForUserId.votes':
            FieldValue.arrayUnion([voterId])
      });
      // Update user's battle status
      await firestore.collection('userBattles').doc(voterId).update({
        'dates.$firstDateKey.voted': FieldValue.arrayUnion([battleId]),
        'dates.$firstDateKey.ongoing': FieldValue.arrayRemove([battleId])
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

  // Check if user has voted
  Future<bool> hasUserVoted(String battleId, String userId) async {
    try {
      final battleDoc = await battlesRef.doc(battleId).get();
      if (!battleDoc.exists) return false;

      final currentBattle = _getCurrentBattleData(battleDoc);
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

      final currentBattle = _getCurrentBattleData(battleDoc);
      if (currentBattle == null) return false;

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
      final userDoc =
          await firestore.collection('userBattles').doc(userId).get();
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
          final battleDoc = await battlesRef.doc(battleId).get();
          if (!battleDoc.exists) continue;

          final data = battleDoc.data() as Map<String, dynamic>;
          if (!data.containsKey('dates')) continue;

          final battleDates = data['dates'] as Map<String, dynamic>;
          if (!battleDates.containsKey(dateKey)) continue;

          final battleData = battleDates[dateKey];
          battleDetails.add({
            'id': battleId,
            'category': data['category'],
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
      final battleDoc = await battlesRef.doc(battleId).get();
      if (!battleDoc.exists) throw Exception('Battle not found');
      final data = battleDoc.data() as Map<String, dynamic>;
      final currentBattle = _getCurrentBattleData(battleDoc);
      if (currentBattle == null) throw Exception('No active battle found');

      final firstDateKey = data['dates'].keys.first;
      // Remove user from participants
      await battlesRef.doc(battleId).update(
          {'dates.$firstDateKey.participants.$userId': FieldValue.delete()});

      // Remove battle from user's ongoing battles
      await firestore.collection('userBattles').doc(userId).update({
        'dates.$firstDateKey.ongoing': FieldValue.arrayRemove([battleId])
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
      final data = battleDoc.data() as Map<String, dynamic>;

      final currentBattle = _getCurrentBattleData(battleDoc);
      if (currentBattle == null) throw Exception('No active battle found');

      final firstDateKey = data['dates'].keys.first;
      // Update participant's media in the battle
      await battlesRef.doc(battleId).update(
          {'dates.$firstDateKey.participants.$userId.mediaPaths': imageUrls});

      // Move battle from ongoing to voted for the user
      await firestore.collection('userBattles').doc(userId).update({
        'dates.$firstDateKey.ongoing': FieldValue.arrayRemove([battleId]),
        'dates.$firstDateKey.voted': FieldValue.arrayUnion([battleId])
      });

      // Create or update battle post
      await firestore.collection('battle_post').doc(battleId).set({
        'mediaPaths': imageUrls,
        'category': data['category'],
        'name': currentBattle['participants'][userId]['name'] ?? 'Unknown',
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
}
