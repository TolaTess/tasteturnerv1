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
    title: "Lunch",
    subtitle: "Delicious lunch options to keep you going",
  ),
  MealsData(
    image: 'assets/images/pescatarian.jpg',
    title: "Korean",
    subtitle: "Delicious Korean dishes for a healthy and sustainable diet",
  ),
  MealsData(
    image: 'assets/images/vegetarian.jpg',
    title: "Italian",
    subtitle: "Delicious Italian dishes for a healthy and sustainable diet",
  ),
  MealsData(
    image: 'assets/images/vegan.jpg',
    title: "Japanese",
    subtitle: "Delicious Japanese dishes for a healthy and sustainable diet",
  ),
  MealsData(
    image: 'assets/images/dessert.jpg',
    title: "African",
    subtitle: "Delicious African dishes for a healthy and sustainable diet",
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
