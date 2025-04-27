
import 'package:flutter/material.dart';

import '../constants.dart';

//this widget can be used in several screen that show list of recipe, in this template, RecipeCard will are being used in home_screen and search_results_screen. RecipeCard uses several argument, ie recipe, press, width, height.

class RecipeCard extends StatelessWidget {
  const RecipeCard({
    super.key,
    required this.recipe,
    required this.press,
    required this.width,
    required this.height,
  });

  final dynamic
      recipe; // call the demo model, Recipe list from /lib/models/recipes.dart
  final GestureTapCallback
      press; // you can assign this argument as an action when the card is press
  final double width,
      height; // you can determine the width and height upon calling this card

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: press,
      child: Row(
        children: [
          SizedBox(
            width: width,
            height: height,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                children: [
                  // recipe image
                  SizedBox(
                    width: width,
                    height: height,
                    child: Image.asset(
                      recipe.image,
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
                          const Color(0xff343434).withOpacity(0.1),
                          const Color(0xff343434).withOpacity(0.3),
                        ],
                      ),
                    ),
                  ),

                  // recipe rating
                  Positioned(
                    right: 10,
                    top: 10,
                    child: Container(
                      decoration: BoxDecoration(
                          color: const Color(0xffffe1b3),
                          borderRadius: BorderRadius.circular(10)),
                      child: Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.star,
                              color: Colors.amber,
                              size: 19,
                            ),
                            Text(
                              "${recipe.rating}",
                              style: const TextStyle(color: Colors.black),
                            )
                          ],
                        ),
                      ),
                    ),
                  ),

                  // recipe title
                  Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 10),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          recipe.title,
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w600),
                          maxLines: 2,
                        ),
                        const SizedBox(
                          height: 7,
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // cooking time
                            Row(
                              children: [
                                const Icon(
                                  Icons.alarm,
                                  color: Colors.white,
                                  size: 17,
                                ),
                                Text(
                                  "${recipe.time} $minute",
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ],
                            ),
                            // recipe serves
                            Text(
                              "${recipe.serve} $serves",
                              style: const TextStyle(color: Colors.white),
                            )
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
