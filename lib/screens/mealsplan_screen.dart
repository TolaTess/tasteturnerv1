// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:get/get.dart';
// import 'package:provider/provider.dart';
// import '../constants.dart';
// import '../data_models/ingredient_model.dart';
// import '../data_models/macro_data.dart';
// import '../data_models/meal_model.dart';
// import '../helper/utils.dart';
// import '../size_config.dart';
// import '../themes/theme_provider.dart';
// import '../widgets/circle_image.dart';
// import '../widgets/home_widget.dart';
// import '../widgets/icon_widget.dart';
// import 'favorite_screen.dart';
// import '../detail_screen/recipe_detail.dart';
// import 'recipes_list_category_screen.dart';
// import 'shopping_list.dart';

// class MealsPlanScreen extends StatefulWidget {
//   const MealsPlanScreen({super.key});

//   @override
//   State<MealsPlanScreen> createState() => _MealsPlanScreenState();
// }

// class _MealsPlanScreenState extends State<MealsPlanScreen>
//     with TickerProviderStateMixin {
//   PageController _pageController = PageController();
//   int currentPage = 0;
//   List<Meal> newMeals = [];
//   List<Meal> mealsPlanData = [];
//   List<MacroData> shoppingList = [];
//   // List<MacroData> myShoppingList = [];

//   late ScrollController _scrollController;

//   bool lastStatus = true;

//   _scrollListener() {
//     if (isShrink != lastStatus) {
//       setState(() {
//         lastStatus = isShrink;
//       });
//     }
//   }

//   bool get isShrink {
//     return _scrollController.hasClients &&
//         _scrollController.offset > (240 - kToolbarHeight);
//   }

//   @override
//   void initState() {
//     super.initState();
//     _scrollController = ScrollController();
//     _scrollController.addListener(_scrollListener);
//     _pageController = PageController(initialPage: currentPage);

//     // Start auto-scrolling
//     _startAutoScroll();
//     mealsPlanData = mealManager.meals;
//     getNewMeal();
//     shoppingList = macroManager.ingredient;
//     macroManager.fetchShoppingList(userService.userId ?? '');
//     // getShoppingList(userService.userId ?? '');
//   }

//   @override
//   void dispose() {
//     _scrollController.removeListener(_scrollListener);
//     _pageController.dispose();
//     super.dispose();
//   }

//   void _startAutoScroll() {
//     // Auto-scroll to the next page every 3 seconds
//     Future.delayed(const Duration(seconds: 3)).then((_) {
//       if (_pageController.hasClients) {
//         if (currentPage < 2) {
//           currentPage++;
//         } else {
//           currentPage = 0;
//         }
//         _pageController.animateToPage(
//           currentPage,
//           duration: const Duration(milliseconds: 500),
//           curve: Curves.easeInOut,
//         );
//         _startAutoScroll();
//       }
//     });
//   }

//   // void getShoppingList(String userId) async {
//   //   myShoppingList = await macroManager.fetchMyShoppingList(userId);
//   //   setState(() {});
//   // }

//   void getNewMeal() async {
//     newMeals = await mealManager.fetchNewMeals();
//     setState(() {});
//   }

//   @override
//   Widget build(BuildContext context) {
//     final themeProvider = Provider.of<ThemeProvider>(context);

//     final List<String> daysOfWeek = [
//       monday,
//       tuesday,
//       wednesday,
//       thursday,
//       friday,
//       saturday,
//       sunday,
//     ];

//     final int todayIndex = DateTime.now().weekday - 1;

//     final List<String> orderedDays = [
//       ...daysOfWeek.sublist(todayIndex),
//       ...daysOfWeek.sublist(0, todayIndex),
//     ];

//     final List<Widget> dayPlans = orderedDays.map((day) {
//       return DayPlan(
//         day: day,
//         themeProvider: themeProvider,
//         demoMealsPlanData: mealsPlanData,
//       );
//     }).toList();

//     SizeConfig().init(context);
//     return Scaffold(
//       body: SafeArea(
//         child: CustomScrollView(
//           controller: _scrollController,
//           slivers: [
//             SliverAppBar(
//               backgroundColor: themeProvider.isDarkMode ? kDarkGrey : kWhite,
//               automaticallyImplyLeading: false,
//               title: isShrink
//                   ? Text(
//                       mealPlan,
//                       style: TextStyle(
//                         fontWeight: FontWeight.bold,
//                         fontSize: 18,
//                         color: themeProvider.isDarkMode ? kWhite : kBlack,
//                       ),
//                     )
//                   : const Text(emptyString),
//               pinned: true,
//               expandedHeight: getProportionalHeight(150),
//               systemOverlayStyle: SystemUiOverlayStyle(
//                 statusBarIconBrightness:
//                     isShrink ? Brightness.dark : Brightness.light,
//               ),
//               flexibleSpace: FlexibleSpaceBar(
//                 background: SizedBox(
//                   child: PageView.builder(
//                     controller: _pageController,
//                     itemCount: newMeals.length,
//                     itemBuilder: (context, index) => TopCategoriesItem(
//                       dataSrc: newMeals[index],
//                       press: () {
//                         Navigator.push(
//                           context,
//                           MaterialPageRoute(
//                             builder: (context) => RecipeDetailScreen(
//                               mealData: newMeals[index],
//                             ),
//                           ),
//                         );
//                       },
//                       isHeader: true,
//                     ),
//                   ),
//                 ),
//               ),
//             ),
//             //content
//             SliverToBoxAdapter(
//               child: Column(
//                 children: [
//                   //shopping / favorite / new recipes

