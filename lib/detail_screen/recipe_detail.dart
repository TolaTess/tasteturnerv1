import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../data_models/meal_model.dart';
import '../data_models/user_data_model.dart';
import '../helper/helper_functions.dart';
import '../helper/notifications_helper.dart';
import '../helper/utils.dart';
import '../screens/friend_screen.dart';
import '../screens/profile_screen.dart';
import '../widgets/primary_button.dart';
import '../constants.dart';
import '../screens/createrecipe_screen.dart';
import '../screens/user_profile_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';

class RecipeDetailScreen extends StatefulWidget {
  const RecipeDetailScreen(
      {super.key, this.mealData, this.mealId, this.screen = 'recipe'});

  final Meal? mealData;
  final String? mealId;
  final String screen;

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  Meal? _meal;
  bool _loading = false;
  StreamSubscription<DocumentSnapshot>? _mealSubscription;

  @override
  void initState() {
    super.initState();

    if (widget.screen == 'share_recipe') {
      _getMeal();
    } else if (widget.screen == 'fridge-recipe') {
      // For fridge recipes, we need to fetch from Firestore using mealId
      if (widget.mealId != null && widget.mealId!.isNotEmpty) {
        _getMealById(widget.mealId!);
      } else if (widget.mealData != null) {
        // Fallback to passed meal data if no mealId
        _meal = widget.mealData;
      }
    } else {
      // For regular recipes
      if (widget.mealData != null) {
        _meal = widget.mealData;
        // If instructions are empty and we have a valid mealId, start listening for real-time updates
        if (widget.mealData!.instructions.isEmpty &&
            widget.mealData!.mealId.isNotEmpty) {
          _listenToMeal();
        }
      } else if (widget.mealId != null && widget.mealId!.isNotEmpty) {
        // If only mealId is provided, fetch the meal
        _getMealById(widget.mealId!);
      }
    }

    // Update user data if we have meal data
    if (widget.mealData != null) {
      friendController.updateUserData(widget.mealData!.userId);
    }
  }

  @override
  void dispose() {
    _mealSubscription?.cancel();
    super.dispose();
  }

  /// Listen for real-time updates to the meal document
  void _listenToMeal() {
    setState(() => _loading = true);

    // Use _meal.mealId if available, otherwise fall back to widget.mealData
    final mealIdToListen = _meal?.mealId ?? widget.mealData?.mealId ?? '';

    // Check if mealId is valid before attempting to listen
    if (mealIdToListen.isEmpty) {
      debugPrint(
          'Warning: mealId is empty, cannot listen to Firestore document');
      setState(() => _loading = false);
      return;
    }

    _mealSubscription = firestore
        .collection('meals')
        .doc(mealIdToListen)
        .snapshots()
        .listen((snapshot) {
      if (!mounted) {
        return;
      }

      if (snapshot.exists && snapshot.data() != null) {
        try {
          final data = snapshot.data()!;

          final meal = Meal.fromJson(snapshot.id, data);

          setState(() {
            _meal = meal;
            _loading = false;
          });

          // If instructions are now populated, we can stop listening
          if (meal.instructions.isNotEmpty) {
            _mealSubscription?.cancel();
          }
        } catch (e, stackTrace) {
          debugPrint('Error parsing meal data: $e');
          debugPrint('Stack trace: $stackTrace');
          setState(() => _loading = false);
        }
      } else {
        setState(() => _loading = false);
      }
    }, onError: (error) {
      debugPrint('Error listening to meal updates: $error');
      if (mounted) {
        setState(() => _loading = false);
      }
    });
  }

  Future<void> _getMeal() async {
    setState(() => _loading = true);

    // Check if mealId is valid before attempting to fetch
    if (widget.mealData?.mealId.isEmpty ?? true) {
      debugPrint('Warning: mealId is empty, cannot fetch meal from Firestore');
      setState(() {
        _meal = widget.mealData; // Use the passed meal data instead
        _loading = false;
      });
      return;
    }

    final meal = await mealManager.getMealbyMealID(widget.mealData!.mealId);
    if (!mounted) return;
    setState(() {
      _meal = meal;
      _loading = false;
    });
  }

