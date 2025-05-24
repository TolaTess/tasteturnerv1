import 'package:flutter/material.dart';
import '../constants.dart';
import '../data_models/meal_model.dart';
import '../data_models/post_model.dart';
import '../data_models/profilescreen_data.dart';
import '../detail_screen/challenge_detail_screen.dart';
import '../detail_screen/recipe_detail.dart';
import '../helper/utils.dart';
import '../pages/recipe_card_flex.dart';

class SearchContentGrid extends StatefulWidget {
  const SearchContentGrid({
    super.key,
    this.screenLength = 9,
    required this.listType,
    this.postId = '',
    this.selectedCategory = '',
  });

  final int screenLength;
  final String listType;
  final String postId;
  final String selectedCategory;

  @override
  _SearchContentGridState createState() => _SearchContentGridState();
}

class _SearchContentGridState extends State<SearchContentGrid> {
  bool showAll = false;
  List<Map<String, dynamic>> searchContentDatas = [];

  @override
  void initState() {
    super.initState();
    _fetchContent();
  }

  @override
  void didUpdateWidget(SearchContentGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Refetch content when category changes
    if (oldWidget.selectedCategory != widget.selectedCategory) {
      _fetchContent();
    }
  }

  Future<void> _fetchContent() async {
    try {
      List<Map<String, dynamic>> fetchedData = [];

      List<Map<String, dynamic>> snapshot;

      if (widget.listType == "meals") {
        snapshot = await firestore
            .collection('meals')
            .get()
            .then((value) => value.docs.map((doc) {
                  final data = doc.data();
                  data['id'] = doc.id;
                  return data;
                }).toList());
      } else if (widget.listType == "post" ||
          widget.listType == 'battle_post') {
        // Fetch both posts and battle posts ordered by createdAt
        final postSnapshot = await firestore
            .collection('posts')
            .orderBy('createdAt', descending: true)
            .get();

        snapshot = postSnapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return data;
        }).where((data) => data['battleId'] != 'private').toList();
      } else {
        setState(() {
          searchContentDatas = [];
        });
        return;
      }

      for (var doc in snapshot) {
        final data = doc;

        final postId = data['id'] as String?;
        final postCategory = data['category'] as String?;

        // If category is 'all' or no category selected, show all posts
        if (widget.selectedCategory.toLowerCase() == 'all' ||
            widget.selectedCategory.toLowerCase() == 'general' ||
            widget.selectedCategory.isEmpty) {
          if (postId != null && postId.isNotEmpty) {
            fetchedData.add(data);
          }
          continue;
        }

        if (postCategory?.toLowerCase() ==
                widget.selectedCategory.toLowerCase() &&
            postId != null &&
            postId.isNotEmpty) {
          fetchedData.add(data);
        }
      }

      if (widget.postId.isNotEmpty) {
        fetchedData.removeWhere((item) => item['id'] == widget.postId);
      }