//                   SizedBox(
//                     height: getPercentageHeight(2),
//                   ),

//                   //avatar list
//                   Row(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//                     children: [
//                       MealCategoryItem(
//                         title: 'Favorite',
//                         press: () {
//                           Navigator.push(
//                             context,
//                             MaterialPageRoute(
//                               builder: (context) => const FavoriteScreen(),
//                             ),
//                           );
//                         },
//                         icon: Icons.favorite,
//                       ),
//                       MealCategoryItem(
//                         title: 'Add to Shopping List',
//                         press: () {
//                           Navigator.push(
//                             context,
//                             MaterialPageRoute(
//                               builder: (context) => ShoppingListScreen(
//                                   shoppingList: shoppingList),
//                             ),
//                           );
//                         },
//                         icon: Icons.shopping_basket,
//                       ),
//                     ],
//                   ),

//                   const SizedBox(
//                     height: 35,
//                   ),
//                   //rows of Ingredients
//                   Obx(() {
//                     if (macroManager.shoppingList.isEmpty) {
//                       return Center(
//                         child: Text(
//                           "No data in your Shopping List",
//                           style: TextStyle(
//                               fontSize: 16,
//                               color: themeProvider.isDarkMode
//                                   ? kLightGrey
//                                   : kAccent),
//                         ),
//                       );
//                     }
//                     return IngredientListView(
//                       demoAcceptedData: macroManager.shoppingList,
//                       spin: false,
//                       isEdit: false,
//                       onRemoveItem: (int) {},
//                     );
//                   }),

//                   const SizedBox(
//                     height: 30,
//                   ),

//                   Column(
//                     children: dayPlans,
//                   ),
//                 ],
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   // dot navigator build method
//   AnimatedContainer buildDot(int? index) {
//     return AnimatedContainer(
//       duration: const Duration(milliseconds: 200),
//       margin: const EdgeInsets.only(right: 8),
//       height: 8,
//       width: 8,
//       decoration: BoxDecoration(
//         color: currentPage == index ? kAccent : kWhite.withOpacity(0.50),
//         borderRadius: BorderRadius.circular(50),
//       ),
//     );
//   }
// }

// //image slider contents
// class SliderContent extends StatelessWidget {
//   const SliderContent({
//     super.key,
//     required this.dataSrc,
//   });
//   final AppbarSliderData dataSrc;

//   @override
//   Widget build(BuildContext context) {
//     return Stack(
//       children: [
//         SizedBox(
//           height: 300,
//           child: Image.asset(
//             dataSrc.image,
//             fit: BoxFit.cover,
//           ),
//         ),
//         Padding(
//           padding: const EdgeInsets.only(
//             top: 108,
//             left: 20,
//             right: 60,
//             bottom: 20,
//           ),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Text(
//                 dataSrc.title,
//                 overflow: TextOverflow.ellipsis,
//                 maxLines: 2,
//                 style: const TextStyle(
//                   fontSize: 28,
//                   fontWeight: FontWeight.w600,
//                 ),
//               ),
//               const SizedBox(
//                 height: 8,
//               ),
//               Text(
//                 dataSrc.subtitle,
//                 overflow: TextOverflow.ellipsis,
//                 maxLines: 2,
//                 style: const TextStyle(
//                   fontSize: 12,
//                 ),
//               ),
//             ],
//           ),
//         )
//       ],
//     );
//   }
// }

// DateTime getDateForDay(String day) {
//   final today = DateTime.now();
//   final weekdayMap = {
//     'Monday': DateTime.monday,
//     'Tuesday': DateTime.tuesday,
//     'Wednesday': DateTime.wednesday,
//     'Thursday': DateTime.thursday,
//     'Friday': DateTime.friday,
//     'Saturday': DateTime.saturday,
//     'Sunday': DateTime.sunday,
//   };

//   // Find the weekday number for the target day
//   final targetWeekday = weekdayMap[day];

//   if (targetWeekday == null) {
//     throw ArgumentError('Invalid day: $day');
//   }

//   // Calculate the difference between today's weekday and target weekday
//   final difference = targetWeekday - today.weekday;

