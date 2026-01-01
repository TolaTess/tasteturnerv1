import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../constants.dart';
import '../data_models/meal_model.dart';
import '../helper/utils.dart';
import '../pages/recipe_card_flex.dart';
import '../detail_screen/recipe_detail.dart';
import '../widgets/icon_widget.dart';

class FavoriteScreen extends StatefulWidget {
  const FavoriteScreen({super.key});

  @override
  State<FavoriteScreen> createState() => _FavoriteScreenState();
}

class _FavoriteScreenState extends State<FavoriteScreen> {
  List<Meal> favoriteMeals = [];
  bool isLoading = true;
  StreamSubscription<DocumentSnapshot>? _favoritesSubscription;

  @override
  void initState() {
    super.initState();
    _setupFavoritesListener();
  }

  void _setupFavoritesListener() {
    final currentUserId = userService.userId;
    
    if (currentUserId == null || currentUserId.isEmpty) {
      setState(() {
        isLoading = false;
      });
      return;
    }

    // Listen to real-time changes in the user document's favorites field
    _favoritesSubscription = firestore
        .collection('users')
        .doc(currentUserId)
        .snapshots()
        .listen(
      (snapshot) {
        if (!mounted) return;
        
        // When favorites change, refetch the favorite meals
        _fetchFavorites();
      },
      onError: (error) {
        debugPrint("Error listening to favorites: $error");
        if (mounted) {
          setState(() {
            isLoading = false;
          });
        }
      },
    );

    // Initial fetch
    _fetchFavorites();
  }

  Future<void> _fetchFavorites() async {
    try {
      final meals = await mealManager.fetchFavoriteMeals();
      if (mounted) {
        setState(() {
          favoriteMeals = meals;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching favorite meals: $e");
      if (mounted) {
        setState(() {
          isLoading = false; // Stop loading on error
        });
      }
    }
  }

  @override
  void dispose() {
    _favoritesSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text('Your Favorite Dishes',
            style: textTheme.displaySmall?.copyWith(
                fontSize: getPercentageWidth(7, context),
                fontWeight: FontWeight.w500)),
        automaticallyImplyLeading: false,
        leading: Padding(
          padding: EdgeInsets.all(getPercentageWidth(1, context)),
          child: InkWell(
            onTap: () {
              Get.back();
            },
            child: const IconCircleButton(),
          ),
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  color: kAccent,
                ),
              )
            : favoriteMeals.isEmpty
                ? noItemTastyWidget(
                    "No favorite meals found.",
                    "Add meals to your favorites...",
                    context,
                    true,
                    'recipe',
                  )
                : SizedBox(
                    width: double.infinity,
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                            horizontal: getPercentageWidth(2, context)),
                        child: Column(
                          children: [
                            SizedBox(height: getPercentageHeight(2, context)),
                            // Generate favorite recipe cards using RecipeCardFlex()
                            ...List.generate(
                              favoriteMeals.length,
                              (index) => Padding(
                                padding: EdgeInsets.only(
                                    bottom: getPercentageHeight(2, context)),
                                child: RecipeCardFlex(
                                  recipe: favoriteMeals[index],
                                  press: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => RecipeDetailScreen(
                                        mealData: favoriteMeals[index],
                                      ),
                                    ),
                                  ),
                                  height: getPercentageHeight(13, context),
                                ),
                              ),
                            ),
                            SizedBox(
                              height: getPercentageHeight(7, context),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
      ),
    );
  }
}
