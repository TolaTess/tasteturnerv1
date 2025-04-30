import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../constants.dart';
import '../data_models/macro_data.dart';
import '../helper/utils.dart';
import '../screens/favorite_screen.dart';
import '../widgets/icon_widget.dart';
import '../widgets/ingredient_features.dart';
import '../widgets/premium_widget.dart';
import '../widgets/shopping_list_view.dart';

class ShoppingTab extends StatefulWidget {
  const ShoppingTab({super.key});

  @override
  State<ShoppingTab> createState() => _ShoppingTabState();
}

class _ShoppingTabState extends State<ShoppingTab> {
  List<MacroData> shoppingList = [];
  List<MacroData> myShoppingList = [];
  Set<String> selectedShoppingItems = {};

  @override
  void initState() {
    super.initState();
    _setupDataListeners();
  }

  void _setupDataListeners() {
    _onRefresh();
  }

  Future<void> _onRefresh() async {
    setState(() {
      shoppingList = macroManager.ingredient;
    });
    final currentWeek = getCurrentWeek();
    macroManager.fetchShoppingList(
        userService.userId ?? '', currentWeek, false);
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _onRefresh,
      child: Column(
        children: [
          // Action buttons row
          const SizedBox(height: 15),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              MealCategoryItem(
                title: favorite,
                press: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const FavoriteScreen(),
                    ),
                  );
                },
                icon: Icons.favorite,
              ),
              MealCategoryItem(
                title: 'Add to Shopping List',
                press: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => IngredientFeatures(
                        items: macroManager.ingredient,
                      ),
                    ),
                  );
                },
                icon: Icons.shopping_basket,
              ),
            ],
          ),

          // ------------------------------------Premium / Ads------------------------------------
          userService.currentUser?.isPremium ?? false
              ? const SizedBox.shrink()
              : const SizedBox(height: 15),
          userService.currentUser?.isPremium ?? false
              ? const SizedBox.shrink()
              : PremiumSection(
                  isPremium: userService.currentUser?.isPremium ?? false,
                  titleOne: joinChallenges,
                  titleTwo: premium,
                  isDiv: false,
                ),

          userService.currentUser?.isPremium ?? false
              ? const SizedBox.shrink()
              : const SizedBox(height: 10),
          userService.currentUser?.isPremium ?? false
              ? const SizedBox.shrink()
              : Divider(
                  color: getThemeProvider(context).isDarkMode
                      ? kWhite
                      : kDarkGrey),
          // ------------------------------------Premium / Ads-------------------------------------

          if (macroManager.shoppingList.isEmpty &&
              macroManager.previousShoppingList.isNotEmpty)
            const SizedBox(height: 30),
          if (macroManager.shoppingList.isEmpty &&
              macroManager.previousShoppingList.isNotEmpty)
            const Center(
              child: Text(
                'Last week\'s list:',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: kAccent,
                ),
              ),
            ),
          const SizedBox(height: 10),

          // Shopping list
          Expanded(
            child: Obx(() {
              if (macroManager.shoppingList.isEmpty &&
                  macroManager.previousShoppingList.isEmpty) {
                macroManager.fetchShoppingList(
                    userService.userId ?? '', getCurrentWeek() - 1, true);
                return noItemTastyWidget(
                  'No items in shopping list',
                  '',
                  context,
                  false,
                );
              }

              return ShoppingListView(
                items: macroManager.shoppingList.isNotEmpty
                    ? macroManager.shoppingList
                    : macroManager.previousShoppingList,
                selectedItems: selectedShoppingItems,
                onToggle: (item) {
                  setState(() {
                    if (selectedShoppingItems.contains(item)) {
                      selectedShoppingItems.remove(item);
                    } else {
                      selectedShoppingItems.add(item);
                    }
                  });
                },
                isCurrentWeek: macroManager.shoppingList.isNotEmpty,
              );
            }),
          ),
          const SizedBox(height: 70),
        ],
      ),
    );
  }
}

// MealCategoryItem widget definition moved from meal_design_screen.dart
class MealCategoryItem extends StatelessWidget {
  const MealCategoryItem({
    super.key,
    required this.title,
    required this.press,
    this.icon = Icons.favorite,
    this.size = 40,
    this.image = intPlaceholderImage,
  });

  final String title, image;
  final VoidCallback press;
  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: press,
      child: Column(
        children: [
          IconCircleButton(
            h: size,
            w: size,
            icon: icon,
            isRemoveContainer: false,
          ),
          const SizedBox(
            height: 5,
          ),
          Text(title,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              )),
        ],
      ),
    );
  }
}
