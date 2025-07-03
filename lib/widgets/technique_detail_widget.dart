import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tasteturner/screens/recipes_list_category_screen.dart';
import '../constants.dart';
import '../helper/utils.dart';
import '../service/macro_manager.dart';
import 'ingredient_features.dart';

class TechniqueDetailWidget extends StatefulWidget {
  final Map<String, dynamic> technique;

  const TechniqueDetailWidget({
    super.key,
    required this.technique,
  });

  @override
  State<TechniqueDetailWidget> createState() => _TechniqueDetailWidgetState();
}

class _TechniqueDetailWidgetState extends State<TechniqueDetailWidget> {
  bool _showFullDescription = false;

  final MacroManager _macroManager = Get.find<MacroManager>();

  @override
  void initState() {
    super.initState();
    _macroManager.fetchIngredients();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    final textTheme = Theme.of(context).textTheme;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: getPercentageHeight(80, context),
          maxWidth: getPercentageWidth(90, context),
        ),
        decoration: BoxDecoration(
          color: isDarkMode ? kDarkGrey : kWhite,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with technique name and close button
            _buildHeader(context, textTheme, isDarkMode),

            // Scrollable content
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(getPercentageWidth(5, context)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Description
                    if (widget.technique['description'] != null)
                      _buildDescriptionSection(context, textTheme, isDarkMode,
                          widget.technique['name']),

                    SizedBox(height: getPercentageHeight(2, context)),

                    // Equipment Section
                    if (widget.technique['equipment'] != null)
                      _buildEquipmentSection(context, textTheme, isDarkMode),

                    SizedBox(height: getPercentageHeight(2, context)),

                    // Best For Section
                    if (widget.technique['bestFor'] != null)
                      _buildBestForSection(context, textTheme, isDarkMode,
                          widget.technique['name']),

                    SizedBox(height: getPercentageHeight(1.5, context)),
                    const Divider(
                      color: kAccent,
                      thickness: 1,
                    ),
                    SizedBox(height: getPercentageHeight(1, context)),

                    // Heat Type Section
                    if (widget.technique['heatType'] != null)
                      _buildHeatTypeSection(context, textTheme, isDarkMode),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
      BuildContext context, TextTheme textTheme, bool isDarkMode) {
    return Container(
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
              capitalizeFirstLetter(
                  widget.technique['name'] ?? 'Cooking Technique'),
              style: textTheme.displayMedium?.copyWith(
                fontSize: getTextScale(5.5, context),
                color: kAccent,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: EdgeInsets.all(getPercentageWidth(2, context)),
              decoration: BoxDecoration(
                color: isDarkMode ? kDarkGrey.withValues(alpha: 0.5) : kWhite,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.close,
                color: kAccent,
                size: getIconScale(5, context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionSection(BuildContext context, TextTheme textTheme,
      bool isDarkMode, String searchIngredient) {
    final description =
        widget.technique['description'] ?? 'No description available';
    final firstSentenceEnd = description.indexOf('.');
    final displayText = _showFullDescription
        ? description
        : (firstSentenceEnd > 0
            ? description.substring(0, firstSentenceEnd + 1)
            : description);
    final hasMoreText =
        firstSentenceEnd > 0 && firstSentenceEnd < description.length - 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Description',
              style: textTheme.titleMedium?.copyWith(
                color: kAccent,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(width: getPercentageWidth(2, context)),
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => RecipeListCategory(
                      index: 0,
                      searchIngredient: searchIngredient,
                      isFilter: true,
                      screen: 'technique',
                    ),
                  ),
                );
              },
              child: Text(
                '(see meals)',
                style: textTheme.bodySmall?.copyWith(
                  color: kAccent,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: getPercentageHeight(1, context)),
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
              Text(
                displayText,
                style: textTheme.bodyMedium?.copyWith(
                  color: isDarkMode ? kWhite : kDarkGrey,
                  height: 1.5,
                ),
              ),
              if (hasMoreText)
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _showFullDescription = !_showFullDescription;
                    });
                  },
                  child: Padding(
                    padding:
                        EdgeInsets.only(top: getPercentageHeight(1, context)),
                    child: Text(
                      _showFullDescription ? 'See less' : 'See more',
                      style: textTheme.bodyMedium?.copyWith(
                        color: kAccent,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEquipmentSection(
      BuildContext context, TextTheme textTheme, bool isDarkMode) {
    final equipment = widget.technique['equipment'];
    if (equipment == null) return const SizedBox.shrink();

    List<String> equipmentList = [];
    if (equipment is String) {
      equipmentList = equipment.split(',').map((e) => e.trim()).toList();
    } else if (equipment is List) {
      equipmentList = equipment.map((e) => e.toString()).toList();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.kitchen, color: kAccent, size: getIconScale(5, context)),
            SizedBox(width: getPercentageWidth(2, context)),
            Text(
              'Equipment Needed',
              style: textTheme.titleMedium?.copyWith(
                color: kAccent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        SizedBox(height: getPercentageHeight(1, context)),
        Wrap(
          spacing: getPercentageWidth(2, context),
          runSpacing: getPercentageHeight(1, context),
          children: equipmentList
              .map((item) =>
                  _buildChip(item, context, textTheme, isDarkMode, Colors.blue))
              .toList(),
        ),
      ],
    );
  }

  Widget _buildBestForSection(BuildContext context, TextTheme textTheme,
      bool isDarkMode, String searchIngredient) {
    final bestFor = widget.technique['bestFor'];
    if (bestFor == null) return const SizedBox.shrink();

    List<String> bestForList = [];
    if (bestFor is String) {
      bestForList = bestFor.split(',').map((e) => e.trim()).toList();
    } else if (bestFor is List) {
      bestForList = bestFor.map((e) => e.toString()).toList();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.restaurant_menu,
                color: kAccent, size: getIconScale(5, context)),
            SizedBox(width: getPercentageWidth(2, context)),
            Row(
              children: [
                Text(
                  'Best For',
                  style: textTheme.titleMedium?.copyWith(
                    color: kAccent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(width: getPercentageWidth(2, context)),
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => IngredientFeatures(
                          items: _macroManager.ingredient,
                        ),
                      ),
                    );
                  },
                  child: Text(
                    '(see ingredients)',
                    style: textTheme.bodySmall?.copyWith(
                      color: kAccent,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        SizedBox(height: getPercentageHeight(1, context)),
        Wrap(
          spacing: getPercentageWidth(2, context),
          runSpacing: getPercentageHeight(1, context),
          children: bestForList
              .map((item) => _buildChip(
                  item, context, textTheme, isDarkMode, Colors.green))
              .toList(),
        ),
      ],
    );
  }

  Widget _buildHeatTypeSection(
      BuildContext context, TextTheme textTheme, bool isDarkMode) {
    final heatType = widget.technique['heatType'];
    final heatTypeList = heatType.split('/').map((e) => e.trim()).toList();
    if (heatType == null) return const SizedBox.shrink();

    IconData heatIcon;
    Color heatColor;

    if (heatTypeList[0].toLowerCase().contains('dry')) {
      heatIcon = Icons.device_thermostat;
      heatColor = Colors.orange;
    } else {
      heatIcon = Icons.device_thermostat;
      heatColor = Colors.lightBlueAccent;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(heatIcon, color: heatColor, size: getIconScale(5, context)),
            SizedBox(width: getPercentageWidth(2, context)),
            Text(
              '${capitalizeFirstLetter(heatTypeList[0])} Type',
              style: textTheme.titleMedium?.copyWith(
                color: heatColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        SizedBox(height: getPercentageHeight(1, context)),
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: getPercentageWidth(4, context),
            vertical: getPercentageHeight(1, context),
          ),
          decoration: BoxDecoration(
            color: heatColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: heatColor.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(heatIcon, color: heatColor, size: getIconScale(4, context)),
              SizedBox(width: getPercentageWidth(1, context)),
              Text(
                capitalizeFirstLetter(heatTypeList[1]),
                style: textTheme.bodyMedium?.copyWith(
                  color: heatColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChip(String text, BuildContext context, TextTheme textTheme,
      bool isDarkMode, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: getPercentageWidth(3, context),
        vertical: getPercentageHeight(0.5, context),
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        capitalizeFirstLetter(text),
        style: textTheme.bodySmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
