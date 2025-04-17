import 'dart:ui';

import 'package:flutter/material.dart';

import '../constants.dart';
import '../helper/utils.dart';
import '../screens/friend_screen.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/helper_widget.dart';
import '../widgets/icon_widget.dart';

class ChallengeDetailScreen extends StatefulWidget {
  final Map<String, dynamic> dataSrc;
  final String screen;

  const ChallengeDetailScreen({
    super.key,
    required this.dataSrc,
    this.screen = 'battle_post',
  });

  @override
  State<ChallengeDetailScreen> createState() => _ChallengeDetailScreenState();
}

class _ChallengeDetailScreenState extends State<ChallengeDetailScreen> {
  bool _isFavorited = false;
  List<String> extractedItems = [];
  @override
  void initState() {
    super.initState();
    extractedItems =
        extractSlashedItems(widget.dataSrc['title'] ?? widget.dataSrc['name']);
    _loadFavoriteStatus();
  }

  Future<void> _loadFavoriteStatus() async {
    final isFavorite = await firebaseService.isRecipeFavorite(
        userService.userId, widget.dataSrc['id'] ?? extractedItems.first);
    setState(() {
      _isFavorited = isFavorite;
    });
  }

  Future<void> _toggleFavorite() async {
    await firebaseService.toggleFavorite(
        userService.userId, widget.dataSrc['id'] ?? extractedItems.first);
    setState(() {
      _isFavorited = !_isFavorited;
    });
  }

  String getTitle() {
    if (extractedItems.isNotEmpty &&
        extractedItems.length > 1 &&
        extractedItems[1].isNotEmpty) {
      return extractedItems[1];
    }

    if (widget.screen == 'battle_post') {
      return widget.dataSrc['name']?.toString().isNotEmpty == true
          ? widget.dataSrc['name'].toString()
          : 'Food Battle';
    } else {
      return widget.dataSrc['title']?.toString().isNotEmpty == true
          ? widget.dataSrc['title'].toString()
          : 'Group Challenge';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              // Custom App Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    // Back Button
                    InkWell(
                      onTap: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => BottomNavSec(
                              selectedIndex: 3,
                              foodScreenTabIndex:
                                  widget.screen == 'battle_post' ? 0 : 1,
                            ),
                          ),
                        );
                      },
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                        ),
                        child: const IconCircleButton(
                          isRemoveContainer: true,
                        ),
                      ),
                    ),

                    const Spacer(),

                    Text(
                      capitalizeFirstLetter(getTitle()),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    const Spacer(),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Challenge Thumbnail
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    double sideLength = constraints.maxWidth; // Make it square

                    final List<String> imageUrls =
                        List<String>.from(widget.dataSrc['mediaPaths'] ?? []);
                    final String? fallbackImage =
                        widget.dataSrc['image'] as String?;

                    // Use fallback image if no array is provided
                    if (imageUrls.isEmpty && fallbackImage != null) {
                      imageUrls.add(fallbackImage);
                    }

                    if (imageUrls.isEmpty) {
                      imageUrls.add(intPlaceholderImage);
                    }

                    return Container(
                      width: sideLength,
                      height: sideLength,
                      clipBehavior: Clip.hardEdge,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: imageUrls.length == 1
                          ? Image.network(
                              imageUrls.first,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Image.asset(
                                intPlaceholderImage,
                                fit: BoxFit.cover,
                              ),
                            )
                          : PageView.builder(
                              itemCount: imageUrls.length,
                              itemBuilder: (context, index) {
                                final imageUrl = imageUrls[index];
                                return Image.network(
                                  imageUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Image.asset(
                                    intPlaceholderImage,
                                    fit: BoxFit.cover,
                                  ),
                                );
                              },
                            ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 24),

              // Favorite, Download Buttons
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(50),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: kAccent.withOpacity(0.1),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(width: 36),

                            // Share Icon (Optional - Add functionality if needed)
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => FriendScreen(
                                      dataSrc: widget.dataSrc,
                                      screen: widget.screen,
                                    ),
                                  ),
                                );
                              },
                              child: const Icon(Icons.share),
                            ),

                            const SizedBox(width: 36),

                            // Favorite Icon with Toggle
                            GestureDetector(
                              onTap: _toggleFavorite,
                              child: Icon(
                                _isFavorited
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                color: _isFavorited ? kRed : null,
                              ),
                            ),

                            const SizedBox(width: 36),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: SearchContentGrid(
                  postId: widget.dataSrc['id'] ?? extractedItems.first,
                  listType: widget.screen == 'group_cha'
                      ? 'group_cha'
                      : 'battle_post',
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
