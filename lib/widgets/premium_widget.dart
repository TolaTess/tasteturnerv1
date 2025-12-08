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
            setState(() {
              _adsInitialized = true;
            });
          },
          onAdLoaded: (_) {
            debugPrint('Banner ad loaded successfully');
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
        // Show consent prompt banner if consent hasn't been obtained
        if (_adsInitialized && !_canRequestAds)
          Padding(
            padding: EdgeInsets.only(
              top: getPercentageHeight(1, context),
            ),
            child: _buildConsentPromptBanner(context, isDarkMode),
          ),
        // Only show ad widget if ad is loaded and ads can be requested
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

  /// Build consent prompt banner when consent hasn't been obtained
  Widget _buildConsentPromptBanner(BuildContext context, bool isDarkMode) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: getPercentageWidth(3, context),
        vertical: getPercentageHeight(1.5, context),
      ),
      decoration: BoxDecoration(
        color: kAccentLight.withValues(alpha: 0.9),
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.privacy_tip_outlined,
            color: Colors.white,
            size: getIconScale(8, context),
          ),
          SizedBox(height: getPercentageHeight(1, context)),
          Text(
            'Privacy & Consent',
            style: TextStyle(
              color: Colors.white,
              fontSize: getTextScale(4.5, context),
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: getPercentageHeight(0.5, context)),
          Text(
            'Please review our privacy policy and terms to enable personalized content and ads.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: getTextScale(3.2, context),
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: getPercentageHeight(1.5, context)),
          ElevatedButton(
            onPressed: () => _requestConsent(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: kAccentLight,
              padding: EdgeInsets.symmetric(
                horizontal: getPercentageWidth(6, context),
                vertical: getPercentageHeight(1, context),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: Text(
              'Review Privacy Policy',
              style: TextStyle(
                fontSize: getTextScale(3.5, context),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Request UMP consent and reload ads if consent is obtained
  Future<void> _requestConsent(BuildContext context) async {
    // Show dialog first, then trigger UMP consent form
    await UMPConsentHelper.showConsentDialog(context);

    // After dialog/consent form is closed, check if consent was obtained
    // Small delay to ensure consent status is updated
    await Future.delayed(const Duration(milliseconds: 500));

    // Reload ads if consent was obtained
    await _reloadAds();
  }

  /// Reload ads after consent is obtained
  Future<void> _reloadAds() async {
    // Dispose existing ad if any
    _bannerAd?.dispose();
    _bannerAd = null;
    _adsInitialized = false;

    // Check consent status again
    _canRequestAds = await _checkCanRequestAds();

    if (mounted) {
      setState(() {});
    }

    // Load ads if consent is now available
    if (_canRequestAds) {
      await _loadBannerAd();
    }
  }
}
