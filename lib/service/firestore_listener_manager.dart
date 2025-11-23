import 'dart:async';
import 'package:get/get.dart';
import 'package:flutter/material.dart' show debugPrint;

/// Centralized service to manage Firestore listeners and reduce overhead
/// 
/// This service helps optimize Firestore usage by:
/// - Tracking active listeners
/// - Providing lifecycle management
/// - Caching frequently accessed data
/// - Converting snapshots() to get() where real-time updates aren't needed
class FirestoreListenerManager extends GetxService {
  static FirestoreListenerManager get instance {
    try {
      return Get.find<FirestoreListenerManager>();
    } catch (e) {
      return Get.put(FirestoreListenerManager());
    }
  }

  // Track active listeners
  final Map<String, StreamSubscription> _activeListeners = {};
  final Map<String, DateTime> _listenerTimestamps = {};
  
  // Cache for non-real-time data
  final Map<String, CachedData> _cache = {};
  static const Duration _cacheValidDuration = Duration(minutes: 5);

  /// Register a listener with lifecycle management
  StreamSubscription<T> registerListener<T>({
    required String listenerId,
    required Stream<T> stream,
    required void Function(T) onData,
    Function? onError,
    void Function()? onDone,
    bool autoCancel = true,
  }) {
    // Cancel existing listener with same ID
    cancelListener(listenerId);

    final subscription = stream.listen(
      onData,
      onError: onError ?? (error) {
        debugPrint('Listener error for $listenerId: $error');
      },
      onDone: onDone,
      cancelOnError: false,
    );

    _activeListeners[listenerId] = subscription;
    _listenerTimestamps[listenerId] = DateTime.now();

    if (autoCancel) {
      // Auto-cancel after 30 minutes of inactivity (configurable)
      Timer(const Duration(minutes: 30), () {
        if (_activeListeners.containsKey(listenerId)) {
          debugPrint('Auto-cancelling inactive listener: $listenerId');
          cancelListener(listenerId);
        }
      });
    }

    return subscription;
  }

  /// Cancel a specific listener
  void cancelListener(String listenerId) {
    final subscription = _activeListeners.remove(listenerId);
    if (subscription != null) {
      subscription.cancel();
      _listenerTimestamps.remove(listenerId);
      debugPrint('Cancelled listener: $listenerId');
    }
  }

  /// Cancel all listeners
  void cancelAllListeners() {
    for (final entry in _activeListeners.entries) {
      entry.value.cancel();
      debugPrint('Cancelled listener: ${entry.key}');
    }
    _activeListeners.clear();
    _listenerTimestamps.clear();
  }

  /// Get cached data or fetch if not cached/expired
  Future<T?> getCachedOrFetch<T>({
    required String cacheKey,
    required Future<T?> Function() fetchFunction,
    Duration? cacheDuration,
  }) async {
    final duration = cacheDuration ?? _cacheValidDuration;
    
    // Check cache
    if (_cache.containsKey(cacheKey)) {
      final cached = _cache[cacheKey]!;
      if (DateTime.now().difference(cached.timestamp) < duration) {
        return cached.data as T?;
      } else {
        _cache.remove(cacheKey);
      }
    }

    // Fetch and cache
    try {
      final data = await fetchFunction();
      if (data != null) {
        _cache[cacheKey] = CachedData(
          data: data,
          timestamp: DateTime.now(),
        );
      }
      return data;
    } catch (e) {
      debugPrint('Error fetching data for cache key $cacheKey: $e');
      return null;
    }
  }

  /// Clear specific cache entry
  void clearCache(String cacheKey) {
    _cache.remove(cacheKey);
  }

  /// Clear all cache
  void clearAllCache() {
    _cache.clear();
  }

  /// Get listener statistics
  Map<String, dynamic> getListenerStats() {
    return {
      'activeListeners': _activeListeners.length,
      'listenerIds': _activeListeners.keys.toList(),
      'cacheSize': _cache.length,
      'cacheKeys': _cache.keys.toList(),
    };
  }

  @override
  void onClose() {
    cancelAllListeners();
    clearAllCache();
    super.onClose();
  }
}

/// Internal class for cached data
class CachedData {
  final dynamic data;
  final DateTime timestamp;

  CachedData({
    required this.data,
    required this.timestamp,
  });
}

