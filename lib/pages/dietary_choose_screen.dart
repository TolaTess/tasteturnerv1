import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../constants.dart';
import '../data_models/ingredient_model.dart';
import '../helper/utils.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../widgets/icon_widget.dart';
import '../widgets/primary_button.dart';

class ChooseDietScreen extends StatefulWidget {
  const ChooseDietScreen({
    super.key,
    this.isOnboarding = false,
    this.onPreferencesSelected,
  });

  final bool isOnboarding;
  final Function(String diet, Set<String> allergies)? onPreferencesSelected;

  @override
  State<ChooseDietScreen> createState() => _ChooseDietScreenState();
}

class _ChooseDietScreenState extends State<ChooseDietScreen> {
  String selectedDiet = 'None';
  Set<String> selectedAllergies = {};

  List<Map<String, dynamic>> dietTypes = [];

  @override
  void initState() {
    super.initState();

    // Initialize from helperController (reactive lists)
    try {
      dietTypes = helperController.category.isNotEmpty
          ? List<Map<String, dynamic>>.from(helperController.category)
          : [];
    } catch (e) {
      debugPrint('Error initializing dietTypes: $e');
      dietTypes = [];
    }

    // Only fetch if data is still empty (shouldn't happen if preloaded, but safety fallback)
    _fetchMissingData();

    // Listen to changes in reactive lists
    ever(helperController.category, (value) {
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          dietTypes = List<Map<String, dynamic>>.from(value);
        });
      });
    });

    if (!widget.isOnboarding) {
      _loadUserPreferences();
    }
  }

  Future<void> _fetchMissingData() async {
    // Only fetch if data is still empty (shouldn't happen if preloaded, but safety fallback)
    if (dietTypes.isEmpty) {
      try {
        await helperController.fetchCategorys();
        if (mounted) {
          setState(() {
            dietTypes =
                List<Map<String, dynamic>>.from(helperController.category);
          });
        }
      } catch (e) {
        debugPrint('Error fetching diet types: $e');
      }
    }
  }

  Future<void> _loadUserPreferences() async {
    final userId = userService.userId;
    if (userId == null) return;

    final mainDiet =
        userService.currentUser.value?.settings['dietPreference'] ?? '';

    final docRef = firestore.collection('users').doc(userId);
    final doc = await docRef.get();

    if (doc.exists && doc.data()?['preferences'] != null) {
      final data = doc.data() as Map<String, dynamic>;
      final preferences = data['preferences'] as Map<String, dynamic>;

      setState(() {
        if (mainDiet.isNotEmpty) {
          selectedDiet = mainDiet;
        } else {
          selectedDiet = preferences['diet'] as String? ?? 'None';
        }
        // Convert List<dynamic> to Set<String>
        final allergiesList = preferences['allergies'] as List<dynamic>? ?? [];
        selectedAllergies = allergiesList.map((e) => e.toString()).toSet();
      });
    } else if (mainDiet.isNotEmpty) {
      setState(() {
        selectedDiet = mainDiet;
      });
    }
  }

  void _updatePreferences() {
    if (widget.isOnboarding && widget.onPreferencesSelected != null) {
      widget.onPreferencesSelected!(selectedDiet, selectedAllergies);
    }
  }

  Future<void> _savePreferences() async {
    final userId = userService.userId;
    if (userId == null) {
      Get.snackbar(
        'Service Error',
        'User not found. Please try again.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    try {
      // Update both preferences and settings
      await firestore.collection('users').doc(userId).update({
        'preferences': {
          'diet': selectedDiet,
          'allergies': selectedAllergies.toList(),
          'lastUpdated': FieldValue.serverTimestamp(),
        },
        'settings.dietPreference': selectedDiet
      });

      // Update userService settings
      if (userService.currentUser.value != null) {
        userService.currentUser.value!.settings['dietPreference'] =
            selectedDiet;
      }

      // Update local user data via authController
      await authController.updateUserData({
        'settings.dietPreference': selectedDiet,
      });

      FirebaseAnalytics.instance.logEvent(name: 'dietary_preferences_updated');

      if (mounted) {
        Get.snackbar(
          'Service Approved',
          'Dietary preferences updated successfully, Chef!',
          snackPosition: SnackPosition.BOTTOM,
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        Get.snackbar(
          'Service Error',
          'Failed to save preferences, Chef. Please try again.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        leading: InkWell(
          onTap: () => Navigator.pop(context),
          child: const IconCircleButton(),
        ),
        title: Text(
          "Dietary Preferences",
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.w500,
                fontSize: getTextScale(7, context),
              ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: getPercentageWidth(5, context),
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: getPercentageHeight(2, context)),
                Text(
                  textAlign: TextAlign.center,
                  "Tell us your dietary preferences?",
                  style: Theme.of(context)
                      .textTheme
                      .displaySmall
                      ?.copyWith(fontWeight: FontWeight.w500, color: kAccent),
                ),
                SizedBox(height: getPercentageHeight(2, context)),
                Text(
                  textAlign: TextAlign.center,
                  "We'll exclusively display recipes aligned with your chosen diet.",
                  style: TextStyle(
                    fontSize: getTextScale(3.5, context),
                  ),
                ),
                SizedBox(height: getPercentageHeight(2, context)),

                //choose diet
                GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: getPercentageWidth(25, context),
                    mainAxisExtent: getPercentageHeight(14, context),
                    mainAxisSpacing: 5,
                    crossAxisSpacing: 5,
                  ),
                  itemCount: dietTypes.length,
                  itemBuilder: (BuildContext ctx, index) {
                    return DietItem(
                      dataSrc: dietTypes[index],
                      isSelected: selectedDiet == dietTypes[index]['name'],
                      onSelected: (title) {
                        setState(() {
                          if (selectedDiet == title) {
                            selectedDiet = dietTypes[0]['name'];
                          } else {
                            selectedDiet = title;
                          }
                          _updatePreferences();
                        });
                      },
                    );
                  },
                ),
                SizedBox(
                  height: getPercentageHeight(4, context),
                ),

                //choose allergy
                Text(
                  "Any allergies?",
                  style: TextStyle(
                    fontSize: getTextScale(4, context),
                  ),
                ),
                SizedBox(height: getPercentageHeight(2, context)),

                Wrap(
                  children: List.generate(
                    demoAllergyItemData.length,
                    (index) => AllergyItem(
                      dataSrc: demoAllergyItemData[index],
                      isSelected: selectedAllergies
                          .contains(demoAllergyItemData[index].allergy),
                      onSelected: (allergy) {
                        setState(() {
                          if (selectedAllergies.contains(allergy)) {
                            selectedAllergies.remove(allergy);
                          } else {
                            selectedAllergies.add(allergy);
                          }
                          _updatePreferences();
                        });
                      },
                    ),
                  ),
                ),
                SizedBox(height: getPercentageHeight(4, context)),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: !widget.isOnboarding
          ? Padding(
              padding: EdgeInsets.symmetric(
                horizontal: getPercentageWidth(5, context),
                vertical: getPercentageHeight(1, context),
              ),
              child: AppButton(
                text: "Save Preferences",
                onPressed: _savePreferences,
                type: AppButtonType.secondary,
              ),
            )
          : null,
    );
  }
}

