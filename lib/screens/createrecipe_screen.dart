import 'dart:io';

import 'package:dotted_border/dotted_border.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import '../data_models/macro_data.dart';
import '../data_models/meal_model.dart';
import '../data_models/user_meal.dart';
import '../helper/helper_functions.dart';
import '../helper/utils.dart';
import '../pages/safe_text_field.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/icon_widget.dart';
import '../widgets/primary_button.dart';
import '../constants.dart';
import 'recipes_list_category_screen.dart';

class CreateRecipeScreen extends StatefulWidget {
  final String screenType;
  final Meal? meal;
  const CreateRecipeScreen({super.key, this.screenType = recipes, this.meal});

  @override
  State<CreateRecipeScreen> createState() => _CreateRecipeScreenState();
}

class _CreateRecipeScreenState extends State<CreateRecipeScreen> {
  final TextEditingController titleController = TextEditingController();
  final TextEditingController serveQtyController = TextEditingController();
  final TextEditingController caloriesController = TextEditingController();
  final TextEditingController categoryController = TextEditingController();
  final TextEditingController stepsController = TextEditingController();
  final List<String> mediaPaths = [];
  List<MacroData> fullLabelsList = [];
  final Map<String, String> macros = {};
  String mediaType = "image";
  final List<Map<String, String>> ingredientsList = [];

  final List<String> selectedIngredients = [];

  List<XFile> _selectedImages = [];
  XFile? _recentImage;
  bool isUploading = false;
  final List<int> ingredientQuantities = [];
  final List<int> ingredientUnits = [];

  int selectedNumber = 0;
  int selectedUnit = 0;
  String selectedServing = 'g';
  String foodType = '';
  String screen = '';

  @override
  void initState() {
    super.initState();
    _loadData();

    if (widget.screenType.contains('addManual')) {
      foodType = widget.screenType.split('addManual')[1];
      screen = 'addManual';
    }

    // If editing, prefill fields
    if (widget.meal != null) {
      final meal = widget.meal!;
      titleController.text = meal.title;
      serveQtyController.text = meal.serveQty.toString();
      caloriesController.text = meal.calories.toString();
      categoryController.text = meal.categories.join(', ');
      stepsController.text = meal.steps.join('\n');
      mediaPaths.addAll(meal.mediaPaths);
      // Prefill ingredients
      ingredientsList.clear();
      ingredientQuantities.clear();
      ingredientUnits.clear();
      meal.ingredients.forEach((name, qty) {
        ingredientsList.add({"name": name, "quantity": qty});
        ingredientQuantities
            .add(0); // Default to 0, or parse from qty if needed
        ingredientUnits.add(0); // Default to 0, or parse from qty if needed
      });
    }
  }

