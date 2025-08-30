import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
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
  String? _bannerId;

  @override
  void initState() {
    super.initState();
    _getBannerId();
  }

  Future<void> _getBannerId() async {
    if (Platform.isIOS) {
      _bannerId = dotenv.env['ADMOB_BANNER_ID_IOS'] ?? '';
    } else if (Platform.isAndroid) {
      _bannerId = dotenv.env['ADMOB_BANNER_ID_ANDROID'] ?? '';
    }
    _loadBannerAd();
  }

  void _loadBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: _bannerId ?? '',
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
                padding: EdgeInsets.symmetric(
                  horizontal: getPercentageWidth(0.5, context),
                ),
                child: Divider(
                  color: isDarkMode ? kWhite : kDarkGrey,
                ),
              )
            : const SizedBox.shrink(),
        SizedBox(height: getPercentageHeight(0.5, context)),

        /// ✅ Wrap in a Container with Conditional Dimensions
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: getPercentageWidth(2, context),
          ),
          child: Container(
            width: double.infinity,
            height: null,
            padding: EdgeInsets.symmetric(
              horizontal: getPercentageWidth(2.5, context),
              vertical: getPercentageHeight(0.5, context),
            ),
            decoration: BoxDecoration(
              color: kAccentLight.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: isDarkMode
                      ? kAccentLight.withValues(alpha: 0.4)
                      : kDarkGrey.withValues(alpha: 0.2),
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
          padding: EdgeInsets.only(
            top: getPercentageHeight(1, context),
          ),
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
          style: Theme.of(context).textTheme.labelLarge,
        ),
        Text(
          widget.titleTwo,
          style: Theme.of(context).textTheme.labelLarge,
        ),
      ],
    );
  }
}
