import 'dart:async';
import '../constants.dart';
import 'battle_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class BattleManagement {
  static final BattleManagement instance = BattleManagement._();
  Timer? _battleTimer;
  bool _isProcessing = false;

  BattleManagement._();

  void startBattleManagement() {
    _checkAndScheduleNextBattle();
  }

  void _checkAndScheduleNextBattle() async {
    if (_isProcessing) return;

    await firebaseService.fetchGeneralData();
    final currentBattleStr =
        firebaseService.generalData['currentBattle'] as String? ?? '2025-04-21';
    final currentBattleDate = DateTime.parse(currentBattleStr);
    final targetTime = DateTime(
      currentBattleDate.year,
      currentBattleDate.month,
      currentBattleDate.day,
      13, // 11:00
      33,
    );

    final now = DateTime.now();
    if (now.isAfter(targetTime)) {
      // If we've passed the target time, process the battle and schedule next one
      _isProcessing = true;
      try {
        await _processBattleEnd();
      } finally {
        _isProcessing = false;
      }
    } else {
      // Schedule for the target time
      final duration = targetTime.difference(now);
      _battleTimer?.cancel();
      _battleTimer = Timer(duration, () async {
        _isProcessing = true;
        try {
          await _processBattleEnd();
        } finally {
          _isProcessing = false;
        }
      });
    }
  }

  Future<void> _processBattleEnd() async {
    try {
      print('Processing battle end...');

      // 1. Get all battles and calculate winners
      final battles = await BattleService.instance.getActiveBattles();
      final Map<String, List<Map<String, dynamic>>> categoryWinners = {};

      // Process each battle and find winners
      for (var battle in battles) {
        final category = battle['category'] as String?;
        final battleId = battle['id'] as String?;
        final currentBattle = battle['currentBattle'] as Map<String, dynamic>?;

        if (category == null || battleId == null || currentBattle == null) {
          print('Invalid battle data structure: $battle');
          continue;
        }

        final participants =
            currentBattle['participants'] as Map<String, dynamic>?;
        if (participants == null || participants.isEmpty) {
          print('No participants found for battle: $battleId');
          continue;
        }

        List<Map<String, dynamic>> sortedParticipants = [];

        for (var entry in participants.entries) {
          final userId = entry.key;
          final userData = entry.value as Map<String, dynamic>?;

          if (userData == null) {
            print('Invalid user data for user: $userId');
            continue;
          }

          final votePercentage =
              await BattleService.instance.calculateUserVotePercentage(
            userId,
            category,
          );

          sortedParticipants.add({
            'userId': userId,
            'votePercentage': votePercentage,
            'displayName': userData['name'] ?? 'Unknown',
          });
        }

        // Sort by vote percentage
        sortedParticipants
            .sort((a, b) => b['votePercentage'].compareTo(a['votePercentage']));

        // Take top winners based on number of participants (minimum 2)
        if (sortedParticipants.length >= 2) {
          // Take either all participants or top 3, whichever is smaller
          int winnersCount =
              sortedParticipants.length >= 3 ? 3 : sortedParticipants.length;
          categoryWinners[category] =
              sortedParticipants.take(winnersCount).toList();
          print('Winners for category $category: ${categoryWinners[category]}');
        } else {
          print(
              'Not enough participants for category $category (minimum 2 required): ${sortedParticipants.length}');
        }
      }

      if (categoryWinners.isEmpty) {
        print('No winners found in any category');
        return;
      }

      // 2. Save winners to Firestore
      final currentDate = DateTime.parse(
          firebaseService.generalData['currentBattle'] as String);
      final weekId = 'week_${currentDate.toString().split(' ')[0]}';

      // Organize winners by category
      final Map<String, List<String>> categoryWinnerIds = {};
      for (var category in categoryWinners.keys) {
        final winners = categoryWinners[category]!;
        final List<String> userIds = [];

        // Assign points based on position
        for (int i = 0; i < winners.length; i++) {
          final userId = winners[i]['userId'];
          final points = _calculatePoints(i);
          final position = _getPositionSuffix(i);

          print(
              'Awarding $points points to user $userId for position $position');

          // Update user points
          await updateUserPoints(userId, points);

          // Send notification to winner
          await _notifyWinner(userId, category, position);

          // Add user to winners list with position suffix
          userIds.add('$userId-$position');
        }

        categoryWinnerIds[category] = userIds;
      }

      // Save all winners organized by category
      await helperController.saveWinners(
        weekId,
        categoryWinnerIds,
        currentDate.toString().split(' ')[0],
      );

      // 3. Update current battle date to next week
      final nextBattleDate = currentDate.add(const Duration(days: 7));
      final nextAnnounceDate = currentDate.add(const Duration(days: 1));
      await firestore.collection('general').doc('data').set({
        'currentBattle': nextBattleDate.toString().split(' ')[0],
        'isAnnounceDate': nextAnnounceDate.toString().split(' ')[0],
      }, SetOptions(merge: true));

      print('Battle processing completed successfully');

      // 4. Schedule next check
      _checkAndScheduleNextBattle();
    } catch (e) {
      print('Error processing battle end: $e');
      print('Stack trace: ${StackTrace.current}');
    }
  }

  int _calculatePoints(int position) {
    switch (position) {
      case 0: // 1st place
        return 50;
      case 1: // 2nd place
        return 30;
      case 2: // 3rd place
        return 20;
      default:
        return 0;
    }
  }

  String _getPositionSuffix(int position) {
    switch (position) {
      case 0:
        return '1st';
      case 1:
        return '2nd';
      case 2:
        return '3rd';
      default:
        return '';
    }
  }

  Future<void> updateUserPoints(String userId, int points) async {
    final userPointsRef = firestore.collection('points').doc(userId);

    try {
      await firestore.runTransaction((transaction) async {
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

  Future<void> _notifyWinner(
      String userId, String category, String position) async {
    try {
      // Get user's display name
      final userDoc = await firestore.collection('users').doc(userId).get();
      final displayName = userDoc.data()?['displayName'] ?? 'Unknown';

      String message;
      switch (position) {
        case '1st':
          message =
              '🏆 Congratulations! You won 1st place in the $category battle! Your points has been updated';
          break;
        case '2nd':
          message =
              '🥈 Amazing! You secured 2nd place in the $category battle! Your points has been updated';
          break;
        case '3rd':
          message =
              '🥉 Well done! You got 3rd place in the $category battle! Your points has been updated';
          break;
        default:
          message =
              'Congratulations on your achievement in the $category battle!';
      }

      await notificationService.showNotification(
        id: DateTime.now().millisecondsSinceEpoch % 100000,
        title: 'Battle Results',
        body: message,
      );

      print(
          'Notification sent to winner $displayName ($position place in $category)');
    } catch (e) {
      print('Error sending winner notification: $e');
    }
  }

  void dispose() {
    _battleTimer?.cancel();
  }
}
