import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tasteturner/pages/edit_goal.dart';
import '../constants.dart';
import '../data_models/macro_data.dart';
import '../helper/utils.dart';
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
    with TickerProviderStateMixin {
  bool _expanded = true;
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;
  late AnimationController _flipController;
  late Animation<double> _flipAnimation;
  bool _isFlipped = false;
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

    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _flipAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _flipController,
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

  String _getDietFact() {
    final diet = widget.diet.toLowerCase();
    switch (diet) {
      case 'low carb':
        return 'Did you know? Low carb diets can help reduce appetite and promote faster initial weight loss by reducing water retention.';
      case 'keto':
        return 'Did you know? The ketogenic diet can improve brain function and mental clarity by providing ketones as an alternative fuel source.';
      case 'paleo':
        return 'Did you know? The paleo diet emphasizes whole foods and can help reduce inflammation in the body.';
      case 'vegan':
        return 'Did you know? Vegan diets are rich in fiber and antioxidants, which can support heart health and longevity.';
      case 'vegetarian':
        return 'Did you know? Vegetarian diets have been linked to lower risks of heart disease and certain types of cancer.';
      case 'pescatarian':
        return 'Did you know? Pescatarian diets provide omega-3 fatty acids from fish, which support brain and heart health.';
      default:
        return 'Did you know? A balanced diet with variety from all food groups provides the nutrients your body needs to thrive.';
    }
  }

  void _flipCard() {
    setState(() {
      _isFlipped = !_isFlipped;
      if (_isFlipped) {
        _flipController.forward();
      } else {
        _flipController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    final textTheme = Theme.of(context).textTheme;
    double fontSize = getTextScale(4, context);

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Expanded(
              flex: 2,
              child: Column(
                children: [
                  GestureDetector(
                    onTap: () {
                      Get.to(() => const NutritionSettingsPage(
                            isHealthExpand: true,
                          ));
                    },
                    child: Text(
                      'Your Diet: ',
                      style: textTheme.displaySmall?.copyWith(
                        color: kAccent,
                        fontSize: getTextScale(7, context),
                      ),
                    ),
                  ),
                  Text(
                    widget.diet.isNotEmpty
                        ? capitalizeFirstLetter(widget.diet)
                        : 'Not set',
                    style: textTheme.titleLarge?.copyWith(
                      fontSize: fontSize,
                      fontWeight: FontWeight.w100,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: getPercentageWidth(4, context)),
            Expanded(
              flex: 2,
              child: Column(
                children: [
                  if (showCaloriesAndGoal)
                    SizedBox(width: getPercentageWidth(1, context)),
                  if (showCaloriesAndGoal)
                    GestureDetector(
                      onTap: () {
                        Get.to(() => const NutritionSettingsPage(
                              isHealthExpand: true,
                            ));
                      },
                      child: Text(
                        'Goal: ',
                        style: textTheme.displaySmall?.copyWith(
                          color: kAccent,
                          fontSize: getTextScale(7, context),
                        ),
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
                      style: textTheme.titleLarge?.copyWith(
                        fontSize: fontSize,
                        fontWeight: FontWeight.w100,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: getPercentageHeight(1, context)),
        GestureDetector(
          onTap: _flipCard,
          child: Container(
            margin: EdgeInsets.symmetric(
                horizontal: getPercentageWidth(2, context),
                vertical: getPercentageHeight(1, context)),
            height: getPercentageHeight(25, context),
            child: AnimatedBuilder(
              animation: _flipAnimation,
              builder: (context, child) {
                final isShowingFront = _flipAnimation.value < 0.5;
                return Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.001)
                    ..rotateY(_flipAnimation.value * math.pi),
                  child: Card(
                    color: isDarkMode ? kDarkGrey : kWhite,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    elevation: 3,
                    child: Container(
                      padding: EdgeInsets.all(getPercentageWidth(4, context)),
                      child: isShowingFront
                          ? _buildDietFactSide(context, textTheme, isDarkMode)
                          : Transform(
                              alignment: Alignment.center,
                              transform: Matrix4.identity()..rotateY(math.pi),
                              child: _buildFeaturedMealSide(
                                  context, textTheme, isDarkMode),
                            ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        SizedBox(height: getPercentageHeight(2, context)),
      ],
    );
  }

  Widget _buildDietFactSide(
      BuildContext context, TextTheme textTheme, bool isDarkMode) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.lightbulb_outline,
            color: kAccent,
            size: getIconScale(10, context),
          ),
          SizedBox(height: getPercentageHeight(2, context)),
          Text(
            _getDietFact(),
            style: textTheme.bodyLarge?.copyWith(
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: getPercentageHeight(1, context)),
          const Divider(
            color: kAccentLight,
            thickness: 1,
          ),
          SizedBox(height: getPercentageHeight(1, context)),
          Text(
            'Tap to see Featured Meal',
            style: textTheme.labelSmall?.copyWith(
              color: kAccent,
              fontSize: getTextScale(4, context),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturedMealSide(
      BuildContext context, TextTheme textTheme, bool isDarkMode) {
    if (widget.featuredMeal == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.restaurant_menu,
              color: kAccent,
              size: getIconScale(10, context),
            ),
            SizedBox(height: getPercentageHeight(2, context)),
            Text(
              'No featured meal available',
              style: textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: getPercentageHeight(1, context)),
            Text(
              'Tap to go back',
              style: textTheme.labelLarge?.copyWith(
                color: kAccent,
                fontSize: getTextScale(4, context),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Featured Meal for ${capitalizeFirstLetter(widget.diet)}',
          style: textTheme.bodyLarge?.copyWith(
            color: kAccent,
            fontSize: getTextScale(6, context),
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: getPercentageHeight(2, context)),
        Expanded(
          child: GestureDetector(
            onTap: widget.onMealTap != null
                ? () => widget.onMealTap!(widget.featuredMeal!)
                : null,
            child: Container(
              decoration: BoxDecoration(
                color: kAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              padding: EdgeInsets.all(getPercentageWidth(3, context)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Expanded(
                    flex: 2,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: widget.featuredMeal!.mediaPaths.isNotEmpty
                          ? buildMealImage(
                              widget.featuredMeal!.mediaPaths.first,
                              getPercentageWidth(25, context),
                              getPercentageWidth(25, context),
                            )
                          : Image.asset(
                              intPlaceholderImage,
                              width: getPercentageWidth(25, context),
                              height: getPercentageWidth(25, context),
                              fit: BoxFit.cover,
                            ),
                    ),
                  ),
                  SizedBox(width: getPercentageWidth(2, context)),
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: getPercentageHeight(1, context)),
                        Text(
                          widget.featuredMeal!.title,
                          style: textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: getPercentageHeight(1, context)),
                        Text(
                          '${widget.featuredMeal!.calories.toString()} kcal',
                          style: textTheme.labelLarge?.copyWith(
                            color: kAccent,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: getPercentageHeight(1, context)),
                        Text(
                          'Tap to view recipe',
                          style: textTheme.labelSmall?.copyWith(
                            color: kAccent.withOpacity(0.7),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
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
    _flipController.dispose();
    super.dispose();
  }
}
