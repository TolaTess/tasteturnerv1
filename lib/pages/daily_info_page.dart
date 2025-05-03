import 'package:flutter/material.dart';

import '../constants.dart';
import '../helper/utils.dart';
import '../widgets/date_widget.dart';

class DailyFoodPage extends StatefulWidget {
  final double total, current;
  final ValueNotifier<double> currentNotifier;
  final String title;
  final double increment;

  const DailyFoodPage({
    super.key,
    this.total = 2000,
    this.current = 0,
    required this.currentNotifier,
    this.title = 'Update Data',
    this.increment = 250,
  });

  @override
  _DailyFoodPageState createState() => _DailyFoodPageState();
}

class _DailyFoodPageState extends State<DailyFoodPage> {
  late ValueNotifier<double> currentWaterLevelNotifier;
  bool isAnimating = false;
  double squareSize = 80;
  double squareW = 100;
  bool fillType = false;
  double fillPercentage = 0;

  @override
  void initState() {
    super.initState();
    currentWaterLevelNotifier = ValueNotifier<double>(widget.current);
  }

  void addWater() {
    if (!isAnimating) {
      isAnimating = true;
      currentWaterLevelNotifier.value += widget.increment;
      fillType = false;

      // Trigger animation delay
      if (widget.title == 'Update Water') {
        Future.delayed(const Duration(milliseconds: 200), () async {
          setState(() {
            isAnimating = false;
          });
          widget.currentNotifier.value = currentWaterLevelNotifier.value;
          // Update Firestore
          await dailyDataController.updateCurrentWater(
            userService.userId ?? '',
            currentWaterLevelNotifier.value,
          );
        });
      }
      if (widget.title == 'Update Steps') {
        Future.delayed(const Duration(milliseconds: 200), () async {
          setState(() {
            isAnimating = false;
          });

          widget.currentNotifier.value = currentWaterLevelNotifier.value;
          // Update Firestore
          await dailyDataController.updateCurrentSteps(
            userService.userId ?? '',
            currentWaterLevelNotifier.value,
          );
        });
      }
    }
  }

  void removeWater() {
    if (!isAnimating && currentWaterLevelNotifier.value > 0) {
      isAnimating = true;
      currentWaterLevelNotifier.value -= widget.increment;
      fillType = true;

      // Trigger animation delay
      if (widget.title == 'Update Water') {
        Future.delayed(const Duration(milliseconds: 200), () async {
          setState(() {
            isAnimating = false;
        });
        widget.currentNotifier.value = currentWaterLevelNotifier.value;
        // Update Firestore
        await dailyDataController.updateCurrentWater(
          userService.userId ?? '',
            currentWaterLevelNotifier.value,
          );
        });
      }
      if (widget.title == 'Update Steps') {
        Future.delayed(const Duration(milliseconds: 200), () async {
          setState(() {
            isAnimating = false;
          });

          widget.currentNotifier.value = currentWaterLevelNotifier.value;
          // Update Firestore
          await dailyDataController.updateCurrentSteps(
            userService.userId ?? '',
            currentWaterLevelNotifier.value,
          );
        });
      }
    }
  }

  void checkPercentage(double value) {
    fillPercentage = value / widget.total;
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    return Scaffold(
      body: Row(
        children: [
          const SizedBox(width: 20),

          // 250ml Cup
          Flexible(
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                // Lower square (background)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: squareW,
                    height: squareSize,
                    color: isDarkMode ? kDarkGrey.withOpacity(kOpacity) : kWhite,
                  ),
                ),
            
                // Filling animation
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                  child: ValueListenableBuilder<double>(
                    valueListenable: currentWaterLevelNotifier,
                    builder: (context, value, child) {
                      checkPercentage(value);
                      return TweenAnimationBuilder<double>(
                        tween: Tween(
                            begin: 0.0, end: fillPercentage.clamp(0.0, 1.0)),
                        duration: const Duration(seconds: 1),
                        builder: (context, animationValue, child) {
                          return SizedBox(
                            width: squareW,
                            height: squareSize * animationValue,
                            child: CustomPaint(
                              painter: widget.title == 'Update Water'
                                  ? WavePainter(animationValue, kBlue, 4)
                                  : StepsPainter(animationValue, kLightGrey),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                // 250ml Label
                ValueListenableBuilder<double>(
                  valueListenable: currentWaterLevelNotifier,
                  builder: (context, currentValue, child) {
                    return Text(
                      '${currentValue.toInt()} ${widget.title == 'Update Water' ? 'ml' : 'steps'}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w200,
                        color: getThemeProvider(context).isDarkMode
                            ? kWhite
                            : kDarkGrey,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(width: 20),
          // Minus Button
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Plus Button
              GestureDetector(
                onTap: addWater,
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: kAccent,
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: const Icon(Icons.add, color: Colors.white),
                ),
              ),
              const SizedBox(height: 10),
              // Minus Button
              GestureDetector(
                onTap: removeWater,
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: kAccentLight,
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: const Icon(Icons.remove, color: Colors.white),
                ),
              ),
            ],
          ),

          const SizedBox(width: 20),
        ],
      ),
    );
  }
}
