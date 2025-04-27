import 'dart:math';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:simple_circular_progress_bar/simple_circular_progress_bar.dart';

import '../constants.dart';
import '../helper/utils.dart';

class FillingSquare extends StatefulWidget {
  final ValueNotifier<double> current;
  final bool isWater;
  final String widgetName, sym;
  final Color upperColor;
  final double total;

  const FillingSquare({
    super.key,
    required this.current,
    required this.upperColor,
    required this.isWater,
    required this.widgetName,
    required this.total,
    required this.sym,
  });

  @override
  State<FillingSquare> createState() => _FillingSquareState();
}

class _FillingSquareState extends State<FillingSquare> {
  double squareSize = 120;
  double squareW = 150;
  bool isWater = false;
  double fillPercentage = 0;

  void checkPercentage(double value) {
    fillPercentage = value / widget.total;
  }

  @override
  void initState() {
    super.initState();
    checkPercentage(widget.current.value);
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    return SizedBox(
      width: squareW,
      height: squareSize,
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
              valueListenable: widget.current,
              builder: (context, value, child) {
                checkPercentage(value);
                return TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: fillPercentage.clamp(0.0, 1.0)),
                  duration: const Duration(seconds: 1),
                  builder: (context, animationValue, child) {
                    if (widget.isWater) {
                      return SizedBox(
                        width: squareW,
                        height: squareSize * animationValue,
                        child: CustomPaint(
                          painter:
                              WavePainter(animationValue, widget.upperColor, 4),
                        ),
                      );
                    } else {
                      return Container(
                        width: squareW,
                        height: squareSize * animationValue,
                        color: widget.upperColor
                            .withOpacity(animationValue.clamp(0.0, 1.0)),
                      );
                    }
                  },
                );
              },
            ),
          ),

          // Text widgets
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ValueListenableBuilder<double>(
              valueListenable: widget.current,
              builder: (context, value, child) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Widget name
                    Text(
                      widget.widgetName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Current value
                    Text(
                      value.toInt().toString(),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: isDarkMode
                            ? kWhite.withOpacity(fillPercentage.clamp(0.3, 1.0))
                            : kBlack
                                .withOpacity(fillPercentage.clamp(0.3, 1.0)),
                      ),
                    ),
                    // Total value
                    Text(
                      "of ${widget.total.toInt()} ${widget.sym}",
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

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

class CustomCircularProgressBar extends StatefulWidget {
  final ValueNotifier<double> valueNotifier;

  final String sym, title;
  final bool isMain;
  final double remainingCalories;

  const CustomCircularProgressBar({
    super.key,
    required this.valueNotifier,
    required this.isMain,
    this.sym = '',
    this.title = 'Remaining',
    this.remainingCalories = 0,
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
    // Ensure remainingCalories is a valid number (not Infinity, NaN, or negative)
    final validRemainingCalories =
        widget.remainingCalories.isNaN || widget.remainingCalories.isInfinite
            ? 0.0
            : widget.remainingCalories < 0
                ? 0.0
                : widget.remainingCalories;

    return Column(
      children: [
        SizedBox(
          height: widget.isMain ? 100 : 50,
          width: widget.isMain ? 100 : 50,
          child: SimpleCircularProgressBar(
            size: widget.isMain ? 100 : 50,
            valueNotifier: safeValueNotifier, // Use the safe value notifier
            backColor: isDarkMode
                ? kWhite.withOpacity(kOpacity)
                : kPrimaryColor.withOpacity(kOpacity),
            progressColors: [kAccentLight.withOpacity(kOpacity)],
            fullProgressColor: kAccent,
            mergeMode: true,
            progressStrokeWidth: widget.isMain ? 8 : 5,
            backStrokeWidth: widget.isMain ? 5 : 3,
            onGetText: (double value) {
              return Text(
                widget.isMain ? '${validRemainingCalories.toInt()}' : '',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: widget.isMain ? 20 : 14,
                  fontWeight: FontWeight.bold,
                ),
              );
            },
          ),
        ),
        widget.isMain ? const SizedBox(height: 12) : const SizedBox.shrink(),
        widget.isMain
            ? Text(
                '${widget.title} ${widget.sym}',
              )
            : const SizedBox.shrink(),
      ],
    );
  }
}

class DailyNutritionOverview extends StatefulWidget {
  final Map<String, String> settings;

  const DailyNutritionOverview({
    super.key,
    required this.settings,
  });

  @override
  State<DailyNutritionOverview> createState() => _DailyNutritionOverviewState();
}

class _DailyNutritionOverviewState extends State<DailyNutritionOverview> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: kAccent.withOpacity(0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Column(
          children: [
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Obx(() {
                  double eatenCalories =
                      dailyDataController.eatenCalories.value.toDouble();

                  return Expanded(
                    flex: 1,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          eatenCalories.toInt().toString(),
                          style: const TextStyle(fontSize: 14),
                        ),
                        const Text(
                          "Eaten",
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  );
                }),
                Obx(() {
                  double eatenCalories =
                      dailyDataController.eatenCalories.value.toDouble();

                  double targetCalories =
                      dailyDataController.targetCalories.value;

                  double remainingValue = targetCalories <= 0
                      ? 0.0
                      : (targetCalories - eatenCalories)
                          .clamp(0.0, targetCalories);

                  return Expanded(
                    flex: 1,
                    child: CustomCircularProgressBar(
                      valueNotifier: dailyDataController.dailyValueNotifier,
                      isMain: true,
                      remainingCalories: remainingValue,
                    ),
                  );
                }),
                Expanded(
                  flex: 1,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        dailyDataController.targetCalories.value
                            .toInt()
                            .toString(),
                        style: const TextStyle(fontSize: 14),
                      ),
                      const Text(
                        "Target",
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                )
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Helper function to check if two dates are on the same day
  bool isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }
}

class MacroNutritionOverview extends StatelessWidget {
  const MacroNutritionOverview({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    DateTime today = DateTime.now();
    int proteinTotal = 120;
    int carbsTotal = 100;
    int fatTotal = 90;
    int proteinGrams = 56;
    int carbsGrams = 42;
    int fatGrams = 90;

    // Ensure values are valid and don't result in Infinity or NaN
    double proteinProgress =
        proteinTotal > 0 ? (proteinGrams.toDouble() / proteinTotal) * 100 : 0.0;
    double proteinProgressValue = proteinProgress.clamp(0.0, 100.0);
    ValueNotifier<double> proteinDailyValueNotifier =
        ValueNotifier<double>(proteinProgressValue);
    double remainingValue = proteinTotal > 0
        ? (proteinTotal - proteinGrams).clamp(0, proteinTotal).toDouble()
        : 0.0;

    // Ensure values are valid and don't result in Infinity or NaN
    double carbsProgress =
        carbsTotal > 0 ? (carbsGrams.toDouble() / carbsTotal) * 100 : 0.0;
    double carbsProgressValue = carbsProgress.clamp(0.0, 100.0);
    ValueNotifier<double> carbsDailyValueNotifier =
        ValueNotifier<double>(carbsProgressValue);
    double remainingCarbsValue = carbsTotal > 0
        ? (carbsTotal - carbsGrams).clamp(0, carbsTotal).toDouble()
        : 0.0;

    // Ensure values are valid and don't result in Infinity or NaN
    double fatsProgress =
        fatTotal > 0 ? (fatGrams.toDouble() / fatTotal) * 100 : 0.0;
    double fatsProgressValue = fatsProgress.clamp(0.0, 100.0);
    ValueNotifier<double> fatsDailyValueNotifier =
        ValueNotifier<double>(fatsProgressValue);
    double remainingFatsValue = fatTotal > 0
        ? (fatTotal - fatGrams).clamp(0, fatTotal).toDouble()
        : 0.0;

    return Container(
      decoration: BoxDecoration(
          color: isDarkMode ? kDarkGrey.withOpacity(0.75) : kWhite,
          borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Column(
          children: [
            Center(
              child: Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(
                      text: 'Macros\n',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    TextSpan(
                      text: DateFormat(dateFormat).format(today),
                      style: const TextStyle(
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                textAlign: TextAlign.center, // Center-align the text
                //DateFormat(dateFormat).format(today),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                CustomCircularProgressBar(
                  valueNotifier: proteinDailyValueNotifier,
                  isMain: true,
                  remainingCalories: remainingValue,
                  title: 'Protein',
                  sym: '(g)',
                ),
                CustomCircularProgressBar(
                  valueNotifier: carbsDailyValueNotifier,
                  isMain: true,
                  remainingCalories: remainingCarbsValue,
                  title: 'Carbs',
                  sym: '(g)',
                ),
                CustomCircularProgressBar(
                  valueNotifier: fatsDailyValueNotifier,
                  isMain: true,
                  remainingCalories: remainingFatsValue,
                  title: 'Fats',
                  sym: '(g)',
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}

class NutritionStatusBar extends StatefulWidget {
  final String userId;
  final Map<String, String> userSettings;
  final Function(String)? onMealTypeSelected;

  const NutritionStatusBar({
    super.key,
    required this.userId,
    required this.userSettings,
    this.onMealTypeSelected,
  });

  @override
  State<NutritionStatusBar> createState() => _NutritionStatusBarState();
}

class _NutritionStatusBarState extends State<NutritionStatusBar> {
  @override
  void initState() {
    super.initState();
    _initializeMealData();
  }

  void _initializeMealData() async {
    final today = DateTime.now();
    await dailyDataController.fetchAllMealData(
        widget.userId, widget.userSettings, today);
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    return Container(
      decoration: BoxDecoration(
        color:
            isDarkMode ? kDarkGrey.withOpacity(0.75) : kWhite.withOpacity(0.75),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildMealColumn(
              title: 'Breakfast',
              target: dailyDataController.breakfastTarget,
              calories: dailyDataController.breakfastCalories,
              themeProvider: isDarkMode,
              context: context,
              valueNotifier: dailyDataController.breakfastNotifier,
            ),
            _buildMealColumn(
              title: 'Lunch',
              target: dailyDataController.lunchTarget,
              calories: dailyDataController.lunchCalories,
              themeProvider: isDarkMode,
              context: context,
              valueNotifier: dailyDataController.lunchNotifier,
            ),
            _buildMealColumn(
              title: 'Dinner',
              target: dailyDataController.dinnerTarget,
              calories: dailyDataController.dinnerCalories,
              themeProvider: isDarkMode,
              context: context,
              valueNotifier: dailyDataController.dinnerNotifier,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMealColumn(
      {required String title,
      required RxInt target,
      required RxInt calories,
      required bool themeProvider,
      required ValueNotifier<double> valueNotifier,
      required BuildContext context}) {
    return Obx(() {
      double remaining = target.value == 0
          ? 0
          : (target.value - calories.value).clamp(0, target.value).toDouble();

      return Column(
        children: [
          const SizedBox(height: 2),
          Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 12, color: kAccent)),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () {
              if (widget.onMealTypeSelected != null) {
                widget.onMealTypeSelected!(title);
              }
            },
            child: CustomCircularProgressBar(
              valueNotifier: valueNotifier,
              isMain: false,
              remainingCalories: remaining,
              title: title,
              sym: '',
            ),
          ),
          const SizedBox(height: 5),
          Text(
            '${calories.value} / ${target.value} kcal',
            style: const TextStyle(fontSize: 10),
          ),
        ],
      );
    });
  }
}
