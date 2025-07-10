import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../constants.dart';
import '../themes/theme_provider.dart';

class TutorialPopupService {
  static final TutorialPopupService _instance =
      TutorialPopupService._internal();
  factory TutorialPopupService() => _instance;
  TutorialPopupService._internal();

  // Restore first time user key logic
  final String _firstTimeUserKey = 'is_first_time_user';

  final List<String> allTutorialSequenceKeys = [
    'meal_design_tutorial',
    'food_tab_tutorial',
    'home_screen_tutorial',
    'spin_wheel_tutorial',
    'message_screen_tutorial',
    'bottom_nav_tutorial',
    // Add more as needed
  ];

  ThemeProvider getThemeProvider(BuildContext context) {
    return Provider.of<ThemeProvider>(context, listen: false);
  }

  Future<bool> isFirstTimeUser() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_firstTimeUserKey) ?? true;
  }

  Future<void> markTutorialComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_firstTimeUserKey, false);
  }

  Future<bool> hasShownTutorial(String tutorialId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('tutorial_shown_$tutorialId') ?? false;
  }

  Future<void> markTutorialShown(String tutorialId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('tutorial_shown_$tutorialId', true);
  }

  OverlayEntry? _currentOverlay;
  bool _isShowingSequence = false;

  void removeCurrentOverlay() {
    _currentOverlay?.remove();
    _currentOverlay = null;
  }

  Future<void> showSequentialTutorials({
    required BuildContext context,
    required List<TutorialStep> tutorials,
    required String sequenceKey,
    Duration delayBetween = const Duration(seconds: 5),
  }) async {
    if (_isShowingSequence) return;
    if (!await isFirstTimeUser()) return;
    if (await isSequenceComplete(sequenceKey)) return;

    _isShowingSequence = true;

    for (int i = 0; i < tutorials.length; i++) {
      final tutorial = tutorials[i];
      if (!await hasShownTutorial(tutorial.tutorialId)) {
        if (i > 0) await Future.delayed(delayBetween);
        if (!_isShowingSequence) break;

        await showTutorialPopup(
          context: context,
          tutorialId: tutorial.tutorialId,
          title: tutorial.title,
          message: tutorial.message,
          targetKey: tutorial.targetKey,
          onComplete: () async {
            tutorial.onComplete?.call();
            if (i == tutorials.length - 1) {
              _isShowingSequence = false;
              await markSequenceComplete(sequenceKey);
              if (await areAllSequencesComplete()) {
                await markTutorialComplete();
              }
            }
          },
          onSkip: tutorial.onSkip,
          stepNumber: i + 1,
          totalSteps: tutorials.length,
          showProgress: tutorial.showProgress,
          autoCloseDuration: tutorial.autoCloseDuration,
        );
      }
    }
    _isShowingSequence = false;
  }

  void cancelSequence() {
    _isShowingSequence = false;
    removeCurrentOverlay();
  }

  Future<void> showTutorialPopup({
    required BuildContext context,
    required String tutorialId,
    required String message,
    required GlobalKey targetKey,
    required VoidCallback onComplete,
    String? title,
    VoidCallback? onSkip,
    int? stepNumber,
    int? totalSteps,
    bool showProgress = false,
    Duration autoCloseDuration = Duration.zero,
  }) async {
    if (await hasShownTutorial(tutorialId)) {
      return;
    }

    // Remove any existing overlay
    removeCurrentOverlay();

    // Get the target widget's position and size
    final RenderBox? renderBox =
        targetKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final targetPosition = renderBox.localToGlobal(Offset.zero);
    final targetSize = renderBox.size;
    final screenSize = MediaQuery.of(context).size;

    // Calculate optimal popup position
    final popupInfo = _calculateOptimalPosition(
      targetPosition,
      targetSize,
      screenSize,
    );

    OverlayEntry overlayEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          // Animated background
          TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 300),
            tween: Tween(begin: 0.0, end: 1.0),
            builder: (context, value, child) {
              return Container(
                color: Colors.black.withValues(alpha: 0.6 * value),
              );
            },
          ),

          // Highlight target widget
          Positioned(
            left: targetPosition.dx - 8,
            top: targetPosition.dy - 8,
            child: TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 400),
              tween: Tween(begin: 0.0, end: 1.0),
              builder: (context, value, child) {
                return Container(
                  width: targetSize.width + 16,
                  height: targetSize.height + 16,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: kAccent.withValues(alpha: value),
                      width: 3,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: kAccent.withValues(alpha: 0.3 * value),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // Tutorial popup
          Positioned(
            left: popupInfo.position.dx,
            top: popupInfo.position.dy,
            child: TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 400),
              tween: Tween(begin: 0.0, end: 1.0),
              curve: Curves.elasticOut,
              builder: (context, value, child) {
                return Transform.scale(
                  scale: value,
                  child: Material(
                    color: Colors.transparent,
                    child: _buildModernPopup(
                      context,
                      title,
                      message,
                      stepNumber,
                      totalSteps,
                      showProgress,
                      popupInfo.arrowDirection,
                      onComplete,
                      onSkip,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );

    _currentOverlay = overlayEntry;
    Overlay.of(context).insert(overlayEntry);
    await markTutorialShown(tutorialId);

    // Auto close after duration if specified
    if (autoCloseDuration != Duration.zero) {
      Future.delayed(autoCloseDuration, () {
        if (_currentOverlay == overlayEntry) {
          removeCurrentOverlay();
          onComplete();
        }
      });
    }
  }

  PopupPositionInfo _calculateOptimalPosition(
    Offset targetPosition,
    Size targetSize,
    Size screenSize,
  ) {
    const double popupWidth = 280.0;
    const double popupHeight = 120.0;
    const double margin = 16.0;
    const double arrowSize = 12.0;

    // Calculate center of target
    final targetCenter = Offset(
      targetPosition.dx + targetSize.width / 2,
      targetPosition.dy + targetSize.height / 2,
    );

    // Try different positions in order of preference
    final positions = [
      // Bottom (preferred)
      _PositionCandidate(
        position: Offset(
          (targetCenter.dx - popupWidth / 2)
              .clamp(margin, screenSize.width - popupWidth - margin),
          targetPosition.dy + targetSize.height + arrowSize + margin,
        ),
        arrowDirection: ArrowDirection.UP,
        score: _calculatePositionScore(
          Offset(targetCenter.dx - popupWidth / 2,
              targetPosition.dy + targetSize.height + arrowSize + margin),
          Size(popupWidth, popupHeight),
          screenSize,
          margin,
        ),
      ),

      // Top
      _PositionCandidate(
        position: Offset(
          (targetCenter.dx - popupWidth / 2)
              .clamp(margin, screenSize.width - popupWidth - margin),
          targetPosition.dy - popupHeight - arrowSize - margin,
        ),
        arrowDirection: ArrowDirection.DOWN,
        score: _calculatePositionScore(
          Offset(targetCenter.dx - popupWidth / 2,
              targetPosition.dy - popupHeight - arrowSize - margin),
          Size(popupWidth, popupHeight),
          screenSize,
          margin,
        ),
      ),

      // Right
      _PositionCandidate(
        position: Offset(
          targetPosition.dx + targetSize.width + arrowSize + margin,
          (targetCenter.dy - popupHeight / 2)
              .clamp(margin, screenSize.height - popupHeight - margin),
        ),
        arrowDirection: ArrowDirection.LEFT,
        score: _calculatePositionScore(
          Offset(targetPosition.dx + targetSize.width + arrowSize + margin,
              targetCenter.dy - popupHeight / 2),
          Size(popupWidth, popupHeight),
          screenSize,
          margin,
        ),
      ),

      // Left
      _PositionCandidate(
        position: Offset(
          targetPosition.dx - popupWidth - arrowSize - margin,
          (targetCenter.dy - popupHeight / 2)
              .clamp(margin, screenSize.height - popupHeight - margin),
        ),
        arrowDirection: ArrowDirection.RIGHT,
        score: _calculatePositionScore(
          Offset(targetPosition.dx - popupWidth - arrowSize - margin,
              targetCenter.dy - popupHeight / 2),
          Size(popupWidth, popupHeight),
          screenSize,
          margin,
        ),
      ),
    ];

    // Find the best position
    positions.sort((a, b) => b.score.compareTo(a.score));
    final bestPosition = positions.first;

    return PopupPositionInfo(
      position: bestPosition.position,
      arrowDirection: bestPosition.arrowDirection,
    );
  }

  double _calculatePositionScore(
      Offset position, Size popupSize, Size screenSize, double margin) {
    double score = 100.0;

    // Penalize if popup goes off screen
    if (position.dx < margin) score -= (margin - position.dx) * 2;
    if (position.dy < margin) score -= (margin - position.dy) * 2;
    if (position.dx + popupSize.width > screenSize.width - margin) {
      score -= (position.dx + popupSize.width - screenSize.width + margin) * 2;
    }
    if (position.dy + popupSize.height > screenSize.height - margin) {
      score -=
          (position.dy + popupSize.height - screenSize.height + margin) * 2;
    }

    return score.clamp(0.0, 100.0);
  }

  Widget _buildModernPopup(
    BuildContext context,
    String? title,
    String message,
    int? stepNumber,
    int? totalSteps,
    bool showProgress,
    ArrowDirection arrowDirection,
    VoidCallback onComplete,
    VoidCallback? onSkip,
  ) {
    final isDarkMode = getThemeProvider(context).isDarkMode;

    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: isDarkMode ? kDarkGrey : kWhite,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 24,
            spreadRadius: 0,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header with progress
          if (showProgress && stepNumber != null && totalSteps != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: kAccent.withValues(alpha: 0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: kAccent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$stepNumber of $totalSteps',
                      style: const TextStyle(
                        color: kWhite,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: LinearProgressIndicator(
                      value: stepNumber / totalSteps,
                      backgroundColor: kAccent.withValues(alpha: 0.2),
                      valueColor: const AlwaysStoppedAnimation<Color>(kAccent),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ),
            ),

          // Content
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                if (title != null)
                  Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: kAccent.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.lightbulb_outline,
                              color: kAccent,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              title,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: isDarkMode ? kWhite : kBlack,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),

                // Message
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDarkMode
                        ? kWhite.withValues(alpha: 0.9)
                        : kBlack.withValues(alpha: 0.8),
                    height: 1.4,
                  ),
                ),

                const SizedBox(height: 20),

                // Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (onSkip != null)
                      TextButton(
                        onPressed: () {
                          removeCurrentOverlay();
                          onSkip();
                        },
                        child: Text(
                          'Skip',
                          style: TextStyle(
                            color: isDarkMode
                                ? kWhite.withValues(alpha: 0.6)
                                : kBlack.withValues(alpha: 0.6),
                            fontSize: 14,
                          ),
                        ),
                      ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        removeCurrentOverlay();
                        onComplete();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kAccent,
                        foregroundColor: kWhite,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        stepNumber != null &&
                                totalSteps != null &&
                                stepNumber < totalSteps
                            ? 'Next'
                            : 'Got it!',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<bool> isSequenceComplete(String sequenceKey) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('sequence_complete_$sequenceKey') ?? false;
  }

  Future<void> markSequenceComplete(String sequenceKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('sequence_complete_$sequenceKey', true);
  }

  Future<bool> areAllSequencesComplete() async {
    for (final key in allTutorialSequenceKeys) {
      if (!await isSequenceComplete(key)) return false;
    }
    return true;
  }
}

class _PositionCandidate {
  final Offset position;
  final ArrowDirection arrowDirection;
  final double score;

  _PositionCandidate({
    required this.position,
    required this.arrowDirection,
    required this.score,
  });
}

class PopupPositionInfo {
  final Offset position;
  final ArrowDirection arrowDirection;

  PopupPositionInfo({
    required this.position,
    required this.arrowDirection,
  });
}

enum ArrowDirection { UP, DOWN, LEFT, RIGHT }

class TutorialStep {
  final String tutorialId;
  final String? title;
  final String message;
  final GlobalKey targetKey;
  final VoidCallback? onComplete;
  final VoidCallback? onSkip;
  final bool showProgress;
  final Duration autoCloseDuration;

  TutorialStep({
    required this.tutorialId,
    required this.message,
    required this.targetKey,
    this.title,
    this.onComplete,
    this.onSkip,
    this.showProgress = true,
    this.autoCloseDuration = Duration.zero,
  });
}
