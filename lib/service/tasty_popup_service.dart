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

  // Single key for first time user check
  final String _firstTimeUserKey = 'is_first_time_user';
  final Map<String, bool> _shownTutorials = {};

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

  bool hasShownTutorial(String tutorialId) {
    return _shownTutorials[tutorialId] ?? false;
  }

  void markTutorialShown(String tutorialId) {
    _shownTutorials[tutorialId] = true;
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
    Duration delayBetween = const Duration(seconds: 2),
  }) async {
    if (_isShowingSequence) return;
    if (!await isFirstTimeUser()) return;

    _isShowingSequence = true;

    for (int i = 0; i < tutorials.length; i++) {
      final tutorial = tutorials[i];

      if (!hasShownTutorial(tutorial.tutorialId)) {
        // Wait for the delay between tutorials (except for the first one)
        if (i > 0) {
          await Future.delayed(delayBetween);
        }

        // Check if we're still in sequence (user hasn't cancelled)
        if (!_isShowingSequence) break;

        await showTutorialPopup(
          context: context,
          tutorialId: tutorial.tutorialId,
          message: tutorial.message,
          targetKey: tutorial.targetKey,
          onComplete: () {
            tutorial.onComplete?.call();
            // Don't mark sequence complete until the last tutorial
            if (i == tutorials.length - 1) {
              _isShowingSequence = false;
              markTutorialComplete();
            }
          },
          autoCloseDuration: tutorial.autoCloseDuration,
          padding: tutorial.padding,
          showArrow: tutorial.showArrow,
          arrowDirection: tutorial.arrowDirection,
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
    EdgeInsets padding = const EdgeInsets.all(8.0),
    bool showArrow = true,
    Duration autoCloseDuration = const Duration(seconds: 5),
    ArrowDirection arrowDirection = ArrowDirection.UP,
  }) async {
    if (!await isFirstTimeUser() || hasShownTutorial(tutorialId)) {
      return;
    }

    // Remove any existing overlay
    removeCurrentOverlay();

    // Get the target widget's position
    final RenderBox? renderBox =
        targetKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final targetPosition = renderBox.localToGlobal(Offset.zero);
    final targetSize = renderBox.size;
    final screenSize = MediaQuery.of(context).size;

    OverlayEntry overlayEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          // Semi-transparent background
          Positioned.fill(
            child: GestureDetector(
              onTap: () {
                removeCurrentOverlay();
                markTutorialComplete();
                onComplete();
              },
              child: Container(
                color: Colors.black.withOpacity(0.5),
              ),
            ),
          ),
          // Tutorial popup
          Positioned(
            left: _calculateLeftPosition(targetPosition.dx, targetSize.width,
                screenSize.width, arrowDirection),
            top: _calculateTopPosition(targetPosition.dy, targetSize.height,
                screenSize.height, arrowDirection),
            child: Material(
              color: Colors.transparent,
              child: _buildPopupContent(
                context,
                message,
                padding,
                showArrow,
                arrowDirection,
                onComplete,
              ),
            ),
          ),
        ],
      ),
    );

    _currentOverlay = overlayEntry;
    Overlay.of(context).insert(overlayEntry);
    markTutorialShown(tutorialId);

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

  Widget _buildPopupContent(
    BuildContext context,
    String message,
    EdgeInsets padding,
    bool showArrow,
    ArrowDirection arrowDirection,
    VoidCallback onComplete,
  ) {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    final arrowSize = const Size(20, 10);

    return Column(
      crossAxisAlignment: _getCrossAxisAlignment(arrowDirection),
      children: [
        if (showArrow && arrowDirection == ArrowDirection.UP)
          CustomPaint(
            size: arrowSize,
            painter: ArrowPainter(
              color: isDarkMode ? kDarkGrey : kWhite,
              direction: arrowDirection,
            ),
          ),
        if (showArrow && arrowDirection == ArrowDirection.LEFT)
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CustomPaint(
                size: const Size(10, 20),
                painter: ArrowPainter(
                  color: isDarkMode ? kDarkGrey : kWhite,
                  direction: arrowDirection,
                ),
              ),
              _buildPopupContainer(context, message, padding, onComplete),
            ],
          ),
        if (arrowDirection == ArrowDirection.UP ||
            arrowDirection == ArrowDirection.DOWN)
          _buildPopupContainer(context, message, padding, onComplete),
        if (showArrow && arrowDirection == ArrowDirection.RIGHT)
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildPopupContainer(context, message, padding, onComplete),
              CustomPaint(
                size: const Size(10, 20),
                painter: ArrowPainter(
                  color: isDarkMode ? kDarkGrey : kWhite,
                  direction: arrowDirection,
                ),
              ),
            ],
          ),
        if (showArrow && arrowDirection == ArrowDirection.DOWN)
          CustomPaint(
            size: arrowSize,
            painter: ArrowPainter(
              color: isDarkMode ? kDarkGrey : kWhite,
              direction: arrowDirection,
            ),
          ),
      ],
    );
  }

  Widget _buildPopupContainer(
    BuildContext context,
    String message,
    EdgeInsets padding,
    VoidCallback onComplete,
  ) {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.8,
        minWidth: MediaQuery.of(context).size.width * 0.3,
      ),
      padding: padding,
      decoration: BoxDecoration(
        color: isDarkMode ? kDarkGrey : kWhite,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const CircleAvatar(
                backgroundColor: kAccentLight,
                radius: 15,
                backgroundImage: AssetImage(tastyImage),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDarkMode ? kWhite : kBlack,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onComplete,
              style: TextButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                minimumSize: const Size(60, 30),
              ),
              child: const Text(
                'Got it',
                style: TextStyle(color: kAccent),
              ),
            ),
          ),
        ],
      ),
    );
  }

  CrossAxisAlignment _getCrossAxisAlignment(ArrowDirection direction) {
    switch (direction) {
      case ArrowDirection.LEFT:
        return CrossAxisAlignment.start;
      case ArrowDirection.RIGHT:
        return CrossAxisAlignment.end;
      default:
        return CrossAxisAlignment.start;
    }
  }

  double _calculateLeftPosition(
    double targetX,
    double targetWidth,
    double screenWidth,
    ArrowDirection direction,
  ) {
    switch (direction) {
      case ArrowDirection.LEFT:
        return targetX + targetWidth + 10;
      case ArrowDirection.RIGHT:
        return targetX - 320;
      default:
        double left = targetX + targetWidth / 2;
        if (left + 300 > screenWidth) {
          left = screenWidth - 320;
        }
        if (left < 20) left = 20;
        return left;
    }
  }

  double _calculateTopPosition(
    double targetY,
    double targetHeight,
    double screenHeight,
    ArrowDirection direction,
  ) {
    switch (direction) {
      case ArrowDirection.UP:
        return targetY + targetHeight + 10;
      case ArrowDirection.DOWN:
        return targetY - 160;
      case ArrowDirection.LEFT:
      case ArrowDirection.RIGHT:
        return targetY - targetHeight / 2;
      default:
        double top = targetY + targetHeight + 10;
        if (top + 150 > screenHeight) {
          top = targetY - 160;
        }
        if (top < 20) top = 20;
        return top;
    }
  }
}

