import 'package:flutter/material.dart';
import '../constants.dart';
import '../helper/utils.dart';

/// Widget that displays a program as "The Menu" - Executive Chef's Daily Briefing format
class MenuDetailWidget extends StatefulWidget {
  final Map<String, dynamic> program;
  final bool isEnrolled;

  const MenuDetailWidget({
    super.key,
    required this.program,
    this.isEnrolled = false,
  });

  @override
  State<MenuDetailWidget> createState() => _MenuDetailWidgetState();
}

class _MenuDetailWidgetState extends State<MenuDetailWidget> {
  bool _showChefsNote = false;

  /// Extract difficulty from options array
  String? _extractDifficulty(List<dynamic>? options) {
    if (options == null || options.isEmpty) return null;

    final optionsList = options.map((e) => e.toString().toLowerCase()).toList();

    if (optionsList.contains('beginner')) return 'Beginner';
    if (optionsList.contains('intermediate')) return 'Intermediate';
    if (optionsList.contains('advanced')) return 'Advanced';

    // Return first option capitalized if none match
    return optionsList.isNotEmpty
        ? optionsList.first[0].toUpperCase() + optionsList.first.substring(1)
        : null;
  }

  /// Extract plate specs from portionDetails with flexible key matching
  /// Returns a map with category as key and a map containing 'size' and 'examples'
  /// portionDetails structure: {'protein': {'palmSize': '1 palm', 'examples': [...]}, ...}
  Map<String, Map<String, dynamic>> _extractPlateSpecs(
      Map<String, dynamic>? portionDetails) {
    if (portionDetails == null || portionDetails.isEmpty) return {};

    final specs = <String, Map<String, dynamic>>{};

    // Map of lowercase keys to display names
    final categoryMap = {
      'protein': 'Protein',
      'grain': 'Grains',
      'vegetable': 'Vegetables',
      'vegetables': 'Vegetables',
      'veg': 'Vegetables',
      'fats': 'Fats',
      'fat': 'Fats',
      'healthy fats': 'Fats',
      'fruit': 'Fruits',
      'fruits': 'Fruits',
      'carbs': 'Grains',
      'carbohydrates': 'Grains',
      'grains': 'Grains',
      'whole grains': 'Grains',
    };

    // Helper function to extract size and examples
    Map<String, dynamic> _extractCategoryData(dynamic value) {
      if (value is Map) {
        final palmSize = value['palmSize']?.toString() ??
            value['size']?.toString() ??
            value['defaultPalmSize']?.toString() ??
            '';
        final examples = value['examples'] is List
            ? List<String>.from(value['examples'].map((e) => e.toString()))
            : (value['defaultExamples'] is List
                ? List<String>.from(
                    value['defaultExamples'].map((e) => e.toString()))
                : []);

        return {
          'size': palmSize.isNotEmpty ? palmSize : value.toString(),
          'examples': examples,
        };
      } else {
        // If it's a string, use it as the size
        return {
          'size': value.toString(),
          'examples': [],
        };
      }
    }

    // Iterate through all keys in portionDetails
    for (var key in portionDetails.keys) {
      final keyLower = key.toString().toLowerCase();

      // Check if this key matches any category
      String? displayName;
      for (var categoryKey in categoryMap.keys) {
        if (keyLower == categoryKey || keyLower.contains(categoryKey)) {
          displayName = categoryMap[categoryKey];
          break;
        }
      }

      // Also check for capitalized variations
      if (displayName == null) {
        if (keyLower.contains('protein')) {
          displayName = 'Protein';
        } else if (keyLower.contains('grain') || keyLower.contains('carb')) {
          displayName = 'Grains';
        } else if (keyLower.contains('vegetable') || keyLower.contains('veg')) {
          displayName = 'Vegetables';
        } else if (keyLower.contains('fat')) {
          displayName = 'Fats';
        } else if (keyLower.contains('fruit')) {
          displayName = 'Fruits';
        }
      }

      if (displayName != null && !specs.containsKey(displayName)) {
        final data = _extractCategoryData(portionDetails[key]);
        if (data['size'].toString().isNotEmpty) {
          specs[displayName] = data;
        }
      }
    }

    return specs;
  }