  @override
  void dispose() {
    titleController.dispose();
    serveQtyController.dispose();
    caloriesController.dispose();
    categoryController.dispose();
    stepsController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      fullLabelsList = macroManager.ingredient;
      setState(() {});
    } catch (e) {
      print('Error loading data: $e');
    }
  }

  /// ✅ Add new ingredient to the list
  void _addIngredient() {
    setState(() {
      ingredientsList.add({"name": "", "quantity": ""});
      ingredientQuantities.add(0);
      ingredientUnits.add(0);
    });
  }

  /// ✅ Remove ingredient from list
  void _removeIngredient(int index) {
    setState(() {
      ingredientsList.removeAt(index);
      ingredientQuantities.removeAt(index);
      ingredientUnits.removeAt(index);
    });
  }

  Future<void> _uploadMeal() async {
    final bool isEditing = widget.meal != null;
    if (_selectedImages.isEmpty && !isEditing) {
      if (mounted) {
        showTastySnackbar(
          'Please try again.',
          'Please select at least one image!',
          context,
        );
      }
      return;
    }

    setState(() => isUploading = true);

    try {
      // Use existing mealId if editing, otherwise create new
      String mealId = isEditing
          ? widget.meal!.mealId
          : firestore.collection('meals').doc().id;
      final List<String> uploadedImageUrls = [];

      // If editing and no new images are selected, use existing images
      if (isEditing && _selectedImages.isEmpty) {
        uploadedImageUrls.addAll(widget.meal!.mediaPaths);
      } else {
        for (final image in _selectedImages) {
          String filePath =
              'meals/$mealId/${userService.userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';

          TaskSnapshot uploadTask =
              await firebaseStorage.ref(filePath).putFile(File(image.path));
          String downloadUrl = await uploadTask.ref.getDownloadURL();

          uploadedImageUrls.add(downloadUrl);
        }
      }

      Map<String, String> mIngredients = {
        for (int i = 0; i < ingredientsList.length; i++)
          if (ingredientsList[i]["name"] != null)
            ingredientsList[i]["name"]!.trim():
                "${ingredientQuantities[i]} ${unitOptions[ingredientUnits[i]]}",
      };

      Meal newMeal = Meal(
        userId: userService.userId ?? '',
        title: titleController.text.trim(),
        createdAt: isEditing ? widget.meal!.createdAt : DateTime.now(),
        mediaPaths: uploadedImageUrls,
        serveQty: int.tryParse(serveQtyController.text) ?? 1,
        calories: int.tryParse(caloriesController.text) ?? 0,
        ingredients: mIngredients,
        macros: macros,
        steps: stepsController.text.split("\n"),
        categories:
            categoryController.text.split(",").map((c) => c.trim()).toList(),
        mealId: mealId,
      );

      // If screenType is 'add_manual', save as in AddMealManuallyScreen
      if (screen == 'addManual') {
        // Create a user meal
        final userMeal = UserMeal(
          name: titleController.text.trim(),
          quantity: serveQtyController.text.trim(),
          servings: selectedServing,
          calories: int.tryParse(caloriesController.text.trim()) ?? 0,
          mealId: mealId,
        );
        // Add to user's daily meals
        await dailyDataController.addUserMeal(
          userService.userId ?? '',
          foodType, // or pass meal type if available
          userMeal,
        );
        // Save meal to Firestore
        await firestore.collection('meals').doc(mealId).set(newMeal.toJson());
        if (mounted) {
          showTastySnackbar(
            'Success',
            'Meal added successfully!',
            context,
          );
        }
        Navigator.pop(context);
        setState(() => isUploading = false);
        return;
      }

      // Save or update meal in Firestore (default behavior)
      await firestore.collection('meals').doc(mealId).set(newMeal.toJson());

      if (mounted) {
        showTastySnackbar(
          'Success',
          isEditing
              ? 'Meal updated successfully!'
              : 'Meal uploaded successfully!',
          context,
        );
      }

      Get.to(() => const BottomNavSec(
            selectedIndex: 1,
            foodScreenTabIndex: 1,
          ));
    } catch (e) {
      print("Error uploading meal: $e");
      if (mounted) {
        showTastySnackbar(
          'Please try again.',
          'Meal was not uploaded. Try again.',
          context,
        );
      }
    } finally {
      setState(() => isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    return Scaffold(
      appBar: AppBar(
          title: Text(
              screen == 'addManual' ? 'Add to $foodType' : 'Create Recipe'),
          leading: InkWell(
            onTap: () {
              if (widget.screenType == 'list') {
                Get.to(
                  () => const RecipeListCategory(
                    index: 1,
                    searchIngredient: '',
                    screen: 'ingredient',
                  ),
                );
              } else if (screen == 'addManual' ||
                  widget.screenType == 'addManual') {
                Get.back();
              } else {
                Get.to(() => const BottomNavSec(
                      selectedIndex: 1,
                      foodScreenTabIndex: 1,
                    ));
              }
            },
            child: const IconCircleButton(
              isRemoveContainer: true,
            ),
          )),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 20,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: getPercentageHeight(1, context),
                ),
                //Recipe Title
                Text(
                  screen == 'addManual' ? '$foodType Title' : recipeTitle,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                SizedBox(
                  height: getPercentageHeight(1, context),
                ),

                SafeTextFormField(
                  controller: titleController,
                  style: const TextStyle(color: kDarkGrey),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFFF3F3F3),
                    enabledBorder: outlineInputBorder(20),
                    focusedBorder: outlineInputBorder(20),
                    border: outlineInputBorder(20),
                    labelStyle: const TextStyle(color: Color(0xffefefef)),
                    hintStyle: const TextStyle(color: kLightGrey),
                    hintText: recipeHint,
                    floatingLabelBehavior: FloatingLabelBehavior.always,
                    contentPadding: const EdgeInsets.only(
                      top: 16,
                      bottom: 16,
                      right: 10,
                      left: 10,
                    ),
                  ),
                ),
                SizedBox(
                  height: getPercentageHeight(1, context),
                ),

                // Quantity and Units Row
                Row(
                  children: [
                    // Quantity
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Serving Size",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          SafeTextFormField(
                            controller: serveQtyController,
                            style: const TextStyle(color: kDarkGrey),
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: const Color(0xFFF3F3F3),
                              enabledBorder: outlineInputBorder(10),
                              focusedBorder: outlineInputBorder(10),
                              border: outlineInputBorder(10),
                              hintStyle: const TextStyle(color: kLightGrey),
                              hintText: '1',
                              contentPadding: const EdgeInsets.all(8),
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(
                      width: getPercentageWidth(1, context),
                    ),

                    // Serving Unit
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Unit",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            value: selectedServing,
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: isDarkMode
                                  ? kWhite.withValues(alpha: 0.9)
                                  : kWhite.withValues(alpha: 0.2),
                              enabledBorder: outlineInputBorder(10),
                              focusedBorder: outlineInputBorder(10),
                              border: outlineInputBorder(10),
                              contentPadding: const EdgeInsets.all(8),
                            ),
                            items: unitOptions.map((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                              );
                            }).toList(),
                            onChanged: (String? newValue) {
                              if (newValue != null) {
                                setState(() {
                                  selectedServing = newValue;
                                });
                              }
                            },
                            dropdownColor: kWhite,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(
                  height: getPercentageHeight(1, context),
                ),

                //Calories Time
                const Text(
                  'Calories',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                SizedBox(
                  height: getPercentageHeight(1, context),
                ),

                SafeTextFormField(
                  controller: caloriesController,
                  style: const TextStyle(color: kDarkGrey),
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFFF3F3F3),
                    enabledBorder: outlineInputBorder(20),
                    focusedBorder: outlineInputBorder(20),
                    border: outlineInputBorder(20),
                    labelStyle: const TextStyle(color: Color(0xffefefef)),
                    hintStyle: const TextStyle(color: kLightGrey),
                    hintText: 'Enter total calories',
                    floatingLabelBehavior: FloatingLabelBehavior.always,
                    contentPadding: const EdgeInsets.only(
                      top: 16,
                      bottom: 16,
                      right: 10,
                      left: 10,
                    ),
                  ),
                ),

                SizedBox(
                  height: getPercentageHeight(1, context),
                ),

                //Ingredients

                const Text(
                  ingredients,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                SizedBox(
                  height: getPercentageHeight(1, context),
                ),

                Column(
                  children: [
                    SizedBox(
                      height: ingredientsList.isEmpty ? 0 : 200,
                      child: ListView.builder(
                        itemCount: ingredientsList.length,
                        itemBuilder: (context, index) {
                          return Card(
                            shape: outlineInputBorder(10),
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: SafeTextFormField(
                                      decoration: const InputDecoration(
                                          labelText: "Ingredient"),
                                      onChanged: (value) {
                                        ingredientsList[index]["name"] = value;
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  // Quantity Picker
                                  SizedBox(
                                    width: 80,
                                    child: buildPicker(context, 21,
                                        ingredientQuantities[index], (val) {
                                      setState(() {
                                        ingredientQuantities[index] = val;
                                      });
                                    }, true),
                                  ),
                                  const SizedBox(width: 10),
                                  // Unit Picker
                                  SizedBox(
                                    width: 80,
                                    child: buildPicker(
                                      context,
                                      unitOptions.length,
                                      ingredientUnits[index],
                                      (val) {
                                        setState(() {
                                          ingredientUnits[index] = val;
                                        });
                                      },
                                      true,
                                      unitOptions,
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.delete,
                                        color: isDarkMode
                                            ? kLightGrey
                                            : kDarkGrey),
                                    onPressed: () => _removeIngredient(index),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(56),
                        backgroundColor: isDarkMode ? kLightGrey : kDarkGrey,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(50),
                        ),
                      ),
                      icon: const Icon(Icons.add),
                      label: const Text("Add Ingredient"),
                      onPressed: _addIngredient,
                    ),
                  ],
                ),
                SizedBox(
                  height: getPercentageHeight(1, context),
                ),

                //Add Cover Image
                const Center(
                  child: Text(
                    addCoverImage,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),

                SizedBox(
                  height: getPercentageHeight(2, context),
                ),

                Center(
                  child: InkWell(
                    onTap: () async {
                      List<XFile> pickedImages =
                          await openMultiImagePickerModal(context: context);

                      if (pickedImages.isNotEmpty) {
                        List<XFile> croppedImages = [];
                        for (final img in pickedImages) {
                          final XFile? cropped = await cropImage(
                            img,
                            context,
                          );
                          if (cropped != null) {
                            croppedImages.add(cropped);
                          }
                        }
                        if (croppedImages.isNotEmpty) {
                          setState(() {
                            _selectedImages = croppedImages;
                            _recentImage = croppedImages.first;
                          });
                        }
                      }
                    },
                    child: _recentImage != null
                        ? Image.file(
                            File(_recentImage!.path),
                            height: getPercentageHeight(15, context),
                            width: getPercentageWidth(40, context),
                            fit: BoxFit.cover,
                          )
                        : DottedBorder(
                            radius: const Radius.circular(30),
                            color: kLightGrey,
                            dashPattern: const [5, 2],
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: getPercentageWidth(5, context),
                                vertical: getPercentageHeight(2, context),
                              ),
                              child: const Column(
                                children: [
                                  Icon(
                                    Icons.photo_camera,
                                    color: kLightGrey,
                                  ),
                                  Text(
                                    addCoverImage,
                                    style: TextStyle(
                                      color: kLightGrey,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                  ),
                ),

                SizedBox(
                  height: getPercentageHeight(2, context),
                ),

                if (screen != 'addManual') ...[
                  //Cooking Instructions
                  const Text(
                    cookingInstructions,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Text(
                    notes,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(
                    height: getPercentageHeight(1, context),
                  ),
                  SafeTextFormField(
                    controller: stepsController,
                    style: const TextStyle(color: kDarkGrey),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFFF3F3F3),
                      enabledBorder: outlineInputBorder(20),
                      focusedBorder: outlineInputBorder(20),
                      border: outlineInputBorder(20),
                      labelStyle: const TextStyle(color: Color(0xffefefef)),
                      hintStyle: const TextStyle(color: kLightGrey),
                      hintText: cookingInstructionsHint,
                      floatingLabelBehavior: FloatingLabelBehavior.always,
                      contentPadding: const EdgeInsets.only(
                        top: 16,
                        bottom: 16,
                        right: 10,
                        left: 10,
                      ),
                    ),
                  ),
                  SizedBox(
                    height: getPercentageHeight(1, context),
                  ),
                  //Notes
                  const Text(
                    category,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Text(
                    snippet,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(
                    height: getPercentageHeight(1, context),
                  ),
                  SafeTextFormField(
                    controller: categoryController,
                    style: const TextStyle(color: kDarkGrey),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFFF3F3F3),
                      enabledBorder: outlineInputBorder(20),
                      focusedBorder: outlineInputBorder(20),
                      border: outlineInputBorder(20),
                      labelStyle: const TextStyle(color: Color(0xffefefef)),
                      hintStyle: const TextStyle(color: kLightGrey),
                      hintText: notesHint,
                      floatingLabelBehavior: FloatingLabelBehavior.always,
                      contentPadding: const EdgeInsets.only(
                        top: 16,
                        bottom: 16,
                        right: 10,
                        left: 10,
                      ),
                    ),
                  ),
                  SizedBox(
                    height: getPercentageHeight(2, context),
                  ),
                ],

                //Submit button
                isUploading
                    ? const Center(
                        child: CircularProgressIndicator(color: kAccent),
                      )
                    : AppButton(
                        text: screen == 'addManual'
                            ? 'Add to $foodType'
                            : 'Submit Recipe',
                        onPressed: _uploadMeal,
                        type: AppButtonType.primary,
                        width: 100,
                      ),

                SizedBox(
                  height: getPercentageHeight(2, context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
