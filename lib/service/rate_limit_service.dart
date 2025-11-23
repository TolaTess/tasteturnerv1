import 'package:get/get.dart';
import 'package:flutter/material.dart' show debugPrint;
import 'package:shared_preferences/shared_preferences.dart';

/// Service to manage rate limiting for AI API calls
///
/// Prevents:
/// - Spam requests
/// - Excessive API costs
/// - Rate limit violations
class RateLimitService extends GetxController {
  static RateLimitService get instance {
    try {
      return Get.find<RateLimitService>();
    } catch (e) {
      return Get.put(RateLimitService());
    }
  }

  // In-memory tracking
  final Map<String, List<DateTime>> _requestHistory = {};

  // Rate limits (configurable)
  static final Map<String, RateLimit> _defaultLimits = {
    'meal_generation': RateLimit(maxRequests: 10, windowMinutes: 60),
    'image_analysis': RateLimit(maxRequests: 20, windowMinutes: 60),
    'chat': RateLimit(maxRequests: 50, windowMinutes: 60),
    'fridge_analysis': RateLimit(maxRequests: 10, windowMinutes: 60),
    'ingredient_generation': RateLimit(maxRequests: 30, windowMinutes: 60),
    'meal_details': RateLimit(maxRequests: 20, windowMinutes: 60),
  };

  /// Check if request is allowed
  Future<bool> canMakeRequest({
    required String operation,
    String? userId,
  }) async {
    try {
      final limit = _defaultLimits[operation] ??
          RateLimit(maxRequests: 20, windowMinutes: 60);
      final key = userId != null ? '${operation}_$userId' : operation;

      // Clean old requests outside window
      _cleanOldRequests(key, limit.windowMinutes);

      // Check if limit exceeded
      final requests = _requestHistory[key] ?? [];
      if (requests.length >= limit.maxRequests) {
        debugPrint(
            'Rate limit exceeded for $operation: ${requests.length}/${limit.maxRequests}');
        return false;
      }

      // Record this request
      requests.add(DateTime.now());
      _requestHistory[key] = requests;

      // Also persist to SharedPreferences for cross-session tracking
      if (userId != null) {
        await _persistRequest(key, DateTime.now());
      }

      return true;
    } catch (e) {
      debugPrint('Error checking rate limit: $e');
      // Allow request on error (fail open)
      return true;
    }
  }

  /// Get remaining requests for an operation
  int getRemainingRequests(String operation, {String? userId}) {
    final limit = _defaultLimits[operation] ??
        RateLimit(maxRequests: 20, windowMinutes: 60);
    final key = userId != null ? '${operation}_$userId' : operation;

    _cleanOldRequests(key, limit.windowMinutes);
    final requests = _requestHistory[key] ?? [];

    return (limit.maxRequests - requests.length).clamp(0, limit.maxRequests);
  }

  /// Get time until next request allowed
  Duration? getTimeUntilNextRequest(String operation, {String? userId}) {
    final limit = _defaultLimits[operation] ??
        RateLimit(maxRequests: 20, windowMinutes: 60);
    final key = userId != null ? '${operation}_$userId' : operation;

    _cleanOldRequests(key, limit.windowMinutes);
    final requests = _requestHistory[key] ?? [];

    if (requests.length < limit.maxRequests) {
      return null; // Can make request now
    }

    // Find oldest request in window
    if (requests.isNotEmpty) {
      final oldest = requests.first;
      final windowEnd = oldest.add(Duration(minutes: limit.windowMinutes));
      final now = DateTime.now();

      if (windowEnd.isAfter(now)) {
        return windowEnd.difference(now);
      }
    }

    return null;
  }

  /// Clean old requests outside the time window
  void _cleanOldRequests(String key, int windowMinutes) {
    final requests = _requestHistory[key];
    if (requests == null) return;

    final cutoff = DateTime.now().subtract(Duration(minutes: windowMinutes));
    _requestHistory[key] =
        requests.where((time) => time.isAfter(cutoff)).toList();
  }

  /// Persist request to SharedPreferences
  Future<void> _persistRequest(String key, DateTime timestamp) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final requestsKey = 'rate_limit_$key';
      final existing = prefs.getStringList(requestsKey) ?? [];

      // Add new request
      existing.add(timestamp.toIso8601String());

      // Keep only requests in last hour
      final cutoff = DateTime.now().subtract(const Duration(hours: 1));
      final filtered = existing.where((timeStr) {
        final time = DateTime.tryParse(timeStr);
        return time != null && time.isAfter(cutoff);
      }).toList();

      await prefs.setStringList(requestsKey, filtered);
    } catch (e) {
      debugPrint('Error persisting rate limit: $e');
    }
  }

  /// Load persisted requests from SharedPreferences
  Future<void> loadPersistedRequests(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      for (final operation in _defaultLimits.keys) {
        final key = '${operation}_$userId';
        final requestsKey = 'rate_limit_$key';
        final persisted = prefs.getStringList(requestsKey) ?? [];

        _requestHistory[key] = persisted
            .map((timeStr) => DateTime.tryParse(timeStr))
            .whereType<DateTime>()
            .toList();
      }
    } catch (e) {
      debugPrint('Error loading persisted requests: $e');
    }
  }

  /// Reset rate limit for an operation
  void resetLimit(String operation, {String? userId}) {
    final key = userId != null ? '${operation}_$userId' : operation;
    _requestHistory.remove(key);
  }

  /// Reset all limits
  void resetAllLimits() {
    _requestHistory.clear();
  }
}

/// Rate limit configuration
class RateLimit {
  final int maxRequests;
  final int windowMinutes;

  RateLimit({
    required this.maxRequests,
    required this.windowMinutes,
  });
}
