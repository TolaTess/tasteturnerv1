import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../constants.dart';
import '../helper/utils.dart';
import '../service/program_service.dart';
import 'package:intl/intl.dart';

class ProgramProgressScreen extends StatefulWidget {
  final String? programId;
  final String? programName;
  final String? programDescription;
  final List<String>? benefits;
  final String? duration;

  const ProgramProgressScreen({
    super.key,
    this.programId,
    this.programName,
    this.programDescription,
    this.benefits,
    this.duration,
  });

  @override
  State<ProgramProgressScreen> createState() => _ProgramProgressScreenState();
}

class _ProgramProgressScreenState extends State<ProgramProgressScreen>
    with TickerProviderStateMixin {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final FirebaseAuth auth = FirebaseAuth.instance;
  final ProgramService programService = Get.find<ProgramService>();

  bool isLoading = true;
  Map<String, dynamic>? programData;
  Map<String, bool> completionStatus = {};
  List<Map<String, dynamic>> programComponents = [];
  List<Map<String, dynamic>> previousDaysProgress = [];

  String get currentUserId {
    final uid = auth.currentUser?.uid ?? '';
    return uid;
  }

  String? lastTrackedDate;
  List<Map<String, dynamic>> userPrograms = [];
  int currentProgramIndex = 0;
  String? currentProgramId;

  // Animation controllers for flip cards
  Map<String, AnimationController> _flipControllers = {};
  Map<String, Animation<double>> _flipAnimations = {};

  // Scroll controllers for description text
  Map<String, ScrollController> _scrollControllers = {};

  // Program completion tracking
  bool isProgramCompleted = false;
  DateTime? programStartDate;
  DateTime? programEndDate;

  @override
  void initState() {
    super.initState();
    if (widget.programId != null) {
      currentProgramId = widget.programId;
      _loadProgramData();
      _loadProgressData();
    } else {
      _loadUserPrograms();
    }
  }

  @override
  void dispose() {
    // Dispose all animation controllers
    for (var controller in _flipControllers.values) {
      controller.dispose();
    }
    // Dispose all scroll controllers
    for (var controller in _scrollControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String _getCurrentDateKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  bool _isNewDay() {
    final currentDate = _getCurrentDateKey();
    return lastTrackedDate != null && lastTrackedDate != currentDate;
  }

  Future<void> _handleDayTransition() async {
    if (_isNewDay()) {
      // Reset daily completion status for the new day
      setState(() {
        for (var key in completionStatus.keys) {
          completionStatus[key] = false;
        }
      });

      // Update the tracked date
      lastTrackedDate = _getCurrentDateKey();

      // Update Firebase with the new day's reset status
      await _resetDailyProgress();

      if (mounted) {
        showTastySnackbar(
          'New Day Started!',
          'Your progress has been reset for today',
          context,
          backgroundColor: kAccent,
        );
      }
    }
  }

  Future<void> _loadUserPrograms() async {
    try {
      setState(() {
        isLoading = true;
      });

      final userProgramsQuery = await firestore
          .collection('userProgram')
          .where('userIds', arrayContains: currentUserId)
          .get();

      if (userProgramsQuery.docs.isNotEmpty) {
        userPrograms = [];
        for (var doc in userProgramsQuery.docs) {
          final programId = doc.id; // Document ID is the programId

          // Load program details
          final programDoc =
              await firestore.collection('programs').doc(programId).get();

          if (programDoc.exists) {
            userPrograms.add({
              'programId': programId,
              ...programDoc.data()!,
            });
          }
        }

        if (userPrograms.isNotEmpty) {
          currentProgramIndex = 0;
          currentProgramId = userPrograms[0]['programId'];
          await _loadSpecificProgram(currentProgramId!);
        } else {
          setState(() {
            isLoading = false;
          });
          Get.snackbar(
            'No Programs',
            'You are not enrolled in any programs yet',
            backgroundColor: kAccent,
            colorText: Colors.white,
          );
        }
      } else {
        setState(() {
          isLoading = false;
        });
        Get.snackbar(
          'No Programs',
          'You are not enrolled in any programs yet',
          backgroundColor: kAccent,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });

      // Distinguish between permission errors and other errors
      final errorString = e.toString().toLowerCase();
      if (errorString.contains('permission-denied') ||
          errorString.contains('permission denied')) {
        Get.snackbar(
          'Permission Error',
          'You do not have permission to access program data. Please check your account status.',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      } else {
        debugPrint('Error loading user programs: $e');
        Get.snackbar(
          'Error',
          'Failed to load user programs. Please try again.',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    }
  }

  Future<void> _loadSpecificProgram(String programId) async {
    try {
      currentProgramId = programId;

      final programDoc =
          await firestore.collection('programs').doc(programId).get();

      if (programDoc.exists) {
        programData = programDoc.data();
        _buildProgramComponents();
        await _loadProgressData();
      } else {
        setState(() {
          isLoading = false;
        });
        Get.snackbar(
          'Error',
          'Program not found',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      Get.snackbar(
        'Error',
        'Failed to load program data: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Future<void> _loadProgramData() async {
    try {
      final programDoc =
          await firestore.collection('programs').doc(currentProgramId).get();

      if (programDoc.exists) {
        programData = programDoc.data();
        _buildProgramComponents();
        setState(() {
          // Components and completion status are now ready
        });
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to load program data: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Future<void> _loadProgressData() async {
    try {
      final trackingDoc = await firestore
          .collection('programTracking')
          .doc(currentUserId)
          .collection('programs')
          .doc(currentProgramId!)
          .get();

      if (trackingDoc.exists) {
        final data = trackingDoc.data()!;

        // Load the last tracked date
        lastTrackedDate = data['lastTrackedDate'] as String?;

        // Extract program start date
        final programDetails =
            data['programDetails'] as Map<String, dynamic>? ?? {};
        final startDateTimestamp = programDetails['startDate'] as Timestamp?;
        if (startDateTimestamp != null) {
          programStartDate = startDateTimestamp.toDate();
        }

        setState(() {
          // Load completion status
          final components = data['components'] as Map<String, dynamic>? ?? {};

          // First, ensure all current program components are initialized
          for (var component in programComponents) {
            completionStatus[component['id']] = false;
          }

          // Then load any saved completion status from Firebase
          for (var entry in components.entries) {
            completionStatus[entry.key] = entry.value['completed'] ?? false;
          }

          // Load weekly progress
          _loadWeeklyProgress(data);

          // Check program completion
          _checkProgramCompletion();

          isLoading = false;
        });

        // Check if it's a new day and handle transition (only if program not completed)
        if (!isProgramCompleted) {
          await _handleDayTransition();
        }
      } else {
        // No progress data exists yet - this is normal for new users
        // Initialize tracking document
        await _initializeTracking();
        setState(() {
          // Start with empty previous days so we show today's progress UI
          previousDaysProgress = [];
          programStartDate = DateTime.now();
          _checkProgramCompletion();
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });

      // Distinguish between permission errors and other errors
      final errorString = e.toString().toLowerCase();
      if (errorString.contains('permission-denied') ||
          errorString.contains('permission denied')) {
        Get.snackbar(
          'Permission Error',
          'You do not have permission to access this data. Please check your account status.',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      } else {
        // For other errors (network, etc.), show generic error
        // But don't show error if it's just missing data (which is handled above)
        debugPrint('Error loading progress data: $e');
        // Only show snackbar for actual errors, not missing data
        if (!errorString.contains('not found') &&
            !errorString.contains('does not exist')) {
          Get.snackbar(
            'Error',
            'Failed to load progress data. Please try again.',
            backgroundColor: Colors.red,
            colorText: Colors.white,
          );
        }
      }
    }
  }

  void _buildProgramComponents() {
    if (programData == null) return;

    final routine = programData!['routine'] as List<dynamic>? ?? [];

    programComponents = [];

    // Create components from routine
    for (int i = 0; i < routine.length; i++) {
      final routineItem = routine[i] as Map<String, dynamic>;
      final componentId = 'routine_$i';

      programComponents.add({
        'id': componentId,
        'title': routineItem['title'] ?? 'Routine ${i + 1}',
        'subtitle': routineItem['duration'] ?? '',
        'description': routineItem['description'] ?? '',
        'image': _getImage(routineItem['title'] ?? ''),
        'color': _getComponentColor(i),
        'type': 'routine',
      });

      // Initialize animation controller for each component
      if (!_flipControllers.containsKey(componentId)) {
        _flipControllers[componentId] = AnimationController(
          duration: const Duration(milliseconds: 600),
          vsync: this,
        );
        _flipAnimations[componentId] = Tween<double>(
          begin: 0.0,
          end: 1.0,
        ).animate(CurvedAnimation(
          parent: _flipControllers[componentId]!,
          curve: Curves.easeInOut,
        ));
      }

      // Initialize scroll controller for each component
      if (!_scrollControllers.containsKey(componentId)) {
        _scrollControllers[componentId] = ScrollController();
      }
    }

    // Initialize completion status for new components
    for (var component in programComponents) {
      completionStatus[component['id']] ??= false;
    }
  }

  Color _getComponentColor(int index) {
    final colors = [
      const Color(0xFFE8D5B7),
      const Color(0xFFF5E6D3),
      const Color(0xFFE3F2FD),
      const Color(0xFFF3E5F5),
      const Color(0xFFE8F5E8),
      const Color(0xFFFFF3E0),
    ];
    return colors[index % colors.length];
  }

  String _getImage(String type) {
    if (type.toLowerCase().contains('sleep')) {
      return 'assets/images/salad.jpg';
    } else if (type.toLowerCase().contains('hydration')) {
      return 'assets/images/vegetable.jpg';
    } else if (type.toLowerCase().contains('exercise')) {
      return 'assets/images/fruit.jpg';
    } else if (type.toLowerCase().contains('eating')) {
      return 'assets/images/meat.jpg';
    } else if (type.toLowerCase().contains('movement')) {
      return 'assets/images/fruit.png';
    } else if (type.toLowerCase().contains('work')) {
      return 'assets/images/grain.png';
    }
    return 'assets/images/placeholder.jpg';
  }

  void _loadWeeklyProgress(Map<String, dynamic> data) {
    final weeklyData = data['weeklyProgress'] as Map<String, dynamic>? ?? {};
    final currentWeek = _getCurrentWeekKey();
    final thisWeekData = weeklyData[currentWeek] as Map<String, dynamic>? ?? {};
    final currentDayKey = _getCurrentDayKey(); // e.g., 'monday'

    // Map day keys to display names
    final dayKeyToName = {
      'monday': 'Mon',
      'tuesday': 'Tue',
      'wednesday': 'Wed',
      'thursday': 'Thu',
      'friday': 'Fri',
      'saturday': 'Sat',
      'sunday': 'Sun',
    };

    // Only include days that have actual progress data AND are not today
    final List<Map<String, dynamic>> weekDays = [];
    for (var entry in dayKeyToName.entries) {
      final dayKey = entry.key;
      final dayName = entry.value;
      final progress = thisWeekData[dayKey];

      // Only add if it's not today AND has progress data
      if (dayKey != currentDayKey && progress != null && progress > 0) {
        weekDays.add({
          'day': dayName,
          'progress': progress,
        });
      }
    }

    previousDaysProgress = weekDays;
  }

  String _getCurrentWeekKey() {
    final now = DateTime.now();
    final year = now.year;
    final weekNumber =
        ((now.difference(DateTime(year, 1, 1)).inDays) / 7).ceil();
    return '$year-W${weekNumber.toString().padLeft(2, '0')}';
  }

  String _getCurrentDayKey() {
    final weekdays = [
      'monday',
      'tuesday',
      'wednesday',
      'thursday',
      'friday',
      'saturday',
      'sunday'
    ];
    return weekdays[DateTime.now().weekday - 1];
  }

  String _getCurrentDayName() {
    final weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    return weekdays[DateTime.now().weekday - 1];
  }

  // Parse duration string to get number of days
  int _parseDurationToDays(String duration) {
    final cleanDuration = duration.toLowerCase().trim();

    // Extract number from duration string
    final RegExp numberRegex = RegExp(r'\d+');
    final match = numberRegex.firstMatch(cleanDuration);
    if (match == null) return 7; // Default to 7 days if parsing fails

    final number = int.tryParse(match.group(0)!) ?? 1;

    // Determine if it's days, weeks, months
    if (cleanDuration.contains('week')) {
      return number * 7;
    } else if (cleanDuration.contains('month')) {
      return number * 30;
    } else if (cleanDuration.contains('year')) {
      return number * 365;
    } else {
      return number; // Assume days if no unit specified
    }
  }

  // Check if program is completed based on start date and duration
  void _checkProgramCompletion() {
    if (programStartDate == null || programData == null) {
      isProgramCompleted = false;
      return;
    }

    final duration = programData!['duration'] as String? ?? '7 days';
    final durationInDays = _parseDurationToDays(duration);
    programEndDate = programStartDate!.add(Duration(days: durationInDays));

    final now = DateTime.now();
    isProgramCompleted = now.isAfter(programEndDate!);
  }

  // Restart the current program
  Future<void> _restartProgram() async {
    try {
      setState(() {
        isLoading = true;
      });

      // Reset start date to today
      await firestore
          .collection('programTracking')
          .doc(currentUserId)
          .collection('programs')
          .doc(currentProgramId!)
          .update({
        'programDetails.startDate': FieldValue.serverTimestamp(),
        'lastTrackedDate': _getCurrentDateKey(),
      });

      // Reset all completion status
      await _resetDailyProgress();

      // Reload data
      await _loadProgressData();

      if (mounted) {
        showTastySnackbar(
          'Program Restarted!',
          'Your program has been restarted. Good luck!',
          context,
          backgroundColor: kAccent,
        );
      }
    } catch (e) {
      if (mounted) {
        showTastySnackbar(
          'Error',
          'Failed to restart program: please try again',
          context,
          backgroundColor: Colors.red,
        );
      }
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  // Remove the current program
  Future<void> _removeProgram() async {
    try {
      setState(() {
        isLoading = true;
      });

      // Remove from user's enrolled programs
      await programService.leaveProgram(currentProgramId!);

      // Delete tracking data
      await firestore
          .collection('programTracking')
          .doc(currentUserId)
          .collection('programs')
          .doc(currentProgramId!)
          .delete();

      if (mounted) {
        showTastySnackbar(
          'Program Removed',
          'Program has been removed from your list',
          context,
          backgroundColor: kAccent,
        );

        // Navigate back after removal
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        showTastySnackbar(
          'Error',
          'Failed to remove program: please try again',
          context,
          backgroundColor: Colors.red,
        );
      }
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _initializeTracking() async {
    lastTrackedDate = _getCurrentDateKey();

    // Set local start date for immediate use
    programStartDate = DateTime.now();

    final trackingData = {
      'programDetails': {
        'name': widget.programName ?? programData?['name'] ?? 'Program',
        'startDate': FieldValue.serverTimestamp(),
        'duration': widget.duration ?? '7 days',
      },
      'components': {},
      'weeklyProgress': {},
      'overallProgress': {
        'totalComponents': programComponents.length,
        'completedComponents': 0,
        'progressPercentage': 0,
        'lastUpdated': FieldValue.serverTimestamp(),
      },
      'lastTrackedDate': lastTrackedDate,
    };

    await firestore
        .collection('programTracking')
        .doc(currentUserId)
        .collection('programs')
        .doc(currentProgramId!)
        .set(trackingData);
  }

  void _completeComponent(String componentId, String programName) async {
    // Check for day transition before updating progress
    await _handleDayTransition();

    setState(() {
      // Safely toggle completion status, defaulting to false if not found
      completionStatus[componentId] = !(completionStatus[componentId] ?? false);
    });

    // Update Firebase
    await _updateComponentProgress(componentId);
    await _updateDailyProgress();

    // Show success message
    if (mounted) {
      final isCompleted = completionStatus[componentId] ?? false;
      showTastySnackbar(
        'Progress Updated!',
        isCompleted
            ? '$programName completed successfully!'
            : 'Component marked as incomplete',
        context,
        backgroundColor: isCompleted ? Colors.green : kAccent,
      );
    }
  }

  Future<void> _updateComponentProgress(String componentId) async {
    try {
      final component =
          programComponents.firstWhere((c) => c['id'] == componentId);

      await firestore
          .collection('programTracking')
          .doc(currentUserId)
          .collection('programs')
          .doc(currentProgramId!)
          .update({
        'components.$componentId': {
          'id': componentId,
          'title': component['title'],
          'type': component['type'],
          'description': component['description'],
          'completed': completionStatus[componentId],
          'completedDate': completionStatus[componentId]!
              ? FieldValue.serverTimestamp()
              : null,
          'lastUpdated': FieldValue.serverTimestamp(),
        }
      });
    } catch (e) {
      if (mounted) {
        showTastySnackbar(
          'Error',
          'Failed to update component progress: $e',
          context,
          backgroundColor: Colors.red,
        );
      }
    }
  }

  Future<void> _updateDailyProgress() async {
    try {
      final completedCount =
          completionStatus.values.where((completed) => completed).length;
      final totalCount = completionStatus.length;
      final progressPercentage =
          totalCount > 0 ? (completedCount / totalCount * 100).round() : 0;

      final currentWeek = _getCurrentWeekKey();
      final currentDay = _getCurrentDayKey();

      await firestore
          .collection('programTracking')
          .doc(currentUserId)
          .collection('programs')
          .doc(currentProgramId!)
          .update({
        'weeklyProgress.$currentWeek.$currentDay': progressPercentage,
        'overallProgress.totalComponents': totalCount,
        'overallProgress.completedComponents': completedCount,
        'overallProgress.progressPercentage': progressPercentage,
        'overallProgress.lastUpdated': FieldValue.serverTimestamp(),
        'lastTrackedDate': _getCurrentDateKey(),
      });
    } catch (e) {
      if (mounted) {
        showTastySnackbar(
          'Error',
          'Failed to update daily progress: please try again',
          context,
          backgroundColor: Colors.red,
        );
      }
    }
  }

  Future<void> _resetDailyProgress() async {
    try {
      final currentWeek = _getCurrentWeekKey();
      final currentDay = _getCurrentDayKey();

      // Reset all component completion status in Firebase
      Map<String, dynamic> resetComponents = {};
      for (var component in programComponents) {
        resetComponents['components.${component['id']}'] = {
          'id': component['id'],
          'title': component['title'],
          'type': component['type'],
          'description': component['description'],
          'completed': false,
          'completedDate': null,
          'lastUpdated': FieldValue.serverTimestamp(),
        };
      }

      await firestore
          .collection('programTracking')
          .doc(currentUserId)
          .collection('programs')
          .doc(currentProgramId!)
          .update({
        ...resetComponents,
        'weeklyProgress.$currentWeek.$currentDay': 0,
        'overallProgress.totalComponents': programComponents.length,
        'overallProgress.completedComponents': 0,
        'overallProgress.progressPercentage': 0,
        'overallProgress.lastUpdated': FieldValue.serverTimestamp(),
        'lastTrackedDate': _getCurrentDateKey(),
      });
    } catch (e) {
      if (mounted) {
        showTastySnackbar(
          'Error',
          'Failed to reset daily progress: please try again',
          context,
          backgroundColor: Colors.red,
        );
      }
    }
  }

  void _switchToNextProgram() async {
    if (userPrograms.length <= 1) return;

    setState(() {
      isLoading = true;
      currentProgramIndex = (currentProgramIndex + 1) % userPrograms.length;
    });

    await _loadSpecificProgram(userPrograms[currentProgramIndex]['programId']);
  }

  void _switchToPreviousProgram() async {
    if (userPrograms.length <= 1) return;

    setState(() {
      isLoading = true;
      currentProgramIndex = currentProgramIndex == 0
          ? userPrograms.length - 1
          : currentProgramIndex - 1;
    });

    await _loadSpecificProgram(userPrograms[currentProgramIndex]['programId']);
  }

  Widget _buildProgramNavigator() {
    if (userPrograms.length < 2) return const SizedBox.shrink();

    final isDarkMode = getThemeProvider(context).isDarkMode;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      margin: EdgeInsets.only(
        top: getPercentageHeight(1, context),
        bottom: getPercentageHeight(2, context),
      ),
      padding: EdgeInsets.all(getPercentageWidth(3, context)),
      decoration: BoxDecoration(
        color: isDarkMode ? kDarkGrey : Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Previous button
          GestureDetector(
            onTap: _switchToPreviousProgram,
            child: Container(
              padding: EdgeInsets.all(getPercentageWidth(2, context)),
              decoration: BoxDecoration(
                color: kAccent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.chevron_left,
                color: kAccent,
                size: getIconScale(6, context),
              ),
            ),
          ),

          // Program indicator
          Expanded(
            child: Column(
              children: [
                Text(
                  'Program ${currentProgramIndex + 1} of ${userPrograms.length}',
                  style: textTheme.bodySmall?.copyWith(
                    color: isDarkMode
                        ? kWhite.withValues(alpha: 0.7)
                        : kDarkGrey.withValues(alpha: 0.7),
                    fontSize: getTextScale(2.5, context),
                  ),
                ),
                SizedBox(height: getPercentageHeight(0.5, context)),
                // Dots indicator
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(userPrograms.length, (index) {
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      width: getPercentageWidth(2, context),
                      height: getPercentageWidth(2, context),
                      decoration: BoxDecoration(
                        color: index == currentProgramIndex
                            ? kAccent
                            : (isDarkMode
                                ? kWhite.withValues(alpha: 0.3)
                                : kDarkGrey.withValues(alpha: 0.3)),
                        shape: BoxShape.circle,
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),

          // Next button
          GestureDetector(
            onTap: _switchToNextProgram,
            child: Container(
              padding: EdgeInsets.all(getPercentageWidth(2, context)),
              decoration: BoxDecoration(
                color: kAccent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.chevron_right,
                color: kAccent,
                size: getIconScale(6, context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({required String title}) {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: getPercentageWidth(4, context),
        vertical: getPercentageHeight(1, context),
      ),
      child: Center(
        child: Text(
          title,
          style: textTheme.titleLarge?.copyWith(
            fontSize: getTextScale(5, context),
            fontWeight: FontWeight.w600,
            color: isDarkMode ? kWhite : kDarkGrey,
          ),
        ),
      ),
    );
  }

  Widget _buildComponentCard(Map<String, dynamic> component, double height) {
    final componentId = component['id'];
    final flipAnimation = _flipAnimations[componentId];
    final flipController = _flipControllers[componentId];

    if (flipAnimation == null || flipController == null) {
      return Container(); // Return empty container if animation not initialized
    }

    return AnimatedBuilder(
      animation: flipAnimation,
      builder: (context, child) {
        final isShowingFront = flipAnimation.value < 0.5;
        return GestureDetector(
          onTap: () {
            // Disable interactions if program is completed
            if (isProgramCompleted) return;

            if (flipController.isCompleted) {
              flipController.reverse();
            } else {
              flipController.forward();
            }
          },
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateY(flipAnimation.value * pi),
            child: isShowingFront
                ? _buildCardFront(component, height)
                : Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()..rotateY(pi),
                    child: _buildCardBack(component, height),
                  ),
          ),
        );
      },
    );
  }

  Widget _buildCardFront(Map<String, dynamic> component, double height) {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    final textTheme = Theme.of(context).textTheme;
    final isCompleted = completionStatus[component['id']] ?? false;

    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCompleted ? kAccent : Colors.transparent,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            // Background Image
            Positioned.fill(
              child: Image.asset(
                component['image'],
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: isDarkMode ? kDarkGrey : component['color'],
                  child: Icon(
                    _getComponentIcon(component['id']),
                    size: getIconScale(15, context),
                    color: isDarkMode
                        ? kWhite.withValues(alpha: 0.3)
                        : kDarkGrey.withValues(alpha: 0.3),
                  ),
                ),
              ),
            ),
            // Gradient Overlay
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      isCompleted
                          ? kAccent.withValues(alpha: 0.7)
                          : Colors.black.withValues(alpha: 0.7),
                    ],
                  ),
                ),
              ),
            ),
            // Content
            Positioned(
              left: getPercentageWidth(4, context),
              right: getPercentageWidth(4, context),
              bottom: getPercentageHeight(2, context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          component['title'],
                          style: textTheme.titleMedium?.copyWith(
                            fontSize: getTextScale(4.5, context),
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      if (isCompleted)
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: kAccent,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.check,
                            color: Colors.white,
                            size: getIconScale(4, context),
                          ),
                        ),
                    ],
                  ),
                  if (component['subtitle'] != null)
                    Text(
                      component['subtitle'],
                      style: textTheme.bodyMedium?.copyWith(
                        fontSize: getTextScale(3, context),
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  SizedBox(height: getPercentageHeight(0.5, context)),
                  // Tap to flip indicator
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      isProgramCompleted
                          ? 'Program Completed'
                          : 'Tap to view complete',
                      style: textTheme.bodySmall?.copyWith(
                        fontSize: getTextScale(2.5, context),
                        color: Colors.white,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Program completed overlay
            if (isProgramCompleted)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: Colors.green.withValues(alpha: 0.8),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: Colors.white,
                          size: getIconScale(12, context),
                        ),
                        SizedBox(height: getPercentageHeight(1, context)),
                        Text(
                          'COMPLETED',
                          style: textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                            fontSize: getTextScale(4, context),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardBack(Map<String, dynamic> component, double height) {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    final textTheme = Theme.of(context).textTheme;
    final isCompleted = completionStatus[component['id']] ?? false;

    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: isDarkMode ? kDarkGrey : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(getPercentageWidth(4, context)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Text(
              component['title'],
              style: textTheme.titleMedium?.copyWith(
                fontSize: getTextScale(4.5, context),
                fontWeight: FontWeight.w600,
                color: isDarkMode ? kWhite : kDarkGrey,
              ),
            ),
            SizedBox(height: getPercentageHeight(1, context)),

            // Description
            Expanded(
              child: _scrollControllers[component['id']]?.hasClients == true
                  ? Scrollbar(
                      controller: _scrollControllers[component['id']]!,
                      thumbVisibility: true,
                      thickness: 2,
                      radius: const Radius.circular(2),
                      child: SingleChildScrollView(
                        controller: _scrollControllers[component['id']]!,
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.only(
                            right: getPercentageWidth(2, context)),
                        child: Text(
                          component['description'] ??
                              'No description available',
                          style: textTheme.bodyMedium?.copyWith(
                            fontSize: getTextScale(3.2, context),
                            color: isDarkMode
                                ? kWhite.withValues(alpha: 0.8)
                                : kDarkGrey.withValues(alpha: 0.8),
                            height: 1.4,
                          ),
                        ),
                      ),
                    )
                  : SingleChildScrollView(
                      controller: _scrollControllers[component['id']],
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.only(
                          right: getPercentageWidth(2, context)),
                      child: Text(
                        component['description'] ?? 'No description available',
                        style: textTheme.bodyMedium?.copyWith(
                          fontSize: getTextScale(3.2, context),
                          color: isDarkMode
                              ? kWhite.withValues(alpha: 0.8)
                              : kDarkGrey.withValues(alpha: 0.8),
                          height: 1.4,
                        ),
                      ),
                    ),
            ),

            // Complete Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isProgramCompleted
                    ? null
                    : () =>
                        _completeComponent(component['id'], component['title']),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isProgramCompleted
                      ? Colors.grey[400]
                      : (isCompleted ? Colors.green : kAccent),
                  foregroundColor: Colors.white,
                  elevation: isProgramCompleted ? 0 : 2,
                  padding: EdgeInsets.symmetric(
                      vertical: getPercentageHeight(0.5, context)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      isProgramCompleted
                          ? 'Program Completed'
                          : (isCompleted ? 'Completed' : 'Done'),
                      style: textTheme.labelMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getComponentIcon(String componentId) {
    switch (componentId) {
      case 'guided_meditation':
        return Icons.self_improvement;
      case 'breathing_exercise':
        return Icons.air;
      case 'healthy_recipes':
        return Icons.restaurant_menu;
      case 'yoga_classes':
        return Icons.accessibility_new;
      default:
        return Icons.circle;
    }
  }

  Widget _buildProgressSummary() {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    final textTheme = Theme.of(context).textTheme;
    final completedCount =
        completionStatus.values.where((completed) => completed).length;
    final totalCount = completionStatus.length;
    final todayProgressPercentage =
        totalCount > 0 ? (completedCount / totalCount * 100).round() : 0;

    return Container(
      margin: EdgeInsets.only(
        left: getPercentageWidth(4, context),
        right: getPercentageWidth(4, context),
        top: getPercentageHeight(1, context),
        bottom: getPercentageHeight(2, context),
      ),
      padding: EdgeInsets.all(getPercentageWidth(4, context)),
      decoration: BoxDecoration(
        color: isDarkMode ? kDarkGrey : kWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: kAccent.withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDarkMode
                ? kWhite.withValues(alpha: 0.4)
                : kDarkGrey.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Weekly Progress',
            style: textTheme.titleLarge?.copyWith(
              fontSize: getTextScale(5, context),
              fontWeight: FontWeight.w600,
              color: kAccent,
            ),
          ),
          SizedBox(height: getPercentageHeight(1, context)),
          // Bar Chart or Today's Progress
          if (previousDaysProgress.isNotEmpty)
            _buildBarChart()
          else
            _buildTodayProgress(completedCount, totalCount,
                todayProgressPercentage, isDarkMode, textTheme),
        ],
      ),
    );
  }

  Widget _buildBarChart() {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    final completedCount =
        completionStatus.values.where((completed) => completed).length;
    final totalCount = completionStatus.length;
    final todayProgressPercentage =
        totalCount > 0 ? (completedCount / totalCount * 100).round() : 0;

    // Add today's progress to the chart data
    final chartData = [
      ...previousDaysProgress,
      {'day': 'Today', 'progress': todayProgressPercentage}
    ];

    return SizedBox(
      height: getPercentageHeight(20, context),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: chartData.map((data) {
          final progress = data['progress'] as int;
          final isToday = data['day'] == 'Today';

          return Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  '$progress%',
                  style: TextStyle(
                    fontSize: getTextScale(2.5, context),
                    color: isDarkMode
                        ? kWhite.withValues(alpha: 0.7)
                        : kDarkGrey.withValues(alpha: 0.7),
                    fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                SizedBox(height: getPercentageHeight(0.5, context)),
                Container(
                  width: getPercentageWidth(8, context),
                  height: (progress / 100) * getPercentageHeight(12, context),
                  decoration: BoxDecoration(
                    color: isToday
                        ? kAccent
                        : (isDarkMode ? kLightGrey : Colors.grey[400]),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                SizedBox(height: getPercentageHeight(0.5, context)),
                Text(
                  data['day'],
                  style: TextStyle(
                    fontSize: getTextScale(2.5, context),
                    color: isDarkMode ? kWhite : kDarkGrey,
                    fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTodayProgress(int completedCount, int totalCount,
      int progressPercentage, bool isDarkMode, TextTheme textTheme) {
    return Row(
      children: [
        CircularProgressIndicator(
          value: totalCount > 0 ? completedCount / totalCount : 0.0,
          backgroundColor: isDarkMode ? kLightGrey : Colors.grey[300],
          valueColor: const AlwaysStoppedAnimation<Color>(kAccent),
          strokeWidth: 4,
        ),
        SizedBox(width: getPercentageWidth(4, context)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_getCurrentDayName()}\'s Progress',
                style: textTheme.titleMedium?.copyWith(
                  fontSize: getTextScale(4, context),
                  fontWeight: FontWeight.w600,
                  color: isDarkMode ? kWhite : kDarkGrey,
                ),
              ),
              SizedBox(height: getPercentageHeight(1, context)),
              Text(
                '$completedCount of $totalCount completed ($progressPercentage%)',
                style: textTheme.bodyMedium?.copyWith(
                  fontSize: getTextScale(3, context),
                  color: isDarkMode
                      ? kWhite.withValues(alpha: 0.7)
                      : kDarkGrey.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBenefits(
      BuildContext context, TextTheme textTheme, bool isDarkMode) {
    final benefits = List<String>.from(widget.benefits ?? []);
    if (benefits.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding:
              EdgeInsets.symmetric(horizontal: getPercentageWidth(4, context)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.lightbulb,
                color: kAccent,
                size: getIconScale(7, context),
              ),
              SizedBox(width: getPercentageWidth(2, context)),
              Text(
                'Benefits',
                style: textTheme.displaySmall?.copyWith(
                  color: kAccent,
                  fontSize: getTextScale(7, context),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: getPercentageHeight(2, context)),
        Padding(
          padding:
              EdgeInsets.symmetric(horizontal: getPercentageWidth(5, context)),
          child: Wrap(
            spacing: getPercentageWidth(2, context),
            runSpacing: getPercentageHeight(1, context),
            children: benefits.map((benefit) {
              return Container(
                padding: EdgeInsets.symmetric(
                  horizontal: getPercentageWidth(3, context),
                  vertical: getPercentageHeight(0.8, context),
                ),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border:
                      Border.all(color: Colors.orange.withValues(alpha: 0.4)),
                ),
                child: Text(
                  benefit,
                  style: textTheme.bodySmall?.copyWith(
                    color: Colors.orange[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildProgramCompletionCard() {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    final textTheme = Theme.of(context).textTheme;

    if (!isProgramCompleted) return const SizedBox.shrink();

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: getPercentageWidth(4, context),
        vertical: getPercentageHeight(2, context),
      ),
      padding: EdgeInsets.all(getPercentageWidth(5, context)),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4CAF50), Color(0xFF45A049)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Congratulations Header
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.celebration,
                color: Colors.white,
                size: getIconScale(8, context),
              ),
              SizedBox(width: getPercentageWidth(2, context)),
              Icon(
                Icons.emoji_events,
                color: Colors.yellow[300],
                size: getIconScale(10, context),
              ),
              SizedBox(width: getPercentageWidth(2, context)),
              Icon(
                Icons.celebration,
                color: Colors.white,
                size: getIconScale(8, context),
              ),
            ],
          ),
          SizedBox(height: getPercentageHeight(1.5, context)),

          // Congratulations Text
          Text(
            '🎉 CONGRATULATIONS! 🎉',
            style: textTheme.displaySmall?.copyWith(
              color: Colors.white,
              fontSize: getTextScale(6, context),
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: getPercentageHeight(1, context)),

          Text(
            'Program Completed Successfully!',
            style: textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontSize: getTextScale(4.5, context),
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: getPercentageHeight(1, context)),

          Text(
            'You have successfully completed the ${programData?['name'] ?? 'program'}. Great job on your dedication!',
            style: textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: getTextScale(3.5, context),
            ),
            textAlign: TextAlign.center,
          ),

          if (programEndDate != null) ...[
            SizedBox(height: getPercentageHeight(1.5, context)),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: getPercentageWidth(3, context),
                vertical: getPercentageHeight(0.8, context),
              ),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Text(
                'Completed on: ${DateFormat('MMM dd, yyyy').format(programEndDate!)}',
                style: textTheme.bodySmall?.copyWith(
                  color: Colors.white,
                  fontSize: getTextScale(3, context),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],

          SizedBox(height: getPercentageHeight(2.5, context)),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _restartProgram,
                  icon: const Icon(Icons.refresh, color: Colors.green),
                  label: Text(
                    'Restart',
                    style: textTheme.labelLarge?.copyWith(
                      color: Colors.green,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    elevation: 2,
                    padding: EdgeInsets.symmetric(
                      vertical: getPercentageHeight(1.2, context),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              SizedBox(width: getPercentageWidth(3, context)),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    // Show confirmation dialog
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        backgroundColor: isDarkMode ? kDarkGrey : Colors.white,
                        title: Text(
                          'Remove Program',
                          style: textTheme.titleLarge?.copyWith(
                            color: isDarkMode ? kWhite : kDarkGrey,
                          ),
                        ),
                        content: Text(
                          'Are you sure you want to remove this program? This action cannot be undone.',
                          style: textTheme.bodyMedium?.copyWith(
                            color: isDarkMode
                                ? kWhite.withValues(alpha: 0.8)
                                : kDarkGrey.withValues(alpha: 0.8),
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: Text(
                              'Cancel',
                              style: TextStyle(
                                  color: isDarkMode ? kWhite : kDarkGrey),
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                              _removeProgram();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                            ),
                            child: const Text(
                              'Remove',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                  icon: const Icon(Icons.delete, color: Colors.red),
                  label: Text(
                    'Remove',
                    style: textTheme.labelLarge?.copyWith(
                      color: Colors.red,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    elevation: 2,
                    padding: EdgeInsets.symmetric(
                      vertical: getPercentageHeight(1.2, context),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    final textTheme = Theme.of(context).textTheme;

    // Check for day transition on every build (handles app resuming from background)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !isLoading) {
        _handleDayTransition();
      }
    });

    if (isLoading) {
      return Scaffold(
        backgroundColor: isDarkMode ? kBlack : kWhite,
        appBar: AppBar(
          backgroundColor: kAccent,
          elevation: 0,
          centerTitle: true,
          title: Text(
            'Loading...',
            style: textTheme.displaySmall?.copyWith(
              fontSize: getTextScale(7, context),
              fontWeight: FontWeight.w200,
            ),
          ),
          automaticallyImplyLeading: true,
          toolbarHeight: getPercentageHeight(10, context),
          iconTheme: IconThemeData(
            color: isDarkMode ? kWhite : kBlack,
          ),
        ),
        body: const Center(
          child: CircularProgressIndicator(color: kAccent),
        ),
      );
    }

    return Scaffold(
      backgroundColor: isDarkMode ? kBlack : kWhite,
      appBar: AppBar(
        backgroundColor: kAccent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          capitalizeFirstLetter(programData?['type'] ??
              (userPrograms.isNotEmpty
                  ? userPrograms[currentProgramIndex]['type']
                  : null) ??
              widget.programName ??
              'Program Progress'),
          style: textTheme.displaySmall?.copyWith(
            fontSize: getTextScale(7, context),
          ),
          maxLines: 2,
          textAlign: TextAlign.center,
        ),
        automaticallyImplyLeading: true,
        toolbarHeight: getPercentageHeight(10, context),
        iconTheme: IconThemeData(
          color: isDarkMode ? kWhite : kBlack,
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section Header
            SizedBox(height: getPercentageHeight(2, context)),

            // Program Navigator (only if multiple programs)
            _buildProgramNavigator(),
            if (userPrograms.length > 1)
              SizedBox(height: getPercentageHeight(1, context)),

            // Program Completion Card (if completed)
            _buildProgramCompletionCard(),

            // Program Name
            Center(
              child: Column(
                children: [
                  Text(
                    widget.programName ??
                        programData?['name'] ??
                        (userPrograms.isNotEmpty
                            ? userPrograms[currentProgramIndex]['name']
                            : null) ??
                        'Program Progress',
                    style: textTheme.displayMedium?.copyWith(
                      fontSize: getTextScale(5, context),
                      fontWeight: FontWeight.w600,
                      color: kAccent,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: getPercentageHeight(1, context)),
                  Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: getPercentageWidth(3.5, context)),
                    child: Text(
                      widget.programDescription ??
                          programData?['description'] ??
                          (userPrograms.isNotEmpty
                              ? userPrograms[currentProgramIndex]['description']
                              : null) ??
                          'Program Progress',
                      textAlign: TextAlign.center,
                      style: textTheme.bodySmall?.copyWith(
                        color: isDarkMode ? kWhite : kDarkGrey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: getPercentageHeight(1.5, context)),

            // Progress Summary (only show if not completed)
            if (!isProgramCompleted) _buildProgressSummary(),

            //Benefits
            _buildBenefits(context, textTheme, isDarkMode),

            SizedBox(height: getPercentageHeight(2, context)),

            // Section Header
            _buildSectionHeader(
                title:
                    isProgramCompleted ? 'Program Summary' : 'Program Details'),

            SizedBox(height: getPercentageHeight(2, context)),

            // Program Components - Staggered Grid
            Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: getPercentageWidth(4, context)),
              child: programComponents.isEmpty
                  ? Container(
                      height: getPercentageHeight(20, context),
                      decoration: BoxDecoration(
                        color: isDarkMode ? kDarkGrey : Colors.grey[100],
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.assignment,
                              size: getIconScale(12, context),
                              color: isDarkMode
                                  ? kWhite.withValues(alpha: 0.5)
                                  : kDarkGrey.withValues(alpha: 0.5),
                            ),
                            SizedBox(height: getPercentageHeight(1, context)),
                            Text(
                              'No program components available',
                              style: textTheme.bodyLarge?.copyWith(
                                color: isDarkMode
                                    ? kWhite.withValues(alpha: 0.7)
                                    : kDarkGrey.withValues(alpha: 0.7),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  : StaggeredGrid.count(
                      crossAxisCount: 2,
                      mainAxisSpacing: getPercentageHeight(1, context),
                      crossAxisSpacing: getPercentageWidth(3, context),
                      children: programComponents.asMap().entries.map((entry) {
                        final index = entry.key;
                        final component = entry.value;

                        // Vary the heights for Pinterest-like effect
                        double cardHeight;
                        if (component['id'] == 'healthy_recipes') {
                          cardHeight = getCardHeight(index, true, context);
                        } else if (index % 3 == 0) {
                          cardHeight = getCardHeight(index, false, context);
                        } else if (index % 2 == 0) {
                          cardHeight = getCardHeight(index, false, context);
                        } else {
                          cardHeight = getCardHeight(index, false, context);
                        }

                        return StaggeredGridTile.fit(
                          crossAxisCellCount: 1,
                          child: _buildComponentCard(component, cardHeight),
                        );
                      }).toList(),
                    ),
            ),

            SizedBox(height: getPercentageHeight(3, context)),
          ],
        ),
      ),
    );
  }
}

double getCardHeight(int index, bool isMeal, BuildContext context) {
  Random random = Random();
  double minHeight = 20;
  double maxHeight = 30;
  double range = maxHeight - minHeight;

  if (isMeal) {
    return getPercentageHeight(
        minHeight + 5 + (random.nextDouble() * range), context);
  } else {
    return getPercentageHeight(
        minHeight + (random.nextDouble() * range), context);
  }
}