  Future<void> _getMealById(String mealId) async {
    setState(() => _loading = true);

    try {
      final meal = await mealManager.getMealbyMealID(mealId);
      if (!mounted) return;
      setState(() {
        _meal = meal;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Error fetching meal by ID: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        // Show error or fallback to passed meal data
        if (widget.mealData != null) {
          _meal = widget.mealData;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_meal == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return Scaffold(
      floatingActionButton: buildFullWidthAddMealButton(
        context: context,
        meal: _meal!,
        date: DateTime.now(),
      ),
      body: Obx(() {
        final mealUser = friendController.userProfileData.value;

        return SafeArea(
          child: CustomScrollView(
            slivers: [
              // Custom app bar > recipe image, back button, more action button, and drawer
              SlvAppBar(
                meal: _meal!,
              ),

              // Recipe title, time to cook, serves, rating, and recipe description
              RecipeTittle(
                meal: _meal!,
                onEdit: () async {
                  final updatedMeal = await Navigator.push<Meal>(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CreateRecipeScreen(
                        screenType: 'edit',
                        meal: _meal!,
                      ),
                    ),
                  );
                  if (updatedMeal != null) {
                    setState(() {
                      _meal = updatedMeal;
                    });
                  } else {
                    // Refetch from Firestore in case of update
                    final doc = await firestore
                        .collection('meals')
                        .doc(_meal!.mealId)
                        .get();
                    if (doc.exists) {
                      setState(() {
                        _meal = Meal.fromJson(doc.id, doc.data()!);
                      });
                    }
                  }
                },
              ),

              // Chef profile: avatar, name, location, and follow button
              RecipeProfile(
                profileId: _meal!.userId,
                mealUser: mealUser,
              ),

              // Nutrition facts (sliver) grid view
              NutritionFacts(
                meal: _meal!,
              ),

              // Turner's Notes section
              if (_meal != null) ..._buildTurnersNotes(context),

              if (_meal!.suggestions != null &&
                  _meal!.suggestions!.isNotEmpty &&
                  _meal!.suggestions!['additions'] != null &&
                  _meal!.suggestions!['additions'].isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: getPercentageWidth(3, context),
                      vertical: getPercentageHeight(2, context),
                    ),
                    child: Builder(
                      builder: (context) {
                        final suggestionsWrapper = {
                          'suggestions': _meal!.suggestions
                        };
                        return buildSuggestionsSection(
                            context, suggestionsWrapper, true);
                      },
                    ),
                  ),
                ),

              // Ingredients title
              if (_meal!.ingredients.isNotEmpty)
                IngredientsTittle(
                  meal: _meal!,
                ),

              // Ingredients details
              if (_meal!.ingredients.isNotEmpty)
                IngredientsDetail(
                  meal: _meal!,
                ),

              // Directions title
              if (_meal!.instructions.isNotEmpty &&
                  _meal!.instructions.first.isNotEmpty) ...[
                DirectionsTittle(
                  meal: _meal!,
                ),
              ] else ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.only(
                        bottom: getPercentageHeight(15, context)),
                    child: noItemTastyWidget(
                      'Dish is being prepared, Chef. Please check back in a moment.',
                      'The recipe is being processed',
                      context,
                      false,
                      '',
                    ),
                  ),
                ),
              ],

              // Directions detail
              if (_meal!.instructions.isNotEmpty &&
                  _meal!.instructions.first.isNotEmpty)
                DirectionsDetail(
                  meal: _meal!,
                ),

              if (_meal!.instructions.isEmpty ||
                  _meal!.instructions.first.isEmpty)
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: getPercentageHeight(20, context),
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }

  /// Generate Turner's Notes based on meal data
  List<String> _generateTurnerNotes(Meal meal) {
    List<String> notes = [];

    // Get nutrition data
    Map<String, String> nutritionMap = {};
    if (meal.macros.isNotEmpty) {
      nutritionMap = {...meal.macros};
      nutritionMap['calories'] = meal.calories.toString();
    } else if (meal.nutrition.isNotEmpty) {
      nutritionMap = meal.nutrition;
    } else if (meal.nutritionalInfo.isNotEmpty) {
      nutritionMap = meal.nutritionalInfo;
      if (nutritionMap['calories'] == null) {
        nutritionMap['calories'] = meal.calories.toString();
      }
    } else {
      nutritionMap['calories'] = meal.calories.toString();
    }

    // Macro balance notes
    if (nutritionMap.isNotEmpty) {
      final protein = double.tryParse(
              removeAllTextJustNumbers(nutritionMap['protein'] ?? '0')) ??
          0.0;
      final carbs = double.tryParse(
              removeAllTextJustNumbers(nutritionMap['carbs'] ?? '0')) ??
          0.0;
      final fat = double.tryParse(
              removeAllTextJustNumbers(nutritionMap['fat'] ?? '0')) ??
          0.0;
      final calories = double.tryParse(
              removeAllTextJustNumbers(nutritionMap['calories'] ?? '0')) ??
          0.0;

      if (calories > 0) {
        final proteinPercent = (protein * 4 / calories) * 100;
        final carbsPercent = (carbs * 4 / calories) * 100;
        final fatPercent = (fat * 9 / calories) * 100;

        // High protein note
        if (proteinPercent > 30) {
          notes.add(
              '**High protein** content makes this a great option for muscle recovery and satiety, Chef.');
        }

        // Balanced macros note
        if (proteinPercent >= 20 &&
            proteinPercent <= 35 &&
            carbsPercent >= 30 &&
            carbsPercent <= 50 &&
            fatPercent >= 20 &&
            fatPercent <= 35) {
          notes.add(
              '**Well-balanced macros** - this dish provides a solid foundation for your daily nutrition goals, Chef.');
        }

        // High carb note
        if (carbsPercent > 60) {
          notes.add(
              '**High carb** content provides quick energy - perfect for pre-workout or active days, Chef.');
        }
      }
    }

    // Cooking method notes
    if (meal.cookingMethod != null && meal.cookingMethod!.isNotEmpty) {
      final method = meal.cookingMethod!.toLowerCase();
      if (method.contains('grill') || method.contains('grilled')) {
        notes.add(
            '**Grilled** preparation enhances flavor while keeping the dish lean, Chef.');
      } else if (method.contains('slow') || method.contains('braise')) {
        notes.add(
            '**Slow-cooked** method ensures maximum tenderness and flavor development, Chef.');
      } else if (method.contains('steam') || method.contains('steamed')) {
        notes.add(
            '**Steamed** preparation preserves nutrients and keeps the dish light, Chef.');
      } else if (method.contains('roast') || method.contains('roasted')) {
        notes.add('**Roasted** for optimal flavor and texture, Chef.');
      }
    }

    // Portion size notes
    if (meal.serveQty > 0) {
      if (meal.serveQty >= 4) {
        notes.add(
            '**Large portion** size - perfect for family service or meal prep, Chef.');
      } else if (meal.serveQty == 1) {
        notes.add('**Single portion** - ideal for solo service, Chef.');
      }
    }

    // Preparation time notes
    if (meal.cookingTime != null && meal.cookingTime!.isNotEmpty) {
      final timeStr = meal.cookingTime!.toLowerCase();
      final timeMatch = RegExp(r'(\d+)').firstMatch(timeStr);
      if (timeMatch != null) {
        final minutes = int.tryParse(timeMatch.group(1) ?? '0') ?? 0;
        if (minutes <= 30) {
          notes.add(
              '**Quick prep** - ready in under 30 minutes, perfect for busy service, Chef.');
        } else if (minutes > 60) {
          notes.add(
              '**Longer prep time** - plan ahead for this dish, but the results are worth it, Chef.');
        }
      }
    }

    // Category notes
    if (meal.categories.isNotEmpty) {
      final categories = meal.categories.map((c) => c.toLowerCase()).toList();
      if (categories.any((c) => c.contains('breakfast'))) {
        notes
            .add('Perfect **breakfast** option to start your day right, Chef.');
      } else if (categories.any((c) => c.contains('lunch'))) {
        notes.add('Great **lunch** choice for midday fuel, Chef.');
      } else if (categories.any((c) => c.contains('dinner'))) {
        notes.add('Excellent **dinner** selection for evening service, Chef.');
      } else if (categories.any((c) => c.contains('snack'))) {
        notes.add(
            '**Snack** option to keep energy levels steady between meals, Chef.');
      }
    }

    // Ingredient quality notes (if certain high-quality ingredients are present)
    if (meal.ingredients.isNotEmpty) {
      final ingredientKeys =
          meal.ingredients.keys.map((k) => k.toLowerCase()).toList();
      if (ingredientKeys.any((k) =>
          k.contains('avocado') ||
          k.contains('salmon') ||
          k.contains('quinoa') ||
          k.contains('kale') ||
          k.contains('spinach'))) {
        notes.add(
            'Features **premium ingredients** that add both flavor and nutritional value, Chef.');
      }
    }

    return notes;
  }

  /// Parse Turner's note to highlight key terms
  List<TextSpan> _parseTurnerNote(String note) {
    final parts = note.split('**');
    List<TextSpan> spans = [];

    for (int i = 0; i < parts.length; i++) {
      if (i % 2 == 0) {
        // Regular text
        spans.add(TextSpan(text: parts[i]));
      } else {
        // Bold text (key term)
        spans.add(TextSpan(
          text: parts[i],
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: kAccent,
          ),
        ));
      }
    }

    return spans;
  }

  /// Build Turner's Notes section widget
  List<Widget> _buildTurnersNotes(BuildContext context) {
    if (_meal == null) return [];

    final notes = _generateTurnerNotes(_meal!);
    if (notes.isEmpty) return [];

    final isDarkMode = getThemeProvider(context).isDarkMode;

    return [
      SliverToBoxAdapter(
        child: Container(
          margin: EdgeInsets.only(
            left: getPercentageWidth(5, context),
            right: getPercentageWidth(5, context),
            top: getPercentageHeight(2, context),
          ),
          padding: EdgeInsets.all(getPercentageWidth(3, context)),
          decoration: BoxDecoration(
            color: kAccent.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: kAccent.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Turner\'s Notes',
                style: TextStyle(
                  fontSize: getTextScale(4.5, context),
                  fontWeight: FontWeight.w700,
                  color: kAccent,
                ),
              ),
              SizedBox(height: getPercentageHeight(1, context)),
              ...notes.map((note) => Padding(
                    padding: EdgeInsets.only(
                        bottom: getPercentageHeight(0.5, context)),
                    child: RichText(
                      text: TextSpan(
                        style: TextStyle(
                          fontSize: getTextScale(3.5, context),
                          fontStyle: FontStyle.italic,
                          color: isDarkMode ? kWhite : kBlack,
                          height: 1.5,
                        ),
                        children: _parseTurnerNote(note),
                      ),
                    ),
                  )),
            ],
          ),
        ),
      ),
    ];
  }
}

// this component is Sliver AppBar

class SlvAppBar extends StatelessWidget {
  const SlvAppBar({super.key, required this.meal});

