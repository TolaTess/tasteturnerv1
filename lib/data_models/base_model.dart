//diet data model

class DataModelBase {
  final String image, title;

  DataModelBase({
    required this.image,
    required this.title,
  });
}

class DateData {
  final int date;
  final double progress;

  DateData({required this.date, required this.progress});
}

List<DataModelBase> demoDietData = [
  DataModelBase(
    image: "assets/images/none_diet.jpg",
    title: "None",
  ),
  DataModelBase(
    image: "assets/images/paleo.jpg",
    title: "Paleo",
  ),
  DataModelBase(
    image: "assets/images/low-carb.jpg",
    title: "Low-Carb",
  ),
  DataModelBase(
    image: "assets/images/vegan.jpg",
    title: "Vegan",
  ),
  DataModelBase(
    image: "assets/images/vegetarian.jpg",
    title: "Vegetarian",
  ),
  DataModelBase(
    image: "assets/images/pescatarian.jpg",
    title: "Pascatarian",
  ),
  DataModelBase(
    image: "assets/images/keto.jpg",
    title: "Keto",
  ),
];

List<DataModelBase> demoFoodCategory = [
  DataModelBase(
    image: "assets/images/quest.png",
    title: "Quest",
  ),
  DataModelBase(
    image: "assets/images/roast.jpg",
    title: "Recipes",
  ),
  DataModelBase(
    image: "assets/images/group.png",
    title: "Groups",
  ),
];

//alergy data model

class AllergyItemData {
  final String allergy;

  AllergyItemData({
    required this.allergy,
  });
}

List<AllergyItemData> demoAllergyItemData = [
  AllergyItemData(
    allergy: "Peanuts",
  ),
  AllergyItemData(
    allergy: "Shellfish",
  ),
  AllergyItemData(
    allergy: "Fish",
  ),
  AllergyItemData(
    allergy: "Milk",
  ),
  AllergyItemData(
    allergy: "Eggs",
  ),
  AllergyItemData(
    allergy: "Soy",
  ),
  AllergyItemData(
    allergy: "Wheat",
  ),
  AllergyItemData(
    allergy: "Sesame seeds",
  ),
  AllergyItemData(
    allergy: "Mustard",
  ),
  AllergyItemData(
    allergy: "Sulphites",
  ),
  AllergyItemData(
    allergy: "Lupin",
  ),
  AllergyItemData(
    allergy: "Celery",
  ),
];

//This model is recipe categories list

class MealCategory {
  final String title, recipesNum, image;

  MealCategory(
      {required this.title, required this.recipesNum, required this.image});
}

List<MealCategory> demoCategory = [
  MealCategory(
    title: 'Breakfast',
    recipesNum: '1250',
    image: 'assets/images/breakfast.jpg',
  ),
  MealCategory(
    title: 'Brunch',
    recipesNum: '1389',
    image: 'assets/images/brunch.jpg',
  ),
  MealCategory(
    title: 'Lunch',
    recipesNum: '1245',
    image: 'assets/images/lunch.jpg',
  ),
  MealCategory(
    title: 'Dinner',
    recipesNum: '1908',
    image: 'assets/images/dinner.jpg',
  ),
  MealCategory(
    title: 'Soup',
    recipesNum: '1580',
    image: 'assets/images/soup.jpg',
  ),
];

class CookBookData {
  final String image, category;

  CookBookData({
    required this.image,
    required this.category,
  });
}

List<CookBookData> demoCookBookData = [
  CookBookData(
    image: "assets/images/food_1.jpg",
    category: "Breakfast Favourite",
  ),
  CookBookData(
    image: "assets/images/food_2.jpg",
    category: "Lunch Favourite",
  ),
  CookBookData(
    image: "assets/images/food_3.jpg",
    category: "Dinner Favourite",
  ),
];
