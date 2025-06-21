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