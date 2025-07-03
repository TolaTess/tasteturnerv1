import 'package:cloud_functions/cloud_functions.dart';
import 'package:get/get.dart';

class PostService extends GetxService {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  // Cache management
  final Map<String, PostFeedCache> _feedCache = {};
  static const Duration cacheValidDuration = Duration(minutes: 5);

  // Singleton instance
  static PostService get instance => Get.find<PostService>();

  /// Efficient post feed loading with server-side filtering and pagination
  Future<PostFeedResult> getPostsFeed({
    String category = 'general',
    int limit = 24,
    String? lastPostId,
    String? excludePostId,
    bool includeBattlePosts = true,
    bool useCache = true,
  }) async {
    try {
      // Check cache first
      final cacheKey = '${category}_${limit}_${lastPostId ?? 'start'}';
      if (useCache && _feedCache.containsKey(cacheKey)) {
        final cached = _feedCache[cacheKey]!;
        if (DateTime.now().difference(cached.timestamp) < cacheValidDuration) {
          return cached.result;
        } else {
          _feedCache.remove(cacheKey);
        }
      }

      final HttpsCallable callable = _functions.httpsCallable('getPostsFeed');
      final HttpsCallableResult result = await callable.call({
        'category': category,
        'limit': limit,
        'lastPostId': lastPostId,
        'excludePostId': excludePostId,
        'includeBattlePosts': includeBattlePosts,
      });

      final data = result.data as Map<String, dynamic>;

      if (data['success'] == true) {
        final posts = (data['posts'] as List)
            .map((post) => Map<String, dynamic>.from(post))
            .toList();

        final feedResult = PostFeedResult(
          posts: posts,
          hasMore: data['hasMore'] ?? false,
          lastPostId: data['lastPostId'],
          totalFetched: data['totalFetched'] ?? 0,
        );

        // Cache the result
        if (useCache) {
          _feedCache[cacheKey] = PostFeedCache(
            result: feedResult,
            timestamp: DateTime.now(),
          );
        }

        return feedResult;
      } else {
        throw Exception(data['error'] ?? 'Failed to fetch posts');
      }
    } catch (e) {
      return PostFeedResult(
        posts: [],
        hasMore: false,
        lastPostId: null,
        totalFetched: 0,
        error: e.toString(),
      );
    }
  }

  /// Get trending posts with engagement analytics
  Future<List<Map<String, dynamic>>> getTrendingPosts({
    int limit = 12,
    String timeRange = 'week', // 'day', 'week', 'month'
  }) async {
    try {
      final HttpsCallable callable =
          _functions.httpsCallable('getTrendingPosts');
      final HttpsCallableResult result = await callable.call({
        'limit': limit,
        'timeRange': timeRange,
      });

      final data = result.data as Map<String, dynamic>;

      if (data['success'] == true) {
        return (data['posts'] as List)
            .map((post) => Map<String, dynamic>.from(post))
            .toList();
      } else {
        throw Exception(data['error'] ?? 'Failed to fetch trending posts');
      }
    } catch (e) {
      return [];
    }
  }

  /// Get posts by multiple categories efficiently
  Future<List<Map<String, dynamic>>> getPostsByCategory({
    List<String> categories = const ['general'],
    int limit = 20,
    bool includeUserData = true,
  }) async {
    try {
      final HttpsCallable callable =
          _functions.httpsCallable('getPostsByCategory');
      final HttpsCallableResult result = await callable.call({
        'categories': categories,
        'limit': limit,
        'includeUserData': includeUserData,
      });

      final data = result.data as Map<String, dynamic>;

      if (data['success'] == true) {
        return (data['posts'] as List)
            .map((post) => Map<String, dynamic>.from(post))
            .toList();
      } else {
        throw Exception(data['error'] ?? 'Failed to fetch posts by category');
      }
    } catch (e) {
      return [];
    }
  }

  /// Clear cache (useful for refresh)
  void clearCache() {
    _feedCache.clear();
  }