  final Meal meal;

  Widget _buildRecipeImage(Meal meal) {
    if (meal.mediaPaths.isNotEmpty &&
        meal.mediaPaths != 'null' &&
        meal.mediaPaths.first.startsWith('http')) {
      return buildOptimizedNetworkImage(
        imageUrl: meal.mediaPaths.first,
        fit: BoxFit.cover,
        placeholder: Container(
          color: Colors.grey[200],
          child: const Center(
            child: CircularProgressIndicator(color: kAccent),
          ),
        ),
        errorWidget: Image.asset(
          getAssetImageForItem(meal.category ?? 'default'),
          fit: BoxFit.cover,
        ),
      );
    } else {
      return Image.asset(
        getAssetImageForItem(meal.category ?? 'default'),
        fit: BoxFit.cover,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    return SliverAppBar(
      backgroundColor: isDarkMode ? kDarkGrey : kWhite,
      expandedHeight: MediaQuery.of(context).size.height > 1100
          ? getPercentageHeight(60, context)
          : getPercentageHeight(45, context),
      flexibleSpace: FlexibleSpaceBar(
        background: _buildRecipeImage(meal),
      ),

      //back button
      leading: Builder(builder: (BuildContext context) {
        return Padding(
          padding: EdgeInsets.all(getPercentageWidth(0.5, context)),
          child: CircleAvatar(
            backgroundColor: isDarkMode
                ? kDarkGrey.withValues(alpha: 0.4)
                : kWhite.withValues(alpha: 0.4),
            child: IconButton(
              onPressed: () {
                Get.back();
              },
              icon: Icon(
                Icons.arrow_back_ios_new,
                color: isDarkMode ? kWhite : kBlack,
              ),
            ),
          ),
        );
      }),

      bottom: PreferredSize(
        preferredSize: Size.fromHeight(getPercentageHeight(3.5, context)),
        child: Container(
          width: double.infinity,
          height: getPercentageHeight(3.5, context),
          decoration: BoxDecoration(
            color: isDarkMode ? kDarkGrey : kWhite,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(50),
              topRight: Radius.circular(50),
            ),
          ),
          child: Column(
            children: [
              SizedBox(
                height: getPercentageHeight(1, context),
              ),

              //drawer
              Container(
                width: getPercentageWidth(20, context),
                height: getPercentageHeight(0.5, context),
                color: isDarkMode ? kLightGrey : kAccent,
              )
            ],
          ),
        ),
      ),
    );
  }
}

//recipe title

class RecipeTittle extends StatefulWidget {
  const RecipeTittle({
    super.key,
    required this.meal,
    required this.onEdit,
  });

