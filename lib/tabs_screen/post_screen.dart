import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../constants.dart';
import '../detail_screen/post_detail_screen.dart';
import '../helper/utils.dart';
import '../themes/theme_provider.dart';
import '../widgets/premium_widget.dart';
import '../widgets/optimized_image.dart';

import 'dart:math';

class PostHomeScreen extends StatelessWidget {
  final ThemeProvider themeProvider;
  const PostHomeScreen({super.key, required this.themeProvider});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Obx(() {
        if (postController.posts.isEmpty) {
          return noItemTastyWidget(
            'No posts available',
            'Share your favorite meals and recipes',
            context,
            false,
          );
        }

        // ✅ Randomly insert ads into the post list
        final List<dynamic> gridItems = [];
        final int totalPosts = postController.posts.length;
        final int adCount =
            max(1, (totalPosts / 7).floor()); // ✅ Adjust ad frequency
        final Set<int> adIndices = {}; // ✅ Track ad positions

        // ✅ Generate unique random indices for ad placement
        final random = Random();
        while (adIndices.length < adCount) {
          int randomIndex = random.nextInt(totalPosts);
          adIndices.add(randomIndex);
        }

        // ✅ Insert posts and ads at random positions
        for (int i = 0; i < totalPosts; i++) {
          gridItems.add(postController.posts[i]);
          if (adIndices.contains(i)) {
            gridItems.add("premium_ad"); // ✅ Insert ad at random index
          }
        }

        return Padding(
          padding: const EdgeInsets.all(8.0),
          child: MasonryGridView.count(
            crossAxisCount: 2,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            itemCount: gridItems.length,
            itemBuilder: (context, index) {
              final item = gridItems[index];

              // ✅ Show Premium Ad Section at Random Positions
              if (item == "premium_ad") {
                return _buildPremiumAdSection();
              }

              final post = item;
              final mediaPaths = post.mediaPaths;

              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PostDetailScreen(
                        post: post,
                      ),
                    ),
                  );
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: Stack(
                    children: [
                      OptimizedImage(
                        imageUrl: mediaPaths.isNotEmpty
                            ? mediaPaths.first
                            : extPlaceholderImage,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: 200,
                      ),
                      if (mediaPaths.length > 1)
                        const Positioned(
                          top: 8,
                          right: 8,
                          child: Icon(
                            Icons.content_copy,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      }),
    );
  }

  /// ✅ Build Premium Ad Section
  Widget _buildPremiumAdSection() {
    final bool isPremium = userService.currentUser?.isPremium ??
        false;

    if (isPremium) {
      return const SizedBox.shrink(); // Don't show ads to premium users
    }

    return PremiumSection(
      isPremium: isPremium,
      titleOne: joinChallenges,
      titleTwo: premium,
      isDiv: false,
      isPost: true,
    );
  }
}