  /// Clear specific category cache
  void clearCategoryCache(String category) {
    _feedCache.removeWhere((key, value) => key.startsWith(category));
  }

  /// Get user-specific posts efficiently with server-side processing
  Future<PostFeedResult> getUserPosts({
    required String userId,
    int limit = 30,
    String? lastPostId,
    bool includeUserData = true,
    bool useCache = true,
  }) async {
    try {
      // Check cache first
      final cacheKey = 'user_${userId}_${limit}_${lastPostId ?? 'start'}';
      if (useCache && _feedCache.containsKey(cacheKey)) {
        final cached = _feedCache[cacheKey]!;
        if (DateTime.now().difference(cached.timestamp) < cacheValidDuration) {
          return cached.result;
        } else {
          _feedCache.remove(cacheKey);
        }
      }

      final HttpsCallable callable = _functions.httpsCallable('getUserPosts');
      final HttpsCallableResult result = await callable.call({
        'userId': userId,
        'limit': limit,
        'lastPostId': lastPostId,
        'includeUserData': includeUserData,
      });

      final data = result.data as Map<String, dynamic>;

      if (data['success'] == true) {
        final posts = (data['posts'] as List)
            .map((post) => Map<String, dynamic>.from(post))
            .toList();

        final feedResult = PostFeedResult(
          posts: posts,
          hasMore: data['hasMore'] ?? false,
          lastPostId: data['lastPostId'],
          totalFetched: data['totalFetched'] ?? 0,
        );

        // Cache the result
        if (useCache) {
          _feedCache[cacheKey] = PostFeedCache(
            result: feedResult,
            timestamp: DateTime.now(),
          );
        }

        return feedResult;
      } else {
        throw Exception(data['error'] ?? 'Failed to fetch user posts');
      }
    } catch (e) {
      return PostFeedResult(
        posts: [],
        hasMore: false,
        lastPostId: null,
        totalFetched: 0,
        error: e.toString(),
      );
    }
  }

  /// Clear user-specific cache
  void clearUserCache(String userId) {
    _feedCache.removeWhere((key, value) => key.startsWith('user_$userId')); 
  }

  /// Get cache status for debugging
  Map<String, dynamic> getCacheStatus() {
    return {
      'totalCachedFeeds': _feedCache.length,
      'cacheKeys': _feedCache.keys.toList(),
      'validCaches': _feedCache.entries
          .where((entry) =>
              DateTime.now().difference(entry.value.timestamp) <
              cacheValidDuration)
          .length,
    };
  }
}

/// Data classes for type safety
class PostFeedResult {
  final List<Map<String, dynamic>> posts;
  final bool hasMore;
  final String? lastPostId;
  final int totalFetched;
  final String? error;

  PostFeedResult({
    required this.posts,
    required this.hasMore,
    this.lastPostId,
    required this.totalFetched,
    this.error,
  });

  bool get isSuccess => error == null;
}

class PostFeedCache {
  final PostFeedResult result;
  final DateTime timestamp;

  PostFeedCache({
    required this.result,
    required this.timestamp,
  });
}

/// Extension for easy pagination
extension PostFeedPagination on PostFeedResult {
  /// Load next page of posts
  Future<PostFeedResult> loadNextPage({
    String category = 'general',
    int limit = 24,
    String? excludePostId,
    bool includeBattlePosts = true,
  }) async {
    if (!hasMore || lastPostId == null) {
      return PostFeedResult(
        posts: [],
        hasMore: false,
        lastPostId: lastPostId,
        totalFetched: 0,
      );
    }

    return PostService.instance.getPostsFeed(
      category: category,
      limit: limit,
      lastPostId: lastPostId,
      excludePostId: excludePostId,
      includeBattlePosts: includeBattlePosts,
      useCache: false, // Don't cache pagination results
    );
  }

  /// Combine with another page result
  PostFeedResult combine(PostFeedResult other) {
    return PostFeedResult(
      posts: [...posts, ...other.posts],
      hasMore: other.hasMore,
      lastPostId: other.lastPostId,
      totalFetched: totalFetched + other.totalFetched,
    );
  }
}
