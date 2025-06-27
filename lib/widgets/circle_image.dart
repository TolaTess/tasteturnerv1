import 'package:flutter/material.dart';

import '../constants.dart';
import '../data_models/macro_data.dart';
import '../detail_screen/ingredientdetails_screen.dart';
import '../helper/utils.dart';

class IngredientListViewRecipe extends StatefulWidget {
  final List<MacroData> demoAcceptedData;
  final bool spin;
  final bool isEdit;
  final Function(int) onRemoveItem;

  const IngredientListViewRecipe({
    super.key,
    required this.demoAcceptedData,
    required this.spin,
    required this.isEdit,
    required this.onRemoveItem,
  });

  @override
  State<IngredientListViewRecipe> createState() =>
      _IngredientListViewRecipeState();
}

class _IngredientListViewRecipeState extends State<IngredientListViewRecipe> {
  bool showAll = false;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height > 1100
          ? getPercentageHeight(17, context)
          : getPercentageHeight(14, context),
      child: widget.demoAcceptedData.isEmpty
          ? noItemTastyWidget(
              'No ingredients available',
              '',
              context,
              false,
              '',
            )
          : ListView.builder(
              itemCount: widget.demoAcceptedData.length,
              padding: EdgeInsets.symmetric(
                horizontal: getPercentageWidth(2, context),
              ),
              scrollDirection: Axis.horizontal,
              itemBuilder: (context, index) {
                return Padding(
                  padding: EdgeInsets.only(
                      left: getPercentageWidth(4, context),
                      right: getPercentageWidth(2, context)),
                  child: IngredientItem(
                    dataSrc: widget.demoAcceptedData[index],
                    press: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => IngredientDetailsScreen(
                            item: widget.demoAcceptedData[index],
                            ingredientItems: widget.demoAcceptedData,
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}

//ingredients category
class IngredientItem extends StatelessWidget {
  const IngredientItem({
    super.key,
    required this.dataSrc,
    required this.press,
    this.isSelected = false,
  });

  final dynamic dataSrc;
  final VoidCallback press;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    String title = '';
    if (dataSrc is Map) {
      title = (dataSrc['title'] ?? '').trim();
      if (title.isEmpty) {
        title = 'Unknown';
      }
    } else {
      try {
        title = (dataSrc.title ?? '').trim();
        if (title.isEmpty) {
          title = 'Unknown';
        }
      } catch (e) {
        title = 'Unknown';
      }
    }

    final isDarkMode = getThemeProvider(context).isDarkMode;
    final firstWord = capitalizeFirstLetter(title);

    return GestureDetector(
      onTap: press,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Base circle with gradient
          Stack(
            alignment: Alignment.center,
            children: [
              ClipOval(
                child: Container(
                  width: getResponsiveBoxSize(context, 77, 77),
                  height: getResponsiveBoxSize(context, 77, 77),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        kAccentLight.withOpacity(0.1),
                        kAccentLight.withOpacity(0.3),
                      ],
                    ),
                    image: const DecorationImage(
                      image: AssetImage('assets/images/placeholder.jpg'),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ],
          ),
          // Text centered in circle
          Positioned.fill(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(getPercentageWidth(1, context)),
                child: Transform.rotate(
                  angle:
                      -0.3, // Negative angle for slight counter-clockwise rotation
                  child: Text(
                    firstWord,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.displayMedium?.copyWith(
                          color: isSelected ? kAccent : kWhite,
                          fontSize: getPercentageWidth(3, context),
                        ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
