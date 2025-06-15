import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../constants.dart';
import '../helper/utils.dart';
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
    Duration delayBetween = const Duration(seconds: 3),
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
    EdgeInsets padding = const EdgeInsets.all(4.0),
    bool showArrow = true,
    Duration autoCloseDuration = const Duration(seconds: 5),
    ArrowDirection arrowDirection = ArrowDirection.UP,
  }) async {
    if (await hasShownTutorial(tutorialId)) {
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

  Widget _buildPopupContent(
    BuildContext context,
    String message,
    EdgeInsets padding,
    bool showArrow,
    ArrowDirection arrowDirection,
    VoidCallback onComplete,
  ) {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    final arrowSize =
        Size(getPercentageWidth(5, context), getPercentageHeight(2.5, context));

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
                size: Size(getPercentageWidth(2.5, context),
                    getPercentageHeight(5, context)),
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
                size: Size(getPercentageWidth(2.5, context),
                    getPercentageHeight(5, context)),
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
        maxWidth: MediaQuery.of(context).size.width * 0.4,
        minWidth: MediaQuery.of(context).size.width * 0.3,
      ),
      padding: padding,
      decoration: BoxDecoration(
        color: isDarkMode ? kDarkGrey : kWhite,
        borderRadius: BorderRadius.circular(getPercentageWidth(3, context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: getPercentageWidth(2.5, context),
            offset: Offset(0, getPercentageHeight(1.25, context)),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              // CircleAvatar(
              //   backgroundColor: kAccentLight.withOpacity(0.5),
              //   radius: getPercentageWidth(3.75, context),
              //   backgroundImage: const AssetImage(tastyImage),
              // ),
              // SizedBox(width: getPercentageWidth(2, context)),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    fontSize: MediaQuery.of(context).size.width > 1000
                        ? getTextScale(2.5, context)
                        : getTextScale(3, context),
                    color: isDarkMode ? kWhite : kBlack,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: getPercentageHeight(1, context)),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onComplete,
              style: TextButton.styleFrom(
                padding: EdgeInsets.symmetric(
                    horizontal: getPercentageWidth(3, context),
                    vertical: getPercentageHeight(1.5, context)),
                minimumSize: Size(getPercentageWidth(15, context),
                    getPercentageHeight(7.5, context)),
              ),
              child: Text(
                'Got it',
                style: TextStyle(
                    color: kAccent, fontSize: getTextScale(3, context)),
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
