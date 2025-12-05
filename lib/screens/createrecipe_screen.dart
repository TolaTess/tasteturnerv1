import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../data_models/macro_data.dart';
import '../data_models/meal_model.dart';
import '../data_models/user_meal.dart';
import '../helper/helper_functions.dart';
import '../helper/utils.dart';
import '../pages/safe_text_field.dart';
import '../widgets/primary_button.dart';
import '../constants.dart';

class CreateRecipeScreen extends StatefulWidget {
  final String screenType;
  final Meal? meal;
  final List<String>? networkImages;
  final String? mealId;
  const CreateRecipeScreen(
      {super.key,
      this.screenType = recipes,
      this.meal,
      this.networkImages,
      this.mealId});

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
  String? _recentNetworkImage;
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
      stepsController.text = meal.instructions.join('\n');
      mediaPaths.addAll(meal.mediaPaths);
      // Prefill ingredients
      ingredientsList.clear();
      ingredientQuantities.clear();
      ingredientUnits.clear();
      meal.ingredients.forEach((name, qty) {
        ingredientsList.add({"name": name, "quantity": qty});
        ingredientQuantities
            .add(0); // Default to 0, or parse from  qty if needed
        ingredientUnits.add(0); // Default to 0, or parse from qty if needed
      });
    } else if (widget.networkImages != null &&
        widget.networkImages!.isNotEmpty) {
      mediaPaths.addAll(widget.networkImages!);
      _recentNetworkImage = widget.networkImages!.first;
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
      debugPrint('Error loading data: $e');
    }
  }

  /// Check if a meal has been logged (has instances in userMeals)
  Future<Map<String, dynamic>> _checkMealHasLoggedInstances(
      String mealId) async {
    try {
      final userId = userService.userId;
      if (userId == null)
        return {'hasInstances': false, 'count': 0, 'dates': []};

      // Query userMeals collection for any meals with this mealId
      final querySnapshot = await firestore
          .collection('userMeals')
          .doc(userId)
          .collection('meals')
          .get();

      int instanceCount = 0;
      List<String> dates = [];

      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        final mealsMap = data['meals'] as Map<String, dynamic>?;

        if (mealsMap != null) {
          for (var mealType in mealsMap.keys) {
            final mealList = mealsMap[mealType] as List<dynamic>?;
            if (mealList != null) {
              for (var mealData in mealList) {
                final mealMap = mealData as Map<String, dynamic>;
                if (mealMap['mealId'] == mealId) {
                  instanceCount++;
                  final dateStr = doc.id;
                  if (!dates.contains(dateStr)) {
                    dates.add(dateStr);
                  }
                }
              }
            }
          }
        }
      }

      return {
        'hasInstances': instanceCount > 0,
        'count': instanceCount,
        'dates': dates,
      };
    } catch (e) {
      debugPrint('Error checking meal instances: $e');
      return {'hasInstances': false, 'count': 0, 'dates': []};
    }
  }

  /// Show dialog warning about editing logged meals
  Future<bool> _showEditLoggedMealDialog(
      Map<String, dynamic> instanceInfo) async {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    final textTheme = Theme.of(context).textTheme;
    final instanceCount = instanceInfo['count'] as int;
    final dates = instanceInfo['dates'] as List<String>;

    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: isDarkMode ? kDarkGrey : kWhite,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            title: Text(
              'This Recipe Has Been Logged',
              style: textTheme.titleMedium?.copyWith(
                color: isDarkMode ? kWhite : kBlack,
                fontWeight: FontWeight.w600,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'This recipe has been logged on ${instanceCount} ${instanceCount == 1 ? 'date' : 'dates'}.',
                  style: textTheme.bodyMedium?.copyWith(
                    color: isDarkMode ? kWhite : kBlack,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Editing will create a new version. Past logs will remain unchanged and will continue to reference the original recipe.',
                  style: textTheme.bodySmall?.copyWith(
                    color: isDarkMode ? Colors.white70 : Colors.black87,
                  ),
                ),
                if (dates.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Logged on:',
                    style: textTheme.bodySmall?.copyWith(
                      color: isDarkMode ? Colors.white70 : Colors.black87,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  ...dates.take(5).map((date) => Padding(
                        padding: const EdgeInsets.only(left: 8.0, top: 2),
                        child: Text(
                          '• ${DateFormat('MMM dd, yyyy').format(DateFormat('yyyy-MM-dd').parse(date))}',
                          style: textTheme.bodySmall?.copyWith(
                            color: isDarkMode ? Colors.white60 : Colors.black54,
                          ),
                        ),
                      )),
                  if (dates.length > 5)
                    Padding(
                      padding: const EdgeInsets.only(left: 8.0, top: 2),
                      child: Text(
                        '• ...and ${dates.length - 5} more',
                        style: textTheme.bodySmall?.copyWith(
                          color: isDarkMode ? Colors.white60 : Colors.black54,
                        ),
                      ),
                    ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  'Cancel',
                  style: textTheme.bodyMedium?.copyWith(
                    color: Colors.grey,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(
                  'Create New Version',
                  style: textTheme.bodyMedium?.copyWith(
                    color: kAccent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ) ??
        false;
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
    if (_selectedImages.isEmpty && mediaPaths.isEmpty && !isEditing) {
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
      String mealId;

      // If editing, check if meal has been logged
      if (isEditing) {
        final instanceInfo =
            await _checkMealHasLoggedInstances(widget.meal!.mealId);

        if (instanceInfo['hasInstances'] == true) {
          // Show dialog warning user
          final shouldCreateNew = await _showEditLoggedMealDialog(instanceInfo);

          if (!shouldCreateNew) {
            // User cancelled, stop upload
            setState(() => isUploading = false);
            return;
          }

          // Create new mealId for new version
          mealId = firestore.collection('meals').doc().id;
        } else {
          // No logged instances, can safely update existing meal
          mealId = widget.meal!.mealId;
        }
      } else {
        // Not editing, use provided mealId or create new
        mealId = (widget.screenType == 'post_add' && widget.mealId != null
            ? widget.mealId!
            : firestore.collection('meals').doc().id);
      }
      final List<String> uploadedImageUrls = [];

      // If editing and no new images are selected, use existing images
      if (isEditing && _selectedImages.isEmpty) {
        uploadedImageUrls.addAll(widget.meal!.mediaPaths);
      } else if (_selectedImages.isEmpty && mediaPaths.isNotEmpty) {
        // Use passed network images if no new images are picked
        uploadedImageUrls.addAll(mediaPaths);
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
        nutritionalInfo: macros,
        instructions: stepsController.text.split("\n"),
        categories:
            categoryController.text.split(",").map((c) => c.trim()).toList(),
        mealId: mealId,
      );

      // If screenType is 'add_manual', save as in AddMealManuallyScreen
      if (screen == 'addManual') {
        // Convert nutritionalInfo (Map<String, String>) to macros (Map<String, double>)
        Map<String, double> mealMacros = {};
        if (macros.isNotEmpty) {
          mealMacros = macros.map((key, value) => MapEntry(
                key,
                double.tryParse(value) ?? 0.0,
              ));
        }
        
        // Create a user meal with macros
        final userMeal = UserMeal(
          name: titleController.text.trim(),
          quantity: serveQtyController.text.trim(),
          servings: selectedServing,
          calories: int.tryParse(caloriesController.text.trim()) ?? 0,
          mealId: mealId,
          macros: mealMacros,
        );
        // Add to user's daily meals
        await dailyDataController.addUserMeal(
          userService.userId ?? '',
          foodType, // or pass meal type if available
          userMeal,
          DateTime.now(),
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
        // Navigate back instead of forward
        Navigator.pop(context, newMeal);
      }
    } catch (e) {
      debugPrint("Error uploading meal: $e");
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
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: true,
        centerTitle: true,
        title: Text(
            screen == 'addManual' ? 'Add to $foodType' : 'Create Recipe',
            style:
                textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w600)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: getPercentageWidth(2, context),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: getPercentageHeight(2, context),
                ),
                //Recipe Title
                Text(
                  screen == 'addManual' ? '$foodType Title' : recipeTitle,
                  style: textTheme.titleLarge,
                ),

                SizedBox(
                  height: getPercentageHeight(2, context),
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
                    hintStyle: TextStyle(
                        color: kLightGrey, fontSize: getTextScale(4, context)),
                    hintText: recipeHint,
                    floatingLabelBehavior: FloatingLabelBehavior.always,
                    contentPadding: EdgeInsets.only(
                      top: getPercentageHeight(1.5, context),
                      bottom: getPercentageHeight(1.5, context),
                      right: getPercentageWidth(2, context),
                      left: getPercentageWidth(2, context),
                    ),
                  ),
                ),
                SizedBox(
                  height: getPercentageHeight(2, context),
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
                          Text(
                            "Serving Size",
                            style: textTheme.titleLarge,
                          ),
                          SizedBox(height: getPercentageHeight(1, context)),
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
                              hintStyle: TextStyle(
                                  color: kLightGrey,
                                  fontSize: getTextScale(4, context)),
                              hintText: '1',
                              contentPadding: EdgeInsets.only(
                                top: getPercentageHeight(1.5, context),
                                bottom: getPercentageHeight(1.5, context),
                                right: getPercentageWidth(2, context),
                                left: getPercentageWidth(2, context),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(
                      width: getPercentageWidth(2, context),
                    ),

                    // Serving Unit
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Unit",
                            style: textTheme.titleLarge,
                          ),
                          SizedBox(height: getPercentageHeight(1, context)),
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
                              contentPadding: EdgeInsets.only(
                                top: getPercentageHeight(1.5, context),
                                bottom: getPercentageHeight(1.5, context),
                                right: getPercentageWidth(2, context),
                                left: getPercentageWidth(2, context),
                              ),
                            ),
                            items: unitOptions.map((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value,
                                    style: textTheme.bodyMedium
                                        ?.copyWith(color: kDarkGrey)),
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
                  height: getPercentageHeight(2, context),
                ),

                //Calories Time
                Text(
                  'Calories',
                  style: textTheme.titleLarge,
                ),

                SizedBox(
                  height: getPercentageHeight(2, context),
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
                    hintStyle: TextStyle(
                        color: kLightGrey, fontSize: getTextScale(4, context)),
                    hintText: 'Enter total calories',
                    floatingLabelBehavior: FloatingLabelBehavior.always,
                    contentPadding: EdgeInsets.only(
                      top: getPercentageHeight(1.5, context),
                      bottom: getPercentageHeight(1.5, context),
                      right: getPercentageWidth(2, context),
                      left: getPercentageWidth(2, context),
                    ),
                  ),
                ),

                SizedBox(
                  height: getPercentageHeight(1, context),
                ),

                //Ingredients

                Text(
                  ingredients,
                  style: textTheme.titleLarge,
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
                              padding: EdgeInsets.only(
                                top: getPercentageHeight(1.5, context),
                                bottom: getPercentageHeight(1.5, context),
                                right: getPercentageWidth(2, context),
                                left: getPercentageWidth(2, context),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: SafeTextFormField(
                                      style: textTheme.titleLarge
                                          ?.copyWith(color: kLightGrey),
                                      decoration: InputDecoration(
                                        labelText: "Ingredient",
                                        labelStyle: textTheme.titleLarge
                                            ?.copyWith(color: kLightGrey),
                                        hintStyle: TextStyle(
                                          fontSize: getTextScale(3.5, context),
                                          color:
                                              kLightGrey.withValues(alpha: 0.5),
                                        ),
                                        hintText: "Enter ingredient",
                                      ),
                                      onChanged: (value) {
                                        ingredientsList[index]["name"] = value;
                                      },
                                    ),
                                  ),
                                  SizedBox(
                                      width: getPercentageWidth(2, context)),
                                  // Quantity Picker
                                  SizedBox(
                                    width: getPercentageWidth(15, context),
                                    child: buildPicker(context, 1000,
                                        ingredientQuantities[index], (val) {
                                      setState(() {
                                        ingredientQuantities[index] = val;
                                      });
                                    }, false),
                                  ),
                                  SizedBox(
                                      width: getPercentageWidth(2, context)),
                                  // Unit Picker
                                  SizedBox(
                                    width: getPercentageWidth(15, context),
                                    child: buildPicker(
                                      context,
                                      unitOptions.length,
                                      ingredientUnits[index],
                                      (val) {
                                        setState(() {
                                          ingredientUnits[index] = val;
                                        });
                                      },
                                      false,
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
                        minimumSize:
                            Size.fromHeight(getPercentageHeight(7, context)),
                        backgroundColor: isDarkMode ? kLightGrey : kDarkGrey,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(50),
                        ),
                      ),
                      icon: Icon(Icons.add, size: getIconScale(7, context)),
                      label: Text("Add Ingredient",
                          style: textTheme.bodyLarge?.copyWith(
                              color: kWhite, fontWeight: FontWeight.w600)),
                      onPressed: _addIngredient,
                    ),
                  ],
                ),
                SizedBox(
                  height: getPercentageHeight(2, context),
                ),

                //Add Cover Image
                Center(
                  child: Text(
                    addCoverImage,
                    style: textTheme.titleLarge,
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
                            getThemeProvider(context).isDarkMode,
                          );
                          if (cropped != null) {
                            croppedImages.add(cropped);
                          }
                        }
                        if (croppedImages.isNotEmpty) {
                          setState(() {
                            _selectedImages = croppedImages;
                            _recentImage = croppedImages.first;
                            _recentNetworkImage = null;
                          });
                        }
                      }
                    },
                    child: _recentImage != null
                        ? Image.file(
                            File(_recentImage!.path),
                            height: MediaQuery.of(context).size.height > 1100
                                ? getPercentageHeight(20, context)
                                : getPercentageHeight(10, context),
                            width: MediaQuery.of(context).size.width > 1100
                                ? getPercentageWidth(40, context)
                                : getPercentageWidth(30, context),
                            fit: BoxFit.cover,
                          )
                        : (_recentNetworkImage != null
                            ? buildOptimizedNetworkImage(
                                imageUrl: _recentNetworkImage!,
                                height:
                                    MediaQuery.of(context).size.height > 1100
                                        ? getPercentageHeight(20, context)
                                        : getPercentageHeight(10, context),
                                width: MediaQuery.of(context).size.width > 1100
                                    ? getPercentageWidth(40, context)
                                    : getPercentageWidth(30, context),
                                fit: BoxFit.cover,
                              )
                            : DottedBorder(
                                radius: Radius.circular(30),
                                color: kLightGrey,
                                dashPattern: [5, 2],
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
                              )),
                  ),
                ),

                SizedBox(
                  height: getPercentageHeight(2, context),
                ),

                if (screen != 'addManual') ...[
                  //Cooking Instructions
                  Text(
                    cookingInstructions,
                    style: textTheme.titleLarge,
                  ),
                  Text(
                    notes,
                    style: textTheme.bodyMedium,
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
                      hintStyle: TextStyle(
                          color: kLightGrey,
                          fontSize: getTextScale(4, context)),
                      hintText: cookingInstructionsHint,
                      floatingLabelBehavior: FloatingLabelBehavior.always,
                      contentPadding: EdgeInsets.only(
                        top: getPercentageHeight(1.5, context),
                        bottom: getPercentageHeight(1.5, context),
                        right: getPercentageWidth(2, context),
                        left: getPercentageWidth(2, context),
                      ),
                    ),
                  ),
                  SizedBox(
                    height: getPercentageHeight(1, context),
                  ),
                  //Notes
                  Text(
                    category,
                    style: textTheme.titleLarge,
                  ),
                  Text(
                    snippet,
                    style: textTheme.bodyMedium,
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
                      labelStyle: textTheme.bodyMedium,
                      hintStyle: textTheme.bodyMedium,
                      hintText: notesHint,
                      floatingLabelBehavior: FloatingLabelBehavior.always,
                      contentPadding: EdgeInsets.only(
                        top: getPercentageHeight(1.5, context),
                        bottom: getPercentageHeight(1.5, context),
                        right: getPercentageWidth(2, context),
                        left: getPercentageWidth(2, context),
                      ),
                    ),
                  ),
                  SizedBox(
                    height: getPercentageHeight(2, context),
                  ),
                ],

                //Submit button
                isUploading
                    ? Center(
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
