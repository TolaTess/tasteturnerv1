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
  final double radius;

  const IngredientListViewRecipe({
    super.key,
    required this.demoAcceptedData,
    required this.spin,
    required this.isEdit,
    required this.onRemoveItem,
    this.radius = 9,
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
      height: widget.radius < 9
          ? MediaQuery.of(context).size.height > 1100
              ? getPercentageHeight(12, context)
              : getPercentageHeight(10, context)
          : MediaQuery.of(context).size.height > 1100
              ? getPercentageHeight(18, context)
              : getPercentageHeight(13, context),
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
              padding: EdgeInsets.only(
                right: getPercentageWidth(2, context),
              ),
              scrollDirection: Axis.horizontal,
              itemBuilder: (context, index) {
                return Padding(
                  padding: EdgeInsets.only(
                      left: getPercentageWidth(2, context),
                      right: getPercentageWidth(2, context)),
                  child: IngredientItem(
                    dataSrc: widget.demoAcceptedData[index],
                    radius: widget.radius,
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
    this.radius = 35,
  });

  final dynamic dataSrc;
  final VoidCallback press;
  final bool isSelected;
  final double radius;

  @override
  Widget build(BuildContext context) {
    String imagePath = '';
    String title = '';
    if (dataSrc is Map) {
      imagePath = dataSrc['mediaPaths']?.first ?? '';
      title = (dataSrc['title'] ?? '').trim();
      if (title.isEmpty) {
        title = 'Unknown';
      }
    } else {
      try {
        imagePath = dataSrc.mediaPaths.isNotEmpty
            ? dataSrc.mediaPaths.first
            : 'placeholder';
        title = (dataSrc.title ?? '').trim();
        if (title.isEmpty) {
          title = 'Unknown';
        }
      } catch (e) {
        imagePath = '';
        title = 'Unknown';
      }
    }
    final isDarkMode = getThemeProvider(context).isDarkMode;
    return GestureDetector(
      onTap: press,
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              CircleAvatar(
                backgroundImage: imagePath.startsWith('http')
                    ? NetworkImage(imagePath) as ImageProvider
                    : AssetImage(getAssetImageForItem(imagePath)),
                radius: getPercentageWidth(radius, context),
              ),
              // Gradient overlay
              Container(
                width: getPercentageWidth(radius * 2, context),
                height: getPercentageWidth(radius * 2, context),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: isSelected
                        ? [
                            kAccent.withOpacity(0.3),
                            kAccent.withOpacity(0.7),
                          ]
                        : [
                            const Color(0xff343434).withOpacity(0.1),
                            const Color(0xff343434).withOpacity(0.3),
                          ],
                    stops: isSelected ? [0.2, 0.9] : [0.0, 0.8],
                  ),
                ),
              ),
            ],
          ),
          SizedBox(
            height: getPercentageHeight(0.5, context),
          ),
          Expanded(
            child: Text(
              textAlign: TextAlign.center,
              capitalizeFirstLetterAndSplitSpace(title),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: getPercentageWidth(radius / 3, context),
                  fontWeight: FontWeight.w600,
                  color: isSelected
                      ? isDarkMode
                          ? kWhite
                          : kAccent
                      : isDarkMode
                          ? kWhite
                          : kDarkGrey),
            ),
          )
        ],
      ),
    );
  }
}