  final Meal meal;
  final Function() onEdit;

  @override
  State<RecipeTittle> createState() => _RecipeTittleState();
}

class _RecipeTittleState extends State<RecipeTittle> {
  bool _isFavorited = false;
  final String? _userId = userService.userId;

  @override
  void initState() {
    super.initState();
    _loadFavoriteStatus();
  }

  /// Format cooking time to show only numbers and "hours" or "minutes"
  String _formatCookingTime(String? cookingTime) {
    if (cookingTime == null || cookingTime.isEmpty) return '';

    // Remove common prefixes/suffixes and normalize
    String cleaned = cookingTime.trim();

    // Skip if it's "Unknown" or similar invalid values
    if (cleaned.toLowerCase() == 'unknown' ||
        cleaned.toLowerCase() == 'n/a' ||
        cleaned.isEmpty) {
      return '';
    }

    // Extract numbers and time units
    final RegExp numberRegex = RegExp(r'\d+');
    final numbers = numberRegex.allMatches(cleaned);

    if (numbers.isEmpty) return '';

    // Check for hours and minutes patterns
    final hoursMatch =
        RegExp(r'(\d+)\s*(?:hour|hr|h|hours|hrs)', caseSensitive: false)
            .firstMatch(cleaned);
    final minutesMatch =
        RegExp(r'(\d+)\s*(?:minute|min|m|minutes|mins)', caseSensitive: false)
            .firstMatch(cleaned);

    int? hours;
    int? minutes;

    if (hoursMatch != null) {
      hours = int.tryParse(hoursMatch.group(1) ?? '');
    }
    if (minutesMatch != null) {
      minutes = int.tryParse(minutesMatch.group(1) ?? '');
    }

    // If no explicit units found, assume minutes for single number
    if (hours == null && minutes == null) {
      final firstNumber = int.tryParse(numbers.first.group(0) ?? '');
      if (firstNumber != null) {
        // If number > 60, assume minutes but convert to hours
        if (firstNumber >= 60) {
          hours = firstNumber ~/ 60;
          minutes = firstNumber % 60;
        } else {
          minutes = firstNumber;
        }
      }
    }

    // Format output
    final parts = <String>[];
    if (hours != null && hours > 0) {
      parts.add('$hours ${hours == 1 ? 'hour' : 'hours'}');
    }
    if (minutes != null && minutes > 0) {
      parts.add('$minutes ${minutes == 1 ? 'minute' : 'minutes'}');
    }

    return parts.isEmpty ? '' : parts.join(' ');
  }

