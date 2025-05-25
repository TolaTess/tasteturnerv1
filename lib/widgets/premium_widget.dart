import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../constants.dart';
import '../helper/utils.dart';
import '../screens/premium_screen.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'dart:io';
import 'package:flutter/services.dart';

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
  static const platform = MethodChannel('com.tasteturner.app/config');
  String? _bannerId;

  @override
  void initState() {
    super.initState();
    _getBannerId();
  }

  Future<void> _getBannerId() async {
    try {
      if (Platform.isIOS) {
        final String? bannerId =
            await platform.invokeMethod('getAdMobBannerId');
        setState(() {
          _bannerId = bannerId;
        });
        _loadBannerAd();
      } else if (Platform.isAndroid) {
        // Keep using dotenv for Android
        _bannerId = dotenv.env['ADMOB_BANNER_ID_ANDROID'] ?? '';
        _loadBannerAd();
      }
    } on PlatformException catch (e) {
      print('Failed to get banner ID: ${e.message}');
      _bannerId = ''; // fallback to empty string
      _loadBannerAd();
    }
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
          padding: EdgeInsets.symmetric(
            horizontal: getPercentageWidth(7, context),
          ),
          child: Container(
            width: double.infinity,
            height: null,
            padding: EdgeInsets.symmetric(
              horizontal: getPercentageWidth(2.5, context),
              vertical: getPercentageHeight(1, context),
            ),
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
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: getPercentageWidth(3.5, context),
          ),
        ),
        Text(
          widget.titleTwo,
          style: TextStyle(
            fontWeight: FontWeight.w400,
            fontSize: getPercentageWidth(3.5, context),
          ),
        ),
      ],
    );
  }
}
