import 'package:fit_hify/data_models/macro_data.dart';
import 'package:flutter/material.dart';

import '../constants.dart';
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
      height: 119,
      child: widget.demoAcceptedData.isEmpty
          ? noItemTastyWidget(
              'No ingredients available',
              '',
              context,
              true,
            )
          : ListView.builder(
              itemCount: widget.demoAcceptedData.length,
              padding: const EdgeInsets.only(right: 20),
              scrollDirection: Axis.horizontal,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(left: 20),
                  child: IngredientItem(
                    dataSrc: widget.demoAcceptedData[index],
                    radius: 45,
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
      title = dataSrc['title'] ?? '';
    } else {
      try {
        imagePath = dataSrc.mediaPaths.first ?? '';
        title = dataSrc.title ?? '';
      } catch (e) {
        imagePath = '';
        title = '';
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
                radius: radius,
              ),
              // Gradient overlay
              Container(
                width: radius * 2,
                height: radius * 2,
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
          const SizedBox(
            height: 5,
          ),
          Expanded(
            child: Text(
              textAlign: TextAlign.center,
              capitalizeFirstLetter(title),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 14,
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
