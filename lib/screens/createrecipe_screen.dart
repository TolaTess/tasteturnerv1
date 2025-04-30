import 'dart:io';

import 'package:dotted_border/dotted_border.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import '../data_models/macro_data.dart';
import '../data_models/meal_model.dart';
import '../detail_screen/recipe_detail.dart';
import '../helper/utils.dart';
import '../pages/safe_text_field.dart';
import '../tabs_screen/spin_tab_screen.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/icon_widget.dart';
import '../widgets/primary_button.dart';
import '../constants.dart';
import 'recipes_list_category_screen.dart';

class CreateRecipeScreen extends StatefulWidget {
  final String screenType;
  const CreateRecipeScreen({super.key, this.screenType = recipes});

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

  @override
  void initState() {
    super.initState();
    _loadData();
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
    });
  }

  /// ✅ Remove ingredient from list
  void _removeIngredient(int index) {
    setState(() {
      ingredientsList.removeAt(index);
    });
  }

  Future<void> _uploadMeal() async {
    if (_selectedImages.isEmpty) {
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
      String mealId = firestore.collection('meals').doc().id;
      final List<String> uploadedImageUrls = [];

      for (final image in _selectedImages) {
        String filePath =
            'meals/$mealId/${userService.userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';

        TaskSnapshot uploadTask =
            await firebaseStorage.ref(filePath).putFile(File(image.path));
        String downloadUrl = await uploadTask.ref.getDownloadURL();

        uploadedImageUrls.add(downloadUrl);
      }

      Map<String, String> mIngredients = {
        for (var ingredient in ingredientsList)
          if (ingredient["name"] != null && ingredient["quantity"] != null)
            ingredient["name"]!.trim(): ingredient["quantity"]!.trim(),
      };

      /// ✅ Create `UserMeal` object
      Meal newMeal = Meal(
        userId: userService.userId ?? '',
        title: titleController.text.trim(),
        createdAt: DateTime.now(),
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

      /// ✅ Save meal to Firestore
      await firestore.collection('meals').doc(mealId).set(newMeal.toJson());

      if (mounted) {
        showTastySnackbar(
          'Success',
          'Meal uploaded successfully!',
          context,
        );
      }

      Navigator.pop(context);
    } catch (e) {
      print("Error uploading meal: $e");
      if (mounted) {
        showTastySnackbar(
          'Please try again.',
          'Failed to upload meal. Try again.',
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
          title: const Text("Create Recipe"),
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
                const SizedBox(
                  height: 24,
                ),
                // Row(
                //   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                //   children: [
                //     //back arrow
                //     InkWell(
                //       onTap: () => Navigator.pop(context),
                //       child: const IconCircleButton(),
                //     ),
                //   ],
                // ),
                const SizedBox(
                  height: 20,
                ),
                //Recipe Title
                const Text(
                  recipeTitle,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(
                  height: 24,
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
                const SizedBox(
                  height: 32,
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

                const SizedBox(
                  height: 24,
                ),

                Center(
                  child: InkWell(
                    onTap: () async {
                      List<XFile> pickedImages =
                          await openMultiImagePickerModal(context: context);

                      if (pickedImages.isNotEmpty) {
                        setState(() {
                          _selectedImages = pickedImages;
                          _recentImage = _selectedImages.first;
                        });
                      }
                    },
                    child: _recentImage != null
                        ? Image.file(
                            File(_recentImage!.path),
                            height: 150,
                            width: 150,
                            fit: BoxFit.cover,
                          )
                        : DottedBorder(
                            radius: const Radius.circular(30),
                            color: kLightGrey,
                            dashPattern: const [5, 2],
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 36,
                                vertical: 54,
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
                const SizedBox(
                  height: 20,
                ),

                //Serving Size
                const Text(
                  servingSize,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(
                  height: 16,
                ),

                SafeTextFormField(
                  controller: serveQtyController,
                  style: const TextStyle(color: kDarkGrey),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFFF3F3F3),
                    enabledBorder: outlineInputBorder(20),
                    focusedBorder: outlineInputBorder(20),
                    border: outlineInputBorder(20),
                    labelStyle: const TextStyle(color: Color(0xffefefef)),
                    hintStyle: const TextStyle(color: kLightGrey),
                    hintText: 'Enter serving size... 1, 2 or 3',
                    floatingLabelBehavior: FloatingLabelBehavior.always,
                    contentPadding: const EdgeInsets.only(
                      top: 16,
                      bottom: 16,
                      right: 10,
                      left: 10,
                    ),
                  ),
                ),

                const SizedBox(
                  height: 16,
                ),

                //Calories Time
                const Text(
                  'Calories',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(
                  height: 16,
                ),

                SafeTextFormField(
                  controller: caloriesController,
                  style: const TextStyle(color: kDarkGrey),
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

                const SizedBox(
                  height: 20,
                ),

                //Ingredients

                const Text(
                  ingredients,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(
                  height: 16,
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
                                  Expanded(
                                    child: TextFormField(
                                      decoration: const InputDecoration(
                                          labelText: "Quantity"),
                                      onChanged: (value) {
                                        ingredientsList[index]["quantity"] =
                                            value;
                                      },
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

                const SizedBox(
                  height: 20,
                ),

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

                const SizedBox(
                  height: 16,
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
                const SizedBox(
                  height: 20,
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

                const SizedBox(
                  height: 16,
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
                const SizedBox(
                  height: 32,
                ),

                //Submit button

                PrimaryButton(
                  text: submitRecipe,
                  press: _uploadMeal,
                ),

                const SizedBox(
                  height: 32,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
