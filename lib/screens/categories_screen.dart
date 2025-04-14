import 'package:flutter/material.dart';
import '../constants.dart';
import '../data_models/base_model.dart';
import '../data_models/meal_model.dart';
import '../widgets/icon_widget.dart';
import '../widgets/search_button.dart';
import 'recipes_list_category_screen.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  List<Meal> demoMealsPlanData = [];

  @override
  void initState() {
    demoMealsPlanData = mealManager.meals;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: SizedBox(
          width: double.infinity,
          child: SingleChildScrollView(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  const SizedBox(
                    height: 24,
                  ),

                  //home appbar
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        //back arrow
                        InkWell(
                          onTap: () => Navigator.pop(context),
                          child: const IconCircleButton(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(
                    height: 8,
                  ),
                  //search bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: SearchButton(
                      press: () {},
                      
                      kText: searchRecipeHint,
                    ),
                  ),
                  const SizedBox(
                    height: 30,
                  ),
                  //generate categories list using CategoriesCard()
                  ...List.generate(
                    demoCategory.length,
                    (index) => Padding(
                      padding:
                          EdgeInsets.only(bottom: 20),
                      child: CategoriesCard(
                        category: demoCategory[index],
                        press: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const RecipeListCategory(
                              index: 1,
                              searchIngredient: '',
                            ),
                          ),
                        ),
                        height: 150,
                      ),
                    ),
                  ),
                  const SizedBox(
                    height: 70,
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

//this widget will render recipe card with flexible (match to parert) width.

class CategoriesCard extends StatelessWidget {
  const CategoriesCard({
    super.key,
    required this.category,
    required this.press,
    required this.height,
  });

  final MealCategory
      category; // call the demo model, Recipe list from /lib/models/recipes.dart
  final GestureTapCallback
      press; // you can assign this argument as an action when the card is press
  final double
      height; // you can determine the width and height upon calling this card

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: press,
      child: SizedBox(
        width: double.infinity,
        height: height,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              // category image
              SizedBox(
                width: double.infinity,
                height: height,
                child: Image.asset(
                  category.image,
                  fit: BoxFit.cover,
                ),
              ),
              // gradient to make image darker
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xff343434).withOpacity(0.4),
                      const Color(0xff343434).withOpacity(0.1),
                    ],
                  ),
                ),
              ),

              //recipes quantity in the category
              Positioned(
                right: 10,
                bottom: 10,
                child: Container(
                  decoration: BoxDecoration(
                      color: const Color(0xffffe1b3),
                      borderRadius: BorderRadius.circular(10)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.menu_book,
                          color: Colors.amber,
                          size: 19,
                        ),
                        const SizedBox(
                          width: 5,
                        ),
                        Text(
                          "${category.recipesNum} ${recipes.toLowerCase()}",
                          style: const TextStyle(color: Colors.black),
                        )
                      ],
                    ),
                  ),
                ),
              ),

              // category title
              Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 10),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w500),
                      maxLines: 2,
                    ),
                    const SizedBox(
                      height: 7,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
