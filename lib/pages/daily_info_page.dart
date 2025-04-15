import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../constants.dart';
import '../helper/utils.dart';
import '../widgets/date_widget.dart';

class DailyFoodPage extends StatefulWidget {
  final double total, current;
  final ValueNotifier<double> currentNotifier;
  final String title;

  const DailyFoodPage({
    super.key,
    this.total = 2000,
    this.current = 0,
    required this.currentNotifier,
    this.title = 'Update Data',
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

  @override
  void initState() {
    super.initState();
    currentWaterLevelNotifier = ValueNotifier<double>(widget.current);
  }

  void addWater() {
    if (!isAnimating) {
      isAnimating = true;
      currentWaterLevelNotifier.value += 250;
      fillType = true;

      // Trigger animation delay
      Future.delayed(const Duration(milliseconds: 200), () {
        setState(() {
          isAnimating = false;
        });
        widget.currentNotifier.value = currentWaterLevelNotifier.value;
      });
    }
  }

  void removeWater() {
    if (!isAnimating && currentWaterLevelNotifier.value > 0) {
      isAnimating = true;
      currentWaterLevelNotifier.value -= 250;
      fillType = false;

      // Trigger animation delay
      Future.delayed(const Duration(milliseconds: 200), () {
        setState(() {
          isAnimating = false;
        });
        widget.currentNotifier.value = currentWaterLevelNotifier.value;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              widget.title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 40),
            // Save Button
            ElevatedButton(
              onPressed: () {
                dailyDataController.updateCurrentWater(
                    userService.userId ?? '', currentWaterLevelNotifier.value);

                showTastySnackbar(
                  'Success',
                  'Your water was updated successfully!',
                  context,
                );

                Navigator.pop(context); // Close the modal
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: isDarkMode ? kDarkGrey : kAccent,
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Save',
                style: TextStyle(fontSize: 16),
              ),
            ),
            const SizedBox(height: 40),

            // Row for 250ml Cup with + and - buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Minus Button
                GestureDetector(
                  onTap: removeWater,
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.red.shade300,
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: const Icon(Icons.remove, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 20),

                // 250ml Cup
                Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    // Lower square (background)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: squareW,
                        height: squareSize,
                        color: isDarkMode
                            ? kDarkGrey.withOpacity(kOpacity)
                            : kWhite,
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
                          // unique key to force rebuild
                          final animationKey = Key(value.toString());

                          return TweenAnimationBuilder<double>(
                            key: animationKey,
                            tween: Tween(
                              begin: fillType ? 1.0 : 0.1,
                              end: fillType ? 0.1 : 1.0,
                            ),
                            duration: const Duration(milliseconds: 1200),
                            builder: (context, animationValue, child) {
                              return SizedBox(
                                width: squareW,
                                height: squareSize,
                                child: CustomPaint(
                                  painter:
                                      WavePainter(animationValue, kBlue, 3),
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
                        double value = currentValue - widget.current;
                        if (value <= 0.0) {
                          value = 0;
                        }
                        return Text(
                          '${value.toInt()} ml',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w200,
                            color: Colors.black,
                          ),
                        );
                      },
                    ),
                  ],
                ),

                const SizedBox(width: 20),

                // Plus Button
                GestureDetector(
                  onTap: addWater,
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.green.shade300,
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: const Icon(Icons.add, color: Colors.white),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 30),

            // Main water bucket
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ValueListenableBuilder<double>(
                valueListenable: currentWaterLevelNotifier,
                builder: (context, currentValue, child) {
                  return FillingSquare(
                    current: currentWaterLevelNotifier,
                    upperColor: kBlue,
                    isWater: true,
                    widgetName: 'Water Intake',
                    total: widget.total,
                    sym: 'ml',
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
