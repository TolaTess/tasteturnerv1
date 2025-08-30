import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart' show debugPrint;

class BattleService extends GetxController {
  static final BattleService instance = Get.put(BattleService());

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Collection reference
  CollectionReference get battlesRef => _firestore.collection('battles');

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
      debugPrint('Error updating points for user $userId: $e');
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
      debugPrint('Error uploading image to storage: $e');
      throw Exception('Failed to upload image to storage');
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
      debugPrint('Error uploading battle video: $e');
      rethrow;
    }
  }
}
