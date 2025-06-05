import 'dart:math';

import 'package:flutter/material.dart';
import 'package:simple_circular_progress_bar/simple_circular_progress_bar.dart';

import '../constants.dart';
import '../helper/utils.dart';
import '../screens/add_food_screen.dart';

class WavePainter extends CustomPainter {
  final double animationValue; // Fill level
  final Color waveColor;
  final double waveHeight;

  WavePainter(this.animationValue, this.waveColor, this.waveHeight);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = waveColor.withOpacity(animationValue.clamp(0.0, 1.0))
      ..style = PaintingStyle.fill;

    final path = Path();

    double waveFrequency = 1.0;

    for (double x = 0; x <= size.width; x++) {
      double y = sin((x / size.width) * waveFrequency * pi * 2) * waveHeight;
      path.lineTo(x, size.height - y - (size.height * animationValue));
    }

    // Close path to fill from the bottom and sides
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class StepsPainter extends CustomPainter {
  final double animationValue; // Progress value between 0 and 1
  final Color stepColor;
  final double stepSize;

  StepsPainter(this.animationValue, this.stepColor, {this.stepSize = 12});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = stepColor.withOpacity(0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final filledPaint = Paint()
      ..color = stepColor.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    // Calculate dimensions for the zigzag pattern
    final double segmentWidth = size.width * 0.8; // Width of each zigzag
    final double margin = (size.width - segmentWidth) / 2; // Horizontal margin
    final double segmentHeight =
        size.height / 10; // Height of each zigzag segment
    final int totalSegments = 10; // Total number of zigzag segments

    Path backgroundPath = Path();
    Path filledPath = Path();

    // Start from bottom left
    backgroundPath.moveTo(margin, size.height);
    filledPath.moveTo(margin, size.height);

    // Create zigzag pattern
    for (int i = 0; i < totalSegments; i++) {
      double y = size.height - (i * segmentHeight);

      if (i % 2 == 0) {
        // Draw line to the right
        backgroundPath.lineTo(margin + segmentWidth, y);
      } else {
        // Draw line to the left
        backgroundPath.lineTo(margin, y);
      }
    }

    // Draw the filled path based on animation value
    double fillHeight = size.height * (1 - animationValue);
    for (int i = 0; i < totalSegments; i++) {
      double y = size.height - (i * segmentHeight);

      if (y < fillHeight) break; // Stop drawing when we reach the fill level

      if (i % 2 == 0) {
        // Draw line to the right
        filledPath.lineTo(margin + segmentWidth, y);
      } else {
        // Draw line to the left
        filledPath.lineTo(margin, y);
      }
    }

    // Draw the background pattern
    canvas.drawPath(backgroundPath, paint);

    // Draw the filled pattern
    canvas.drawPath(filledPath, filledPaint);

    // Add dots at the zigzag points
    for (int i = 0; i < totalSegments; i++) {
      double y = size.height - (i * segmentHeight);
      if (y < fillHeight) break; // Stop drawing when we reach the fill level

      double x = (i % 2 == 0) ? margin : margin + segmentWidth;

      // Draw filled dots
      canvas.drawCircle(
          Offset(x, y),
          5,
          Paint()
            ..color = stepColor.withOpacity(0.3)
            ..style = PaintingStyle.fill);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class CustomCircularProgressBar extends StatefulWidget {
  final ValueNotifier<double> valueNotifier;

  final String sym, title;
  final double remainingCalories;

  final DateTime currentDate;

  const CustomCircularProgressBar({
    super.key,
    required this.valueNotifier,
    this.sym = '',
    this.title = 'Remaining',
    this.remainingCalories = 0,
    required this.currentDate,
  });

  @override
  State<CustomCircularProgressBar> createState() =>
      _CustomCircularProgressBarState();
}

class _CustomCircularProgressBarState extends State<CustomCircularProgressBar> {
  // Safe value notifier that will be used by the SimpleCircularProgressBar
  late final ValueNotifier<double> safeValueNotifier;

  @override
  void initState() {
    super.initState();
    // Initialize with a safe value
    safeValueNotifier =
        ValueNotifier<double>(_getSafeValue(widget.valueNotifier.value));

    // Set up the listener
    widget.valueNotifier.addListener(_updateSafeValue);
  }

  @override
  void dispose() {
    // Remove the listener when the widget is disposed
    widget.valueNotifier.removeListener(_updateSafeValue);
    // Dispose the safe notifier
    safeValueNotifier.dispose();
    super.dispose();
  }

  // Update the safe value when the original notifier changes
  void _updateSafeValue() {
    safeValueNotifier.value = _getSafeValue(widget.valueNotifier.value);
  }

  // Validate and sanitize a value
  double _getSafeValue(double value) {
    if (value.isNaN || value.isInfinite) {
      return 0.0;
    }
    return value.clamp(0.0, 100.0);
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = getThemeProvider(context).isDarkMode;

    return GestureDetector(
      onTap: () {
        if (getCurrentDate(widget.currentDate)) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddFoodScreen(),
            ),
          );
        }
      },
      child: Column(
        children: [
          SizedBox(
            height: getPercentageHeight(10, context),
            width: getPercentageWidth(10, context),
            child: SimpleCircularProgressBar(
              size: getPercentageWidth(10, context),
              valueNotifier: safeValueNotifier, // Use the safe value notifier
              backColor: isDarkMode
                  ? kWhite.withOpacity(kOpacity)
                  : kPrimaryColor.withOpacity(kOpacity),
              progressColors: [kAccentLight.withOpacity(kOpacity)],
              fullProgressColor: kAccent,
              mergeMode: true,
              progressStrokeWidth: getPercentageWidth(1.5, context),
              backStrokeWidth: getPercentageWidth(1, context),
              onGetText: (double value) {
                return Text(
                  '+',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: getPercentageWidth(4, context),
                    fontWeight: FontWeight.normal,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
