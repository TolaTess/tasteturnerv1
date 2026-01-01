import 'package:flutter/material.dart';
import '../constants.dart';
import '../helper/utils.dart';

/// Reusable widget that displays the "Speaking the Lingo" popup
/// with all the chef terminology terms from onboarding
class LingualPopup extends StatelessWidget {
  const LingualPopup({super.key});

  /// Show the lingual popup as a dialog
  static void show(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const LingualPopup(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              kAccent,
              kPurple.withValues(alpha: 0.7),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: kAccent.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Speaking the Lingo",
                          style: textTheme.displaySmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: getTextScale(6, context),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Learn the language of the kitchen",
                          style: textTheme.bodyMedium?.copyWith(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: getTextScale(3.5, context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            // Scrollable content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    _buildTermRow(
                      context,
                      "Head Chef",
                      "That's You! You're in charge of your kitchen and nutrition goals.",
                      Icons.person,
                    ),
                    _buildDivider(context),
                    _buildTermRow(
                      context,
                      "Sous Chef",
                      "That's Me (Turner). I'm your AI assistant here to help with meal planning and tracking.",
                      Icons.smart_toy,
                    ),
                    _buildDivider(context),
                    _buildTermRow(
                      context,
                      "The Pass",
                      "Your Food Diary. Log meals, track macros, and review your daily nutrition here.",
                      Icons.assignment,
                    ),
                    _buildDivider(context),
                    _buildTermRow(
                      context,
                      "Dine In",
                      "Cook with what you have. Get recipe suggestions based on ingredients in your fridge and pantry.",
                      Icons.kitchen,
                    ),
                    _buildDivider(context),
                    _buildTermRow(
                      context,
                      "Kitchen",
                      "Your main dashboard. Track daily nutrition, view goals, and access quick actions.",
                      Icons.home,
                    ),
                    _buildDivider(context),
                    _buildTermRow(
                      context,
                      "Menus",
                      "Meal programs and plans tailored to your dietary needs.",
                      Icons.restaurant_menu,
                    ),
                    _buildDivider(context),
                    _buildTermRow(
                      context,
                      "Inspiration",
                      "Community feed where chefs share recipes and tips.",
                      Icons.explore,
                    ),
                    _buildDivider(context),
                    _buildTermRow(
                      context,
                      "Spin",
                      "Spin the wheel for spontaneous recipe discovery when you can't decide.",
                      Icons.casino,
                    ),
                    _buildDivider(context),
                    _buildTermRow(
                      context,
                      "Schedule",
                      "Your meal planning calendar. Plan ahead and organize your week.",
                      Icons.calendar_month,
                    ),
                    _buildDivider(context),
                    _buildTermRow(
                      context,
                      "Market",
                      "Your shopping list. Auto-generated from planned meals.",
                      Icons.shopping_cart,
                    ),
                    _buildDivider(context),
                    _buildTermRow(
                      context,
                      "Cookbook",
                      "Your recipe collection. Save and browse favorite dishes.",
                      Icons.menu_book,
                    ),
                    _buildDivider(context),
                    _buildTermRow(
                      context,
                      "Brigade",
                      "Your friends and community. Connect with other chefs.",
                      Icons.people,
                    ),
                    _buildDivider(context),
                    _buildTermRow(
                      context,
                      "My Station",
                      "Your profile and kitchen settings. Customize your experience.",
                      Icons.settings,
                    ),
                    _buildDivider(context),
                    _buildTermRow(
                      context,
                      "Order Fire",
                      "Log meals and track what you've eaten.",
                      Icons.restaurant,
                    ),
                    _buildDivider(context),
                    _buildTermRow(
                      context,
                      "Chef's Choice",
                      "Your favorite dish from the cookbook. Choose your own adventure.",
                      Icons.favorite,
                    ),
                    _buildDivider(context),
                    _buildTermRow(
                      context,
                      "Kitchen Setup",
                      "Your typical settings screen to customize your profile and kitchen settings.",
                      Icons.settings,
                    ),
                    _buildDivider(context),
                    _buildTermRow(
                      context,
                      "Day / Night Shift",
                      "Switch between Light and Dark modes to suit your schedule.",
                      Icons.visibility,
                    ),
                    _buildDivider(context),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTermRow(
    BuildContext context,
    String term,
    String definition,
    IconData icon,
  ) {
    return Padding(
      padding:
          EdgeInsets.symmetric(vertical: getPercentageHeight(1.5, context)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(getPercentageWidth(2, context)),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: getIconScale(5, context),
            ),
          ),
          SizedBox(width: getPercentageWidth(4, context)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  term,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: getTextScale(4, context),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: getPercentageHeight(0.5, context)),
                Text(
                  definition,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: getTextScale(3.2, context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider(BuildContext context) {
    return Divider(
      color: Colors.white.withOpacity(0.2),
      thickness: 1,
      height: 1,
    );
  }
}