enum ArrowDirection { UP, DOWN, LEFT, RIGHT }

class ArrowPainter extends CustomPainter {
  final Color color;
  final ArrowDirection direction;

  ArrowPainter({
    required this.color,
    required this.direction,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();

    switch (direction) {
      case ArrowDirection.UP:
        path
          ..moveTo(0, size.height)
          ..lineTo(size.width / 2, 0)
          ..lineTo(size.width, size.height)
          ..close();
        break;
      case ArrowDirection.DOWN:
        path
          ..moveTo(0, 0)
          ..lineTo(size.width / 2, size.height)
          ..lineTo(size.width, 0)
          ..close();
        break;
      case ArrowDirection.LEFT:
        path
          ..moveTo(size.width, 0)
          ..lineTo(0, size.height / 2)
          ..lineTo(size.width, size.height)
          ..close();
        break;
      case ArrowDirection.RIGHT:
        path
          ..moveTo(0, 0)
          ..lineTo(size.width, size.height / 2)
          ..lineTo(0, size.height)
          ..close();
        break;
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class TutorialStep {
  final String tutorialId;
  final String message;
  final GlobalKey targetKey;
  final VoidCallback? onComplete;
  final EdgeInsets padding;
  final bool showArrow;
  final Duration autoCloseDuration;
  final ArrowDirection arrowDirection;

  TutorialStep({
    required this.tutorialId,
    required this.message,
    required this.targetKey,
    this.onComplete,
    this.padding = const EdgeInsets.all(8.0),
    this.showArrow = true,
    this.autoCloseDuration = const Duration(seconds: 5),
    this.arrowDirection = ArrowDirection.UP,
  });
}

// Updated example usage:
/*
final GlobalKey buttonKey1 = GlobalKey();
final GlobalKey buttonKey2 = GlobalKey();

// In your widget:
TutorialPopupService().showSequentialTutorials(
  context: context,
  tutorials: [
    TutorialStep(
      tutorialId: 'add_food_button',
      message: 'Tap here to add your meals!',
      targetKey: buttonKey1,
      onComplete: () {
        // Handle first tutorial completion
      },
    ),
    TutorialStep(
      tutorialId: 'settings_button',
      message: 'Access your settings here',
      targetKey: buttonKey2,
      onComplete: () {
        // Handle second tutorial completion
      },
    ),
  ],
);
*/