  /// Extract 3 prep list items from routine, fitnessProgram, and tips
  List<Map<String, String>> _extractPrepListItems(
      Map<String, dynamic> program) {
    final prepItems = <Map<String, String>>[];

    // Extract routine items
    List<dynamic> routine = [];
    if (program['routine'] != null && program['routine'] is List) {
      routine = program['routine'] as List;
    }

    // Extract fitness program data
    Map<String, dynamic> fitnessProgram = {};
    if (program['fitnessProgram'] != null && program['fitnessProgram'] is Map) {
      fitnessProgram = Map<String, dynamic>.from(program['fitnessProgram']);
    }

    // Extract tips
    List<String> tips = [];
    if (program['tips'] != null && program['tips'] is List) {
      tips = List<String>.from(program['tips']);
    }

    // 1. Movement - from fitnessProgram or routine
    String? movementText;
    if (fitnessProgram.isNotEmpty) {
      if (fitnessProgram.containsKey('overview') &&
          fitnessProgram['overview'] != null) {
        movementText = fitnessProgram['overview'].toString();
      } else if (fitnessProgram.containsKey('frequency') &&
          fitnessProgram['frequency'] != null) {
        final frequency = fitnessProgram['frequency'].toString();
        final exercises = fitnessProgram['exercises'] != null
            ? (fitnessProgram['exercises'] as List).join(', ')
            : '';
        movementText =
            exercises.isNotEmpty ? '$frequency: $exercises' : frequency;
      }
    }

    // If no movement from fitnessProgram, check routine for exercise-related items
    if (movementText == null || movementText.isEmpty) {
      for (var item in routine) {
        if (item is Map) {
          final title = item['title']?.toString().toLowerCase() ?? '';
          if (title.contains('exercise') ||
              title.contains('workout') ||
              title.contains('movement') ||
              title.contains('fitness') ||
              title.contains('training')) {
            final duration = item['duration']?.toString() ?? '';
            final description = item['description']?.toString() ?? '';
            movementText =
                duration.isNotEmpty ? '$duration: $description' : description;
            break;
          }
        }
      }
    }

    if (movementText != null && movementText.isNotEmpty) {
      prepItems.add({
        'label': 'Movement',
        'value': movementText,
        'icon': 'fitness_center',
      });
    }

    // 2. Hydration/Habit - from routine
    String? hydrationText;
    for (var item in routine) {
      if (item is Map) {
        final title = item['title']?.toString().toLowerCase() ?? '';
        if (title.contains('hydration') ||
            title.contains('water') ||
            title.contains('drink') ||
            title.contains('meal planning') ||
            title.contains('meal prep') ||
            title.contains('prep')) {
          final duration = item['duration']?.toString() ?? '';
          final description = item['description']?.toString() ?? '';
          hydrationText =
              duration.isNotEmpty ? '$duration: $description' : description;
          break;
        }
      }
    }

    if (hydrationText != null && hydrationText.isNotEmpty) {
      prepItems.add({
        'label': 'Hydration',
        'value': hydrationText,
        'icon': 'water_drop',
      });
    } else if (routine.isNotEmpty && prepItems.length < 2) {
      // Use first routine item as fallback
      final firstItem = routine[0];
      if (firstItem is Map) {
        final title = firstItem['title']?.toString() ?? 'Daily Habit';
        final duration = firstItem['duration']?.toString() ?? '';
        final description = firstItem['description']?.toString() ?? '';
        final value =
            duration.isNotEmpty ? '$duration: $description' : description;
        prepItems.add({
          'label': title,
          'value': value,
          'icon': 'check_circle',
        });
      }
    }

    // 3. Mindset/Sleep - from routine or tips
    String? mindsetText;
    for (var item in routine) {
      if (item is Map) {
        final title = item['title']?.toString().toLowerCase() ?? '';
        if (title.contains('sleep') ||
            title.contains('read') ||
            title.contains('meditation') ||
            title.contains('mindset') ||
            title.contains('recovery') ||
            title.contains('rest')) {
          final duration = item['duration']?.toString() ?? '';
          final description = item['description']?.toString() ?? '';
          mindsetText =
              duration.isNotEmpty ? '$duration: $description' : description;
          break;
        }
      }
    }

    // If no mindset from routine, check tips
    if (mindsetText == null || mindsetText.isEmpty) {
      for (var tip in tips) {
        final tipLower = tip.toLowerCase();
        if (tipLower.contains('sleep') ||
            tipLower.contains('read') ||
            tipLower.contains('rest') ||
            tipLower.contains('recovery')) {
          mindsetText = tip;
          break;
        }
      }
    }

    if (mindsetText != null && mindsetText.isNotEmpty) {
      prepItems.add({
        'label': 'Mindset',
        'value': mindsetText,
        'icon': 'self_improvement',
      });
    } else if (tips.isNotEmpty && prepItems.length < 3) {
      // Use first tip as fallback
      prepItems.add({
        'label': 'Tip',
        'value': tips[0],
        'icon': 'lightbulb',
      });
    }

    // Ensure we have at most 3 items
    return prepItems.take(3).toList();
  }