  Future<void> _loadFavoriteStatus() async {
    final isFavorite =
        await firebaseService.isRecipeFavorite(_userId, widget.meal.mealId);
    if (!mounted) return;
    setState(() {
      _isFavorited = isFavorite;
    });
  }

  Future<void> _toggleFavorite() async {
    await firebaseService.toggleFavorite(_userId, widget.meal.mealId);
    if (!mounted) return;
    setState(() {
      _isFavorited = !_isFavorited;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    final textTheme = Theme.of(context).textTheme;
    return SliverToBoxAdapter(
      child: Wrap(
        children: [
          Container(
            width: double.infinity,
            color: isDarkMode ? kDarkGrey : kWhite,
            child: Column(
              children: [
                //Recipe tittle
                Padding(
                  padding: EdgeInsets.symmetric(
                      horizontal: getPercentageWidth(10, context)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        capitalizeFirstLetter(widget.meal.title),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        style: textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(height: getPercentageHeight(0.5, context)),
                      if (widget.meal.description != null &&
                          widget.meal.description!.isNotEmpty &&
                          widget.meal.description != 'Unknown Description')
                        Padding(
                          padding: EdgeInsets.symmetric(
                              vertical: getPercentageHeight(0.5, context)),
                          child: Text(
                            widget.meal.description!,
                            textAlign: TextAlign.center,
                            style: textTheme.bodyMedium?.copyWith(
                              fontStyle: FontStyle.italic,
                              color: kLightGrey,
                              fontWeight: FontWeight.w400,
                            ),
                            maxLines: 5,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      SizedBox(height: getPercentageHeight(0.5, context)),
                      Text(
                        "Portions: ${widget.meal.serveQty == 0 ? '1' : widget.meal.serveQty.toString()}",
                        style: textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      SizedBox(height: getPercentageHeight(1, context)),
                      if (widget.meal.cookingTime != null &&
                          widget.meal.cookingTime!.isNotEmpty) ...[
                        Builder(
                          builder: (context) {
                            final formattedTime =
                                _formatCookingTime(widget.meal.cookingTime);
                            if (formattedTime.isEmpty)
                              return const SizedBox.shrink();

                            return Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(width: getPercentageWidth(4, context)),
                                Icon(Icons.access_time,
                                    size: getIconScale(4, context),
                                    color: kAccent),
                                SizedBox(width: getPercentageWidth(2, context)),
                                Text(
                                  formattedTime,
                                  textAlign: TextAlign.center,
                                  style: textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w400,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  maxLines: 1,
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                      SizedBox(height: getPercentageHeight(1, context)),
                      if (widget.meal.cookingMethod != null &&
                          widget.meal.cookingMethod!.isNotEmpty)
                        Padding(
                          padding: EdgeInsets.only(
                              top: getPercentageHeight(0.5, context)),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.restaurant,
                                  size: getIconScale(4, context),
                                  color: kAccent),
                              SizedBox(width: getPercentageWidth(1, context)),
                              Text(
                                "Heat Method: ${capitalizeFirstLetter(widget.meal.cookingMethod!)}",
                                maxLines: 1,
                                style: textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w400,
                                  fontStyle: FontStyle.italic,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (widget.meal.categories.isNotEmpty) ...[
                        Padding(
                          padding: EdgeInsets.only(
                              top: getPercentageHeight(0.5, context)),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.category,
                                  size: getIconScale(4, context),
                                  color: kAccent),
                              SizedBox(width: getPercentageWidth(1, context)),
                              Flexible(
                                child: Text(
                                  "Menu Categories: ${widget.meal.categories.map((e) => capitalizeFirstLetter(e)).join(', ')}",
                                  overflow: TextOverflow.ellipsis,
                                  style: textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.w400,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                SizedBox(height: getPercentageHeight(1, context)),
                //time, serve, rating
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(width: getPercentageWidth(2, context)),
                    GestureDetector(
                      onTap: _toggleFavorite,
                      child: Container(
                        decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10)),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal: getPercentageWidth(1.5, context)),
                          child: Icon(
                            _isFavorited
                                ? Icons.favorite
                                : Icons.favorite_border,
                            color: kRed,
                            size: getResponsiveBoxSize(context, 20, 20),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: getPercentageWidth(2.5, context)),
                    GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => FriendScreen(
                            dataSrc: {
                              ...widget.meal.toJson(),
                              'mealId': widget.meal.mealId
                            },
                            screen: 'share_recipe',
                          ),
                        ),
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10)),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal: getPercentageWidth(1.5, context)),
                          child: Icon(
                            Icons.ios_share,
                            color: kAccent,
                            size: getResponsiveBoxSize(context, 20, 20),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: getPercentageWidth(2, context)),

                    // Edit button if user is the owner
                    if (userService.userId == widget.meal.userId) ...[
                      TextButton.icon(
                        onPressed: widget.onEdit,
                        icon: Icon(Icons.edit,
                            size: getResponsiveBoxSize(context, 17, 17)),
                        label: Text('Remake Plate',
                            style: textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w400,
                            )),
                        style: TextButton.styleFrom(
                          foregroundColor: kAccent,
                          padding: EdgeInsets.symmetric(
                              horizontal: getPercentageWidth(1.5, context)),
                        ),
                      ),
                      SizedBox(width: getPercentageWidth(1.5, context)),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: kRed),
                        iconSize: getResponsiveBoxSize(context, 20, 20),
                        tooltip: 'Remove from Menu',
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15)),
                              backgroundColor:
                                  getThemeProvider(context).isDarkMode
                                      ? kDarkGrey
                                      : kWhite,
                              title: Text('Remove from Menu',
                                  style: textTheme.bodyMedium?.copyWith(
                                    color: getThemeProvider(context).isDarkMode
                                        ? kWhite
                                        : kDarkGrey,
                                    fontWeight: FontWeight.w400,
                                  )),
                              content: Text(
                                  'Are you sure you want to remove this dish from your menu, Chef? This action cannot be undone, Chef.',
                                  style: textTheme.bodyMedium?.copyWith(
                                    color: getThemeProvider(context).isDarkMode
                                        ? kWhite
                                        : kDarkGrey,
                                    fontWeight: FontWeight.w400,
                                  )),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: Text('Cancel',
                                      style: textTheme.bodyMedium?.copyWith(
                                        color:
                                            getThemeProvider(context).isDarkMode
                                                ? kWhite
                                                : kDarkGrey,
                                        fontWeight: FontWeight.w400,
                                      )),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: Text('Remove',
                                      style: textTheme.bodyMedium?.copyWith(
                                        color: kRed,
                                        fontWeight: FontWeight.w400,
                                      )),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            try {
                              await mealManager.removeMeal(widget.meal.mealId);
                              if (context.mounted) {
                                showTastySnackbar('Service Approved',
                                    'Dish removed from menu, Chef!', context);
                                Navigator.pop(context);
                              }
                            } catch (e) {
                              if (context.mounted) {
                                showTastySnackbar(
                                    'Service Error',
                                    'Failed to remove dish, Chef. Please try again.',
                                    context,
                                    backgroundColor: kRed);
                              }
                            }
                          }
                        },
                      ),
                    ],
                  ],
                ),
                SizedBox(
                  height: getPercentageHeight(1, context),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}

//recipe filter
class RecipeProfile extends StatefulWidget {
  final UserModel? mealUser;
  final String profileId;

  const RecipeProfile({
    super.key,
    required this.mealUser,
    this.profileId = '',
  });

  @override
  State<RecipeProfile> createState() => _RecipeProfileState();
}

class _RecipeProfileState extends State<RecipeProfile> {
  @override
  void initState() {
    super.initState();
    friendController.fetchFollowing(userService.userId ?? '');
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    final textTheme = Theme.of(context).textTheme;
    return SliverPadding(
      padding: EdgeInsets.only(
        left: getPercentageWidth(5, context),
        right: getPercentageWidth(5, context),
        top: getPercentageHeight(2, context),
      ),
      sliver: SliverToBoxAdapter(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                //chef avatar
                GestureDetector(
                  onTap: () {
                    if (widget.profileId.isEmpty) return;

                    // ✅ Navigate to ProfileScreen if viewing own profile
                    if (userService.userId == widget.profileId) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ProfileScreen(),
                        ),
                      );
                    } else {
                      // ✅ Navigate to UserProfileScreen for other users
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              UserProfileScreen(userId: widget.profileId),
                        ),
                      );
                    }
                  },
                  child: CircleAvatar(
                    radius: getResponsiveBoxSize(context, 20, 20),
                    backgroundColor: kAccent.withValues(alpha: kOpacity),
                    child: CircleAvatar(
                      backgroundImage: widget.mealUser?.profileImage != null &&
                              widget.mealUser!.profileImage!.isNotEmpty &&
                              widget.mealUser!.profileImage!.contains('http')
                          ? CachedNetworkImageProvider(
                              widget.mealUser!.profileImage!)
                          : const AssetImage(intPlaceholderImage)
                              as ImageProvider,
                      radius: getResponsiveBoxSize(context, 18, 18),
                    ),
                  ),
                ),
                SizedBox(
                  width: getPercentageWidth(2, context),
                ),
                //name and location
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      capitalizeFirstLetter(
                          widget.mealUser?.displayName ?? appName),
                      style: textTheme.bodyLarge?.copyWith(
                        color: isDarkMode ? kWhite : kBlack,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // Follow button - Show only if the user is not viewing their own profile
            if (userService.userId != widget.profileId)
              Obx(() {
                bool isFollowing =
                    friendController.isFollowing(widget.profileId);

                // ✅ Properly check if the profile ID is in the following list
                if (!isFollowing) {
                  isFollowing =
                      friendController.followingList.contains(widget.profileId);
                }

                return AppButton(
                  height: 4.5,
                  type: AppButtonType.follow,
                  text: isFollowing ? 'Unfollow' : follow,
                  onPressed: () {
                    if (isFollowing) {
                      friendController.unfollowFriend(
                          userService.userId ?? '', widget.profileId, context);
                    } else {
                      friendController.followFriend(
                          userService.userId ?? '',
                          widget.profileId,
                          widget.mealUser?.displayName ?? '',
                          context);
                    }

                    // ✅ Toggle UI immediately for better user experience
                    friendController.toggleFollowStatus(widget.profileId);
                  },
                );
              }),
          ],
        ),
      ),
    );
  }
}

//nutrition facts

class NutritionFacts extends StatelessWidget {
  const NutritionFacts({
    super.key,
    required this.meal,
  });

  final Meal meal;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    final textTheme = Theme.of(context).textTheme;

    Map<String, String> nutritionMap = {};

    if (meal.macros.isNotEmpty) {
      nutritionMap = {...meal.macros};
      // Always add calories to macros since it's not included in macros but needed
      nutritionMap['calories'] = meal.calories.toString();
    } else if (meal.nutrition.isNotEmpty) {
      nutritionMap = meal.nutrition;
    } else if (meal.nutritionalInfo.isNotEmpty) {
      nutritionMap = meal.nutritionalInfo;
      if (nutritionMap['calories'] == null) {
        nutritionMap['calories'] = meal.calories.toString();
      }
    } else {
      nutritionMap = {};
      nutritionMap['calories'] = meal.calories.toString();
    }

    List<Color> colors = [
      Colors.orange,
      Colors.blue,
      Colors.green,
      Colors.purple,
    ];

    // Convert map entries to a list for iteration
    List<MapEntry<String, String>> nutritionEntries =
        nutritionMap.entries.toList();

    return SliverPadding(
      padding: EdgeInsets.only(
        left: getPercentageWidth(3, context),
        right: getPercentageWidth(3, context),
        top: getPercentageHeight(3, context),
      ),
      sliver: SliverGrid(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            return Container(
              decoration: BoxDecoration(
                color: colors[index % colors.length].withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: colors[index % colors.length].withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: getPercentageWidth(3, context)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Nutrition type (key)
                    Text(
                      capitalizeFirstLetter(normaliseMacrosText(
                          nutritionEntries[index].key)), // Display key
                      style: textTheme.displayMedium?.copyWith(
                        color: isDarkMode ? kWhite : kBlack,
                        fontWeight: FontWeight.w400,
                        fontSize: getTextScale(4, context),
                      ),
                    ),
                    // Quantity (value)
                    Text(
                      removeAllTextJustNumbers(nutritionEntries[index].value) +
                          (nutritionEntries[index].key == 'calories'
                              ? ' kcal'
                              : ' g'), // Display value
                      style: textTheme.bodyMedium?.copyWith(
                        color: isDarkMode ? kWhite : kBlack,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
          childCount: nutritionEntries.length,
        ),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisExtent: getPercentageHeight(8, context),
          crossAxisSpacing: getPercentageWidth(4, context),
          mainAxisSpacing: getPercentageHeight(1, context),
        ),
      ),
    );
  }
}

//-----------------------Ingredient Title-----------------------------------

class IngredientsTittle extends StatelessWidget {
  const IngredientsTittle({
    super.key,
    required this.meal,
  });

  final Meal meal;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    final textTheme = Theme.of(context).textTheme;
    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.symmetric(
            horizontal: getPercentageWidth(3, context),
            vertical: getPercentageHeight(3, context)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (meal.ingredients.isNotEmpty) ...[
              Text('Stock',
                  style: textTheme.bodyLarge?.copyWith(
                    color: isDarkMode ? kWhite : kBlack,
                    fontWeight: FontWeight.bold,
                  )),
              Text(
                  "${meal.ingredients.length} ${meal.ingredients.length == 1 ? 'item' : 'items'}",
                  style: textTheme.bodySmall?.copyWith())
            ]
          ],
        ),
      ),
    );
  }
}

//-----------------------Ingredient Detail-----------------------------------

class IngredientsDetail extends StatelessWidget {
  const IngredientsDetail({
    super.key,
    required this.meal,
  });

