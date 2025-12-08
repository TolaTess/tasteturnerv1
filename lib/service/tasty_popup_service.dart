import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../constants.dart';
import '../themes/theme_provider.dart';
import '../helper/utils.dart'; // Import for percentage functions

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
    'program_screen_tutorial',
    'message_screen_tutorial',
    'profile_screen_tutorial',
    'inspiration_screen_tutorial',
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
    if (_currentOverlay != null) {
      debugPrint('[TUTORIAL] 🗑️ Removing tutorial overlay');
      _currentOverlay?.remove();
      _currentOverlay = null;
    }
  }

  Future<void> showSequentialTutorials({
    required BuildContext context,
    required List<TutorialStep> tutorials,
    required String sequenceKey,
    Duration delayBetween = const Duration(seconds: 3),
  }) async {
    debugPrint(
        '[TUTORIAL] showSequentialTutorials called for sequence: $sequenceKey');

    if (_isShowingSequence) {
      debugPrint('[TUTORIAL] ⚠️ Already showing sequence, skipping');
      return;
    }
    if (!await isFirstTimeUser()) {
      debugPrint('[TUTORIAL] ⚠️ Not first time user, skipping');
      return;
    }
    if (await isSequenceComplete(sequenceKey)) {
      debugPrint('[TUTORIAL] ⚠️ Sequence already complete: $sequenceKey');
      return;
    }

    debugPrint(
        '[TUTORIAL] ✅ Starting tutorial sequence: $sequenceKey (${tutorials.length} steps)');
    _isShowingSequence = true;

    for (int i = 0; i < tutorials.length; i++) {
      final tutorial = tutorials[i];
      if (!await hasShownTutorial(tutorial.tutorialId)) {
        if (i > 0) {
          debugPrint(
              '[TUTORIAL] ⏳ Waiting ${delayBetween.inSeconds}s before next tutorial...');
          await Future.delayed(delayBetween);
        }
        if (!_isShowingSequence) {
          debugPrint(
              '[TUTORIAL] ⚠️ Sequence cancelled during delay, breaking loop');
          break;
        }

        debugPrint(
            '[TUTORIAL] 📍 Showing tutorial step ${i + 1}/${tutorials.length}: ${tutorial.tutorialId}');
        await showTutorialPopup(
          context: context,
          tutorialId: tutorial.tutorialId,
          title: tutorial.title,
          message: tutorial.message,
          targetKey: tutorial.targetKey,
          onComplete: () async {
            debugPrint(
                '[TUTORIAL] ✅ Tutorial step completed: ${tutorial.tutorialId}');
            tutorial.onComplete?.call();
            if (i == tutorials.length - 1) {
              debugPrint(
                  '[TUTORIAL] 🎉 Last tutorial step completed, finishing sequence');
              _isShowingSequence = false;
              await markSequenceComplete(sequenceKey);
              if (await areAllSequencesComplete()) {
                debugPrint(
                    '[TUTORIAL] 🏁 All sequences complete, marking tutorial as done');
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
      } else {
        debugPrint(
            '[TUTORIAL] ⏭️ Skipping already shown tutorial: ${tutorial.tutorialId}');
      }
    }

    _isShowingSequence = false;
    debugPrint('[TUTORIAL] 📝 Sequence finished: $sequenceKey');
  }

  void cancelSequence() {
    debugPrint('[TUTORIAL] 🚫 Cancelling tutorial sequence');
    _isShowingSequence = false;
    removeCurrentOverlay();
  }

  /// Scroll to make the target widget visible
  Future<void> _scrollToWidget(GlobalKey targetKey) async {
    final context = targetKey.currentContext;
    if (context == null) {
      debugPrint('[TUTORIAL] ⚠️ Cannot scroll: target context is null');
      return;
    }

    // Find the nearest Scrollable ancestor
    final scrollableState = Scrollable.maybeOf(context);
    if (scrollableState == null) {
      debugPrint('[TUTORIAL] ⚠️ Cannot scroll: no Scrollable ancestor found');
      return;
    }

    final scrollController = scrollableState.widget.controller;
    if (scrollController == null || !scrollController.hasClients) {
      debugPrint(
          '[TUTORIAL] ⚠️ Cannot scroll: ScrollController not available or not attached');
      return;
    }

    // Get the target widget's position
    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) {
      debugPrint('[TUTORIAL] ⚠️ Cannot scroll: target RenderBox is null');
      return;
    }

    // Calculate the position relative to the scroll view
    final targetPosition = renderBox.localToGlobal(Offset.zero);
    final scrollPosition =
        scrollableState.context.findRenderObject() as RenderBox?;
    if (scrollPosition == null) {
      debugPrint('[TUTORIAL] ⚠️ Cannot scroll: Scrollable RenderBox is null');
      return;
    }

    final scrollGlobalPosition = scrollPosition.localToGlobal(Offset.zero);
    final relativeY = targetPosition.dy - scrollGlobalPosition.dy;

    // Add some padding to ensure the widget is fully visible
    const padding = 20.0;
    final targetScrollOffset = scrollController.offset + relativeY - padding;

    debugPrint(
        '[TUTORIAL] 📜 Scrolling to widget: current offset=${scrollController.offset}, target offset=$targetScrollOffset');

    // Scroll to the target widget
    await scrollController.animateTo(
      targetScrollOffset.clamp(0.0, scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );

    // Wait a bit for the scroll animation to complete
    await Future.delayed(const Duration(milliseconds: 350));
    debugPrint('[TUTORIAL] ✅ Scroll completed');
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
    debugPrint('[TUTORIAL] 🎯 showTutorialPopup called: $tutorialId');

    if (await hasShownTutorial(tutorialId)) {
      debugPrint('[TUTORIAL] ⏭️ Tutorial already shown, skipping: $tutorialId');
      return;
    }

    // Remove any existing overlay
    removeCurrentOverlay();

    // Scroll to the target widget first
    debugPrint('[TUTORIAL] 📜 Scrolling to target widget: $tutorialId');
    await _scrollToWidget(targetKey);

    // Get the target widget's position and size
    final RenderBox? renderBox =
        targetKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) {
      debugPrint('[TUTORIAL] ⚠️ Target widget not found for: $tutorialId');
      return;
    }

    debugPrint(
        '[TUTORIAL] ✅ Target widget found, creating overlay for: $tutorialId');

    final targetPosition = renderBox.localToGlobal(Offset.zero);
    final targetSize = renderBox.size;
    final screenSize = MediaQuery.of(context).size;

    // Calculate optimal popup position
    final popupInfo = _calculateOptimalPosition(
      context,
      targetPosition,
      targetSize,
      screenSize,
    );

    bool canDismissOnTap = false;

    // Enable tap-to-dismiss after 5 seconds
    Future.delayed(const Duration(seconds: 5), () {
      canDismissOnTap = true;
    });

    OverlayEntry overlayEntry = OverlayEntry(
      builder: (context) => GestureDetector(
        onTap: () {
          if (canDismissOnTap) {
            removeCurrentOverlay();
            onComplete();
          }
        },
        child: Stack(
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
                        popupInfo.popupSize,
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
      ),
    );

    _currentOverlay = overlayEntry;
    Overlay.of(context).insert(overlayEntry);
    debugPrint('[TUTORIAL] 📌 Overlay inserted for tutorial: $tutorialId');
    await markTutorialShown(tutorialId);

    // Auto close after duration if specified
    if (autoCloseDuration != Duration.zero) {
      debugPrint(
          '[TUTORIAL] ⏰ Auto-close scheduled for ${autoCloseDuration.inSeconds}s: $tutorialId');
      Future.delayed(autoCloseDuration, () {
        if (_currentOverlay == overlayEntry) {
          debugPrint('[TUTORIAL] ⏰ Auto-closing tutorial: $tutorialId');
          removeCurrentOverlay();
          onComplete();
        }
      });
    }
  }

  PopupPositionInfo _calculateOptimalPosition(
    BuildContext context,
    Offset targetPosition,
    Size targetSize,
    Size screenSize,
  ) {
    // Use responsive sizing based on screen size
    final double basePopupWidth = getPercentageWidth(75, context);
    final double basePopupHeight = getPercentageHeight(20, context);

    final double popupWidth = basePopupWidth.clamp(
        250.0, screenSize.width * 0.9); // Ensure it fits on screen
    final double popupHeight = basePopupHeight.clamp(
        120.0, screenSize.height * 0.4); // Ensure it fits on screen
    final double margin = getPercentageWidth(4, context).clamp(12.0, 20.0);
    final double arrowSize = getPercentageWidth(3, context).clamp(8.0, 12.0);

    // Calculate available space in all directions
    final double spaceAbove = targetPosition.dy - margin;
    final double spaceBelow =
        screenSize.height - (targetPosition.dy + targetSize.height) - margin;
    final double spaceLeft = targetPosition.dx - margin;
    final double spaceRight =
        screenSize.width - (targetPosition.dx + targetSize.width) - margin;

    // Determine the best position based on available space
    ArrowDirection arrowDirection = ArrowDirection.DOWN;
    Offset popupPosition;

    // Try to position below first (most common case)
    if (spaceBelow >= popupHeight) {
      // Position below
      arrowDirection = ArrowDirection.UP;
      double left =
          targetPosition.dx + (targetSize.width / 2) - (popupWidth / 2);

      // Ensure popup doesn't go off-screen horizontally
      left = left.clamp(margin, screenSize.width - popupWidth - margin);

      popupPosition =
          Offset(left, targetPosition.dy + targetSize.height + arrowSize);
    } else if (spaceAbove >= popupHeight) {
      // Position above
      arrowDirection = ArrowDirection.DOWN;
      double left =
          targetPosition.dx + (targetSize.width / 2) - (popupWidth / 2);

      // Ensure popup doesn't go off-screen horizontally
      left = left.clamp(margin, screenSize.width - popupWidth - margin);

      popupPosition = Offset(left, targetPosition.dy - popupHeight - arrowSize);
    } else if (spaceRight >= popupWidth) {
      // Position to the right
      arrowDirection = ArrowDirection.LEFT;
      double top =
          targetPosition.dy + (targetSize.height / 2) - (popupHeight / 2);

      // Ensure popup doesn't go off-screen vertically
      top = top.clamp(margin, screenSize.height - popupHeight - margin);

      popupPosition =
          Offset(targetPosition.dx + targetSize.width + arrowSize, top);
    } else if (spaceLeft >= popupWidth) {
      // Position to the left
      arrowDirection = ArrowDirection.RIGHT;
      double top =
          targetPosition.dy + (targetSize.height / 2) - (popupHeight / 2);

      // Ensure popup doesn't go off-screen vertically
      top = top.clamp(margin, screenSize.height - popupHeight - margin);

      popupPosition = Offset(targetPosition.dx - popupWidth - arrowSize, top);
    } else {
      // Fallback: center on screen with reduced size
      final maxAvailableWidth = screenSize.width - 2 * margin;
      final maxAvailableHeight = screenSize.height - 2 * margin;

      final adjustedWidth = maxAvailableWidth.clamp(200.0, popupWidth);
      final adjustedHeight = maxAvailableHeight.clamp(120.0, popupHeight);

      popupPosition = Offset(
        (screenSize.width - adjustedWidth) / 2,
        (screenSize.height - adjustedHeight) / 2,
      );

      arrowDirection = ArrowDirection.UP; // Use UP as fallback

      return PopupPositionInfo(
        position: popupPosition,
        popupSize: Size(adjustedWidth, adjustedHeight),
        arrowDirection: arrowDirection,
      );
    }

    return PopupPositionInfo(
      position: popupPosition,
      popupSize: Size(popupWidth, popupHeight),
      arrowDirection: arrowDirection,
    );
  }

  Widget _buildModernPopup(
    BuildContext context,
    String? title,
    String message,
    int? stepNumber,
    int? totalSteps,
    bool showProgress,
    ArrowDirection arrowDirection,
    Size popupSize,
    VoidCallback onComplete,
    VoidCallback? onSkip,
  ) {
    final isDarkMode = getThemeProvider(context).isDarkMode;

    // Ensure constraints are always valid
    final minWidth =
        getPercentageWidth(60, context).clamp(200.0, popupSize.width);
    final minHeight =
        getPercentageHeight(12, context).clamp(100.0, popupSize.height);

    return Container(
      width: popupSize.width,
      constraints: BoxConstraints(
        maxHeight: popupSize.height,
        maxWidth: popupSize.width,
        minHeight: minHeight,
        minWidth: minWidth,
      ),
      decoration: BoxDecoration(
        color: isDarkMode ? kDarkGrey : kWhite,
        borderRadius: BorderRadius.circular(getPercentageWidth(4, context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: getPercentageWidth(6, context),
            spreadRadius: 0,
            offset: Offset(0, getPercentageHeight(1, context)),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header with progress
          if (showProgress && stepNumber != null && totalSteps != null)
            Container(
              padding: EdgeInsets.all(getPercentageWidth(4, context)),
              decoration: BoxDecoration(
                color: kAccent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(getPercentageWidth(4, context)),
                  topRight: Radius.circular(getPercentageWidth(4, context)),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: getPercentageWidth(2, context),
                      vertical: getPercentageHeight(0.5, context),
                    ),
                    decoration: BoxDecoration(
                      color: kAccent,
                      borderRadius:
                          BorderRadius.circular(getPercentageWidth(3, context)),
                    ),
                    child: Text(
                      '$stepNumber of $totalSteps',
                      style: TextStyle(
                        color: kWhite,
                        fontSize: getTextScale(3, context),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  SizedBox(width: getPercentageWidth(3, context)),
                  Expanded(
                    child: LinearProgressIndicator(
                      value: stepNumber / totalSteps,
                      backgroundColor: kAccent.withValues(alpha: 0.2),
                      valueColor: const AlwaysStoppedAnimation<Color>(kAccent),
                      borderRadius: BorderRadius.circular(
                          getPercentageWidth(0.5, context)),
                    ),
                  ),
                ],
              ),
            ),

          // Content
          Flexible(
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.all(getPercentageWidth(5, context)),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    if (title != null)
                      Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: EdgeInsets.all(
                                    getPercentageWidth(2, context)),
                                decoration: BoxDecoration(
                                  color: kAccent.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(
                                      getPercentageWidth(2, context)),
                                ),
                                child: Icon(
                                  Icons.lightbulb_outline,
                                  color: kAccent,
                                  size: getIconScale(5, context),
                                ),
                              ),
                              SizedBox(width: getPercentageWidth(3, context)),
                              Expanded(
                                child: Text(
                                  title,
                                  style: TextStyle(
                                    fontSize: getTextScale(4, context),
                                    fontWeight: FontWeight.w600,
                                    color: isDarkMode ? kWhite : kBlack,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: getPercentageHeight(1.5, context)),
                        ],
                      ),

                    // Message
                    Text(
                      capitalizeFirstLetter(message),
                      style: TextStyle(
                        fontSize: getTextScale(3.5, context),
                        color: isDarkMode
                            ? kWhite.withValues(alpha: 0.9)
                            : kBlack.withValues(alpha: 0.8),
                      ),
                    ),
                    SizedBox(height: getPercentageHeight(0.5, context)),

                    // Actions
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (onSkip != null)
                          TextButton(
                            onPressed: () {
                              removeCurrentOverlay();
                              // Note: onSkip callback should handle setting _isTutorialActive if needed
                              onSkip();
                            },
                            child: Text(
                              'Skip',
                              style: TextStyle(
                                color: isDarkMode
                                    ? kWhite.withValues(alpha: 0.6)
                                    : kBlack.withValues(alpha: 0.6),
                                fontSize: getTextScale(3.5, context),
                              ),
                            ),
                          ),
                        // Tap to dismiss hint (appears after 5 seconds)
                        TweenAnimationBuilder<double>(
                          duration: const Duration(seconds: 5),
                          tween: Tween(begin: 0.0, end: 1.0),
                          builder: (context, value, child) {
                            return AnimatedOpacity(
                              opacity: value >= 1.0 ? 1.0 : 0.0,
                              duration: const Duration(milliseconds: 300),
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: getPercentageWidth(3, context),
                                  vertical: getPercentageHeight(0.8, context),
                                ),
                                decoration: BoxDecoration(
                                  color: isDarkMode
                                      ? kWhite.withValues(alpha: 0.1)
                                      : kBlack.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(
                                      getPercentageWidth(2, context)),
                                ),
                                child: Text(
                                  'Tap anywhere to dismiss',
                                  style: TextStyle(
                                    fontSize: getTextScale(3, context),
                                    color: isDarkMode
                                        ? kWhite.withValues(alpha: 0.6)
                                        : kBlack.withValues(alpha: 0.6),
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                        SizedBox(width: getPercentageWidth(0.5, context)),
                        ElevatedButton(
                          onPressed: () {
                            removeCurrentOverlay();
                            onComplete();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kAccent,
                            foregroundColor: kWhite,
                            elevation: 0,
                            padding: EdgeInsets.symmetric(
                              horizontal: getPercentageWidth(5, context),
                              vertical: getPercentageHeight(1.2, context),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                  getPercentageWidth(2, context)),
                            ),
                          ),
                          child: Text(
                            stepNumber != null &&
                                    totalSteps != null &&
                                    stepNumber < totalSteps
                                ? 'Next'
                                : 'Got it!',
                            style: TextStyle(
                              fontSize: getTextScale(3.5, context),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
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

  // Method to reset all tutorial preferences for testing
  Future<void> resetTutorialPreferences() async {
    final prefs = await SharedPreferences.getInstance();

    // Reset first time user flag
    await prefs.setBool(_firstTimeUserKey, true);

    // Clear all tutorial shown flags
    final keys = prefs.getKeys();
    for (final key in keys) {
      if (key.startsWith('tutorial_shown_') ||
          key.startsWith('sequence_complete_')) {
        await prefs.remove(key);
      }
    }
  }
}


class PopupPositionInfo {
  final Offset position;
  final ArrowDirection arrowDirection;
  final Size popupSize;

  PopupPositionInfo({
    required this.position,
    required this.arrowDirection,
    required this.popupSize,
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
