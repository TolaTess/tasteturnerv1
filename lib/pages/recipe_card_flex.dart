import 'package:flutter/material.dart';
import '../constants.dart';
import '../data_models/meal_model.dart';
import '../helper/utils.dart';

class RecipeCardFlex extends StatefulWidget {
  const RecipeCardFlex({
    super.key,
    required this.recipe,
    required this.press,
    required this.height,
    this.isSelected = false,
    this.enableSelection = false,
    this.onToggleSelection,
  });

  final Meal recipe;
  final GestureTapCallback press;
  final double height;
  final bool isSelected;
  final bool enableSelection;
  final VoidCallback? onToggleSelection;

  @override
  State<RecipeCardFlex> createState() => _RecipeCardFlexState();
}

class _RecipeCardFlexState extends State<RecipeCardFlex> {
  bool _isFavorited = false;
  final String? _userId = userService.userId;

  @override
  void initState() {
    super.initState();
    _loadFavoriteStatus();
  }

  Future<void> _loadFavoriteStatus() async {
    final isFavorite =
        await firebaseService.isRecipeFavorite(_userId, widget.recipe.mealId);
    setState(() {
      _isFavorited = isFavorite;
    });
  }

  Future<void> _toggleFavorite() async {
    await firebaseService.toggleFavorite(_userId, widget.recipe.mealId);
    setState(() {
      _isFavorited = !_isFavorited;
    });
  }

  //todo: add a loading state
  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final String? mediaPath = widget.recipe.mediaPaths.isNotEmpty
        ? widget.recipe.mediaPaths.first
        : extPlaceholderImage;

    return GestureDetector(
      onTap: widget.enableSelection
          ? widget.onToggleSelection
          : widget.press, // Handle selection toggle or regular tap
      child: Stack(
        children: [
          // Recipe card with image and content
          SizedBox(
            width: double.infinity,
            height: widget.height,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                children: [
                  // Recipe image
                  mediaPath != null &&
                          mediaPath.isNotEmpty &&
                          mediaPath.startsWith('http')
                      ? buildOptimizedNetworkImage(
                          imageUrl: mediaPath,
                          width: double.infinity,
                          height: widget.height,
                          fit: BoxFit.cover,
                          borderRadius: BorderRadius.circular(20),
                          errorWidget: Image.asset(
                            getAssetImageForItem(
                                widget.recipe.category ?? 'default'),
                            width: double.infinity,
                            height: widget.height,
                            fit: BoxFit.cover,
                          ),
                        )
                      : Image.asset(
                          getAssetImageForItem(
                              widget.recipe.category ?? 'default'),
                          width: double.infinity,
                          height: widget.height,
                          fit: BoxFit.cover,
                        ),

                  // Gradient overlay
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: widget.isSelected
                            ? [
                                kAccent.withValues(alpha: 0.3),
                                kAccent.withValues(alpha: 0.7),
                              ]
                            : [
                                const Color(0xff343434).withValues(alpha: 0.1),
                                const Color(0xff343434).withValues(alpha: 0.5),
                              ],
                        stops: widget.isSelected
                            ? [0.2, 0.9]
                            : [0.0, 0.8], //todo: make this dynamic
                      ),
                    ),
                  ),

                  // Favorite button
                  Positioned(
                    left: getPercentageWidth(1, context),
                    top: getPercentageWidth(1, context),
                    child: GestureDetector(
                      onTap: widget.enableSelection ? null : _toggleFavorite,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Padding(
                          padding:
                              EdgeInsets.all(getPercentageWidth(0.4, context)),
                          child: Icon(
                            _isFavorited
                                ? Icons.favorite
                                : Icons.favorite_border,
                            color: kAccent,
                            size: MediaQuery.of(context).size.height > 700
                                ? getPercentageWidth(5, context)
                                : getPercentageWidth(5.5, context),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Recipe details (title, prep time, serve quantity)
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: getPercentageWidth(1, context),
                      vertical: getPercentageHeight(0.3, context),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Recipe title
                        Text(
                          widget.recipe.title,
                          style: textTheme.bodyLarge?.copyWith(
                              fontSize: getPercentageWidth(4, context),
                              fontWeight: FontWeight.w500,
                              color: kWhite),
                          maxLines: 3,
                        ),
                        SizedBox(height: getPercentageHeight(1, context)),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            //Serves quantity
                            Text(
                              "${widget.recipe.calories} kcal",
                              style: textTheme.bodyMedium?.copyWith(
                                  fontSize: getPercentageWidth(3, context),
                                  color: kWhite),
                            ),
                            Text(
                              "${widget.recipe.serveQty} servings",
                              style: textTheme.bodyMedium?.copyWith(
                                  fontSize: getPercentageWidth(3, context),
                                  color: kWhite),
                            ),
                          ],
                        ),
                        SizedBox(height: getPercentageHeight(1, context)),
                      ],
                    ),
                  ),

                  // Selection highlight
                  if (widget.enableSelection && widget.isSelected)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Center(
                          child: Icon(
                            Icons.check_circle,
                            color: kAccent,
                            size: getIconScale(5, context),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
