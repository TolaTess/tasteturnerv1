import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:flutter/material.dart' show debugPrint;
import '../constants.dart';

/// Service to cache AI responses to avoid regenerating same content
/// 
/// Caches responses by:
/// - Prompt hash (for identical prompts)
/// - Operation type
/// - TTL-based expiration
class AICacheService extends GetxController {
  static AICacheService get instance {
    try {
      return Get.find<AICacheService>();
    } catch (e) {
      return Get.put(AICacheService());
    }
  }

  // In-memory cache
  final Map<String, CachedAIResponse> _memoryCache = {};
  static const Duration _memoryCacheTTL = Duration(hours: 1);

  /// Get cached response or null if not found/expired
  Future<Map<String, dynamic>?> getCachedResponse({
    required String operation,
    required String prompt,
    String? userId,
  }) async {
    try {
      final cacheKey = _generateCacheKey(operation, prompt);
      
      // Check memory cache first
      if (_memoryCache.containsKey(cacheKey)) {
        final cached = _memoryCache[cacheKey]!;
        if (DateTime.now().difference(cached.timestamp) < _memoryCacheTTL) {
          debugPrint('AI cache hit (memory): $operation');
          return cached.response;
        } else {
          _memoryCache.remove(cacheKey);
        }
      }

      // Check Firestore cache if userId provided
      if (userId != null && userId.isNotEmpty) {
        final firestoreCache = await _getFirestoreCache(cacheKey, userId);
        if (firestoreCache != null) {
          // Also update memory cache
          _memoryCache[cacheKey] = CachedAIResponse(
            response: firestoreCache,
            timestamp: DateTime.now(),
          );
          debugPrint('AI cache hit (Firestore): $operation');
          return firestoreCache;
        }
      }

      return null;
    } catch (e) {
      debugPrint('Error getting cached response: $e');
      return null;
    }
  }

  /// Cache a response
  Future<void> cacheResponse({
    required String operation,
    required String prompt,
    required Map<String, dynamic> response,
    String? userId,
    Duration? ttl,
  }) async {
    try {
      final cacheKey = _generateCacheKey(operation, prompt);
      final expiration = DateTime.now().add(ttl ?? const Duration(days: 7));

      // Cache in memory
      _memoryCache[cacheKey] = CachedAIResponse(
        response: response,
        timestamp: DateTime.now(),
      );

      // Cache in Firestore if userId provided
      if (userId != null && userId.isNotEmpty) {
        await _setFirestoreCache(cacheKey, userId, response, expiration);
      }
    } catch (e) {
      debugPrint('Error caching response: $e');
    }
  }

  /// Generate cache key from operation and prompt
  String _generateCacheKey(String operation, String prompt) {
    final normalizedPrompt = prompt.trim().toLowerCase();
    final bytes = utf8.encode('$operation:$normalizedPrompt');
    final hash = sha256.convert(bytes);
    return '${operation}_${hash.toString().substring(0, 16)}';
  }

  /// Get from Firestore cache
  Future<Map<String, dynamic>?> _getFirestoreCache(String cacheKey, String userId) async {
    try {
      final doc = await firestore
          .collection('users')
          .doc(userId)
          .collection('ai_cache')
          .doc(cacheKey)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        final expiration = (data['expiresAt'] as Timestamp?)?.toDate();
        
        if (expiration != null && expiration.isAfter(DateTime.now())) {
          return data['response'] as Map<String, dynamic>?;
        } else {
          // Expired, delete it
          await doc.reference.delete();
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error getting Firestore cache: $e');
      return null;
    }
  }

  /// Set Firestore cache
  Future<void> _setFirestoreCache(
    String cacheKey,
    String userId,
    Map<String, dynamic> response,
    DateTime expiration,
  ) async {
    try {
      await firestore
          .collection('users')
          .doc(userId)
          .collection('ai_cache')
          .doc(cacheKey)
          .set({
        'response': response,
        'expiresAt': Timestamp.fromDate(expiration),
        'cachedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error setting Firestore cache: $e');
    }
  }

  /// Clear cache for specific operation
  void clearOperationCache(String operation) {
    _memoryCache.removeWhere((key, value) => key.startsWith('${operation}_'));
  }

  /// Clear all cache
  void clearAllCache() {
    _memoryCache.clear();
  }

  /// Get cache statistics
  Map<String, dynamic> getCacheStats() {
    return {
      'memoryCacheSize': _memoryCache.length,
      'memoryCacheKeys': _memoryCache.keys.toList(),
    };
  }
}

/// Internal class for cached AI response
class CachedAIResponse {
  final Map<String, dynamic> response;
  final DateTime timestamp;

  CachedAIResponse({
    required this.response,
    required this.timestamp,
  });
}

