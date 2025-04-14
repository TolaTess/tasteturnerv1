import 'dart:io';

import 'package:dotted_border/dotted_border.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../data_models/meal_model.dart';
import '../data_models/user_meal.dart';
import '../helper/utils.dart';
import '../pages/safe_text_field.dart';
import '../widgets/icon_widget.dart';
import '../widgets/primary_button.dart';
import '../constants.dart';

class AddMealManuallyScreen extends StatefulWidget {
  final String mealType;

  const AddMealManuallyScreen({
    super.key,
    required this.mealType,
  });

  @override
  State<AddMealManuallyScreen> createState() => _AddMealManuallyScreenState();
}

class _AddMealManuallyScreenState extends State<AddMealManuallyScreen> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController servingController = TextEditingController();
  final TextEditingController quantityController = TextEditingController();
  final TextEditingController caloriesController = TextEditingController();
  final List<Map<String, String>> ingredientsList = [];

  final List<String> servingOptions = [
    'g',
    'ml',
    'cup',
    'tbsp',
    'tsp',
    'oz',
    'piece',
    'slice'
  ];
  String selectedServing = 'g';
  String _selectedMealType = '';

  List<XFile> _selectedImages = [];
  XFile? _recentImage;
  bool isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _selectedMealType = widget.mealType;
  }

  @override
  void dispose() {
    nameController.dispose();
    servingController.dispose();
    quantityController.dispose();
    caloriesController.dispose();
    super.dispose();
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

  Future<void> _submitMeal() async {
    // Validate inputs
    if (nameController.text.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a meal name')),
        );
      }
      return;
    }

    if (quantityController.text.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a quantity')),
        );
      }
      return;
    }

    if (caloriesController.text.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter calories')),
        );
      }
      return;
    }

    setState(() => isSubmitting = true);

    try {
      List<String> uploadedImageUrls = [];

      // Upload images if any are selected
      String mealId = firestore.collection('meals').doc().id;
      if (_selectedImages.isNotEmpty) {
        for (final image in _selectedImages) {
          String filePath =
              'meals/manual/${userService.userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
          TaskSnapshot uploadTask =
              await firebaseStorage.ref(filePath).putFile(File(image.path));
          String downloadUrl = await uploadTask.ref.getDownloadURL();
          uploadedImageUrls.add(downloadUrl);
        }
      }

      Map<String, String> mIngredients = {
        for (var ingredient in ingredientsList)
          if (ingredient["name"] != null && ingredient["quantity"] != null)
            ingredient["name"]!.trim(): ingredient["quantity"]!.trim(),
      };

      // Create a user meal
      final userMeal = UserMeal(
        name: nameController.text.trim(),
        quantity: quantityController.text.trim(),
        servings: selectedServing,
        calories: int.tryParse(caloriesController.text.trim()) ?? 0,
        mealId: mealId,
      );

      final meal = Meal(
        userId: userService.userId ?? '',
        title: nameController.text.trim(),
        serveQty: int.tryParse(quantityController.text.trim()) ?? 0,
        calories: int.tryParse(caloriesController.text.trim()) ?? 0,
        mealId: mealId,
        ingredients: mIngredients,
        mediaPaths: uploadedImageUrls,
        createdAt: DateTime.now(),
      );

      // Add to user's daily meals
      await nutritionController.addUserMeal(
        userService.userId ?? '',
        _selectedMealType,
        userMeal,
      );

      await firestore.collection('meals').doc(mealId).set(meal.toJson());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Meal added successfully!')),
        );
      }

      Navigator.pop(context);
    } catch (e) {
      print("Error adding meal: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add meal: $e')),
        );
      }
    } finally {
      setState(() => isSubmitting = false);
    }
  }

  Widget _buildMealTypeOption(
      String label, String value, bool isSelected, Function(bool) onSelected) {
    return GestureDetector(
      onTap: () => onSelected(!isSelected),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? kAccentLight : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? kAccentLight : kPrimaryColor,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? kWhite : kPrimaryColor,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),

                // Back button and title
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    InkWell(
                      onTap: () => Navigator.pop(context),
                      child: const IconCircleButton(),
                    ),
                    Text(
                      "Add to ${_selectedMealType}",
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 40), // For visual balance
                  ],
                ),

                const SizedBox(height: 32),

                if (widget.mealType == 'Add Food') ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildMealTypeOption('Breakfast', 'Breakfast',
                          _selectedMealType == 'Breakfast', (isSelected) {
                        setState(() {
                          _selectedMealType =
                              isSelected ? 'Breakfast' : _selectedMealType;
                        });
                      }),
                      _buildMealTypeOption(
                          'Lunch', 'Lunch', _selectedMealType == 'Lunch',
                          (isSelected) {
                        setState(() {
                          _selectedMealType =
                              isSelected ? 'Lunch' : _selectedMealType;
                        });
                      }),
                      _buildMealTypeOption(
                          'Dinner', 'Dinner', _selectedMealType == 'Dinner',
                          (isSelected) {
                        setState(() {
                          _selectedMealType =
                              isSelected ? 'Dinner' : _selectedMealType;
                        });
                      }),
                    ],
                  ),
                  const SizedBox(height: 15),
                ],

                // Meal Name
                const Text(
                  "Meal Name",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 12),

                SafeTextFormField(
                  controller: nameController,
                  style: const TextStyle(color: kDarkGrey),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFFF3F3F3),
                    enabledBorder: outlineInputBorder(20),
                    focusedBorder: outlineInputBorder(20),
                    border: outlineInputBorder(20),
                    hintStyle: const TextStyle(color: kLightGrey),
                    hintText: 'Enter meal name',
                    contentPadding: const EdgeInsets.all(16),
                  ),
                ),

                const SizedBox(height: 24),

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
                            "Quantity",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          SafeTextFormField(
                            controller: quantityController,
                            style: const TextStyle(color: kDarkGrey),
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: const Color(0xFFF3F3F3),
                              enabledBorder: outlineInputBorder(20),
                              focusedBorder: outlineInputBorder(20),
                              border: outlineInputBorder(20),
                              hintStyle: const TextStyle(color: kLightGrey),
                              hintText: '1',
                              contentPadding: const EdgeInsets.all(16),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 16),

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
                              fillColor: const Color(0xFFF3F3F3),
                              enabledBorder: outlineInputBorder(20),
                              focusedBorder: outlineInputBorder(20),
                              border: outlineInputBorder(20),
                              contentPadding: const EdgeInsets.all(16),
                            ),
                            items: servingOptions.map((String value) {
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
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Calories
                const Text(
                  "Calories",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 12),

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
                    hintStyle: const TextStyle(color: kLightGrey),
                    hintText: 'Enter calories',
                    contentPadding: const EdgeInsets.all(16),
                    suffixText: 'kcal',
                  ),
                ),

                const SizedBox(height: 24),

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
                                    child: SafeTextFormField(
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

                const SizedBox(height: 24),

                // Add Image (Optional)
                const Text(
                  "Add Image (Optional)",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 12),

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
                            radius: const Radius.circular(15),
                            color: kLightGrey,
                            dashPattern: const [5, 2],
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 36,
                                vertical: 36,
                              ),
                              child: const Column(
                                children: [
                                  Icon(
                                    Icons.photo_camera,
                                    color: kLightGrey,
                                    size: 32,
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    "Add Image",
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

                const SizedBox(height: 36),

                // Add Meal Button
                PrimaryButton(
                  text: isSubmitting ? "Adding..." : "Add Meal",
                  press: isSubmitting ? () {} : _submitMeal,
                ),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
