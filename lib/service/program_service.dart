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
  final RxList<Program> archivedPrograms = RxList<Program>([]);

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
      // 1. Get user's program enrollments
      final userProgramsSnapshot = await _firestore
          .collection('userProgram')
          .where('userIds', arrayContains: userId)
          .get();

      final enrolledProgramIds =
          userProgramsSnapshot.docs.map((doc) => doc.id).toSet();
      
      // Track IDs we've already checked archive status for
      final checkedArchiveStatusIds = enrolledProgramIds.toSet();

      // Track archived status
      final archivedProgramIds = <String>{};
      for (final doc in userProgramsSnapshot.docs) {
        try {
          final data = doc.data();
          final archivedUsers = List<dynamic>.from(data['archivedUsers'] ?? [])
              .map((e) => e.toString())
              .toList();
          if (archivedUsers.contains(userId)) {
            archivedProgramIds.add(doc.id);
          }
        } catch (e) {
          debugPrint('Error checking archive status for program ${doc.id}: $e');
        }
      }

      // 2. Get private programs owned by user
      final ownedPrivateProgramsSnapshot = await _firestore
          .collection('programs')
          .where('userId', isEqualTo: userId)
          .where('isPrivate', isEqualTo: true)
          .get();

      final privateProgramIdsToCheck = <String>[];

      for (final doc in ownedPrivateProgramsSnapshot.docs) {
        enrolledProgramIds.add(doc.id);
        if (!checkedArchiveStatusIds.contains(doc.id)) {
          privateProgramIdsToCheck.add(doc.id);
        }
      }
      
      // 2.5 Check archive status for private programs that weren't in the enrollment list
      // This handles cases where user owns a private program but isn't in 'userIds' 
      // or if the enrollment query missed it for some reason
      if (privateProgramIdsToCheck.isNotEmpty) {
        // Batch fetch userProgram docs
        for (var i = 0; i < privateProgramIdsToCheck.length; i += 10) {
          final end = (i + 10 < privateProgramIdsToCheck.length) 
              ? i + 10 
              : privateProgramIdsToCheck.length;
          final batchIds = privateProgramIdsToCheck.sublist(i, end);
          
          if (batchIds.isEmpty) continue;

          try {
            final batchSnapshot = await _firestore
                .collection('userProgram')
                .where(FieldPath.documentId, whereIn: batchIds)
                .get();
            
            for (final doc in batchSnapshot.docs) {
              try {
                final data = doc.data();
                final archivedUsers = List<dynamic>.from(data['archivedUsers'] ?? [])
                    .map((e) => e.toString())
                    .toList();
                if (archivedUsers.contains(userId)) {
                  archivedProgramIds.add(doc.id);
                }
              } catch (e) {
                debugPrint('Error checking archive status for private program ${doc.id}: $e');
              }
            }
          } catch (e) {
            debugPrint('Error fetching userProgram batch: $e');
          }
        }
      }

      if (enrolledProgramIds.isEmpty) {
        userPrograms.value = [];
        archivedPrograms.value = [];
        currentProgram.value = null;
        return;
      }

      // 3. Fetch the actual program documents in batches
      final allUserPrograms = <Program>[];
      final programIdsList = enrolledProgramIds.toList();

      // Firestore whereIn limit is 10
      for (var i = 0; i < programIdsList.length; i += 10) {
        final end =
            (i + 10 < programIdsList.length) ? i + 10 : programIdsList.length;
        final batchIds = programIdsList.sublist(i, end);

        if (batchIds.isEmpty) continue;

        try {
          final batchSnapshot = await _firestore
              .collection('programs')
              .where(FieldPath.documentId, whereIn: batchIds)
              .get();

          final batchPrograms = batchSnapshot.docs
              .map((doc) => Program.fromJson({
                    ...doc.data(),
                    'programId': doc.id,
                  }))
              .toList();

          allUserPrograms.addAll(batchPrograms);
        } catch (e) {
          debugPrint('Error fetching program batch: $e');
        }
      }

      // 4. Filter and sort
      userPrograms.value = allUserPrograms
          .where((program) => !archivedProgramIds.contains(program.programId))
          .toList();

      archivedPrograms.value = allUserPrograms
          .where((program) => archivedProgramIds.contains(program.programId))
          .toList();

      // Set current active program (only from non-archived)
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
    final isPrivate = programData['isPrivate'] ?? false;
    final planningConversationId =
        programData['planningConversationId'] as String?;

    final program = Program(
      programId: programId,
      type: programData['type'] ?? 'custom',
      name: programData['name'],
      description: programData['description'],
      duration: programData['duration'],
      weeklyPlans: (programData['weeklyPlans'] as List)
          .map((plan) => WeeklyPlan.fromJson(plan))
          .toList(),
      requirements: programData['requirements'] is List
          ? List<String>.from(
              programData['requirements'].map((item) => item.toString()))
          : [],
      recommendations: programData['recommendations'] is List
          ? List<String>.from(
              programData['recommendations'].map((item) => item.toString()))
          : [],
      userId: userId,
      createdAt: now,
      startDate: now,
      benefits: programData['benefits'] is List
          ? List<String>.from(
              programData['benefits'].map((item) => item.toString()))
          : [],
      notAllowed: programData['notAllowed'] is List
          ? List<String>.from(
              programData['notAllowed'].map((item) => item.toString()))
          : [],
      programDetails: programData['programDetails'] is List
          ? List<String>.from(
              programData['programDetails'].map((item) => item.toString()))
          : [],
      portionDetails: programData['portionDetails'] is Map
          ? Map<String, dynamic>.from(programData['portionDetails'])
          : {},
      isPrivate: isPrivate,
      planningConversationId: planningConversationId,
    );

    try {
      // Save program - include ALL fields from programData (not just those in Program model)
      // This ensures enrichment data from cloud function is preserved
      final programJson = program.toJson();

      // Add ALL additional fields from programData (routine, goals, benefits, etc.)
      // These may come from either client-side generation or server-side enrichment
      for (final entry in programData.entries) {
        if (!programJson.containsKey(entry.key)) {
          programJson[entry.key] = entry.value;
        }
      }

      // Explicitly ensure routine, goals, benefits, etc. are included if present
      if (programData['routine'] != null) {
        programJson['routine'] = programData['routine'];
      }
      if (programData['goals'] != null) {
        programJson['goals'] = programData['goals'];
      }
      if (programData['benefits'] != null) {
        programJson['benefits'] = programData['benefits'];
      }
      if (programData['requirements'] != null) {
        programJson['requirements'] = programData['requirements'];
      }
      if (programData['recommendations'] != null) {
        programJson['recommendations'] = programData['recommendations'];
      }
      if (programData['programDetails'] != null) {
        programJson['programDetails'] = programData['programDetails'];
      }
      if (programData['notAllowed'] != null) {
        programJson['notAllowed'] = programData['notAllowed'];
      }
      if (programData['portionDetails'] != null) {
        programJson['portionDetails'] = programData['portionDetails'];
      }

      await _firestore.collection('programs').doc(programId).set(programJson);

      // Auto-enroll user in private programs
      if (isPrivate) {
        await joinProgram(programId, 'default');
      } else {
        // Note: userProgram document will be created when first user joins
        await loadUserPrograms();
      }

      return program;
    } catch (e) {
      debugPrint('Error creating program: $e');
      throw Exception('Failed to create program');
    }
  }

  // Create a private program (convenience method)
  Future<Program> createPrivateProgram(Map<String, dynamic> programData,
      {String? planningConversationId}) async {
    return createProgram({
      ...programData,
      'isPrivate': true,
      if (planningConversationId != null)
        'planningConversationId': planningConversationId,
    });
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
      // Check if this is a private program owned by the user
      // Users cannot "leave" their own private programs - they own them
      final programDoc =
          await _firestore.collection('programs').doc(programId).get();
      if (programDoc.exists) {
        final programData = programDoc.data();
        final isPrivate = programData?['isPrivate'] ?? false;
        final programUserId = programData?['userId'] as String?;

        if (isPrivate && programUserId == userId) {
          throw Exception(
              'You cannot leave your own private program. You can delete it instead.');
        }
      }

      // Check if userProgram document exists and user is enrolled
      final userProgramDoc =
          await _firestore.collection('userProgram').doc(programId).get();
      if (!userProgramDoc.exists) {
        // Document doesn't exist - user might not be enrolled
        debugPrint(
            'UserProgram document does not exist for program $programId');
        // Still refresh the list in case the program was already removed
        await loadUserPrograms();
        return;
      }

      final userProgramData = userProgramDoc.data();
      final userIds = userProgramData?['userIds'] as List<dynamic>?;

      if (userIds == null || !userIds.contains(userId)) {
        // User is not enrolled in this program
        debugPrint('User is not enrolled in program $programId');
        await loadUserPrograms();
        return;
      }

      // Remove user from userProgram document
      await _firestore.collection('userProgram').doc(programId).update({
        'userIds': FieldValue.arrayRemove([userId])
      });

      await loadUserPrograms();
    } catch (e) {
      debugPrint('Error leaving program: $e');
      // Re-throw if it's already a user-friendly exception
      if (e.toString().contains('cannot leave')) {
        rethrow;
      }
      throw Exception('Failed to leave program: ${e.toString()}');
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

  // Update program with enrichment data
  Future<void> updateProgram(
      String programId, Map<String, dynamic> enrichmentData) async {
    try {
      // Merge enrichment data with existing program
      // Ensure all fields are preserved
      final programRef = _firestore.collection('programs').doc(programId);
      await programRef.update(enrichmentData);

      // Reload user programs to reflect changes
      await loadUserPrograms();
    } catch (e) {
      debugPrint('Error updating program: $e');
      throw Exception('Failed to update program');
    }
  }

  // Archive a program (hide from main UI but keep enrolled)
  Future<void> archiveProgram(String programId) async {
    final userId = userService.userId;
    if (userId == null) throw Exception('User not authenticated');

    try {
      // Check if userProgram document exists
      final userProgramRef =
          _firestore.collection('userProgram').doc(programId);
      final userProgramDoc = await userProgramRef.get();

      if (!userProgramDoc.exists) {
        // Create document if it doesn't exist (for private programs)
        await userProgramRef.set({
          'userIds': [userId],
          'archivedUsers': [userId],
        });
      } else {
        // Add user to archivedUsers array
        final data = userProgramDoc.data();
        final archivedUsers = (data?['archivedUsers'] as List<dynamic>? ?? [])
            .map((e) => e.toString())
            .toList();

        if (!archivedUsers.contains(userId)) {
          await userProgramRef.update({
            'archivedUsers': FieldValue.arrayUnion([userId]),
          });
        }
      }

      await loadUserPrograms();
    } catch (e) {
      debugPrint('Error archiving program: $e');
      throw Exception('Failed to archive program');
    }
  }

  // Unarchive a program (show in main UI again)
  Future<void> unarchiveProgram(String programId) async {
    final userId = userService.userId;
    if (userId == null) throw Exception('User not authenticated');

    try {
      final userProgramRef =
          _firestore.collection('userProgram').doc(programId);
      final userProgramDoc = await userProgramRef.get();

      if (userProgramDoc.exists) {
        // Remove user from archivedUsers array
        await userProgramRef.update({
          'archivedUsers': FieldValue.arrayRemove([userId]),
        });
      }

      await loadUserPrograms();
    } catch (e) {
      debugPrint('Error unarchiving program: $e');
      throw Exception('Failed to unarchive program');
    }
  }
}