class DietItem extends StatelessWidget {
  DietItem({
    super.key,
    required this.dataSrc,
    required this.isSelected,
    required this.onSelected,
  });

  final Map<String, dynamic> dataSrc;
  final bool isSelected;
  final Function(String) onSelected;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onSelected(dataSrc['name']),
      child: Container(
        decoration: BoxDecoration(
          color: getThemeProvider(context).isDarkMode ? kWhite : kDarkGrey,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.shade300,
              spreadRadius: 0.6,
              blurRadius: 6,
              offset: const Offset(1, 0),
            ),
          ],
          border: Border.all(
            color: isSelected ? kAccentLight : kWhite,
            width: 3,
          ),
        ),
        child: Column(
          children: [
            Flexible(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.asset(
                  getAssetImageForItem(dataSrc['name']),
                  width: getPercentageWidth(20, context),
                  height: getPercentageHeight(12, context),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(getPercentageWidth(1, context)),
              child: Text(
                dataSrc['name'] == 'All' ? 'General' : dataSrc['name'],
                style: TextStyle(
                  fontSize: getTextScale(2.5, context),
                  fontWeight: FontWeight.w600,
                  color:
                      getThemeProvider(context).isDarkMode ? kDarkGrey : kWhite,
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            )
          ],
        ),
      ),
    );
  }
}

class AllergyItem extends StatelessWidget {
  const AllergyItem({
    super.key,
    required this.dataSrc,
    required this.isSelected,
    required this.onSelected,
  });

  final AllergyItemData dataSrc;
  final bool isSelected;
  final Function(String) onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          right: getPercentageWidth(4, context),
          bottom: getPercentageHeight(2, context)),
      child: InkWell(
        onTap: () => onSelected(dataSrc.allergy),
        splashColor: kPrimaryColor.withValues(alpha: 0.4),
        borderRadius: const BorderRadius.all(
          Radius.circular(50),
        ),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: getPercentageWidth(2, context),
            vertical: getPercentageHeight(1, context),
          ),
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.all(
              Radius.circular(10),
            ),
            border: Border.all(
              color: kPrimaryColor,
            ),
            color: isSelected
                ? kAccentLight
                : getThemeProvider(context).isDarkMode
                    ? kWhite
                    : kDarkGrey,
          ),
          child: Text(
            dataSrc.allergy,
            style: TextStyle(
              color: getThemeProvider(context).isDarkMode ? kDarkGrey : kWhite,
              fontSize: getTextScale(3, context),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