//   // If the target day is in the future, add the difference to today's date
//   // If it's in the past, calculate for next week
//   final targetDate =
//       today.add(Duration(days: difference >= 0 ? difference : 7 + difference));

//   return targetDate;
// }

// class DayPlan extends StatelessWidget {
//   final ThemeProvider themeProvider;
//   final String day;
//   final List<Meal> demoMealsPlanData;

//   const DayPlan({
//     super.key,
//     required this.day,
//     required this.themeProvider,
//     required this.demoMealsPlanData,
//   });

//   @override
//   Widget build(BuildContext context) {
//     // Calculate the date for the given day
//     final dateForDay = getDateForDay(day);
//     final formattedDate =
//         dateForDay.toLocal().toIso8601String().split('T').first;

//     return Padding(
//       padding: EdgeInsets.symmetric(
//         horizontal: getPercentageWidth(5),
//         vertical: getPercentageHeight(2),
//       ),
//       child: Column(
//         children: [
//           Row(
//             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//             children: [
//               Text(
//                 '$day ($formattedDate)', // Display day with the calculated date
//                 style: const TextStyle(
//                   fontSize: 18,
//                   fontWeight: FontWeight.w500,
//                 ),
//               ),
//               ThirdButton(
//                 icon: Icons.add,
//                 text: 'Add', // Replace with `add` variable if defined
//                 screen: 'mealPlan', // Replace with your screen variable
//                 date: formattedDate,
//                 onToggleEdit: () {},
//               )
//             ],
//           ),
//           const Divider(),
//           MealPlanList(
//             day: day,
//             date: dateForDay,
//           ),
//         ],
//       ),
//     );
//   }
// }


// class MealPlanList extends StatefulWidget {
//   final DateTime date; // Pass the date instead of just the day
//   final String day; // Optionally keep the day for additional filtering

//   const MealPlanList({
//     required this.date,
//     required this.day,
//     super.key,
//   });

//   @override
//   State<MealPlanList> createState() => _MealPlanListState();
// }

// class _MealPlanListState extends State<MealPlanList> {
//   List<Meal> meals = [];
//   bool isLoading = true;

//   @override
//   void initState() {
//     super.initState();
//     final formattedDate = widget.date;
//     _loadMealsForDate(widget.date, widget.day);
//   }

//   Future<void> _loadMealsForDate(DateTime date, String day) async {
//     try {
//       // Format the date to use as the document ID
//       final formattedDate = date.toIso8601String().split('T').first;

//       // Retrieve the MealPlan document for the specific date
//       final docSnapshot =
//           await firestore.collection('mealPlans').doc(formattedDate).get();

//       if (docSnapshot.exists) {
//         // Extract meal IDs from the document
//         final mealPlanData = docSnapshot.data();
//         final mealIds = List<String>.from(mealPlanData?['meals'] ?? []);

//         // Fetch meals by their IDs
//         final loadedMeals = await mealManager.getMealsByMealIds(mealIds);

//         setState(() {
//           meals = loadedMeals;
//           isLoading = false;
//         });
//       } else {
//         // No meal plan found for the date
//         setState(() {
//           meals = [];
//           isLoading = false;
//         });
//       }
//     } catch (e) {
//       print('Error loading meals for date: $e');
//       setState(() {
//         meals = [];
//         isLoading = false;
//       });
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     final themeProvider = Provider.of<ThemeProvider>(context);
//     if (isLoading) {
//       return const Center(child: CircularProgressIndicator());
//     }

//     return SizedBox(
//       height: getProportionalHeight(170),
//       child: meals.isEmpty
//           ? Center(
//               child: Text(
//                 "No meals yet",
//                 style: TextStyle(
//                     fontSize: 16,
//                     color: themeProvider.isDarkMode ? kLightGrey : kAccent),
//                 textAlign: TextAlign.center,
//               ),
//             )
//           : ListView.builder(
//               itemCount: meals.length,
//               padding: const EdgeInsets.only(right: 20),
//               scrollDirection: Axis.horizontal,
//               itemBuilder: (context, index) {
//                 return Padding(
//                   padding: const EdgeInsets.only(left: 20),
//                   child: InkWell(
//                     onTap: () {
//                       Navigator.push(
//                         context,
//                         MaterialPageRoute(
//                           builder: (context) => RecipeDetailScreen(
//                             mealData: meals[index],
//                           ),
//                         ),
//                       );
//                     },
//                     child: TopCategoriesItem(
//                       dataSrc: meals[index],
//                       isRecipe: true,
//                       press: () {
//                         Navigator.push(
//                           context,
//                           MaterialPageRoute(
//                             builder: (context) => RecipeDetailScreen(
//                               mealData: meals[index],
//                             ),
//                           ),
//                         );
//                       },
//                     ),
//                   ),
//                 );
//               },
//             ),
//     );
//   }
// }

