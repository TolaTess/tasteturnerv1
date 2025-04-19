import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../data_models/meal_model.dart';
import '../data_models/user_data_model.dart';
import '../helper/utils.dart';
import '../bottom_nav/profile_screen.dart';
import '../widgets/secondary_button.dart';
import '../constants.dart';
import '../widgets/follow_button.dart';
import '../screens/createrecipe_screen.dart';
import '../screens/user_profile_screen.dart';

class RecipeDetailScreen extends StatefulWidget {
  const RecipeDetailScreen({super.key, required this.mealData});

  final Meal mealData;

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  @override
  void initState() {
    super.initState();
    friendController.updateUserData(widget.mealData.userId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Obx(() {
        final mealUser = friendController.userProfileData.value;

        return SafeArea(
          child: CustomScrollView(
            slivers: [
              // Custom app bar > recipe image, back button, more action button, and drawer
              SlvAppBar(
                meal: widget.mealData,
              ),

              // Recipe title, time to cook, serves, rating, and recipe description
              RecipeTittle(
                meal: widget.mealData,
              ),

              // Chef profile: avatar, name, location, and follow button
              RecipeProfile(
                profileId: widget.mealData.userId,
                mealUser: mealUser,
              ),

              // Nutrition facts (sliver) grid view
              NutritionFacts(
                meal: widget.mealData,
              ),

              // Ingredients title
              IngredientsTittle(
                meal: widget.mealData,
              ),

              // Ingredients details
              IngredientsDetail(
                meal: widget.mealData,
              ),

              // Directions title
              DirectionsTittle(
                meal: widget.mealData,
              ),

              // Directions detail
              DirectionsDetail(
                meal: widget.mealData,
              ),
            ],
          ),
        );
      }),
    );
  }
}

// this component is Sliver AppBar

class SlvAppBar extends StatelessWidget {
  const SlvAppBar({super.key, required this.meal});

  final Meal meal;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    return SliverAppBar(
      backgroundColor: isDarkMode ? kDarkGrey : kWhite,
      expandedHeight: 450,
      // recipe image
      flexibleSpace: FlexibleSpaceBar(
        background: (meal.mediaPaths.isNotEmpty &&
                meal.mediaPaths != 'null' &&
                meal.mediaPaths.first.startsWith('http'))
            ? Image.network(
                meal.mediaPaths.first,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Image.asset(
                  getAssetImageForItem(meal.category ?? 'default'),
                  fit: BoxFit.cover,
                ),
              )
            : Image.asset(
                getAssetImageForItem(meal.category ?? 'default'),
                fit: BoxFit.cover,
              ),
      ),

      //back button
      leading: Builder(builder: (BuildContext context) {
        return Padding(
          padding: const EdgeInsets.all(5.0),
          child: CircleAvatar(
            backgroundColor: isDarkMode
                ? kDarkGrey.withOpacity(0.4)
                : kWhite.withOpacity(0.4),
            child: IconButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              icon: Icon(
                Icons.arrow_back_ios_new,
                color: isDarkMode ? kWhite : kBlack,
              ),
            ),
          ),
        );
      }),

      bottom: PreferredSize(
        preferredSize: Size.fromHeight(10),
        child: Container(
          width: double.infinity,
          height: 50,
          decoration: BoxDecoration(
            color: isDarkMode ? kDarkGrey : kWhite,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(50),
              topRight: Radius.circular(50),
            ),
          ),
          child: Column(
            children: [
              const SizedBox(
                height: 15,
              ),

              //drawer
              Container(
                width: 80,
                height: 4,
                color: isDarkMode ? kLightGrey : kAccent,
              )
            ],
          ),
        ),
      ),
    );
  }
}

//Recipe Pop Menu

class RecipePopMenu extends StatelessWidget {
  const RecipePopMenu({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton(
      //more action button
      icon: const Icon(
        Icons.more_horiz,
        color: Colors.black,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(
          Radius.circular(10),
        ),
      ),
      itemBuilder: (context) {
        return [
          //share button
          const PopupMenuItem<int>(
            value: 0,
            child: Row(
              children: [
                Icon(
                  Icons.share,
                  color: Colors.black,
                ),
                SizedBox(
                  width: 10,
                ),
                Text(share),
              ],
            ),
          ),
          //rate button
          const PopupMenuItem<int>(
            value: 1,
            child: Row(
              children: [
                Icon(
                  Icons.star,
                  color: Colors.black,
                ),
                SizedBox(
                  width: 10,
                ),
                Text(rate),
              ],
            ),
          ),
          //review button
          const PopupMenuItem<int>(
            value: 2,
            child: Row(
              children: [
                Icon(
                  Icons.reviews,
                  color: Colors.black,
                ),
                SizedBox(
                  width: 10,
                ),
                Text(review),
              ],
            ),
          ),
          //favorite button
          const PopupMenuItem<int>(
            value: 3,
            child: Row(
              children: [
                Icon(
                  Icons.favorite,
                  color: Colors.black,
                ),
                SizedBox(
                  width: 10,
                ),
                Text(favorite),
              ],
            ),
          ),
        ];
      },
      onSelected: ((value) {
        if (value == 0) {
          print("Share menu is selected.");
          //you can use flutter share package
        } else if (value == 1) {
          //Modal buttom sheet to call rating box
          showModalBottomSheet(
              shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30))),
              context: context,
              builder: (BuildContext context) {
                return const RatingBox();
              });
        } else if (value == 2) {
          //Go to recipe review screen
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const CreateRecipeScreen(),
            ),
          );
        } else if (value == 3) {
          print("Favorite menu is selected.");
          // call API to favorite/unfavorite recipe
        }
      }),
    );
  }
}

