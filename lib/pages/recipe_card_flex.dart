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
  bool _isSelected = false;
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

  Future<void> _toggleSelection() async {
    setState(() {
      _isSelected = !_isSelected;
    });
  }

  @override
  Widget build(BuildContext context) {

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
                  mediaPath != null && mediaPath.isNotEmpty && mediaPath.startsWith('http')
                      ? Image.network(
                          mediaPath,
                          width: double.infinity,
                          height: widget.height,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Image.asset(
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
                                kAccent.withOpacity(0.3),
                                kAccent.withOpacity(0.7),
                              ]
                            : [
                                const Color(0xff343434).withOpacity(0.1),
                                const Color(0xff343434).withOpacity(0.5),
                              ],
                        stops: widget.isSelected ? [0.2, 0.9] : [0.0, 0.8],
                      ),
                    ),
                  ),

                  // Favorite button
                  Positioned(
                    left: 10,
                    top: 10,
                    child: GestureDetector(
                      onTap: widget.enableSelection ? null : _toggleFavorite,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            _isFavorited
                                ? Icons.favorite
                                : Icons.favorite_border,
                            color: kAccent,
                            size: 19,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Recipe details (title, prep time, serve quantity)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Recipe title
                        Text(
                          widget.recipe.title,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 2,
                        ),
                        const SizedBox(height: 7),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            //Serves quantity
                            Text(
                              "${widget.recipe.serveQty} servings",
                              style: const TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Selection highlight
                  if (widget.enableSelection && widget.isSelected)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.check_circle,
                            color: kAccent,
                            size: 50,
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