  final Meal meal;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.only(
            left: getPercentageWidth(3, context),
            top: getPercentageHeight(1, context)),
        child: Row(
          children: [
            // Generate IngredientsCard using the map entries
            if (meal.ingredients.isNotEmpty) ...[
              ...meal.ingredients.entries.map(
                (entry) => IngredientsCard(
                  ingredientName: entry.key,
                  ingredientQty: entry.value,
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }
}

//-----------------------Ingredient Card-----------------------------------

class IngredientsCard extends StatelessWidget {
  const IngredientsCard({
    super.key,
    required this.ingredientName,
    required this.ingredientQty,
  });

  final String ingredientName, ingredientQty;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.only(right: getPercentageWidth(1.2, context)),
      child: Container(
        decoration: BoxDecoration(
          color: isDarkMode ? kLightGrey : kAccent.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Padding(
          padding: EdgeInsets.only(
              bottom: getPercentageHeight(2, context),
              left: getPercentageWidth(2, context),
              right: getPercentageWidth(2, context)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                height: getPercentageHeight(2, context),
              ),
              //ingredient title
              Text(
                capitalizeFirstLetter(ingredientName),
                style: textTheme.bodyMedium?.copyWith(
                  fontSize: getTextScale(3, context),
                  fontWeight: FontWeight.w700,
                  color: isDarkMode ? kWhite : kBlack,
                ),
              ),
              //ingredient quantity
              Text(ingredientQty,
                  style: textTheme.bodyMedium?.copyWith(
                    fontSize: getTextScale(2.5, context),
                    fontWeight: FontWeight.w500,
                    color: isDarkMode ? kWhite : kBlack,
                  ))
            ],
          ),
        ),
      ),
    );
  }
}

//-----------------------Directions Title-----------------------------------

class DirectionsTittle extends StatelessWidget {
  const DirectionsTittle({
    super.key,
    required this.meal,
  });