//rating box

class RatingBox extends StatelessWidget {
  const RatingBox({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
              topLeft: Radius.circular(30), topRight: Radius.circular(30))),
      child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              rateRecipe,
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(
              height: 20,
            ),
            // star rating
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 80),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Icon(
                    Icons.star_border_outlined,
                    color: Colors.amber,
                    size: 45,
                  ),
                  Icon(
                    Icons.star_border_outlined,
                    color: Colors.amber,
                    size: 45,
                  ),
                  Icon(
                    Icons.star_border_outlined,
                    color: Colors.amber,
                    size: 45,
                  ),
                  Icon(
                    Icons.star_border_outlined,
                    color: Colors.amber,
                    size: 45,
                  ),
                  Icon(
                    Icons.star_border_outlined,
                    color: Colors.amber,
                    size: 45,
                  ),
                ],
              ),
            ),
            const SizedBox(
              height: 15,
            ),
            SecondaryButton(
              text: send,
              press: () => Navigator.pop(context),
            )
          ]),
    );
  }
}

//recipe title

class RecipeTittle extends StatefulWidget {
  const RecipeTittle({
    super.key,
    required this.meal,
  });

  final Meal meal;

  @override
  State<RecipeTittle> createState() => _RecipeTittleState();
}

class _RecipeTittleState extends State<RecipeTittle> {
  bool _isFavorited = false;
  final String? _userId = userService.userId;

  @override
  void initState() {
    super.initState();
    _loadFavoriteStatus();
  }

  Future<void> _loadFavoriteStatus() async {
    final isFavorite =
        await firebaseService.isRecipeFavorite(_userId, widget.meal.mealId);
    setState(() {
      _isFavorited = isFavorite;
    });
  }

  Future<void> _toggleFavorite() async {
    await firebaseService.toggleFavorite(_userId, widget.meal.mealId);
    setState(() {
      _isFavorited = !_isFavorited;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    return SliverToBoxAdapter(
      child: Wrap(
        children: [
          Container(
            width: double.infinity,
            color: isDarkMode ? kDarkGrey : kWhite,
            child: Column(
              children: [
                //Recipe tittle
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    capitalizeFirstLetter(widget.meal.title),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(
                  height: 10,
                ),
                //time, serve, rating
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(width: 20),
                    Text(
                      " $serves: ${widget.meal.serveQty}",
                    ),
                    const SizedBox(width: 20),
                    GestureDetector(
                      onTap: _toggleFavorite,
                      child: Container(
                        decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10)),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            _isFavorited
                                ? Icons.favorite
                                : Icons.favorite_border,
                            color: kRed,
                            size: 19,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(
                  height: 15,
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}

//recipe filter
class RecipeProfile extends StatefulWidget {
  final UserModel? mealUser;
  final String profileId;

  const RecipeProfile({
    super.key,
    required this.mealUser,
    this.profileId = '',
  });

  @override
  State<RecipeProfile> createState() => _RecipeProfileState();
}

class _RecipeProfileState extends State<RecipeProfile> {
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    friendController.fetchFollowing(userService.userId ?? '');
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      sliver: SliverToBoxAdapter(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                //chef avatar
                GestureDetector(
                  onTap: () {
                    if (widget.profileId.isEmpty) return;

                    // ✅ Navigate to ProfileScreen if viewing own profile
                    if (userService.userId == widget.profileId) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ProfileScreen(),
                        ),
                      );
                    } else {
                      // ✅ Navigate to UserProfileScreen for other users
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              UserProfileScreen(userId: widget.profileId),
                        ),
                      );
                    }
                  },
                  child: CircleAvatar(
                    radius: 25,
                    backgroundColor: kAccent.withOpacity(kOpacity),
                    child: CircleAvatar(
                      backgroundImage: widget.mealUser?.profileImage != null &&
                              widget.mealUser!.profileImage!.isNotEmpty &&
                              widget.mealUser!.profileImage!.contains('http')
                          ? NetworkImage(widget.mealUser!.profileImage!)
                          : const AssetImage(intPlaceholderImage)
                              as ImageProvider,
                      radius: 22,
                    ),
                  ),
                ),

                const SizedBox(
                  width: 10,
                ),
                //name and location
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      capitalizeFirstLetter(
                          widget.mealUser?.displayName ?? appName),
                      style: TextStyle(
                        fontSize: 16,
                        color: isDarkMode ? kWhite : kBlack,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // Follow button - Show only if the user is not viewing their own profile
            if (userService.userId != widget.profileId)
              Obx(() {
                bool isFollowing =
                    friendController.isFollowing(widget.profileId);

                // ✅ Properly check if the profile ID is in the following list
                if (!isFollowing) {
                  isFollowing =
                      friendController.followingList.contains(widget.profileId);
                }

                return FollowButton(
                  h: 35,
                  w: 90,
                  title: isFollowing ? 'Unfollow' : follow,
                  press: () {
                    if (isFollowing) {
                      friendController.unfollowFriend(
                          userService.userId ?? '', widget.profileId, context);
                    } else {
                      friendController.followFriend(
                          userService.userId ?? '', widget.profileId, context);
                    }

                    // ✅ Toggle UI immediately for better user experience
                    friendController.toggleFollowStatus(widget.profileId);
                  },
                );
              }),
          ],
        ),
      ),
    );
  }
}

//nutrition facts

class NutritionFacts extends StatelessWidget {
  const NutritionFacts({
    super.key,
    required this.meal,
  });

  final Meal meal;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = getThemeProvider(context).isDarkMode;

    // Use the meal.macros map
    Map<String, String> nutritionMap = {
      ...meal.macros, // Add existing macros
      'Calories': '${meal.calories} kcal', // Add calories as a new entry
    };

// Convert map entries to a list for iteration
    List<MapEntry<String, String>> nutritionEntries =
        nutritionMap.entries.toList();

    return SliverPadding(
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 20,
      ),
      sliver: SliverGrid(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            return Container(
              decoration: BoxDecoration(
                color: isDarkMode ? kLightGrey : kWhite,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Nutrition type (key)
                    Text(
                      nutritionEntries[index].key, // Display key
                      style: TextStyle(
                        color: isDarkMode ? kWhite : kBlack,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    // Quantity (value)
                    Text(
                      nutritionEntries[index].value, // Display value
                      style: TextStyle(
                        color: isDarkMode ? kWhite : kBlack,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
          childCount: nutritionEntries.length,
        ),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisExtent: 50,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
      ),
    );
  }
}

//-----------------------Ingredient Title-----------------------------------

class IngredientsTittle extends StatelessWidget {
  const IngredientsTittle({
    super.key,
    required this.meal,
  });

  final Meal meal;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(ingredients,
                style: TextStyle(
                    fontSize: 18,
                    color: isDarkMode ? kWhite : kBlack,
                    fontWeight: FontWeight.bold)),
            Text("${meal.ingredients.length} $items")
          ],
        ),
      ),
    );
  }
}

