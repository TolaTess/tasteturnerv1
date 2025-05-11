import 'package:flutter/material.dart';
import '../constants.dart';
import '../helper/utils.dart';
import '../screens/premium_screen.dart';

class PremiumSection extends StatelessWidget {
  final bool isPremium, isDiv, isPost;

  final String titleOne;
  final String titleTwo;

  const PremiumSection({
    super.key,
    required this.isPremium,
    this.isDiv = false,
    this.titleOne = joinChallenges,
    this.titleTwo = premium,
    this.isPost = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    if (isPremium) return const SizedBox.shrink();

    return Column(
      children: [
        isDiv
            ? Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 5,
                ),
                child: Divider(
                  color: isDarkMode ? kWhite : kDarkGrey,
                ),
              )
            : const SizedBox.shrink(),
        const SizedBox(height: 1),

        /// ✅ Wrap in a Container with Conditional Dimensions
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            width: isPost
                  ? 40
                : double.infinity, 
            height: isPost ? 40 : null, 
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: kLightGrey.withOpacity(0.7),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: isDarkMode
                      ? kLightGrey.withOpacity(0.4)
                      : kDarkGrey.withOpacity(0.2),
                  spreadRadius: 0.6,
                  blurRadius: 8,
                ),
              ],
            ),
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PremiumScreen(),
                  ),
                );
              },
              child: isPost
                  ? _buildSquareLayout()
                  : _buildRowLayout(),
            ),
          ),
        ),
      ],
    );
  }

  /// ✅ Square Layout for Posts
  Widget _buildSquareLayout() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          titleOne,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: kWhite.withOpacity(0.5),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            titleTwo,
            style: const TextStyle(
              fontWeight: FontWeight.w400,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  /// ✅ Original Row Layout
  Widget _buildRowLayout() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          titleOne,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: kWhite.withOpacity(0.5),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            titleTwo,
            style: const TextStyle(
              fontWeight: FontWeight.w400,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }
}
