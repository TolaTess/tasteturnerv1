import 'package:flutter/material.dart';
import '../constants.dart';

class MacroType {
  final String image, title;

  MacroType({
    required this.image,
    required this.title,
  });
}

List<MacroType> demoMacroData = [
  MacroType(
    image: "assets/images/meat.jpg",
    title: "Protein",
  ),
  MacroType(
    image: "assets/images/grain.jpg",
    title: "Carbs",
  ),
  MacroType(
    image: "assets/images/butter.jpg",
    title: "Fat",
  ),
];

class CategoryData {
  final String category;
  final IconData kIcon;

  CategoryData({required this.kIcon, required this.category});
}

List<CategoryData> categoryDataTabs = [
  CategoryData(
    kIcon: Icons.food_bank,
    category: "Food",
  ),
  CategoryData(
    kIcon: Icons.group,
    category: "Group",
  ),
];

// Meals Data model

class MealsData {
  final String image, title, subtitle;

  MealsData({required this.title, required this.image, required this.subtitle});
}

List<MealsData> demoMealsData = [
  //todo: add meals data
  MealsData(
    image: 'assets/images/keto.jpg',
    title: "Breakfast",
    subtitle: "Delicious breakfast options to start your day",
  ),
  MealsData(
    image: 'assets/images/paleo.jpg',
    title: "Paleo",
    subtitle: "Delicious appetizers to start your meal",
  ),
  MealsData(
    image: 'assets/images/pescatarian.jpg',
    title: "Seafood",
    subtitle: "Delicious seafood dishes for a healthy and sustainable diet",
  ),
  MealsData(
    image: 'assets/images/vegetarian.jpg',
    title: "Vegetarian",
    subtitle: "Enjoy a plant-based diet for a healthier lifestyle",
  ),
  MealsData(
    image: 'assets/images/vegan.jpg',
    title: "Vegan",
    subtitle: "Vegan meals for a healthy and sustainable diet",
  ),
  MealsData(
    image: 'assets/images/dessert.jpg',
    title: "Dessert",
    subtitle: "Get your sweet fix with these decadent desserts",
  ),
];

// Food Category Data model

class FoodCategoryData {
  final String image, title, subtitle;

  FoodCategoryData(
      {required this.title, required this.image, required this.subtitle});
}

List<FoodCategoryData> demoFoodCategoryData = [
  FoodCategoryData(
    image: intPlaceholderImage,
    title: "Low-carb",
    subtitle: "Delicious meals with minimal carbs",
  ),
  FoodCategoryData(
    image: intPlaceholderImage,
    title: "Healthy",
    subtitle: "Nutritious options for a balanced diet",
  ),
  FoodCategoryData(
    image: intPlaceholderImage,
    title: "Pasta",
    subtitle: "Indulge in comforting pasta dishes",
  ),
  FoodCategoryData(
    image: intPlaceholderImage,
    title: "Budget-friendly",
    subtitle: "Tasty meals that are easy on your wallet",
  ),
  FoodCategoryData(
    image: intPlaceholderImage,
    title: "Asian",
    subtitle: "Explore vibrant flavors from the East",
  ),
  FoodCategoryData(
          image: intPlaceholderImage,
    title: "Baked",
    subtitle: "Freshly baked delights for any occasion",
  ),
  FoodCategoryData(
    image: intPlaceholderImage,
    title: "Air Fryer",
    subtitle: "Crispy and healthy air-fried goodness",
  ),
  FoodCategoryData(
    image: intPlaceholderImage,
    title: "Snack",
    subtitle: "Quick bites to curb your hunger",
  ),
];

List<FoodCategoryData> demoDiscover = [
  FoodCategoryData(
    image: tastyImage,
    title: "G-Buddy",
    subtitle: "A friend indeed",
  ),
  FoodCategoryData(
    image: intPlaceholderImage,
    title: "Recipes",
    subtitle: "Feed the soul",
  ),
  FoodCategoryData(
    image: intPlaceholderImage,
    title: "Explore",
    subtitle: "See what others are up to",
  ),
  FoodCategoryData(
    image: intPlaceholderImage,
    title: "Community",
    subtitle: "Get inspired",
  ),
  FoodCategoryData(
    image: intPlaceholderImage,
    title: "Challenges",
    subtitle: "Join and Win",
  ),
  FoodCategoryData(
    image: intPlaceholderImage,
    title: "Sync up",
    subtitle: "Link your devices",
  ),
];

class AppbarSliderData {
  final String image, title, subtitle;

  AppbarSliderData({
    required this.image,
    required this.title,
    required this.subtitle,
  });
}

List<AppbarSliderData> appbarSliderDatas = [
  AppbarSliderData(
    image: tastyImage,
    title: "Healthy Meal Prep Ideas",
    subtitle:
        "Learn how to prepare delicious and nutritious meals to support your health goals, with easy-to-follow recipes.",
  ),
  AppbarSliderData(
    image: intPlaceholderImage,
    title: "Nutritional Tips for a Balanced Diet",
    subtitle:
        "Discover expert advice on how to build a balanced diet, with practical tips for everyday meals.",
  ),
  AppbarSliderData(
    image: "assets/images/placeholder.jpg",
    title: "Delicious Recipes for Wellness",
    subtitle:
        "Explore a variety of recipes designed to improve your well-being, from breakfast ideas to satisfying dinners.",
  ),
];

class Direction {
  final String step, description;

  Direction({required this.step, required this.description});
}

List<Direction> demoDirection = [
  Direction(
    step: 'Step 1',
    description: 'Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
  ),
  Direction(
    step: 'Step 2',
    description:
        'Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.',
  ),
  Direction(
    step: 'Step 3',
    description:
        'Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.',
  ),
  Direction(
    step: 'Step 4',
    description:
        'Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.',
  ),
  Direction(
    step: 'Step 5',
    description:
        'Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.',
  ),
  Direction(
    step: 'Step 6',
    description:
        'Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.',
  ),
  Direction(
    step: 'Step 7',
    description:
        'Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.',
  ),
  Direction(
    step: 'Step 8',
    description: 'Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
  ),
  Direction(
    step: 'Step 9',
    description: 'Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
  ),
  Direction(
    step: 'Step 10',
    description:
        'Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.',
  ),
];

List preparationTime = [
  '10 min',
  '20 min',
  '30 min',
  '40 min',
  '50 min',
  '60 min',
];

List recipeRating = [
  '5',
  '4',
  '3',
  '2',
  '1',
];

List recipeCategory = [
  'All',
  'Indonesian',
  'Italian',
  'Chinese',
  'Breakfast',
  'Dinner',
  'Lunch',
  'Vegetarian',
  'Spanish',
  'Fruit',
];
