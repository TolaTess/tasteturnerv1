import 'package:flutter/material.dart';
import '../constants.dart';
import '../helper/utils.dart';
import '../screens/premium_screen.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'dart:io';

class PremiumSection extends StatefulWidget {
  final bool isPremium, isDiv;

  final String titleOne;
  final String titleTwo;

  const PremiumSection({
    super.key,
    required this.isPremium,
    this.isDiv = false,
    this.titleOne = joinChallenges,
    this.titleTwo = premium,
  });

  @override
  State<PremiumSection> createState() => _PremiumSectionState();
}

class _PremiumSectionState extends State<PremiumSection> {
  late BannerAd _bannerAd;

  @override
  void initState() {
    super.initState();
    String adUnitId;
    if (Platform.isAndroid) {
      adUnitId =
          'ca-app-pub-3940256099942544/9214589741'; // <-- your Android ad unit
    } else if (Platform.isIOS) {
      adUnitId =
          'ca-app-pub-3940256099942544/2435281174'; // <-- your iOS ad unit
    } else {
      adUnitId = ''; // fallback or test id
    }
    _bannerAd = BannerAd(
      adUnitId: adUnitId,
      size: AdSize.banner,
      request: AdRequest(),
      listener: BannerAdListener(),
    )..load();
  }

  @override
  void dispose() {
    _bannerAd.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    if (widget.isPremium) return const SizedBox.shrink();

    return Column(
      children: [
        widget.isDiv
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
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Container(
            width: double.infinity,
            height: null,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: kAccentLight.withOpacity(0.7),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: isDarkMode
                      ? kAccentLight.withOpacity(0.4)
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
              child: _buildRowLayout(),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: SizedBox(
            width: _bannerAd.size.width.toDouble(),
            height: _bannerAd.size.height.toDouble(),
            child: AdWidget(ad: _bannerAd),
          ),
        ),
      ],
    );
  }

  /// ✅ Original Row Layout
  Widget _buildRowLayout() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        Text(
          widget.titleOne,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
        Text(
          widget.titleTwo,
          style: const TextStyle(
            fontWeight: FontWeight.w400,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

//prod

//android - ca-app-pub-5248381217574361~5625594673
//banner - ca-app-pub-5248381217574361/7370755334

//ios - ca-app-pub-5248381217574361~2048493509
//banner - ca-app-pub-5248381217574361/1819353243
