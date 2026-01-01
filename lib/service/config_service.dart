import 'package:flutter/material.dart' show debugPrint;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:cloud_functions/cloud_functions.dart';

/// Configuration service that fetches configuration from Firestore
/// with .env as fallback. Provides caching to reduce Firestore calls.
/// Pre-loads configuration at app startup for better performance.
class ConfigService {
  static final ConfigService _instance = ConfigService._internal();
  factory ConfigService() => _instance;
  ConfigService._internal();

  static ConfigService get instance => _instance;

  Map<String, dynamic>? _cachedConfig;
  DateTime? _lastFetch;
  bool _isPreloading = false;
  bool _preloadAttempted = false;
  static const Duration _cacheTTL = Duration(hours: 1);

  /// Pre-load configuration from Firestore at app startup
  /// Silently falls back to .env if Firestore fails
  /// Does not block app startup - runs in background
  Future<void> preloadConfig() async {
    if (_isPreloading || _preloadAttempted) {
      debugPrint('[ConfigService] Pre-load already in progress or attempted');
      return; // Already loading or attempted
    }

    _isPreloading = true;
    _preloadAttempted = true;
    debugPrint('[ConfigService] 🚀 Starting pre-load from Firestore...');

    try {
      // Try Firestore (silently, no user messages)
      final callable = FirebaseFunctions.instance.httpsCallable('getApiKeys');
      debugPrint('[ConfigService] 📡 Calling getApiKeys cloud function...');
      final result = await callable().timeout(const Duration(seconds: 10));

      if (result.data is Map<String, dynamic>) {
        final data = result.data as Map<String, dynamic>;
        if (data['success'] == true) {
          _cachedConfig = Map<String, dynamic>.from(data);
          _lastFetch = DateTime.now();
          final iosId = data['admobBannerIdIos'] ?? 'not set';
          final androidId = data['admobBannerIdAndroid'] ?? 'not set';
          debugPrint('[ConfigService] ✅ Pre-loaded configuration from Firestore');
          debugPrint('[ConfigService]   - AdMob iOS: ${iosId.length > 20 ? "${iosId.substring(0, 20)}..." : iosId}');
          debugPrint('[ConfigService]   - AdMob Android: ${androidId.length > 20 ? "${androidId.substring(0, 20)}..." : androidId}');
        } else {
          debugPrint('[ConfigService] ⚠️ getApiKeys returned success=false');
        }
      } else {
        debugPrint('[ConfigService] ⚠️ getApiKeys returned unexpected data type');
      }
    } catch (e, stackTrace) {
      // Silently fallback to .env - no user messages
      // Only log detailed error if it's not a timeout (timeouts are expected in poor network conditions)
      if (e.toString().contains('TimeoutException')) {
        debugPrint('[ConfigService] ⏱️ Pre-load timeout (network may be slow), using .env fallback');
      } else {
      debugPrint('[ConfigService] ❌ Pre-load from Firestore failed, will use .env');
      debugPrint('[ConfigService]   Error: $e');
      debugPrint('[ConfigService]   Stack: $stackTrace');
      }
      _cachedConfig = {}; // Empty config means use .env
      _lastFetch = DateTime.now();
    } finally {
      _isPreloading = false;
      debugPrint('[ConfigService] Pre-load completed');
    }
  }

  /// Get AdMob banner ID for the specified platform
  /// Returns Firestore value if available, otherwise falls back to .env
  Future<String?> getAdMobBannerId({required bool isIOS}) async {
    final config = await _getConfig();
    if (isIOS) {
      return config['admobBannerIdIos'] ?? dotenv.env['ADMOB_BANNER_ID_IOS'];
    } else {
      return config['admobBannerIdAndroid'] ??
          dotenv.env['ADMOB_BANNER_ID_ANDROID'];
    }
  }

  /// Get configuration from Firestore with .env fallback
  /// Uses caching to reduce Firestore calls
  /// Retries Firestore once if cache is stale and fails
  Future<Map<String, dynamic>> _getConfig({bool retry = false}) async {
    // Check cache validity
    if (_cachedConfig != null && _lastFetch != null) {
      final age = DateTime.now().difference(_lastFetch!);
      if (age < _cacheTTL) {
        debugPrint('[ConfigService] 💾 Using cached config (age: ${age.inMinutes}m)');
        return _cachedConfig!;
      } else {
        debugPrint('[ConfigService] ⏰ Cache expired (age: ${age.inMinutes}m), fetching fresh config');
      }
    }

    // Try Firestore (silently, no user messages)
    try {
      debugPrint('[ConfigService] 📡 Fetching config from Firestore${retry ? " (retry)" : ""}...');
      final callable = FirebaseFunctions.instance.httpsCallable('getApiKeys');
      final result = await callable().timeout(const Duration(seconds: 10));

      if (result.data is Map<String, dynamic>) {
        final data = result.data as Map<String, dynamic>;
        if (data['success'] == true) {
          _cachedConfig = Map<String, dynamic>.from(data);
          _lastFetch = DateTime.now();
          debugPrint('[ConfigService] ✅ Config fetched from Firestore');
          return _cachedConfig!;
        } else {
          debugPrint('[ConfigService] ⚠️ getApiKeys returned success=false');
        }
      } else {
        debugPrint('[ConfigService] ⚠️ getApiKeys returned unexpected data type: ${result.data.runtimeType}');
      }
    } catch (e) {
      // If first attempt failed and we haven't retried, try once more
      if (!retry) {
        // Only log detailed error if it's not a timeout
        if (e.toString().contains('TimeoutException')) {
          debugPrint('[ConfigService] ⏱️ Firestore fetch timeout, retrying once...');
        } else {
        debugPrint('[ConfigService] ⚠️ Firestore fetch failed, retrying once...');
        debugPrint('[ConfigService]   Error: $e');
        }
        return await _getConfig(retry: true);
      }
      // After retry, silently fallback to .env
      if (e.toString().contains('TimeoutException')) {
        debugPrint('[ConfigService] ⏱️ Firestore fetch timeout after retry, using .env fallback');
      } else {
      debugPrint('[ConfigService] ❌ Firestore fetch failed after retry, using .env fallback');
      debugPrint('[ConfigService]   Error: $e');
      }
    }

    // Fallback to .env (return empty map, individual getters will use dotenv directly)
    debugPrint('[ConfigService] 🔄 Falling back to .env');
    _cachedConfig = {};
    _lastFetch = DateTime.now();
    return _cachedConfig!;
  }

  /// Clear the configuration cache
  /// Useful when you want to force a refresh
  void clearCache() {
    _cachedConfig = null;
    _lastFetch = null;
    _preloadAttempted = false;
  }
}
