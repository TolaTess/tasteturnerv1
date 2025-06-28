import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tasteturner/constants.dart';
import 'package:tasteturner/widgets/helper_widget.dart';

import '../helper/utils.dart';
import '../pages/upload_battle.dart';

class InspirationScreen extends StatelessWidget {
  const InspirationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: kAccent,
        toolbarHeight:
            getPercentageHeight(10, context), // Control height with percentage
        automaticallyImplyLeading: false,
        centerTitle: true,
        title: Text(
          "What's on your plate?",
          style: TextStyle(fontSize: getTextScale(6, context)),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Get.to(
            () => const UploadBattleImageScreen(battleId: battleIdConstant),
          );
        },
        backgroundColor: kAccent,
        child: Icon(Icons.add_a_photo, color: kWhite),
      ),
      body: const SingleChildScrollView(
        child: SearchContentGrid(
          screenLength: 24, // Show more images on this dedicated screen
          listType: 'battle_post',
          selectedCategory: 'general',
        ),
      ),
    );
  }
}
