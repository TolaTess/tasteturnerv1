import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:flutter/material.dart' show debugPrint;
import '../constants.dart';

/// Service to track AI API token usage and costs
/// 
/// Tracks:
/// - Input tokens per operation
/// - Output tokens per operation
/// - Total cost per operation
/// - Per-user usage
/// - Daily/monthly aggregates
class TokenUsageService extends GetxController {
  static TokenUsageService get instance {
    try {
      return Get.find<TokenUsageService>();
    } catch (e) {
      return Get.put(TokenUsageService());
    }
  }

  // In-memory tracking for current session
  final Map<String, TokenUsage> _sessionUsage = {};

  /// Track token usage for an operation
  Future<void> trackUsage({
    required String operation,
    required int inputTokens,
    required int outputTokens,
    required String provider, // 'gemini', 'openai', 'openrouter'
    String? userId,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      // Apply 1.5x multiplier for planning mode operations
      final multiplier = (metadata?['mode'] == 'planning') ? 1.5 : 1.0;
      final adjustedInputTokens = (inputTokens * multiplier).round();
      final adjustedOutputTokens = (outputTokens * multiplier).round();
      
      final usage = TokenUsage(
        operation: operation,
        inputTokens: adjustedInputTokens,
        outputTokens: adjustedOutputTokens,
        provider: provider,
        timestamp: DateTime.now(),
        metadata: metadata ?? {},
      );

      // Update session tracking
      final sessionKey = '${operation}_${provider}';
      if (_sessionUsage.containsKey(sessionKey)) {
        final existing = _sessionUsage[sessionKey]!;
        _sessionUsage[sessionKey] = TokenUsage(
          operation: existing.operation,
          inputTokens: existing.inputTokens + inputTokens,
          outputTokens: existing.outputTokens + outputTokens,
          provider: existing.provider,
          timestamp: DateTime.now(),
          metadata: existing.metadata,
        );
      } else {
        _sessionUsage[sessionKey] = usage;
      }

      // Calculate cost (approximate)
      final cost = _calculateCost(inputTokens, outputTokens, provider);

      // Log to Firestore for analytics (async, don't block)
      if (userId != null && userId.isNotEmpty) {
        _logToFirestore(userId, usage, cost).catchError((e) {
          debugPrint('Error logging token usage to Firestore: $e');
        });
      }

      debugPrint('Token usage tracked: $operation - Input: $inputTokens, Output: $outputTokens, Cost: \$${cost.toStringAsFixed(4)}');
    } catch (e) {
      debugPrint('Error tracking token usage: $e');
    }
  }

  /// Calculate approximate cost based on provider and tokens
  double _calculateCost(int inputTokens, int outputTokens, String provider) {
    // Pricing as of 2024 (approximate, adjust as needed)
    const Map<String, Map<String, double>> pricing = {
      'gemini': {
        'input': 0.30 / 1000000, // $0.30 per 1M input tokens
        'output': 2.50 / 1000000, // $2.50 per 1M output tokens
      },
      'openai': {
        'input': 1.25 / 1000000, // $1.25 per 1M input tokens
        'output': 10.00 / 1000000, // $10.00 per 1M output tokens
      },
      'openrouter': {
        'input': 0.30 / 1000000, // Approximate
        'output': 2.50 / 1000000, // Approximate
      },
    };

    final providerPricing = pricing[provider.toLowerCase()] ?? pricing['gemini']!;
    final inputCost = (inputTokens * providerPricing['input']!);
    final outputCost = (outputTokens * providerPricing['output']!);
    
    return inputCost + outputCost;
  }

  /// Log usage to Firestore for analytics
  Future<void> _logToFirestore(String userId, TokenUsage usage, double cost) async {
    try {
      final date = DateTime.now();
      final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      
      final usageRef = firestore
          .collection('users')
          .doc(userId)
          .collection('token_usage')
          .doc();

      await usageRef.set({
        'operation': usage.operation,
        'inputTokens': usage.inputTokens,
        'outputTokens': usage.outputTokens,
        'totalTokens': usage.inputTokens + usage.outputTokens,
        'provider': usage.provider,
        'cost': cost,
        'timestamp': FieldValue.serverTimestamp(),
        'date': dateStr,
        'metadata': usage.metadata,
      });

      // Update daily aggregate
      final dailyRef = firestore
          .collection('users')
          .doc(userId)
          .collection('token_usage_daily')
          .doc(dateStr);

      await dailyRef.set({
        'date': dateStr,
        'totalInputTokens': FieldValue.increment(usage.inputTokens),
        'totalOutputTokens': FieldValue.increment(usage.outputTokens),
        'totalCost': FieldValue.increment(cost),
        'operationCount': FieldValue.increment(1),
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error logging to Firestore: $e');
    }
  }

  /// Get session usage summary
  Map<String, dynamic> getSessionSummary() {
    int totalInput = 0;
    int totalOutput = 0;
    double totalCost = 0.0;

    for (final usage in _sessionUsage.values) {
      totalInput += usage.inputTokens;
      totalOutput += usage.outputTokens;
      totalCost += _calculateCost(usage.inputTokens, usage.outputTokens, usage.provider);
    }

    return {
      'totalInputTokens': totalInput,
      'totalOutputTokens': totalOutput,
      'totalTokens': totalInput + totalOutput,
      'totalCost': totalCost,
      'operationCount': _sessionUsage.length,
      'operations': _sessionUsage.keys.toList(),
    };
  }

  /// Clear session tracking
  void clearSession() {
    _sessionUsage.clear();
  }

  /// Get daily usage for a user
  Future<Map<String, dynamic>?> getDailyUsage(String userId, DateTime date) async {
    try {
      final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final doc = await firestore
          .collection('users')
          .doc(userId)
          .collection('token_usage_daily')
          .doc(dateStr)
          .get();

      if (doc.exists) {
        return doc.data();
      }
      return null;
    } catch (e) {
      debugPrint('Error getting daily usage: $e');
      return null;
    }
  }
}

/// Data class for token usage
class TokenUsage {
  final String operation;
  final int inputTokens;
  final int outputTokens;
  final String provider;
  final DateTime timestamp;
  final Map<String, dynamic> metadata;

  TokenUsage({
    required this.operation,
    required this.inputTokens,
    required this.outputTokens,
    required this.provider,
    required this.timestamp,
    this.metadata = const {},
  });
}

