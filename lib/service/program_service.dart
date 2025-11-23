import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';
import '../constants.dart';
import '../data_models/program_model.dart';
import 'package:flutter/material.dart' show debugPrint;

class ProgramService extends GetxController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Rx<Program?> currentProgram = Rx<Program?>(null);
  final RxList<Program> userPrograms = RxList<Program>([]);

  @override
  void onInit() {
    super.onInit();
    loadUserPrograms();
  }

  // Fetch all available programs
  Future<List<Program>> getAllPrograms() async {
    try {
      final snapshot = await _firestore.collection('programs').get();
      return snapshot.docs
          .map((doc) => Program.fromJson({
                ...doc.data(),
                'programId': doc.id,
              }))
          .toList();
    } catch (e) {
      debugPrint('Error loading programs: $e');
      return [];
    }
  }

  // Fetch programs a user is enrolled in
  Future<void> loadUserPrograms() async {
    final userId = userService.userId;
    if (userId == null) return;

    try {
      // Get all programs
      final programsSnapshot = await _firestore.collection('programs').get();
      final allPrograms = programsSnapshot.docs
          .map((doc) => Program.fromJson({
                ...doc.data(),
                'programId': doc.id,
              }))
          .toList();

      // Get user's program enrollments from userProgram collection
      final userProgramsSnapshot = await _firestore
          .collection('userProgram')
          .where('userIds', arrayContains: userId)
          .get();

      // Filter programs to only those the user is enrolled in
      final enrolledProgramIds =
          userProgramsSnapshot.docs.map((doc) => doc.id).toSet();

      userPrograms.value = allPrograms
          .where((program) => enrolledProgramIds.contains(program.programId))
          .toList();

      // Set current active program
      currentProgram.value =
          userPrograms.firstWhereOrNull((program) => program.isActive);
    } catch (e) {
      debugPrint('Error loading user programs: $e');
    }
  }

  // Create a new program
  Future<Program> createProgram(Map<String, dynamic> programData) async {
    final userId = userService.userId;
    if (userId == null) throw Exception('User not authenticated');

    final programId = const Uuid().v4();
    final now = DateTime.now();

    final program = Program(
      programId: programId,
      type: programData['type'],
      name: programData['name'],
      description: programData['description'],
      duration: programData['duration'],
      weeklyPlans: (programData['weeklyPlans'] as List)
          .map((plan) => WeeklyPlan.fromJson(plan))
          .toList(),
      requirements: List<String>.from(programData['requirements']),
      recommendations: List<String>.from(programData['recommendations']),
      userId: userId,
      createdAt: now,
      startDate: now,
      benefits: List<String>.from(programData['benefits']),
      notAllowed: List<String>.from(programData['notAllowed']),
      programDetails: List<String>.from(programData['programDetails']),
      portionDetails: Map<String, dynamic>.from(programData['portionDetails']),
    );

    try {
      // Save program
      await _firestore
          .collection('programs')
          .doc(programId)
          .set(program.toJson());

      // Note: userProgram document will be created when first user joins

      await loadUserPrograms();
      return program;
    } catch (e) {
      debugPrint('Error creating program: $e');
      throw Exception('Failed to create program');
    }
  }

  // Check if user is already enrolled in a program
  Future<bool> isUserEnrolledInProgram(String programId) async {
    final userId = userService.userId;
    if (userId == null || userId.isEmpty) return false;

    try {
      final userProgramDoc =
          await _firestore.collection('userProgram').doc(programId).get();

      if (userProgramDoc.exists) {
        final data = userProgramDoc.data();
        if (data == null) return false;

        final userIds = data['userIds'] as List?;
        if (userIds == null) return false;

        return userIds.contains(userId);
      }

      return false;
    } catch (e) {
      debugPrint('Error checking program enrollment: $e');
      // If permission denied, assume user is not enrolled (document might exist but user can't read it)
      // This allows the join flow to proceed
      return false;
    }
  }

  // Join a program with a specific option
  Future<void> joinProgram(String programId, String option) async {
    final userId = userService.userId;
    if (userId == null || userId.isEmpty) {
      throw Exception('User not authenticated');
    }

    try {
      // Check if user is already enrolled
      final isAlreadyEnrolled = await isUserEnrolledInProgram(programId);
      if (isAlreadyEnrolled) {
        throw Exception('You are already enrolled in this program');
      }

      // Use a transaction to safely add user to program
      // This ensures atomicity and handles race conditions
      await _firestore.runTransaction((transaction) async {
        final userProgramRef =
            _firestore.collection('userProgram').doc(programId);
        final userProgramDoc = await transaction.get(userProgramRef);

        if (userProgramDoc.exists) {
          final data = userProgramDoc.data();
          final existingUserIds = (data?['userIds'] as List<dynamic>?)
                  ?.map((e) => e.toString())
                  .toList() ??
              [];

          // Double-check user is not already enrolled
          if (existingUserIds.contains(userId)) {
            throw Exception('You are already enrolled in this program');
          }

          // Update existing document - add user to userIds array
          transaction.update(userProgramRef, {
            'userIds': FieldValue.arrayUnion([userId])
          });
        } else {
          // Create new document with userIds array
          transaction.set(userProgramRef, {
            'userIds': [userId]
          });
        }
      });

      await loadUserPrograms();
    } catch (e) {
      debugPrint('Error joining program: $e');
      // Provide more specific error message
      if (e.toString().contains('permission-denied')) {
        throw Exception('Permission denied. Please check your account status.');
      } else if (e.toString().contains('already enrolled')) {
        throw Exception('You are already enrolled in this program');
      } else {
        throw Exception('Failed to join program: ${e.toString()}');
      }
    }
  }

  // Leave a program
  Future<void> leaveProgram(String programId) async {
    final userId = userService.userId;
    if (userId == null) throw Exception('User not authenticated');

    try {
      // Remove user from userProgram document
      await _firestore.collection('userProgram').doc(programId).update({
        'userIds': FieldValue.arrayRemove([userId])
      });

      await loadUserPrograms();
    } catch (e) {
      debugPrint('Error leaving program: $e');
      throw Exception('Failed to leave program');
    }
  }

  // Get users in a program
  Future<List<String>> getProgramUsers(String programId) async {
    try {
      final doc =
          await _firestore.collection('userProgram').doc(programId).get();

      if (!doc.exists) return [];

      final data = doc.data() as Map<String, dynamic>;
      final userIds = data['userIds'] as List?;
      return userIds?.cast<String>() ?? [];
    } catch (e) {
      debugPrint('Error getting program users: $e');
      return [];
    }
  }

  // Deactivate a program
  Future<void> deactivateProgram(String programId) async {
    try {
      await _firestore
          .collection('programs')
          .doc(programId)
          .update({'isActive': false});
      await loadUserPrograms();
    } catch (e) {
      debugPrint('Error deactivating program: $e');
      throw Exception('Failed to deactivate program');
    }
  }
}
