import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tasteturner/widgets/bottom_nav.dart';
import '../constants.dart';
import '../data_models/macro_data.dart';
import '../helper/utils.dart';
import 'circle_image.dart';
import '../data_models/meal_model.dart';

class GoalDietWidget extends StatefulWidget {
  final String diet;
  final String goal;
  final List<MacroData> topIngredients;
  final Meal? featuredMeal;
  final void Function(MacroData)? onIngredientTap;
  final void Function(Meal)? onMealTap;
  final VoidCallback? onRefresh;

  const GoalDietWidget({
    super.key,
    required this.diet,
    required this.goal,
    required this.topIngredients,
    this.featuredMeal,
    this.onIngredientTap,
    this.onMealTap,
    this.onRefresh,
  });

  @override
  State<GoalDietWidget> createState() => _GoalDietWidgetState();
}

class _GoalDietWidgetState extends State<GoalDietWidget>
    with SingleTickerProviderStateMixin {
  bool _expanded = true;
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;
  bool showCaloriesAndGoal = true;

  static const String _showCaloriesPrefKey = 'showCaloriesAndGoal';

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _shakeAnimation = Tween<double>(begin: -0.1, end: 0.1).animate(
      CurvedAnimation(
        parent: _shakeController,
        curve: Curves.easeInOut,
      ),
    );
    _loadShowCaloriesPref();
    if (_expanded) {
      _shakeController.repeat(reverse: true);
      if (widget.onRefresh != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            widget.onRefresh!();
          }
        });
      }
    }
  }

  Future<void> _loadShowCaloriesPref() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      showCaloriesAndGoal = prefs.getBool(_showCaloriesPrefKey) ?? true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    return Card(
      color: isDarkMode ? kDarkGrey : kWhite,
      margin: EdgeInsets.symmetric(
          horizontal: getPercentageWidth(2, context),
          vertical: getPercentageHeight(1, context)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 3,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        padding: EdgeInsets.all(getPercentageWidth(2, context)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () {
                setState(() {
                  final wasCollapsed = !_expanded;
                  _expanded = !_expanded;
                  if (_expanded) {
                    _shakeController.repeat(reverse: true);
                  } else {
                    _shakeController.stop();
                    _shakeController.reset();
                  }
                  if (wasCollapsed && _expanded && widget.onRefresh != null) {
                    widget.onRefresh!();
                  }
                });
              },
              behavior: HitTestBehavior.opaque,
              child: Row(
                children: [
                  SizedBox(width: getPercentageWidth(2, context)),
                  Icon(Icons.emoji_food_beverage,
                      color: kAccent, size: getPercentageWidth(4.5, context)),
                  SizedBox(width: getPercentageWidth(1, context)),
                  Text(
                    'Your Diet: ',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: getTextScale(3, context),
                      color: kAccent,
                    ),
                  ),
                  Text(
                    widget.diet.isNotEmpty
                        ? capitalizeFirstLetter(widget.diet)
                        : 'Not set',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: getTextScale(3, context),
                      color: isDarkMode ? kWhite : kDarkGrey,
                    ),
                  ),
                  SizedBox(width: getPercentageWidth(4, context)),
                  if (showCaloriesAndGoal)
                    Icon(Icons.flag,
                        color: kAccentLight,
                        size: getPercentageWidth(4.5, context)),
                  if (showCaloriesAndGoal)
                    SizedBox(width: getPercentageWidth(1, context)),
                  if (showCaloriesAndGoal)
                    Text(
                      'Goal: ',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: getTextScale(3, context),
                        color: kAccentLight,
                      ),
                    ),
                  if (showCaloriesAndGoal)
                    Text(
                      widget.goal.isNotEmpty
                          ? widget.goal.toLowerCase() == "lose weight"
                              ? 'Weight Loss'
                              : widget.goal.toLowerCase() == "muscle gain"
                                  ? 'Muscle Gain'
                                  : capitalizeFirstLetter(widget.goal)
                          : 'Not set',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: getTextScale(3, context),
                        color: isDarkMode ? kWhite : kDarkGrey,
                      ),
                    ),
                  const Spacer(),
                  Icon(_expanded ? Icons.expand_less : Icons.expand_more,
                      color: kAccent, size: getPercentageWidth(6, context)),
                ],
              ),
            ),
            if (_expanded) ...[
              SizedBox(height: getPercentageHeight(1, context)),
              Text(
                widget.goal.toLowerCase() == "lose weight"
                    ? 'Featured Ingredients for Weight Loss'
                    : 'Featured Ingredients',
                style: TextStyle(
                  fontWeight: FontWeight.w400,
                  fontSize: getTextScale(3, context),
                  color: kAccentLight,
                ),
              ),
              SizedBox(height: getPercentageHeight(0.5, context)),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: IngredientListViewRecipe(
                      demoAcceptedData: widget.topIngredients,
                      spin: false,
                      isEdit: false,
                      onRemoveItem: (int) {},
                      radius: 18,
                    ),
                  ),
                  SizedBox(width: getPercentageWidth(2, context)),
                  Expanded(
                    flex: 1,
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                BottomNavSec(selectedIndex: 3),
                          ),
                        );
                      },
                      child: TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0, end: 2 * pi),
                        duration: const Duration(seconds: 3),
                        builder: (context, value, child) {
                          return Transform.rotate(
                            angle: value,
                            child: AnimatedBuilder(
                              animation: _expanded
                                  ? _shakeAnimation
                                  : AlwaysStoppedAnimation(0.0),
                              builder: (context, child) {
                                return Transform.translate(
                                  offset: Offset(
                                      _expanded
                                          ? sin(_shakeAnimation.value) * 5
                                          : 0,
                                      0),
                                  child: child,
                                );
                              },
                              child: CircleAvatar(
                                backgroundColor: kAccent.withOpacity(0.3),
                                radius: getResponsiveBoxSize(context, 30, 30),
                                child: Text(
                                  'Spin',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: getTextScale(3, context),
                                    color: kAccent,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
              if (widget.featuredMeal != null) ...[
                Text(
                  'Featured Meal for ${capitalizeFirstLetter(widget.diet)}',
                  style: TextStyle(
                    fontWeight: FontWeight.w400,
                    fontSize: getTextScale(3, context),
                    color: kAccentLight,
                  ),
                ),
                SizedBox(height: getPercentageHeight(0.5, context)),
                GestureDetector(
                  onTap: widget.onMealTap != null
                      ? () => widget.onMealTap!(widget.featuredMeal!)
                      : null,
                  child: Card(
                    color: kAccent.withOpacity(0.3),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: widget.featuredMeal!.mediaPaths.isNotEmpty
                              ? buildMealImage(
                                  widget.featuredMeal!.mediaPaths.first,
                                  getPercentageWidth(15, context),
                                  getPercentageWidth(15, context),
                                )
                              : Image.asset(
                                  intPlaceholderImage,
                                  width: getPercentageWidth(15, context),
                                  height: getPercentageWidth(15, context),
                                  fit: BoxFit.cover,
                                ),
                        ),
                        SizedBox(width: getPercentageWidth(2, context)),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.featuredMeal!.title,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: getTextScale(3, context),
                                  color: isDarkMode ? kWhite : kDarkGrey,
                                ),
                              ),
                              SizedBox(
                                  height: getPercentageHeight(0.5, context)),
                              Text(
                                (widget.featuredMeal!.macros['description'] ??
                                    (widget.featuredMeal!.steps.isNotEmpty
                                        ? widget.featuredMeal!.steps.first
                                        : (widget.featuredMeal!.ingredients
                                                .isNotEmpty
                                            ? widget.featuredMeal!.ingredients
                                                .entries.first.value
                                            : ''))),
                                style: TextStyle(
                                  fontSize: getTextScale(2.5, context),
                                  color: isDarkMode ? kWhite : kDarkGrey,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (widget.featuredMeal!.categories.isNotEmpty)
                                Padding(
                                  padding: EdgeInsets.only(
                                      top: getPercentageHeight(0.5, context)),
                                  child: Text(
                                    '${widget.featuredMeal!.calories.toString()} kcal',
                                    style: TextStyle(
                                      fontSize: getTextScale(2.5, context),
                                      color: isDarkMode ? kAccentLight : kWhite,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget buildMealImage(String imageUrl, double width, double height) {
    if (imageUrl.isEmpty) {
      return Image.asset(intPlaceholderImage,
          width: width, height: height, fit: BoxFit.cover);
    }
    if (imageUrl.startsWith('http')) {
      return Image.network(
        imageUrl,
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Image.asset(intPlaceholderImage,
              width: width, height: height, fit: BoxFit.cover);
        },
      );
    } else {
      return Image.asset(getAssetImageForItem(imageUrl),
          width: width, height: height, fit: BoxFit.cover);
    }
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }
}
