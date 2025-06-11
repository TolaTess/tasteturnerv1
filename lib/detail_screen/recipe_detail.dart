import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../data_models/meal_model.dart';
import '../data_models/user_data_model.dart';
import '../helper/helper_functions.dart';
import '../helper/utils.dart';
import '../screens/friend_screen.dart';
import '../screens/profile_screen.dart';
import '../widgets/primary_button.dart';
import '../constants.dart';
import '../screens/createrecipe_screen.dart';
import '../screens/user_profile_screen.dart';
import '../data_models/user_meal.dart';

class RecipeDetailScreen extends StatefulWidget {
  const RecipeDetailScreen(
      {super.key, required this.mealData, this.screen = 'recipe'});

  final Meal mealData;
  final String screen;

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  Meal? _meal;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.screen == 'share_recipe') {
      _getMeal();
    } else {
      _meal = widget.mealData;
    }
    friendController.updateUserData(widget.mealData.userId);
  }

  Future<void> _getMeal() async {
    setState(() => _loading = true);
    final meal = await mealManager.getMealbyMealID(widget.mealData.mealId);
    if (!mounted) return;
    setState(() {
      _meal = meal;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_meal == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return Scaffold(
      body: Obx(() {
        final mealUser = friendController.userProfileData.value;

        return SafeArea(
          child: CustomScrollView(
            slivers: [
              // Custom app bar > recipe image, back button, more action button, and drawer
              SlvAppBar(
                meal: _meal!,
              ),

              // Recipe title, time to cook, serves, rating, and recipe description
              RecipeTittle(
                meal: _meal!,
                onEdit: () async {
                  final updatedMeal = await Navigator.push<Meal>(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CreateRecipeScreen(
                        screenType: 'edit',
                        meal: _meal!,
                      ),
                    ),
                  );
                  if (updatedMeal != null) {
                    setState(() {
                      _meal = updatedMeal;
                    });
                  } else {
                    // Refetch from Firestore in case of update
                    final doc = await firestore
                        .collection('meals')
                        .doc(_meal!.mealId)
                        .get();
                    if (doc.exists) {
                      setState(() {
                        _meal = Meal.fromJson(doc.id, doc.data()!);
                      });
                    }
                  }
                },
              ),

              // Chef profile: avatar, name, location, and follow button
              RecipeProfile(
                profileId: _meal!.userId,
                mealUser: mealUser,
              ),

              // Nutrition facts (sliver) grid view
              NutritionFacts(
                meal: _meal!,
              ),

              // Ingredients title
              IngredientsTittle(
                meal: _meal!,
              ),

              // Ingredients details
              IngredientsDetail(
                meal: _meal!,
              ),

              // Directions title
              DirectionsTittle(
                meal: _meal!,
              ),

              // Directions detail
              DirectionsDetail(
                meal: _meal!,
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
      expandedHeight: MediaQuery.of(context).size.height > 1100
          ? getPercentageHeight(60, context)
          : getPercentageHeight(45, context),
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
          padding: EdgeInsets.all(getPercentageWidth(0.5, context)),
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
        preferredSize: Size.fromHeight(getPercentageHeight(10, context)),
        child: Container(
          width: double.infinity,
          height: getPercentageHeight(10, context),
          decoration: BoxDecoration(
            color: isDarkMode ? kDarkGrey : kWhite,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(50),
              topRight: Radius.circular(50),
            ),
          ),
          child: Column(
            children: [
              SizedBox(
                height: getPercentageHeight(1, context),
              ),

              //drawer
              Container(
                width: getPercentageWidth(20, context),
                height: getPercentageHeight(0.5, context),
                color: isDarkMode ? kLightGrey : kAccent,
              )
            ],
          ),
        ),
      ),
    );
  }
}

//recipe title

class RecipeTittle extends StatefulWidget {
  const RecipeTittle({
    super.key,
    required this.meal,
    required this.onEdit,
  });

  final Meal meal;
  final Function() onEdit;

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
    if (!mounted) return;
    setState(() {
      _isFavorited = isFavorite;
    });
  }

  Future<void> _toggleFavorite() async {
    await firebaseService.toggleFavorite(_userId, widget.meal.mealId);
    if (!mounted) return;
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
                  padding: EdgeInsets.symmetric(
                      horizontal: getPercentageWidth(10, context)),
                  child: Column(
                    children: [
                      Text(
                        capitalizeFirstLetter(widget.meal.title),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: getPercentageWidth(4, context),
                          fontWeight: FontWeight.bold,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(height: getPercentageHeight(0.5, context)),
                      Text(
                        " $serves: ${widget.meal.serveQty}",
                        style:
                            TextStyle(fontSize: getPercentageWidth(3, context)),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: getPercentageHeight(1, context)),
                //time, serve, rating
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(width: getPercentageWidth(2, context)),
                    GestureDetector(
                      onTap: _toggleFavorite,
                      child: Container(
                        decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10)),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal: getPercentageWidth(1.5, context)),
                          child: Icon(
                            _isFavorited
                                ? Icons.favorite
                                : Icons.favorite_border,
                            color: kRed,
                            size: getPercentageWidth(5, context),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: getPercentageWidth(2, context)),
                    TextButton.icon(
                      onPressed: () async {
                        final userMeal = UserMeal(
                          name: widget.meal.title,
                          quantity: '1',
                          calories: widget.meal.calories,
                          mealId: widget.meal.mealId,
                          servings: 'serving',
                        );

                        try {
                          await dailyDataController.addUserMeal(
                            userService.userId ?? '',
                            getMealTimeOfDay(),
                            userMeal,
                          );

                          if (mounted) {
                            showTastySnackbar(
                              'Success',
                              'Added ${widget.meal.title} to today\'s meals',
                              context,
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            showTastySnackbar(
                              'Error',
                              'Failed to add meal: $e',
                              context,
                              backgroundColor: kRed,
                            );
                          }
                        }
                      },
                      icon:
                          Icon(Icons.add, size: getPercentageWidth(5, context)),
                      label: Text('Today\'s Meal',
                          style: TextStyle(
                              fontSize: getPercentageWidth(3.5, context))),
                      style: TextButton.styleFrom(
                        foregroundColor: kAccent,
                        padding: EdgeInsets.symmetric(
                            horizontal: getPercentageWidth(1.5, context)),
                      ),
                    ),
                    SizedBox(width: getPercentageWidth(1.5, context)),
                    GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => FriendScreen(
                            dataSrc: {
                              ...widget.meal.toJson(),
                              'mealId': widget.meal.mealId
                            },
                            screen: 'share_recipe',
                          ),
                        ),
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10)),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal: getPercentageWidth(1.5, context)),
                          child: Icon(
                            Icons.share,
                            color: kAccentLight,
                            size: getPercentageWidth(4.5, context),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: getPercentageWidth(1.5, context)),

                    // Edit button if user is the owner
                    if (userService.userId == widget.meal.userId) ...[
                      TextButton.icon(
                        onPressed: widget.onEdit,
                        icon: Icon(Icons.edit,
                            size: getPercentageWidth(4, context)),
                        label: Text('Edit Meal',
                            style: TextStyle(
                                fontSize: getPercentageWidth(3.5, context))),
                        style: TextButton.styleFrom(
                          foregroundColor: kAccent,
                          padding: EdgeInsets.symmetric(
                              horizontal: getPercentageWidth(1.5, context)),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.delete_outline, color: kRed),
                        iconSize: getPercentageWidth(5, context),
                        tooltip: 'Delete Meal',
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15)),
                              backgroundColor:
                                  getThemeProvider(context).isDarkMode
                                      ? kDarkGrey
                                      : kWhite,
                              title: Text('Delete Meal',
                                  style: TextStyle(
                                      color:
                                          getThemeProvider(context).isDarkMode
                                              ? kWhite
                                              : kDarkGrey,
                                      fontSize:
                                          getPercentageWidth(4.5, context))),
                              content: Text(
                                  'Are you sure you want to delete this meal? This action cannot be undone.',
                                  style: TextStyle(
                                      color:
                                          getThemeProvider(context).isDarkMode
                                              ? kWhite
                                              : kDarkGrey,
                                      fontSize:
                                          getPercentageWidth(3.5, context))),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: Text('Cancel',
                                      style: TextStyle(
                                          color: getThemeProvider(context)
                                                  .isDarkMode
                                              ? kWhite
                                              : kDarkGrey,
                                          fontSize: getPercentageWidth(
                                              3.5, context))),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: Text('Delete',
                                      style: TextStyle(
                                          color: kRed,
                                          fontSize: getPercentageWidth(
                                              3.5, context))),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            try {
                              await mealManager.removeMeal(widget.meal.mealId);
                              if (context.mounted) {
                                showTastySnackbar('Deleted',
                                    'Meal deleted successfully.', context);
                                Navigator.pop(context);
                              }
                            } catch (e) {
                              if (context.mounted) {
                                showTastySnackbar('Error',
                                    'Failed to delete meal: $e', context,
                                    backgroundColor: kRed);
                              }
                            }
                          }
                        },
                      ),
                    ],
                  ],
                ),
                SizedBox(
                  height: getPercentageHeight(1, context),
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
      padding: EdgeInsets.only(
        left: getPercentageWidth(5, context),
        right: getPercentageWidth(5, context),
        top: getPercentageHeight(2, context),
      ),
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
                    radius: getPercentageWidth(6, context),
                    backgroundColor: kAccent.withOpacity(kOpacity),
                    child: CircleAvatar(
                      backgroundImage: widget.mealUser?.profileImage != null &&
                              widget.mealUser!.profileImage!.isNotEmpty &&
                              widget.mealUser!.profileImage!.contains('http')
                          ? NetworkImage(widget.mealUser!.profileImage!)
                          : const AssetImage(intPlaceholderImage)
                              as ImageProvider,
                      radius: getPercentageWidth(5.5, context),
                    ),
                  ),
                ),
                SizedBox(
                  width: getPercentageWidth(2, context),
                ),
                //name and location
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      capitalizeFirstLetter(
                          widget.mealUser?.displayName ?? appName),
                      style: TextStyle(
                        fontSize: getPercentageWidth(4, context),
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

                return AppButton(
                  height: 4.5,
                  type: AppButtonType.follow,
                  text: isFollowing ? 'Unfollow' : follow,
                  onPressed: () {
                    if (isFollowing) {
                      friendController.unfollowFriend(
                          userService.userId ?? '', widget.profileId, context);
                    } else {
                      friendController.followFriend(
                          userService.userId ?? '',
                          widget.profileId,
                          widget.mealUser?.displayName ?? '',
                          context);
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
      padding: EdgeInsets.only(
        left: getPercentageWidth(3, context),
        right: getPercentageWidth(3, context),
        top: getPercentageHeight(3, context),
        bottom: getPercentageHeight(5, context),
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
                padding: EdgeInsets.symmetric(
                    horizontal: getPercentageWidth(3, context)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Nutrition type (key)
                    Text(
                      capitalizeFirstLetter(nutritionEntries[index].key), // Display key
                      style: TextStyle(
                        color: isDarkMode ? kWhite : kBlack,
                        fontWeight: FontWeight.bold,
                        fontSize: getPercentageWidth(3, context),
                      ),
                    ),
                    // Quantity (value)
                    Text(
                      nutritionEntries[index].value, // Display value
                      style: TextStyle(
                        color: isDarkMode ? kWhite : kBlack,
                        fontWeight: FontWeight.w500,
                        fontSize: getPercentageWidth(2.5, context),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
          childCount: nutritionEntries.length,
        ),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisExtent: getPercentageHeight(8, context),
          crossAxisSpacing: getPercentageWidth(4, context),
          mainAxisSpacing: getPercentageHeight(1, context),
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
        padding: EdgeInsets.symmetric(
            horizontal: getPercentageWidth(3, context),
            vertical: getPercentageHeight(3, context)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(ingredients,
                style: TextStyle(
                    fontSize: getPercentageWidth(4, context),
                    color: isDarkMode ? kWhite : kBlack,
                    fontWeight: FontWeight.bold)),
            Text("${meal.ingredients.length} $items", style: TextStyle(fontSize: getPercentageWidth(2.5, context)))
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
        padding: EdgeInsets.only(
            left: getPercentageWidth(3, context),
            top: getPercentageHeight(1, context)),
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
      padding: EdgeInsets.only(right: getPercentageWidth(0.5, context)),
      child: Container(
        decoration: BoxDecoration(
          color: isDarkMode ? kLightGrey : kWhite,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Padding(
          padding: EdgeInsets.only(
              bottom: getPercentageHeight(1, context),
              left: getPercentageWidth(1, context),
              right: getPercentageWidth(1, context)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                height: getPercentageHeight(1, context),
              ),
              //ingredient title
              Text(
                capitalizeFirstLetter(ingredientName),
                style: TextStyle(
                    fontSize: getPercentageWidth(3, context),
                    fontWeight: FontWeight.w700,
                    color: isDarkMode ? kWhite : kBlack),
              ),
              //ingredient quantity
              Text(ingredientQty,
                  style: TextStyle(
                      fontSize: getPercentageWidth(2.5, context),
                      fontWeight: FontWeight.w500,
                      color: isDarkMode ? kWhite : kBlack))
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
        padding: EdgeInsets.symmetric(
            horizontal: getPercentageWidth(3, context),
            vertical: getPercentageHeight(3, context)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(directions,
                style: TextStyle(
                    fontSize: getPercentageWidth(4, context),
                    color: isDarkMode ? kWhite : kBlack,
                    fontWeight: FontWeight.bold)),
            Text("${meal.steps.length} steps", style: TextStyle(fontSize: getPercentageWidth(2.5, context)))
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
      padding: EdgeInsets.symmetric(horizontal: getPercentageWidth(3, context)),
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
      margin: EdgeInsets.only(bottom: getPercentageHeight(1, context)),
      decoration: BoxDecoration(
          color: isDarkMode ? kLightGrey : kWhite,
          borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: EdgeInsets.symmetric(
            horizontal: getPercentageWidth(3, context),
            vertical: getPercentageHeight(2.5, context)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            //step number
            Text(
              'Step ${index + 1}',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: getPercentageWidth(3, context),
                  color: isDarkMode ? kWhite : kBlack),
            ),
            //direction
            Text(
              direction,
              style: TextStyle(fontSize: getPercentageWidth(2.5, context)),
            )
          ],
        ),
      ),
    );
  }
}
