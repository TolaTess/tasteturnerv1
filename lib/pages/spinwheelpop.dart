import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants.dart';
import '../data_models/macro_data.dart';
import '../data_models/meal_model.dart';
import '../helper/helper_files.dart';
import '../helper/notifications_helper.dart';
import '../helper/utils.dart';
import '../service/audio_service.dart';
import '../service/tasty_popup_service.dart';
import '../tabs_screen/shopping_tab.dart';
import '../widgets/category_selector.dart';
import '../widgets/info_icon_widget.dart';
import '../widgets/tutorial_blocker.dart';
import 'safe_text_field.dart';
import 'spin_stack.dart';

class SpinWheelPop extends StatefulWidget {
  const SpinWheelPop({
    super.key,
    required this.ingredientList,
    required this.mealList,
    required this.selectedCategory,
  });

  final String selectedCategory;
  final List<MacroData> ingredientList;
  final List<Meal> mealList;

  @override
  _SpinWheelPopState createState() => _SpinWheelPopState();
}

class _SpinWheelPopState extends State<SpinWheelPop>
    with SingleTickerProviderStateMixin {
  final TextEditingController customController = TextEditingController();
  List<String> _ingredientList = [];
  List<String> _mealList = [];
  // AudioPlayer now handled by AudioService
  bool _isMuted = false;
  String selectedCategoryMeal = 'all';
  String selectedCategoryIdMeal = '';
  String selectedCategoryIdIngredient = '';
  String selectedCategoryIngredient = 'all';
  bool showIngredientSpin = true; // New state to toggle between modes
  bool _funMode = false;

  List<Map<String, dynamic>> _mealDietCategories = [];
  // Pantry items
  List<Map<String, dynamic>> pantryItems = [];
  bool isLoadingPantry = false;
  final GlobalKey _addSpinButtonKey = GlobalKey();
  final GlobalKey _addSwitchButtonKey = GlobalKey();
  final GlobalKey _addAudioButtonKey = GlobalKey();

  // Constants
  static const int _maxMealListSize = 10;

  @override
  void initState() {
    super.initState();
    _loadMuteState();

    // Set default for meal category
    // Defer any mutations to reactive lists until after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        final categoryDatasMeal = helperController.headers;
        if (categoryDatasMeal.isNotEmpty && selectedCategoryIdMeal.isEmpty) {
          // Check if meal times are already added to avoid duplicates
          final hasMealTimes = categoryDatasMeal.any((item) =>
              item['id'] == '1' || item['id'] == '2' || item['id'] == '3');

          if (!hasMealTimes) {
            // Add meal times to start of the list
            categoryDatasMeal.insertAll(0, [
              {'id': '1', 'name': 'breakfast'},
              {'id': '2', 'name': 'lunch'},
              {'id': '3', 'name': 'dinner'},
            ]);
          }

          // Add bounds check before accessing array
          if (categoryDatasMeal.isNotEmpty) {
            selectedCategoryIdMeal =
                categoryDatasMeal[0]['id']?.toString() ?? '';

            // Safely extract the name
            final nameData = categoryDatasMeal[0]['name'];
            if (nameData is String) {
              selectedCategoryMeal = nameData;
            } else if (nameData is Map<String, dynamic>) {
              selectedCategoryMeal = nameData['name']?.toString() ?? '';
            } else {
              selectedCategoryMeal = nameData?.toString() ?? '';
            }

            if (mounted) {
              setState(() {});
            }
          }
        }
      } catch (e) {
        debugPrint('Error initializing meal categories: $e');
        // Non-critical error, continue with defaults
      }
    });

    // Set default for meal diet categories
    try {
      if (userService.currentUser.value?.familyMode ?? false) {
        _mealDietCategories = [
          ...helperController.category
              .where((category) => category['kidsFriendly'] == true)
        ];
      } else {
        _mealDietCategories = [...helperController.category];
      }
    } catch (e) {
      debugPrint('Error loading meal diet categories: $e');
      _mealDietCategories = [];
    }

    // Ensure meal list is populated for default category
    _updateMealListByType();
    // Fetch pantry items
    _fetchPantryItems();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _showAddSpinTutorial();
      }
    });
  }

  void _showAddSpinTutorial() {
    tastyPopupService.showSequentialTutorials(
      context: context,
      sequenceKey: 'spin_wheel_tutorial',
      tutorials: [
        TutorialStep(
          tutorialId: 'add_switch_button',
          message: 'Tap to switch from Single Ingredient to Full Plate mode.',
          targetKey: _addSwitchButtonKey,
          onComplete: () {
            // Optional: Add any actions to perform after the tutorial is completed
          },
        ),
        TutorialStep(
          tutorialId: 'add_audio_button',
          message: 'Tap here to toggle the audio!',
          targetKey: _addAudioButtonKey,
          onComplete: () {
            // Optional: Add any actions to perform after the tutorial is completed
          },
        ),
        TutorialStep(
          tutorialId: 'add_spin_button',
          message: 'Double tap for an instant Chef\'s Special!',
          targetKey: _addSpinButtonKey,
          onComplete: () {
            // Optional: Add any actions to perform after the tutorial is completed
          },
        ),
      ],
    );
  }

  Future<void> _loadMuteState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() {
          _isMuted =
              prefs.getBool('isMuted') ?? false; // Default to false if not set
        });
      }
    } catch (e) {
      debugPrint('Error loading mute state: $e');
      // Non-critical error, continue with default
    }
  }

  Future<void> _saveMuteState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isMuted', _isMuted);
  }

  @override
  void dispose() {
    // Always dispose controller to prevent memory leak
    customController.dispose();
    // AudioPlayer disposal handled by AudioService
    super.dispose();
  }

  void _playSound() async {
    if (!_isMuted) {
      await AudioService.player
          .play(AssetSource('audio/spin.mp3')); // Use a spin-specific sound
    }
  }

  void _stopSound() async {
    await AudioService.player.stop();
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
      _saveMuteState(); // Save state when toggled
    });
  }

  void _updateCategoryData(String categoryId, String category) {
    if (!mounted) return;
    setState(() {
      selectedCategoryIdMeal = categoryId;
      selectedCategoryMeal = category;
      _updateMealListByType();
    });
  }

  void _updateCategoryIngredientData(String categoryId, String category) async {
    if (!mounted) return;

    try {
      if (mounted) {
        setState(() {
          selectedCategoryIdIngredient = categoryId;
          selectedCategoryIngredient = category;
        });
      }

      if (categoryId == 'custom' && category == 'custom') {
        if (!mounted || !context.mounted) return;

        try {
          bool isFromPantry = false;
          final result = await showDialog<List<String>>(
            context: context,
            builder: (context) {
              final TextEditingController modalController =
                  TextEditingController();
              final isDarkMode = getThemeProvider(context).isDarkMode;
              final textTheme = Theme.of(context).textTheme;
              return AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                backgroundColor: isDarkMode ? kDarkGrey : kWhite,
                title: Text(
                  'What\'s in the Walk-in?',
                  style: textTheme.titleMedium?.copyWith(color: kAccent),
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SafeTextFormField(
                      controller: modalController,
                      style: textTheme.bodyMedium
                          ?.copyWith(color: isDarkMode ? kWhite : kDarkGrey),
                      keyboardType: TextInputType.text,
                      decoration: InputDecoration(
                        labelText:
                            "List available inventory (eggs, tuna, etc.) for the spin.",
                        labelStyle: textTheme.bodySmall?.copyWith(
                            color: isDarkMode ? kLightGrey : kLightGrey),
                        enabledBorder: outlineInputBorder(10),
                        focusedBorder: outlineInputBorder(10),
                        border: outlineInputBorder(10),
                      ),
                    ),
                    if (pantryItems.isNotEmpty) ...[
                      SizedBox(height: getPercentageHeight(2, context)),
                      OutlinedButton.icon(
                        onPressed: isLoadingPantry
                            ? null
                            : () async {
                                final selectedItems =
                                    await _showPantryIngredientSelector();
                                if (selectedItems != null &&
                                    selectedItems.isNotEmpty) {
                                  isFromPantry = true;
                                  Navigator.pop(context, selectedItems);
                                }
                              },
                        icon: Icon(
                          Icons.inventory_2,
                          color: isLoadingPantry ? kLightGrey : kAccent,
                        ),
                        label: Text(
                          isLoadingPantry
                              ? 'Preparing...'
                              : 'Add from Pantry (${pantryItems.length})',
                          style: textTheme.bodyMedium?.copyWith(
                            color: isLoadingPantry ? kLightGrey : kAccent,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: isLoadingPantry ? kLightGrey : kAccent,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Cancel',
                      style: textTheme.bodyMedium
                          ?.copyWith(color: isDarkMode ? kWhite : kDarkGrey),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      try {
                        final text = modalController.text.trim();
                        if (text.isEmpty) {
                          Navigator.pop(context, null);
                          return;
                        }
                        final items = text
                            .split(RegExp(r'[,;\n]'))
                            .map((i) => i.trim())
                            .where((i) => i.isNotEmpty)
                            .toList();
                        if (items.isNotEmpty) {
                          isFromPantry = false;
                          Navigator.pop(context, items);
                        } else {
                          Navigator.pop(context, null);
                        }
                      } catch (e) {
                        debugPrint('Error parsing custom ingredients: $e');
                        Navigator.pop(context, null);
                      }
                    },
                    child: Text(
                      'Add',
                      style: textTheme.bodyMedium?.copyWith(color: kAccent),
                    ),
                  ),
                ],
              );
            },
          );
          if (result != null && result.isNotEmpty && mounted) {
            setState(() {
              _ingredientList = result;
              _funMode =
                  !isFromPantry; // false if from pantry, true if manual input
            });
          }
        } catch (e) {
          debugPrint('Error showing custom ingredient dialog: $e');
          // Non-critical error, continue with default category
        }
      } else {
        _ingredientList = updateIngredientListByType(
                widget.ingredientList, selectedCategoryIngredient)
            .map((ingredient) => ingredient.title)
            .toList();
      }
    } catch (e) {
      debugPrint('Error updating category ingredient data: $e');
      // Non-critical error, continue with defaults
    }
  }

  /// Fetch pantry items from Firestore
  Future<void> _fetchPantryItems() async {
    try {
      final userId = userService.userId;
      if (userId == null || userId.isEmpty) {
        return;
      }

      setState(() {
        isLoadingPantry = true;
      });

      final pantryRef =
          firestore.collection('users').doc(userId).collection('pantry');

      final snapshot = await pantryRef.get();

      if (mounted) {
        setState(() {
          pantryItems = snapshot.docs.map((doc) {
            final data = doc.data();
            return {
              'id': doc.id,
              'name': data['name'] as String? ?? '',
              'type': data['type'] as String? ?? 'ingredient',
              'calories': data['calories'] as int? ?? 0,
              'protein': (data['protein'] as num?)?.toDouble() ?? 0.0,
              'carbs': (data['carbs'] as num?)?.toDouble() ?? 0.0,
              'fat': (data['fat'] as num?)?.toDouble() ?? 0.0,
              'addedAt': data['addedAt'],
              'updatedAt': data['updatedAt'],
            };
          }).toList();
          isLoadingPantry = false;
        });
      }

      debugPrint('Fetched ${pantryItems.length} pantry items');
    } catch (e) {
      debugPrint('Error fetching pantry items: $e');
      if (mounted) {
        setState(() {
          isLoadingPantry = false;
        });
      }
    }
  }

  /// Show pantry ingredient selector dialog
  Future<List<String>?> _showPantryIngredientSelector() async {
    if (pantryItems.isEmpty) {
      showTastySnackbar(
        'Empty Pantry, Chef',
        'The pantry is empty. Stock ingredients in pantry mode first, Chef.',
        context,
        backgroundColor: Colors.orange,
      );
      return null;
    }

    final isDarkMode = getThemeProvider(context).isDarkMode;
    final Set<String> selectedIngredientIds = {};

    final result = await showDialog<List<String>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          backgroundColor: isDarkMode ? kDarkGrey : kWhite,
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Add from Pantry',
                style: TextStyle(
                  color: isDarkMode ? kWhite : kBlack,
                ),
              ),
              if (pantryItems.length > 1)
                TextButton(
                  onPressed: () {
                    setDialogState(() {
                      if (selectedIngredientIds.length == pantryItems.length) {
                        selectedIngredientIds.clear();
                      } else {
                        selectedIngredientIds.addAll(
                          pantryItems.map((item) => item['id'] as String),
                        );
                      }
                    });
                  },
                  child: Text(
                    selectedIngredientIds.length == pantryItems.length
                        ? 'Deselect All'
                        : 'Select All',
                    style: TextStyle(
                      color: kAccent,
                      fontSize: getTextScale(3, context),
                    ),
                  ),
                ),
            ],
          ),
          content: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.6,
            ),
            child: pantryItems.isEmpty
                ? Center(
                    child: Text(
                      'No items in the pantry, Chef.',
                      style: TextStyle(
                        color: isDarkMode ? kLightGrey : kDarkGrey,
                      ),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: pantryItems.length,
                    itemBuilder: (context, index) {
                      final item = pantryItems[index];
                      final itemId = item['id'] as String;
                      final itemName = item['name'] as String;
                      final isSelected = selectedIngredientIds.contains(itemId);

                      return CheckboxListTile(
                        title: Text(
                          capitalizeFirstLetter(itemName),
                          style: TextStyle(
                            color: isDarkMode ? kWhite : kBlack,
                            fontSize: getTextScale(3.5, context),
                          ),
                        ),
                        subtitle: item['calories'] != null &&
                                item['calories'] > 0
                            ? Text(
                                '${item['calories']} kcal',
                                style: TextStyle(
                                  color: isDarkMode ? kLightGrey : kDarkGrey,
                                  fontSize: getTextScale(2.5, context),
                                ),
                              )
                            : null,
                        value: isSelected,
                        onChanged: (value) {
                          setDialogState(() {
                            if (value == true) {
                              selectedIngredientIds.add(itemId);
                            } else {
                              selectedIngredientIds.remove(itemId);
                            }
                          });
                        },
                        secondary: Icon(
                          Icons.inventory_2,
                          color: kAccent,
                          size: getIconScale(5, context),
                        ),
                        activeColor: kAccent,
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: isDarkMode ? kWhite : kAccent,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: selectedIngredientIds.isEmpty
                  ? null
                  : () {
                      final selectedItems = pantryItems
                          .where((item) => selectedIngredientIds
                              .contains(item['id'] as String))
                          .map((item) => item['name'] as String)
                          .toList();

                      Navigator.pop(dialogContext, selectedItems);
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: kAccent,
              ),
              child: Text(
                'Add Selected (${selectedIngredientIds.length})',
                style: TextStyle(color: kWhite),
              ),
            ),
          ],
        ),
      ),
    );

    return result;
  }

  void _updateMealListByType() async {
    if (!mounted) return;

    try {
      final categoryLower = selectedCategoryMeal.toLowerCase();
      if (selectedCategoryMeal.isEmpty ||
          categoryLower == 'balanced' ||
          categoryLower == 'general' ||
          categoryLower == 'all') {
        if (mounted) {
          setState(() {
            _mealList = widget.mealList
                .map((meal) => meal.title)
                .take(_maxMealListSize)
                .toList();
          });
        }
      } else {
        final newMealList = widget.mealList
            .where((meal) => meal.categories.contains(selectedCategoryMeal))
            .toList();

        if (mounted) {
          setState(() {
            if (newMealList.length > _maxMealListSize) {
              _mealList = newMealList
                  .map((meal) => meal.title)
                  .take(_maxMealListSize)
                  .toList();
            } else {
              _mealList = newMealList.map((meal) => meal.title).toList();
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Error updating meal list by type: $e');
      if (mounted) {
        setState(() {
          _mealList = [];
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoryDatasMeal = helperController.headers;
    final categoryDatasIngredientDiet = _mealDietCategories;
    final isDarkMode = getThemeProvider(context).isDarkMode;
    final textTheme = Theme.of(context).textTheme;
    final dietPreference =
        userService.currentUser.value?.settings['dietPreference']?.toString() ??
            'balanced';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: kAccent,
        automaticallyImplyLeading: false,
        centerTitle: true,
        toolbarHeight:
            getPercentageHeight(10, context), // Control height with percentage
        title: Text('Need a Menu Idea, Chef?',
            style: textTheme.displayMedium
                ?.copyWith(fontSize: getTextScale(5.5, context))),
      ),
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage(
              isDarkMode
                  ? 'assets/images/background/imagedark.jpeg'
                  : 'assets/images/background/imagelight.jpeg',
            ),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              isDarkMode
                  ? Colors.black.withOpacity(0.5)
                  : Colors.white.withOpacity(0.5),
              isDarkMode ? BlendMode.darken : BlendMode.lighten,
            ),
          ),
        ),
        child: BlockableSingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height,
            ),
            child: IntrinsicHeight(
              child: Column(
                children: [
                  SizedBox(height: getPercentageHeight(1.5, context)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Take a Spin!',
                        style: textTheme.displaySmall?.copyWith(color: kAccent),
                      ),
                      SizedBox(width: getPercentageWidth(2, context)),
                      const InfoIconWidget(
                        title: 'The Inspiration Wheel',
                        description:
                            'Let the wheel decide tonight\'s Special, Chef.',
                        details: [
                          {
                            'icon': Icons.casino,
                            'title': 'Ingredient Mode',
                            'description':
                                'Spin for random ingredients to inspire your cooking, Chef',
                            'color': kAccentLight,
                          },
                          {
                            'icon': Icons.restaurant,
                            'title': 'Full Plate Mode',
                            'description':
                                'Generate a full service plan based on your preferences.',
                            'color': kAccentLight,
                          },
                          {
                            'icon': Icons.category,
                            'title': 'Category Filter',
                            'description':
                                'Filter by Station: Protein, Veg, or full inventory.',
                            'color': kAccentLight,
                          },
                          {
                            'icon': Icons.volume_up,
                            'title': 'Sound Effects',
                            'description':
                                'Toggle kitchen ambience and effects.',
                            'color': kAccentLight,
                          },
                        ],
                        iconColor: kAccentLight,
                        tooltip: 'Wheel Mechanics',
                      ),
                    ],
                  ),
                  SizedBox(height: getPercentageHeight(1, context)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: getPercentageWidth(2, context),
                        ),
                        decoration: BoxDecoration(
                          color: kAccent.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: TextButton(
                          key: _addSwitchButtonKey,
                          onPressed: () {
                            setState(() {
                              showIngredientSpin = !showIngredientSpin;
                              if (!showIngredientSpin) {
                                // Switched to meal spin, update meal list
                                _updateMealListByType();
                              }
                            });
                          },
                          child: Text(
                            showIngredientSpin
                                ? 'Switch to Full Plate Mode'
                                : 'Switch to Ingredient Mode',
                            style: textTheme.titleMedium?.copyWith(
                                color: kAccentLight,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      IconButton(
                        key: _addAudioButtonKey,
                        iconSize: getIconScale(6, context),
                        icon: Icon(
                          _isMuted ? Icons.volume_off : Icons.volume_up,
                        ),
                        onPressed: _toggleMute,
                      ),
                    ],
                  ),
                  Expanded(
                    child: showIngredientSpin
                        ? _buildIngredientSpinView(isDarkMode, textTheme)
                        : _buildMealSpinView(
                            isDarkMode,
                            categoryDatasMeal,
                            categoryDatasIngredientDiet,
                            textTheme,
                            dietPreference.toString()),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIngredientSpinView(bool isDarkMode, TextTheme textTheme) {
    return Column(
      children: [
        SizedBox(height: getPercentageHeight(2, context)),

        //category options
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            GestureDetector(
              onTap: () => _updateCategoryIngredientData('protein', 'protein'),
              child: buildAddMealTypeLegend(
                context,
                'protein',
                isSelected: selectedCategoryIngredient == 'protein',
              ),
            ),
            GestureDetector(
              onTap: () => _updateCategoryIngredientData('grain', 'grain'),
              child: buildAddMealTypeLegend(
                context,
                'grain',
                isSelected: selectedCategoryIngredient == 'grain',
              ),
            ),
            GestureDetector(
              onTap: () =>
                  _updateCategoryIngredientData('vegetable', 'vegetable'),
              child: buildAddMealTypeLegend(
                context,
                'vegetable',
                isSelected: selectedCategoryIngredient == 'vegetable',
              ),
            ),
            GestureDetector(
              onTap: () => _updateCategoryIngredientData('fruit', 'fruit'),
              child: buildAddMealTypeLegend(
                context,
                'fruit',
                isSelected: selectedCategoryIngredient == 'fruit',
              ),
            ),
            GestureDetector(
              onTap: () => _updateCategoryIngredientData('custom', 'custom'),
              child: buildAddMealTypeLegend(
                context,
                'custom',
                isSelected: selectedCategoryIngredient == 'custom',
              ),
            ),
          ],
        ),

        SizedBox(height: getPercentageHeight(2, context)),
        // Removed custom mode checkbox row
        //const SizedBox(height: 15),
        // Spin wheel below macros

        GestureDetector(
          onTap: () {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) =>
                        const ShoppingTab(is54321View: true)));
          },
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: getPercentageWidth(2, context),
              vertical: getPercentageHeight(1.3, context),
            ),
            decoration: BoxDecoration(
              color: kAccent.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              'Generate a 5-4-3-2-1 Prep List, Chef?',
              style: textTheme.bodyMedium?.copyWith(color: kAccent),
            ),
          ),
        ),

        SizedBox(height: getPercentageHeight(1, context)),

        Expanded(
          child: SpinWheelWidget(
            key: _addSpinButtonKey,
            labels: widget.ingredientList,
            customLabels: _ingredientList.isNotEmpty ? _ingredientList : null,
            isMealSpin: false,
            playSound: _playSound,
            stopSound: _stopSound,
            funMode: _funMode,
            selectedCategory: selectedCategoryIngredient,
          ),
        ),
      ],
    );
  }

  Widget _buildMealSpinView(
      bool isDarkMode,
      List<Map<String, dynamic>> categoryDatas,
      List<Map<String, dynamic>> categoryDatatDiet,
      TextTheme textTheme,
      String dietPreference) {
    // Ensure dietPreference is not null
    final safeDietPreference =
        dietPreference.isNotEmpty ? dietPreference : 'balanced';
    return Column(
      children: [
        // ------------------------------------Premium / Ads------------------------------------
        SizedBox(height: getPercentageHeight(2, context)),
        getAdsWidget(userService.currentUser.value?.isPremium ?? false,
            isDiv: false),
        if (!(userService.currentUser.value?.isPremium ?? false))
          SizedBox(height: getPercentageHeight(2, context)),
        // ------------------------------------Premium / Ads------------------------------------

        Row(
          children: [
            Expanded(
              flex: 1,
              child: GestureDetector(
                onTap: () {
                  if (mounted) {
                    setState(() {
                      selectedCategoryIdMeal = safeDietPreference;
                      selectedCategoryMeal = safeDietPreference;
                    });
                    _updateMealListByType();
                  }
                },
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: getPercentageWidth(2, context),
                    vertical: getPercentageHeight(1.3, context),
                  ),
                  decoration: BoxDecoration(
                    color: selectedCategoryMeal.toLowerCase() ==
                            safeDietPreference.toLowerCase()
                        ? kAccent.withValues(alpha: 0.2)
                        : kLightGrey.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      safeDietPreference,
                      style: textTheme.titleMedium?.copyWith(
                          color: selectedCategoryMeal.toLowerCase() ==
                                  safeDietPreference.toLowerCase()
                              ? kAccent
                              : kLightGrey),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: CategorySelector(
                categories: categoryDatas,
                selectedCategoryId: selectedCategoryIdMeal,
                onCategorySelected: _updateCategoryData,
                isDarkMode: isDarkMode,
                accentColor: kAccentLight,
                darkModeAccentColor: kDarkModeAccent,
                isFunMode: false,
              ),
            ),
          ],
        ),
        _ingredientList.isEmpty
            ? SizedBox(height: getPercentageHeight(1.5, context))
            : SizedBox(height: getPercentageHeight(1, context)),

        _mealList.isEmpty
            ? const SizedBox(height: 1)
            : SizedBox(height: getPercentageHeight(1.5, context)),

        Expanded(
          child: Center(
            child: _mealList.isEmpty
                ? noItemTastyWidget(
                    "I can't build a plate with those specs...",
                    "",
                    context,
                    false,
                    '',
                  )
                : SpinWheelWidget(
                    mealList: widget.mealList,
                    labels: [], // Empty since we use customLabels
                    customLabels: _mealList,
                    isMealSpin: true,
                    playSound: _playSound,
                    stopSound: _stopSound,
                  ),
          ),
        ),
      ],
    );
  }

  void snackbar(BuildContext context, String mMacro, String category) {
    if (mounted) {
      showTastySnackbar(
        'Let\'s reset the station and try again.',
        "$mMacro doesn't fit the profile for $category.",
        context,
      );
    }
  }
}
