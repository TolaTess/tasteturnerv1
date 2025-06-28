import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';
import '../constants.dart';
import '../data_models/program_model.dart';

class ProgramService extends GetxController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Rx<Program?> currentProgram = Rx<Program?>(null);
  final RxList<Program> userPrograms = RxList<Program>([]);

  @override
  void onInit() {
    super.onInit();
    loadUserPrograms();
  }

  Future<void> loadUserPrograms() async {
    final userId = userService.userId;
    if (userId == null) return;

    try {
      final snapshot = await _firestore
          .collection('programs')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();

      userPrograms.value =
          snapshot.docs.map((doc) => Program.fromJson(doc.data())).toList();

      // Set current active program
      currentProgram.value =
          userPrograms.firstWhereOrNull((program) => program.isActive);
    } catch (e) {
      print('Error loading user programs: $e');
    }
  }

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
    );

    try {
      // Deactivate current active program if exists
      if (currentProgram.value != null) {
        await _firestore
            .collection('programs')
            .doc(currentProgram.value!.programId)
            .update({'isActive': false});
      }

      // Save new program
      await _firestore
          .collection('programs')
          .doc(programId)
          .set(program.toJson());

      await loadUserPrograms();
      return program;
    } catch (e) {
      print('Error creating program: $e');
      throw Exception('Failed to create program');
    }
  }

  Future<void> deactivateProgram(String programId) async {
    try {
      await _firestore
          .collection('programs')
          .doc(programId)
          .update({'isActive': false});
      await loadUserPrograms();
    } catch (e) {
      print('Error deactivating program: $e');
      throw Exception('Failed to deactivate program');
    }
  }
}