  /// Check if program type should hide certain categories
  bool _shouldHideCategory(String category, String? programType) {
    if (programType == null) return false;

    final type = programType.toLowerCase();

    // Carnivore/Keto might hide grains/vegetables
    if ((type.contains('carnivore') || type.contains('keto')) &&
        (category == 'Grains' || category == 'Vegetables')) {
      return true;
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    final textTheme = Theme.of(context).textTheme;

    final programName = widget.program['name'] ?? 'Menu';
    final duration = widget.program['duration'] ?? '';
    final options = widget.program['options'] as List<dynamic>?;
    final difficulty = _extractDifficulty(options);
    final benefits = List<String>.from(widget.program['benefits'] ?? []);
    final description = widget.program['description'] ?? '';
    final portionDetails =
        widget.program['portionDetails'] as Map<String, dynamic>?;
    final plateSpecsMap = _extractPlateSpecs(portionDetails);
    final notAllowed = List<String>.from(widget.program['notAllowed'] ?? []);
    final guidelines = List<String>.from(widget.program['guidelines'] ?? []);
    final programDetails =
        List<String>.from(widget.program['programDetails'] ?? []);
    final programType = widget.program['type']?.toString();
    final prepListItems = _extractPrepListItems(widget.program);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // A. Service Overview Header
        _buildServiceOverview(
          context,
          textTheme,
          isDarkMode,
          programName,
          duration,
          difficulty,
          benefits,
          description,
        ),

        SizedBox(height: getPercentageHeight(2, context)),

        // B. The Plate Specs Section
        if (plateSpecsMap.isNotEmpty ||
            notAllowed.isNotEmpty ||
            guidelines.isNotEmpty ||
            programDetails.isNotEmpty)
          _buildPlateSpecsSection(
            context,
            textTheme,
            isDarkMode,
            plateSpecsMap,
            notAllowed,
            guidelines,
            programDetails,
            programType,
          ),

        SizedBox(height: getPercentageHeight(2, context)),

        // C. The Daily Prep List Section
        if (prepListItems.isNotEmpty)
          _buildPrepListSection(
            context,
            textTheme,
            isDarkMode,
            prepListItems,
          ),
      ],
    );
  }

  Widget _buildServiceOverview(
    BuildContext context,
    TextTheme textTheme,
    bool isDarkMode,
    String programName,
    String duration,
    String? difficulty,
    List<String> benefits,
    String description,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Duration • Difficulty
        if (duration.isNotEmpty || difficulty != null)
          Row(
            children: [
              if (duration.isNotEmpty) ...[
                Icon(
                  Icons.schedule,
                  size: getIconScale(4, context),
                  color: isDarkMode
                      ? kWhite.withValues(alpha: 0.7)
                      : kDarkGrey.withValues(alpha: 0.7),
                ),
                SizedBox(width: getPercentageWidth(1, context)),
                Text(
                  duration,
                  style: textTheme.titleMedium?.copyWith(
                    color: isDarkMode
                        ? kWhite.withValues(alpha: 0.7)
                        : kDarkGrey.withValues(alpha: 0.7),
                  ),
                ),
              ],
              if (duration.isNotEmpty && difficulty != null)
                Text(
                  ' • ',
                  style: textTheme.titleMedium?.copyWith(
                    color: isDarkMode
                        ? kWhite.withValues(alpha: 0.7)
                        : kDarkGrey.withValues(alpha: 0.7),
                  ),
                ),
              if (difficulty != null)
                Text(
                  difficulty,
                  style: textTheme.titleMedium?.copyWith(
                    color: kAccent,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),

        SizedBox(height: getPercentageHeight(1.5, context)),

        // Benefits section
        if (benefits.isNotEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Benefits',
                style: textTheme.titleLarge?.copyWith(
                  color: kAccent,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: getPercentageHeight(1, context)),
              ...benefits.map((benefit) => Padding(
                    padding: EdgeInsets.only(
                      bottom: getPercentageHeight(0.8, context),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: EdgeInsets.only(
                            top: getPercentageHeight(0.5, context),
                            right: getPercentageWidth(2, context),
                          ),
                          child: Icon(
                            Icons.check_circle,
                            size: getIconScale(4, context),
                            color: kAccent,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            benefit,
                            style: textTheme.bodyMedium?.copyWith(
                              color: isDarkMode
                                  ? kWhite.withValues(alpha: 0.9)
                                  : kDarkGrey.withValues(alpha: 0.9),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )),
            ],
          ),

        SizedBox(height: getPercentageHeight(1.5, context)),

        // Chef's Note (collapsible description)
        if (description.isNotEmpty)
          GestureDetector(
            onTap: () {
              setState(() {
                _showChefsNote = !_showChefsNote;
              });
            },
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.all(getPercentageWidth(4, context)),
              decoration: BoxDecoration(
                color: isDarkMode
                    ? kLightGrey.withValues(alpha: 0.1)
                    : kLightGrey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: kAccent.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.note,
                        size: getIconScale(4, context),
                        color: kAccent,
                      ),
                      SizedBox(width: getPercentageWidth(2, context)),
                      Text(
                        'Chef\'s Note',
                        style: textTheme.titleMedium?.copyWith(
                          color: kAccent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        _showChefsNote ? Icons.expand_less : Icons.expand_more,
                        color: kAccent,
                        size: getIconScale(4, context),
                      ),
                    ],
                  ),
                  if (_showChefsNote) ...[
                    SizedBox(height: getPercentageHeight(1, context)),
                    Text(
                      description,
                      style: textTheme.bodyMedium?.copyWith(
                        color: isDarkMode ? kWhite : kDarkGrey,
                        height: 1.5,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPlateSpecsSection(
    BuildContext context,
    TextTheme textTheme,
    bool isDarkMode,
    Map<String, Map<String, dynamic>> plateSpecs,
    List<String> notAllowed,
    List<String> guidelines,
    List<String> programDetails,
    String? programType,
  ) {
    final foodRules = guidelines.isNotEmpty ? guidelines : programDetails;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.restaurant_menu,
              size: getIconScale(5, context),
              color: kAccent,
            ),
            SizedBox(width: getPercentageWidth(2, context)),
            Text(
              'The Plate Specs',
              style: textTheme.titleLarge?.copyWith(
                color: kAccent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),

        SizedBox(height: getPercentageHeight(1.5, context)),

        // Plate specs items
        if (plateSpecs.isNotEmpty)
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(getPercentageWidth(4, context)),
            decoration: BoxDecoration(
              color: isDarkMode
                  ? kLightGrey.withValues(alpha: 0.1)
                  : kLightGrey.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                if (plateSpecs.containsKey('Protein') &&
                    !_shouldHideCategory('Protein', programType))
                  _buildPlateSpecItem(
                    context,
                    textTheme,
                    isDarkMode,
                    'Protein',
                    plateSpecs['Protein']!['size']?.toString() ?? '',
                    (plateSpecs['Protein']!['examples'] as List<dynamic>?)
                            ?.map((e) => e.toString())
                            .toList() ??
                        [],
                    Icons.set_meal,
                    Colors.brown,
                  ),
                if (plateSpecs.containsKey('Vegetables') &&
                    !_shouldHideCategory('Vegetables', programType))
                  _buildPlateSpecItem(
                    context,
                    textTheme,
                    isDarkMode,
                    'Vegetables',
                    plateSpecs['Vegetables']!['size']?.toString() ?? '',
                    (plateSpecs['Vegetables']!['examples'] as List<dynamic>?)
                            ?.map((e) => e.toString())
                            .toList() ??
                        [],
                    Icons.eco,
                    Colors.green,
                  ),
                if (plateSpecs.containsKey('Grains') &&
                    !_shouldHideCategory('Grains', programType))
                  _buildPlateSpecItem(
                    context,
                    textTheme,
                    isDarkMode,
                    'Grains',
                    plateSpecs['Grains']!['size']?.toString() ?? '',
                    (plateSpecs['Grains']!['examples'] as List<dynamic>?)
                            ?.map((e) => e.toString())
                            .toList() ??
                        [],
                    Icons.bakery_dining,
                    Colors.amber,
                  ),
                if (plateSpecs.containsKey('Fats') &&
                    !_shouldHideCategory('Fats', programType))
                  _buildPlateSpecItem(
                    context,
                    textTheme,
                    isDarkMode,
                    'Healthy Fats',
                    plateSpecs['Fats']!['size']?.toString() ?? '',
                    (plateSpecs['Fats']!['examples'] as List<dynamic>?)
                            ?.map((e) => e.toString())
                            .toList() ??
                        [],
                    Icons.water_drop,
                    Colors.orange,
                  ),
                if (plateSpecs.containsKey('Fruits') &&
                    !_shouldHideCategory('Fruits', programType))
                  _buildPlateSpecItem(
                    context,
                    textTheme,
                    isDarkMode,
                    'Fruits',
                    plateSpecs['Fruits']!['size']?.toString() ?? '',
                    (plateSpecs['Fruits']!['examples'] as List<dynamic>?)
                            ?.map((e) => e.toString())
                            .toList() ??
                        [],
                    Icons.apple,
                    Colors.red,
                  ),
              ],
            ),
          ),

        // Clickable Palm Method Link
        if (plateSpecs.isNotEmpty) ...[
          SizedBox(height: getPercentageHeight(1.5, context)),
          GestureDetector(
            onTap: () => _showPalmMethodDialog(context, textTheme, isDarkMode),
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.all(getPercentageWidth(4, context)),
              decoration: BoxDecoration(
                color: kAccent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: kAccent.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Image.asset(
                    'assets/images/background/palm4.png',
                    width: getPercentageWidth(15, context),
                    height: getPercentageWidth(15, context),
                    fit: BoxFit.contain,
                  ),
                  SizedBox(width: getPercentageWidth(3, context)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'The Palm Method',
                          style: textTheme.titleMedium?.copyWith(
                            color: kAccent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: getPercentageHeight(0.5, context)),
                        Text(
                          'Tap to learn how to measure portions using your palm, Chef',
                          style: textTheme.bodySmall?.copyWith(
                            color: isDarkMode
                                ? kWhite.withValues(alpha: 0.7)
                                : kDarkGrey.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: getIconScale(4, context),
                    color: kAccent,
                  ),
                ],
              ),
            ),
          ),
        ],

        SizedBox(height: getPercentageHeight(1.5, context)),

        // Not Allowed restrictions
        if (notAllowed.isNotEmpty &&
            !notAllowed.any(
                (item) => item.toString().toLowerCase().contains('fallback')))
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(getPercentageWidth(4, context)),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.red.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.block,
                      size: getIconScale(4, context),
                      color: Colors.red,
                    ),
                    SizedBox(width: getPercentageWidth(2, context)),
                    Text(
                      'Restrictions',
                      style: textTheme.titleMedium?.copyWith(
                        color: Colors.red,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: getPercentageHeight(1, context)),
                Wrap(
                  spacing: getPercentageWidth(2, context),
                  runSpacing: getPercentageHeight(1, context),
                  children: notAllowed
                      .where(
                          (item) => item.toString().toLowerCase() != 'fallback')
                      .map((item) {
                    return Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: getPercentageWidth(3, context),
                        vertical: getPercentageHeight(0.8, context),
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.red.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Text(
                        capitalizeFirstLetter(item),
                        style: textTheme.bodySmall?.copyWith(
                          color: Colors.red[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),

        // Food rules (guidelines/programDetails)
        if (foodRules.isNotEmpty) ...[
          SizedBox(height: getPercentageHeight(1.5, context)),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(getPercentageWidth(4, context)),
            decoration: BoxDecoration(
              color: isDarkMode
                  ? kLightGrey.withValues(alpha: 0.1)
                  : kLightGrey.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.checklist,
                      size: getIconScale(4, context),
                      color: kAccent,
                    ),
                    SizedBox(width: getPercentageWidth(2, context)),
                    Text(
                      'Food Rules',
                      style: textTheme.titleMedium?.copyWith(
                        color: kAccent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: getPercentageHeight(1, context)),
                ...foodRules.map((rule) {
                  return Padding(
                    padding: EdgeInsets.only(
                        bottom: getPercentageHeight(0.8, context)),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.circle,
                          size: getIconScale(2, context),
                          color: kAccent,
                        ),
                        SizedBox(width: getPercentageWidth(2, context)),
                        Expanded(
                          child: Text(
                            rule,
                            style: textTheme.bodyMedium?.copyWith(
                              color: isDarkMode ? kWhite : kDarkGrey,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPlateSpecItem(
    BuildContext context,
    TextTheme textTheme,
    bool isDarkMode,
    String label,
    String value,
    List<String> examples,
    IconData icon,
    Color color,
  ) {
    return Padding(
      padding: EdgeInsets.only(bottom: getPercentageHeight(1, context)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(getPercentageWidth(2.5, context)),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: color,
              size: getIconScale(4.5, context),
            ),
          ),
          SizedBox(width: getPercentageWidth(2, context)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (examples.isNotEmpty) ...[
                  Wrap(
                    spacing: getPercentageWidth(1.5, context),
                    runSpacing: getPercentageHeight(0.5, context),
                    children: examples.take(3).map((example) {
                      return Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: getPercentageWidth(2, context),
                          vertical: getPercentageHeight(0.4, context),
                        ),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: color.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          example,
                          style: textTheme.bodySmall?.copyWith(
                            color: color,
                            fontSize: getTextScale(2.2, context),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
                Builder(
                  builder: (context) {
                    // Look for "palmPercentage: X" and show just X (e.g. "1 palm", "2 fists")
                    final RegExp palmReg = RegExp(
                        r'palmPercentage\s*:\s*([^\,;]+)',
                        caseSensitive: false);
                    final match = palmReg.firstMatch(value);
                    String displayText;
                    if (match != null) {
                      displayText = match.group(1)?.trim() ?? value;
                    } else {
                      displayText = value;
                    }
                    return Text(
                      displayText,
                      style: textTheme.bodyMedium?.copyWith(
                        color: isDarkMode
                            ? kWhite.withValues(alpha: 0.7)
                            : kDarkGrey.withValues(alpha: 0.7),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Show palm method dialog
  void _showPalmMethodDialog(
      BuildContext context, TextTheme textTheme, bool isDarkMode) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: BoxConstraints(
            maxHeight: getPercentageHeight(80, context),
            maxWidth: getPercentageWidth(90, context),
          ),
          decoration: BoxDecoration(
            color: isDarkMode ? kDarkGrey : kWhite,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(getPercentageWidth(5, context)),
                decoration: BoxDecoration(
                  color: kAccent.withValues(alpha: 0.1),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'The Palm Method',
                        style: textTheme.titleLarge?.copyWith(
                          color: kAccent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Icon(
                        Icons.close,
                        color: kAccent,
                        size: getIconScale(5, context),
                      ),
                    ),
                  ],
                ),
              ),

              // Content
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(getPercentageWidth(5, context)),
                  child: Column(
                    children: [
                      Text(
                        'Use your palm to measure portions, Chef',
                        style: textTheme.bodyMedium?.copyWith(
                          color: isDarkMode ? kWhite : kDarkGrey,
                        ),
                      ),
                      SizedBox(height: getPercentageHeight(2, context)),
                      Center(
                        child: Image.asset(
                          'assets/images/background/palm4.png',
                          width: getPercentageWidth(60, context),
                          fit: BoxFit.contain,
                        ),
                      ),
                      SizedBox(height: getPercentageHeight(2, context)),
                      _buildPalmMethodDetail(
                        context,
                        textTheme,
                        isDarkMode,
                        '1 palm',
                        '3-4 oz protein',
                      ),
                      SizedBox(height: getPercentageHeight(1.5, context)),
                      _buildPalmMethodDetail(
                        context,
                        textTheme,
                        isDarkMode,
                        '1 fist',
                        '1 cup carbs',
                      ),
                      SizedBox(height: getPercentageHeight(1.5, context)),
                      _buildPalmMethodDetail(
                        context,
                        textTheme,
                        isDarkMode,
                        '2 cupped hands',
                        '2 cups vegetables',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPalmMethodDetail(
    BuildContext context,
    TextTheme textTheme,
    bool isDarkMode,
    String measurement,
    String equivalent,
  ) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(getPercentageWidth(4, context)),
      decoration: BoxDecoration(
        color: isDarkMode
            ? kLightGrey.withValues(alpha: 0.1)
            : kLightGrey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.pan_tool,
            color: kAccent,
            size: getIconScale(5, context),
          ),
          SizedBox(width: getPercentageWidth(3, context)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  measurement,
                  style: textTheme.titleSmall?.copyWith(
                    color: kAccent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: getPercentageHeight(0.3, context)),
                Text(
                  equivalent,
                  style: textTheme.bodyMedium?.copyWith(
                    color: isDarkMode
                        ? kWhite.withValues(alpha: 0.7)
                        : kDarkGrey.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrepListSection(
    BuildContext context,
    TextTheme textTheme,
    bool isDarkMode,
    List<Map<String, String>> prepListItems,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.checklist_rtl,
              size: getIconScale(5, context),
              color: kAccent,
            ),
            SizedBox(width: getPercentageWidth(2, context)),
            Text(
              'The Daily Prep List',
              style: textTheme.titleLarge?.copyWith(
                color: kAccent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        SizedBox(height: getPercentageHeight(1.5, context)),
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(getPercentageWidth(4, context)),
          decoration: BoxDecoration(
            color: isDarkMode
                ? kLightGrey.withValues(alpha: 0.1)
                : kLightGrey.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: prepListItems.map((item) {
              final iconName = item['icon'] ?? 'check_circle';
              IconData iconData;
              switch (iconName) {
                case 'fitness_center':
                  iconData = Icons.fitness_center;
                  break;
                case 'water_drop':
                  iconData = Icons.water_drop;
                  break;
                case 'self_improvement':
                  iconData = Icons.self_improvement;
                  break;
                case 'lightbulb':
                  iconData = Icons.lightbulb;
                  break;
                default:
                  iconData = Icons.check_circle;
              }

              return Padding(
                padding:
                    EdgeInsets.only(bottom: getPercentageHeight(1.5, context)),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      iconData,
                      size: getIconScale(4, context),
                      color: kAccent,
                    ),
                    SizedBox(width: getPercentageWidth(2, context)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${item['label']}:',
                            style: textTheme.titleSmall?.copyWith(
                              color: kAccent,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: getPercentageHeight(0.3, context)),
                          Text(
                            item['value'] ?? '',
                            style: textTheme.bodyMedium?.copyWith(
                              color: isDarkMode ? kWhite : kDarkGrey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
