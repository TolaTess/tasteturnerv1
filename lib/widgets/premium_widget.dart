import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../constants.dart';
import '../helper/utils.dart';
import '../helper/ump_consent_helper.dart';
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
  BannerAd? _bannerAd;
  String? _bannerId;
  // canRequestAds() returns true if consent has been obtained (granted OR denied)
  // It returns false only if consent hasn't been obtained yet
  // The SDK automatically handles personalized vs non-personalized ads
  bool _canRequestAds = true; // Default to true, will be checked before loading
  bool _adsInitialized = false;

  @override
  void initState() {
    super.initState();
    _getBannerId();
    // Retry loading ad after a delay in case consent is obtained asynchronously
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && !_canRequestAds) {
        _loadBannerAd(); // Retry after delay
      }
    });
  }

  Future<void> _getBannerId() async {
    if (Platform.isIOS) {
      _bannerId = dotenv.env['ADMOB_BANNER_ID_IOS'] ?? '';
    } else if (Platform.isAndroid) {
      _bannerId = dotenv.env['ADMOB_BANNER_ID_ANDROID'] ?? '';
    }
    await _loadBannerAd();
  }

  /// Check if ads can be requested based on UMP consent status
  /// Returns true if consent has been obtained (whether granted or denied)
  /// Returns false only if consent hasn't been obtained yet
  /// Note: SDK automatically handles personalized vs non-personalized ads
  Future<bool> _checkCanRequestAds() async {
    return await UMPConsentHelper.canRequestAds();
  }

  /// Load banner ad after checking consent status
  /// Note: If canRequestAds() is true, ads will load (personalized or non-personalized)
  /// If canRequestAds() is false, consent hasn't been obtained yet, so we skip loading
  Future<void> _loadBannerAd() async {
    // Check if ads can be requested (consent has been obtained)
    _canRequestAds = await _checkCanRequestAds();

    if (!_canRequestAds) {
      debugPrint('Cannot load ads - consent has not been obtained yet');
      setState(() {
        _adsInitialized = true;
      });
      return;
    }

    if (_bannerId == null || _bannerId!.isEmpty) {
      debugPrint('Banner ad unit ID is not set');
      setState(() {
        _adsInitialized = true;
      });
      return;
    }

    try {
      _bannerAd = BannerAd(
        adUnitId: _bannerId!,
        size: AdSize.banner,
        request: AdRequest(), // SDK automatically includes consent info
        listener: BannerAdListener(
          onAdFailedToLoad: (ad, error) {
            debugPrint('Banner ad failed to load: $error');
            debugPrint('Ad unit ID: $_bannerId');
            debugPrint('Can request ads: $_canRequestAds');
            
            // Handle Google Play services errors gracefully
            final errorMessage = error.message;
            if (errorMessage.contains('Google Play services') || 
                errorMessage.contains('out of date')) {
              debugPrint('Google Play services may be outdated. This is expected on emulators or older devices.');
              debugPrint('The app will continue to function, but ads may not load until Google Play services is updated.');
            }
            
            setState(() {
              _adsInitialized = true;
              _bannerAd = null; // Ensure bannerAd is null on failure
            });
          },
          onAdLoaded: (_) {
            debugPrint('Banner ad loaded successfully');
            debugPrint(
                'Ad size: ${_bannerAd?.size.width}x${_bannerAd?.size.height}');
            setState(() {
              _adsInitialized = true;
            });
          },
        ),
      )..load();

      setState(() {
        _adsInitialized = true;
      });
    } catch (e) {
      debugPrint('Error creating banner ad: $e');
      setState(() {
        _adsInitialized = true;
      });
    }
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
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
        // Show ad widget if ad is loaded and ads can be requested
        // Note: SDK automatically serves personalized or non-personalized ads based on consent
        if (_adsInitialized && _canRequestAds && _bannerAd != null)
          Padding(
            padding: EdgeInsets.only(
              top: getPercentageHeight(1, context),
            ),
            child: SizedBox(
              width: _bannerAd!.size.width.toDouble(),
              height: _bannerAd!.size.height.toDouble(),
              child: AdWidget(ad: _bannerAd!),
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
