import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:audioplayers/audioplayers.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:tasteturner/constants.dart';
import 'package:tasteturner/helper/utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class WidgetSpinningWheel extends StatefulWidget {
  final List<String> labels;
  final Function(String label) onSpinComplete;
  final double size;
  final double defaultSpeed;
  final List<Color>? colours;
  final TextStyle? textStyle;
  final bool shouldVibrate;
  final VoidCallback playSound;
  final VoidCallback stopSound;

  const WidgetSpinningWheel({
    super.key,
    required this.labels,
    required this.onSpinComplete,
    required this.size,
    this.defaultSpeed = 3,
    this.colours,
    this.textStyle,
    this.shouldVibrate = true,
    required this.playSound,
    required this.stopSound,
  });

  @override
  State<WidgetSpinningWheel> createState() => _WidgetSpinningWheelState();
}

class _WidgetSpinningWheelState extends State<WidgetSpinningWheel> {
  double currentOffset = 0;
  double currentSpeed = 0;
  double rateOfSlowDown = 0;
  Timer? timer;
  late String previousLabel;
  bool needsImageUpdate = false;

  late List<double> labelLimits;
  late List<double> labelValues;
  late Random _random;
  late AudioPlayer _audioPlayer;

  @override
  void initState() {
    super.initState();
    _random = Random();
    _generateLabelValues();
    _generateLabelLimits();
    previousLabel = _getCurrentLabel();
    _audioPlayer = AudioPlayer();
    _audioPlayer.onPlayerComplete.listen((_) {
      widget.stopSound();
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  /// Gets a random spin duration between 1 - 5 seconds
  Duration _getRandomSpinDuration() {
    int randomSeconds = 1 + _random.nextInt(5);
    return Duration(seconds: randomSeconds);
  }

  void _generateLabelValues() {
    labelValues = List<double>.filled(widget.labels.length, 1.0);
  }

  void _generateLabelLimits() {
    labelLimits = List.generate(widget.labels.length, (index) {
      double anglePerSection = (2 * pi) / widget.labels.length;
      return anglePerSection * (index + 1);
    });
  }

  /// Returns the current label based on `currentOffset`
  String _getCurrentLabel() {
    double angle = currentOffset.remainder(2 * pi);
    double anglePerSection = (2 * pi) / widget.labels.length;

    for (int i = 0; i < widget.labels.length; i++) {
      if (angle < anglePerSection * (i + 1)) {
        return widget.labels[i];
      }
    }

    // If we somehow get here, return the last label
    return widget.labels.last;
  }

  /// Spins the wheel with a dynamic speed and ensures it stops at a different position
  void spin({double? withSpeed}) {
    widget.playSound();

    // Log spin event to Firebase
    FirebaseAnalytics.instance.logEvent(
      name: 'spin_wheel',
      parameters: {
        'speed': withSpeed ?? widget.defaultSpeed,
        'num_labels': widget.labels.length,
      },
    );

    if (timer != null) timer?.cancel();

    currentSpeed =
        withSpeed ?? (widget.defaultSpeed + _random.nextDouble() * 1.2);
    rateOfSlowDown = currentSpeed / (30 + _random.nextInt(40));

    final Duration spinDuration = _getRandomSpinDuration();
    final startTime = DateTime.now();

    timer = Timer.periodic(const Duration(milliseconds: 10), (timer) {
      final elapsedTime = DateTime.now().difference(startTime);

      if (elapsedTime < spinDuration) {
        currentSpeed = widget.defaultSpeed;
      } else {
        currentSpeed -= rateOfSlowDown;
      }

      currentSpeed = currentSpeed.clamp(0, 1.5);
      currentOffset += currentSpeed;

      // Vibrate only when label actually changes
      String latestLabel = _getCurrentLabel();
      if (widget.shouldVibrate && previousLabel != latestLabel) {
        previousLabel = latestLabel;
        HapticFeedback.lightImpact();
      }

      // Stop when speed reaches near zero
      if (currentSpeed <= 0.02) {
        currentSpeed = 0;

        // Force image update if any label is missing its image
        setState(() {
          needsImageUpdate = true;
        });

        widget.onSpinComplete(latestLabel);
        timer.cancel();
        widget.stopSound();
      }

      if (mounted) {
        setState(() {});
      } else {
        timer.cancel();
        widget.stopSound();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.size,
      width: widget.size,
      child: GestureDetector(
        onDoubleTap: () {
          spin(withSpeed: 0.01);
        },
        onTap: () {
          // Stop the spinning animation
          if (timer != null) {
            String latestLabel = _getCurrentLabel();
            widget.onSpinComplete(latestLabel);
            timer?.cancel();
            currentSpeed = 0;
            widget.stopSound();
            setState(() {});
          }
        },
        child: PieChart(
          key: needsImageUpdate ? UniqueKey() : null,
          data: labelValues,
          labels: widget.labels,
          angleOffset: currentOffset,
          radius: 1000,
          textStyle: widget.textStyle ?? const TextStyle(),
          isDarkMode: getThemeProvider(context).isDarkMode,
          isSpinning: currentSpeed > 0,
          onImagesLoaded: () {
            if (needsImageUpdate) {
              setState(() {
                needsImageUpdate = false;
              });
            }
          },
        ),
      ),
    );
  }
}

class PieChart extends StatefulWidget {
  final List<double> data;
  final List<String> labels;
  final double angleOffset;
  final double radius;
  final TextStyle textStyle;
  final bool isDarkMode;
  final Function() onImagesLoaded;
  final bool isSpinning;

  const PieChart({
    super.key,
    required this.data,
    required this.labels,
    required this.textStyle,
    required this.onImagesLoaded,
    this.angleOffset = 0,
    this.radius = 100,
    this.isDarkMode = false,
    this.isSpinning = false,
  });

  @override
  State<PieChart> createState() => _PieChartState();
}

class _PieChartState extends State<PieChart> {
  Map<String, ui.Image> loadedImages = {};
  bool isLoading = true;
  List<String> currentLabels = [];

  @override
  void initState() {
    super.initState();
    currentLabels = widget.labels;
    _loadImages();
  }

  @override
  void didUpdateWidget(PieChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Check if we need to load any missing images
    bool needsUpdate = false;
    for (String label in widget.labels) {
      if (!loadedImages.containsKey(label)) {
        needsUpdate = true;
        break;
      }
    }

    if (needsUpdate) {
      currentLabels = widget.labels;
      _loadImages();
    } else {
      widget.onImagesLoaded();
    }
  }

  Future<void> _loadImages() async {
    setState(() {
      isLoading = true;
    });

    try {
      // First, identify which labels need images
      final List<String> labelsNeedingImages = currentLabels
          .where((label) => !loadedImages.containsKey(label))
          .toList();

      if (labelsNeedingImages.isEmpty) {
        setState(() {
          isLoading = false;
        });
        widget.onImagesLoaded();
        return;
      }

      // Create a map of label to image path using the utility function
      final Map<String, String> labelToImagePath = {};
      for (String label in labelsNeedingImages) {
        String imagePath = getRandomAssetImage();
        labelToImagePath[label] = imagePath;
      }

      // Load images for each label
      bool allImagesLoaded = true;
      for (String label in labelsNeedingImages) {
        try {
          String imagePath = labelToImagePath[label]!;

          final ByteData data = await rootBundle.load(imagePath);
          final Uint8List bytes = data.buffer.asUint8List();
          final ui.Codec codec = await ui.instantiateImageCodec(bytes);
          final ui.FrameInfo fi = await codec.getNextFrame();
          loadedImages[label] = fi.image;
        } catch (e) {
          print('Error loading image for label $label: $e');
          allImagesLoaded = false;
          continue;
        }
      }

      if (mounted) {
        setState(() {
          isLoading = false;
        });
        if (allImagesLoaded) {
          widget.onImagesLoaded();
        }
      }
    } catch (e, stackTrace) {
      print('Error in _loadImages: $e');
      print('Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return noItemTastyWidget(
        'Loading Spinning Wheel',
        '',
        context,
        false,
        '',
      );
    }

    // Ensure data array matches labels length
    final List<double> normalizedData = List.generate(
      currentLabels.length,
      (index) => index < widget.data.length ? widget.data[index] : 1.0,
    );

    double total = normalizedData.fold(
        0, (previousValue, element) => previousValue + element);
    final startAngle = 0 - pi / 2 + widget.angleOffset;

    return CustomPaint(
      painter: _PieChartPainter(
        context,
        normalizedData,
        currentLabels,
        total,
        startAngle,
        widget.textStyle,
        widget.isDarkMode,
        loadedImages,
        widget.isSpinning,
      ),
      size: Size.fromRadius(widget.radius),
    );
  }
}

class _PieChartPainter extends CustomPainter {
  final BuildContext context;
  final List<double> data;
  final List<String> labels;
  final double total;
  final double startAngle;
  final TextStyle textStyle;
  final bool isDarkMode;
  final Map<String, ui.Image> loadedImages;
  final bool isSpinning;

  _PieChartPainter(
    this.context,
    this.data,
    this.labels,
    this.total,
    this.startAngle,
    this.textStyle,
    this.isDarkMode,
    this.loadedImages,
    this.isSpinning,
  );

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2;
    final paint = Paint()..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = isDarkMode ? kWhite.withOpacity(0.1) : kBlack.withOpacity(0.1)
      ..strokeWidth = 2.0;
    double sweepAngle = 0;

    // Draw pie sections
    for (int i = 0; i < data.length; i++) {
      final sweepRad = (data[i] / total) * 2 * pi;
      paint.color = kAccent.withOpacity(0.5);

      // Draw filled section
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle + sweepAngle,
        sweepRad,
        true,
        paint,
      );

      // Draw stroke lines
      final startX = center.dx + radius * cos(startAngle + sweepAngle);
      final startY = center.dy + radius * sin(startAngle + sweepAngle);

      // Draw radius line
      canvas.drawLine(
        center,
        Offset(startX, startY),
        strokePaint,
      );

      // Draw icons
      final iconAngle = startAngle + sweepAngle + sweepRad / 2;
      final iconRadius = radius * 0.75;
      final iconX = center.dx + iconRadius * cos(iconAngle);
      final iconY = center.dy + iconRadius * sin(iconAngle);

      // Draw icon background circle
      final iconBgPaint = Paint()
        ..color =
            isDarkMode ? kDarkGrey.withOpacity(0.1) : kWhite.withOpacity(0.1)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(
        Offset(iconX, iconY),
        25,
        iconBgPaint,
      );

      // Draw icon border
      final iconBorderPaint = Paint()
        ..color = kAccent.withOpacity(0.1)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;

      canvas.drawCircle(
        Offset(iconX, iconY),
        25,
        iconBorderPaint,
      );

      // Draw icon if available
      final label = labels[i];
      if (loadedImages.containsKey(label)) {
        final iconImage = loadedImages[label]!;
        final iconSize = getPercentageWidth(10, context);
        final iconRect = Rect.fromCenter(
          center: Offset(iconX, iconY),
          width: iconSize,
          height: iconSize,
        );

        // Draw the icon with circular clip
        canvas.save();
        canvas.clipPath(Path()
          ..addOval(Rect.fromCircle(
            center: Offset(iconX, iconY),
            radius: iconSize / 2,
          )));
        canvas.drawImageRect(
          iconImage,
          Rect.fromLTWH(
              0, 0, iconImage.width.toDouble(), iconImage.height.toDouble()),
          iconRect,
          Paint(),
        );
        canvas.restore();
      }

      sweepAngle += sweepRad;
    }

    // Draw outer circle stroke
    final outerBorderPaint = Paint()
      ..color = kAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawCircle(
      center,
      radius,
      outerBorderPaint,
    );

    // Draw center circle
    final centerCirclePaint = Paint()
      ..color =
          isDarkMode ? kDarkGrey.withOpacity(0.8) : kWhite.withOpacity(0.8)
      ..style = PaintingStyle.fill;

    final centerBorderPaint = Paint()
      ..color = kAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final centerRadius = radius * 0.15; // Adjust size as needed
    canvas.drawCircle(center, centerRadius, centerCirclePaint);
    canvas.drawCircle(center, centerRadius, centerBorderPaint);

    // Draw text in center
    final textSpan = TextSpan(
      text: isSpinning ? 'Tap' : 'Double\nTap',
      style: TextStyle(
        color: kAccent,
        fontSize: centerRadius * 0.4,
        fontWeight: FontWeight.bold,
      ),
    );
    final textPainter = TextPainter(
      text: textSpan,
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    final textX = center.dx - (textPainter.width / 2);
    final textY = center.dy - (textPainter.height / 2);
    textPainter.paint(canvas, Offset(textX, textY));
  }

  @override
  bool shouldRepaint(_PieChartPainter old) =>
      old.startAngle != startAngle ||
      old.labels != labels ||
      old.data != data ||
      old.loadedImages != loadedImages;
}
