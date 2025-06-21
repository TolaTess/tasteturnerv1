import 'package:flutter/material.dart';
import 'package:tasteturner/widgets/helper_widget.dart';

class InspirationScreen extends StatelessWidget {
  const InspirationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Get Inspired'),
        leading: const SizedBox.shrink(),
      ),
      body: const SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 5.0),
          child: SearchContentGrid(
            screenLength: 24, // Show more images on this dedicated screen
            listType: 'battle_post',
            selectedCategory: 'general',
          ),
        ),
      ),
    );
  }
}