  final Meal meal;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    final textTheme = Theme.of(context).textTheme;
    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.symmetric(
            horizontal: getPercentageWidth(3, context),
            vertical: getPercentageHeight(3, context)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Service Steps',
                style: textTheme.bodyLarge?.copyWith(
                  color: isDarkMode ? kWhite : kBlack,
                  fontWeight: FontWeight.bold,
                )),
            Text(
                "${meal.instructions.length} ${meal.instructions.length == 1 ? 'service step' : 'service steps'}",
                style: textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w400,
                ))
          ],
        ),
      ),
    );
  }
}

//-----------------------Directions Detail-----------------------------------

class DirectionsDetail extends StatelessWidget {
  const DirectionsDetail({
    super.key,
    required this.meal,
  });

  final Meal meal;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: EdgeInsets.symmetric(horizontal: getPercentageWidth(3, context)),
      sliver: SliverToBoxAdapter(
        child: Column(
          children: [
            for (int i = 0; i < meal.instructions.length; i++)
              DirectionsCard(
                direction: meal.instructions[i],
                index: i,
              ),
            SizedBox(
              height: getPercentageHeight(15, context),
            ),
          ],
        ),
      ),
    );
  }
}

//-----------------------Directions Card-----------------------------------
class DirectionsCard extends StatelessWidget {
  const DirectionsCard({
    super.key,
    required this.direction,
    required this.index,
  });

  final String direction;
  final int index;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: getPercentageHeight(1, context)),
      decoration: BoxDecoration(
        color: colors[index % colors.length].withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: colors[index % colors.length].withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
            horizontal: getPercentageWidth(3, context),
            vertical: getPercentageHeight(2.5, context)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            //step number
            Text(
              'Service Step ${index + 1}',
              style: textTheme.displaySmall?.copyWith(
                fontSize: getTextScale(5, context),
                fontWeight: FontWeight.w500,
                color: isDarkMode ? kWhite : kBlack,
              ),
            ),
            //direction
            Text(
              direction,
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w400,
                color: isDarkMode ? kWhite : kBlack,
              ),
            )
          ],
        ),
      ),
    );
  }
}