      if (mounted) {
        setState(() {
          searchContentDatas = fetchedData;
        });
      }
    } catch (e) {
      print('Error fetching content: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final itemCount = showAll
        ? searchContentDatas.length
        : (searchContentDatas.length > widget.screenLength
            ? widget.screenLength
            : searchContentDatas.length);

    return Column(
      children: [
        if (searchContentDatas.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: noItemTastyWidget("No posts yet.", "", context, false, ''),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              int crossAxisCount =
                  (constraints.maxWidth / 120).floor().clamp(3, 6);
              return GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  mainAxisSpacing: 1,
                  crossAxisSpacing: 1,
                ),
                padding: const EdgeInsets.only(
                  top: 1,
                  bottom: 1,
                ),
                itemCount: itemCount,
                itemBuilder: (BuildContext ctx, index) {
                  final data = searchContentDatas[index];
                  return SearchContent(
                    dataSrc: data,
                    press: () => Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChallengeDetailScreen(
                          screen: widget.listType,
                          dataSrc: data,
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        if (searchContentDatas.isNotEmpty &&
            searchContentDatas.length > widget.screenLength)
          GestureDetector(
            onTap: () {
              setState(() {
                showAll = !showAll;
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 1.0),
              child: Icon(
                showAll ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                size: 36,
                color: Colors.grey,
              ),
            ),
          ),
      ],
    );
  }
}

//Profile Recipe List
class ProfileRecipeList extends StatefulWidget {
  const ProfileRecipeList({
    super.key,
  });

  @override
  State<ProfileRecipeList> createState() => _ProfileRecipeListState();
}

class _ProfileRecipeListState extends State<ProfileRecipeList> {
  List<Meal> demoMealsPlanData = [];

  @override
  void initState() {
    demoMealsPlanData = mealManager.meals;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          //generate user's recipe list
          ...List.generate(
            demoMealsPlanData.length,
            (index) => Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: RecipeCardFlex(
                recipe: demoMealsPlanData[index],
                press: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => RecipeDetailScreen(
                      mealData: demoMealsPlanData[
                          index], // Pass the selected meal data
                    ),
                  ),
                ),
                height: 200,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

//Story Slider Widget
class StorySlider extends StatelessWidget {
  const StorySlider({
    super.key,
    required this.dataSrc,
    required this.press,
    this.mHeight = 80,
    this.mWidth = 80,
  });

  final BadgeAchievementData dataSrc;
  final VoidCallback press;
  final double mHeight, mWidth;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: press,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Background Image
                  Opacity(
                    opacity: kMidOpacity,
                    child: CircleAvatar(
                      radius: mWidth / 2,
                      backgroundImage: const AssetImage(
                        'assets/images/vegetable_stamp.jpg',
                      ),
                    ),
                  ),

                  // Title Text on top of the image
                  SizedBox(
                    width: mWidth,
                    child: Text(
                      dataSrc.title,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
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

class SearchContent extends StatelessWidget {
  const SearchContent({
    super.key,
    required this.dataSrc,
    required this.press,
  });

  final Map<String, dynamic> dataSrc; // ✅ Data source map
  final VoidCallback press;

  @override
  Widget build(BuildContext context) {
    final List<dynamic>? mediaPaths = dataSrc['mediaPaths'] as List<dynamic>?;
    final String? mediaType = dataSrc['mediaType'] as String?;

    final String? mediaPath = mediaPaths != null && mediaPaths.isNotEmpty
        ? mediaPaths.first as String
        : extPlaceholderImage;

    return GestureDetector(
      onTap: press,
      child: Stack(
        children: [
          // ✅ Image Display (with loading & error handling)
          mediaPath != null && mediaPath.isNotEmpty
              ? Image.network(
                  mediaPath,
                  height: 140,
                  width: 140,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(
                        child: CircularProgressIndicator(
                      color: kAccent,
                    ));
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Image.asset(
                      intPlaceholderImage,
                      height: 140,
                      width: 140,
                      fit: BoxFit.cover,
                    );
                  },
                )
              : Image.asset(
                  intPlaceholderImage,
                  height: 140,
                  width: 140,
                  fit: BoxFit.cover,
                ),

          // ✅ Multiple Images Overlay Icon
          if (mediaPaths != null && mediaPaths.length > 1)
            const Positioned(
              top: 4,
              right: 4,
              child: Icon(
                Icons.content_copy,
                color: Colors.white,
                size: 20,
              ),
            ),
        ],
      ),
    );
  }
}

class SearchContentPost extends StatelessWidget {
  const SearchContentPost({
    super.key,
    required this.dataSrc,
    required this.press,
  });

  final Post dataSrc; // Assuming Post model
  final VoidCallback press;

  @override
  Widget build(BuildContext context) {
    final List<String> mediaPaths = dataSrc.mediaPaths;
    final String mediaPath =
        mediaPaths.isNotEmpty ? mediaPaths.first : extPlaceholderImage;

    return GestureDetector(
      onTap: press,
      child: Stack(
        children: [
          // Display image or fallback
          mediaPath.isNotEmpty
              ? Image.network(
                  mediaPath,
                  height: 140,
                  width: 140,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(
                        child: CircularProgressIndicator(
                      color: kAccent,
                    ));
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Image.asset(
                      intPlaceholderImage,
                      height: 140,
                      width: 140,
                      fit: BoxFit.cover,
                    );
                  },
                )
              : Image.asset(
                  intPlaceholderImage,
                  height: 140,
                  width: 140,
                  fit: BoxFit.cover,
                ),

          // ✅ Multiple Images Icon
          if (mediaPaths.length > 1)
            const Positioned(
              top: 4,
              right: 4,
              child: Icon(
                Icons.content_copy,
                color: Colors.white,
                size: 20,
              ),
            ),
        ],
      ),
    );
  }
}
