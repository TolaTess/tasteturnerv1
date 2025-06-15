import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();
    _fetchFavorites();
  }

  Future<void> _fetchFavorites() async {
    try {
      final meals =
          await mealManager.fetchFavoriteMeals(); // Use your fetch function
      setState(() {
        favoriteMeals = meals;
        isLoading = false;
      });
    } catch (e) {
      print("Error fetching favorite meals: $e");
      setState(() {
        isLoading = false; // Stop loading on error
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text('Favorites',
            style: TextStyle(
                fontSize: getTextScale(4, context),
                fontWeight: FontWeight.w600)),
        automaticallyImplyLeading: false,
        leading: Padding(
          padding: EdgeInsets.all(getPercentageWidth(1, context)),
          child: InkWell(
            onTap: () {
              Navigator.pop(context);
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
                            SizedBox(height: getPercentageHeight(1, context)),
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
