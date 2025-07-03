import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tasteturner/constants.dart';
import 'package:tasteturner/widgets/helper_widget.dart';
import 'package:tasteturner/service/post_service.dart';

import '../helper/helper_functions.dart';
import '../helper/utils.dart';
import '../pages/upload_battle.dart';

class InspirationScreen extends StatefulWidget {
  const InspirationScreen({super.key});

  @override
  State<InspirationScreen> createState() => _InspirationScreenState();
}

class _InspirationScreenState extends State<InspirationScreen> {
  final GlobalKey<SearchContentGridState> _gridKey =
      GlobalKey<SearchContentGridState>();

  String selectedGoal = 'general';

  Future<void> _refreshPosts() async {
    // Clear cache and refresh
    setState(() {
      selectedGoal = 'general';
    });
    PostService.instance.clearCategoryCache('general');

    // Trigger refresh in SearchContentGrid
    if (_gridKey.currentState != null) {
      await _gridKey.currentState!.fetchContent();
    }

    // Show success feedback
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: kWhite, size: 20),
              SizedBox(width: 8),
              Text('Posts refreshed!'),
            ],
          ),
          backgroundColor: kAccent,
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isDarkMode = getThemeProvider(context).isDarkMode;
    final userGoal = userService.currentUser.value?.settings['dietPreference'];
    return Scaffold(
      appBar: AppBar(
        backgroundColor: kAccent,
        toolbarHeight: getPercentageHeight(10, context),
        automaticallyImplyLeading: false,
        centerTitle: true,
        title: Column(
          children: [
            Text(
              "What's on Your Plate?",
              style: textTheme.displayMedium?.copyWith(),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle,
                    color: kWhite, size: getIconScale(3.5, context)),
                SizedBox(width: 8),
                Text(
                  "Your $userGoal goal",
                  style: textTheme.bodySmall
                      ?.copyWith(fontSize: getTextScale(2.5, context)),
                ),
              ],
            ),
          ],
        ),
      ),
      floatingActionButtonLocation: CustomFloatingActionButtonLocation(
         verticalOffset: getPercentageHeight(5, context),
          horizontalOffset: getPercentageWidth(2, context),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Get.to(
            () => const UploadBattleImageScreen(
                battleId: 'general', isMainPost: true),
          );
        },
        backgroundColor: kAccent,
        child: Icon(Icons.add_a_photo, color: isDarkMode ? kWhite : kBlack),
      ),
      body: RefreshIndicator(
        onRefresh: _refreshPosts,
        color: kAccent,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        child: SingleChildScrollView(
          physics:
              AlwaysScrollableScrollPhysics(), // Enables pull-to-refresh even when content is short
          child: SearchContentGrid(
            key: _gridKey,
            screenLength: 24, // Show more images on this dedicated screen
            listType: 'battle_post',
            selectedCategory: selectedGoal,
          ),
        ),
      ),
    );
  }
}
