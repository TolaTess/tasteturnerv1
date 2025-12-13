import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../constants.dart';
import 'utils.dart';

/// Shared utility for managing UMP (User Messaging Platform) consent
class UMPConsentHelper {
  // Track if a form is currently being shown/loaded to prevent concurrent calls
  static bool _isFormLoading = false;

  /// Show a dialog and then request UMP consent
  /// This provides a better UX by showing a dialog first, then the consent form
  static Future<void> showConsentDialog(BuildContext context) async {
    final isDarkMode = getThemeProvider(context).isDarkMode;
    final textTheme = Theme.of(context).textTheme;

    // Show dialog first
    final shouldProceed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            decoration: BoxDecoration(
              color: isDarkMode ? kDarkGrey : kWhite,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            padding: EdgeInsets.all(getPercentageWidth(6, context)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon
                Container(
                  padding: EdgeInsets.all(getPercentageWidth(4, context)),
                  decoration: BoxDecoration(
                    color: kAccentLight.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.privacy_tip,
                    color: kAccentLight,
                    size: getIconScale(12, context),
                  ),
                ),
                SizedBox(height: getPercentageHeight(2, context)),
                // Title
                Text(
                  'Privacy & Consent',
                  style: textTheme.titleLarge?.copyWith(
                    color: isDarkMode ? kWhite : kBlack,
                    fontWeight: FontWeight.bold,
                    fontSize: getTextScale(5, context),
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: getPercentageHeight(1.5, context)),
                // Description
                Text(
                  'To provide you with personalized content and ads, we need your consent to process your data according to our privacy policy.',
                  style: textTheme.bodyMedium?.copyWith(
                    color: isDarkMode ? kLightGrey : kDarkGrey,
                    fontSize: getTextScale(3.5, context),
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: getPercentageHeight(3, context)),
                // Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      child: Text(
                        'Cancel',
                        style: textTheme.bodyMedium?.copyWith(
                          color: isDarkMode ? kLightGrey : kDarkGrey,
                        ),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(dialogContext, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kAccentLight,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          horizontal: getPercentageWidth(6, context),
                          vertical: getPercentageHeight(1.2, context),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: Text(
                        'Review Policy',
                        style: TextStyle(
                          fontSize: getTextScale(3.5, context),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    // If user clicked "Review Policy", show the UMP consent form
    if (shouldProceed == true) {
      await requestUMPConsent(
        onConsentObtained: () {
          debugPrint('UMP Consent obtained successfully');
        },
        onError: () {
          debugPrint('Error obtaining UMP consent');
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text(
                    'Unable to load consent form. Please try again later.'),
                backgroundColor: kRed,
              ),
            );
          }
        },
      );
    }
  }

  /// Request UMP consent and show consent form if needed
  /// This can be called from anywhere in the app (not just onboarding)
  /// Handles both initial consent and privacy options form
  static Future<void> requestUMPConsent({
    VoidCallback? onConsentObtained,
    VoidCallback? onError,
  }) async {
    try {
      final params = ConsentRequestParameters();
      ConsentInformation.instance.requestConsentInfoUpdate(
        params,
        () async {
          // Consent info updated successfully
          final canRequest = await ConsentInformation.instance.canRequestAds();
          final privacyOptionsStatus = await ConsentInformation.instance
              .getPrivacyOptionsRequirementStatus();

          debugPrint(
              'UMP Status - canRequestAds: $canRequest, privacyOptionsStatus: $privacyOptionsStatus');

          // If consent hasn't been obtained, show the initial consent form
          if (!canRequest) {
            if (_isFormLoading) {
              debugPrint('Form already loading, skipping...');
              return;
            }
            debugPrint('Consent not obtained, showing initial consent form...');
            _isFormLoading = true;
            ConsentForm.loadAndShowConsentFormIfRequired((formError) {
              _isFormLoading = false;
              if (formError != null) {
                debugPrint('=== UMP Consent form error ===');
                debugPrint('Error code: ${formError.errorCode}');
                debugPrint('Error message: ${formError.message}');
                debugPrint('Full error: $formError');
                debugPrint('================================');
                _setFirebaseConsent();
                onError?.call();
              } else {
                debugPrint('UMP Consent form processed successfully');
                _setFirebaseConsent();
                onConsentObtained?.call();
              }
            });
          } else if (privacyOptionsStatus ==
              PrivacyOptionsRequirementStatus.required) {
            // If consent was already obtained but privacy options are required,
            // show the privacy options form
            // But first check if we don't already have consent granted
            if (_isFormLoading) {
              debugPrint('Privacy options form already loading, skipping...');
              // If form is loading, treat as success since user will see it
              onConsentObtained?.call();
              return;
            }
            debugPrint('Showing privacy options form...');
            _isFormLoading = true;
            ConsentForm.showPrivacyOptionsForm((formError) {
              _isFormLoading = false;
              if (formError != null) {
                debugPrint('=== Privacy options form error ===');
                debugPrint('Error code: ${formError.errorCode}');
                debugPrint('Error message: ${formError.message}');
                debugPrint('Full error: $formError');
                debugPrint('===================================');

                // Error code 7 means form is already being loaded
                // This is not a critical error, consent is already obtained
                if (formError.errorCode == 7) {
                  debugPrint(
                      'Form already loading (error 7), consent already obtained');
                  _setFirebaseConsent();
                  onConsentObtained?.call();
                } else {
                  _setFirebaseConsent();
                  onError?.call();
                }
              } else {
                debugPrint('Privacy options form processed successfully');
                _setFirebaseConsent();
                onConsentObtained?.call();
              }
            });
          } else {
            // Consent already obtained and privacy options not required
            debugPrint('Consent already obtained, no form needed');
            _setFirebaseConsent();
            onConsentObtained?.call();
          }
        },
        (FormError error) {
          // Handle the error updating consent info
          debugPrint('=== UMP Consent info update error ===');
          debugPrint('Error code: ${error.errorCode}');
          debugPrint('Error message: ${error.message}');
          debugPrint('Full error: $error');
          debugPrint('=====================================');
          _setFirebaseConsent();
          onError?.call();
        },
      );
    } catch (e) {
      debugPrint('Error requesting UMP consent: $e');
      _setFirebaseConsent();
      onError?.call();
    }
  }

  /// Check if ads can be requested based on consent status
  /// Returns true if consent has been obtained (granted OR denied)
  /// Returns false only if consent hasn't been obtained yet
  static Future<bool> canRequestAds() async {
    try {
      return await ConsentInformation.instance.canRequestAds();
    } catch (e) {
      debugPrint('Error checking consent status: $e');
      // Default to allowing ads if check fails (SDK will handle it anyway)
      return true;
    }
  }

  /// Set Firebase Analytics consent based on UMP consent status
  static Future<void> _setFirebaseConsent() async {
    try {
      final canRequest = await ConsentInformation.instance.canRequestAds();
      await FirebaseAnalytics.instance.setConsent(
        adStorageConsentGranted: canRequest,
        analyticsStorageConsentGranted: canRequest,
      );
    } catch (e) {
      debugPrint('Error setting Firebase consent: $e');
    }
  }
}
