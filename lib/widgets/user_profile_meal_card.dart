import 'package:flutter/material.dart';
import '../constants.dart';
import '../data_models/meal_model.dart';
import '../detail_screen/recipe_detail.dart';
import '../helper/utils.dart';
import '../widgets/optimized_image.dart';

/// Meal card widget for user profile screen
/// Displays a meal with image, gradient overlay, and title
class UserProfileMealCard extends StatelessWidget {
  final Meal meal;
  final double height;
  final double width;

  const UserProfileMealCard({
    super.key,
    required this.meal,
    this.height = 33.0,
    this.width = 33.0,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final mediaPath = meal.mediaPaths.isNotEmpty
        ? meal.mediaPaths.first
        : extPlaceholderImage;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => RecipeDetailScreen(
              mealData: meal,
            ),
          ),
        );
      },
      child: Stack(
        children: [
          Container(
            height: getPercentageHeight(height, context),
            width: getPercentageWidth(width, context),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: mediaPath.isNotEmpty && mediaPath.contains('http')
                  ? OptimizedImage(
                      imageUrl: mediaPath,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      borderRadius: BorderRadius.circular(8),
                    )
                  : Image.asset(
                      getAssetImageForItem(meal.category ?? 'default'),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          Image.asset(
                        extPlaceholderImage,
                        fit: BoxFit.cover,
                      ),
                    ),
            ),
          ),
          // Gradient overlay for better text visibility
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.6),
                  ],
                ),
              ),
            ),
          ),
          // Meal title overlay
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Padding(
              padding: EdgeInsets.all(getPercentageWidth(1.5, context)),
              child: Text(
                meal.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodySmall?.copyWith(
                  color: kWhite,
                  fontWeight: FontWeight.w600,
                  fontSize: getTextScale(2.8, context),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