//-----------------------Ingredient Detail-----------------------------------

class IngredientsDetail extends StatelessWidget {
  const IngredientsDetail({
    super.key,
    required this.meal,
  });

  final Meal meal;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(left: 20, top: 20),
        child: Row(
          children: [
            // Generate IngredientsCard using the map entries
            ...meal.ingredients.entries.map(
              (entry) => IngredientsCard(
                ingredientName: entry.key,
                ingredientQty: entry.value,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

//-----------------------Ingredient Card-----------------------------------

class IngredientsCard extends StatelessWidget {
  const IngredientsCard({
    super.key,
    required this.ingredientName,
    required this.ingredientQty,
  });

  final String ingredientName, ingredientQty;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    return Padding(
      padding: const EdgeInsets.only(right: 5),
      child: Container(
        decoration: BoxDecoration(
          color: isDarkMode ? kLightGrey : kWhite,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8.0, left: 8.0, right: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(
                height: 10,
              ),
              //ingredient title
              Text(
                ingredientName,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isDarkMode ? kWhite : kBlack),
              ),
              //ingredient quantity
              Text(ingredientQty)
            ],
          ),
        ),
      ),
    );
  }
}

//-----------------------Directions Title-----------------------------------

class DirectionsTittle extends StatelessWidget {
  const DirectionsTittle({
    super.key,
    required this.meal,
  });

  final Meal meal;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(directions,
                style: TextStyle(
                    fontSize: 18,
                    color: isDarkMode ? kWhite : kBlack,
                    fontWeight: FontWeight.bold)),
            Text("${meal.steps.length} $grams")
          ],
        ),
      ),
    );
  }
}

//-----------------------Directions Detail-----------------------------------

class DirectionsDetail extends StatelessWidget {
  const DirectionsDetail({
    super.key,
    required this.meal,
  });

  final Meal meal;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverToBoxAdapter(
        child: Column(
          children: [
            for (int i = 0; i < meal.steps.length; i++)
              DirectionsCard(
                direction: meal.steps[i],
                index: i,
              ),
          ],
        ),
      ),
    );
  }
}

//-----------------------Directions Card-----------------------------------
class DirectionsCard extends StatelessWidget {
  const DirectionsCard({
    super.key,
    required this.direction,
    required this.index,
  });

  final String direction;
  final int index;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
          color: isDarkMode ? kLightGrey : kWhite,
          borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            //step number
            Text(
              'Step ${index + 1}',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: isDarkMode ? kWhite : kBlack),
            ),
            //direction
            Text(
              direction,
              style: const TextStyle(fontSize: 14),
            )
          ],
        ),
      ),
    );
  }
}
