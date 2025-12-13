import 'dart:io';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart' show debugPrint;
import '../constants.dart';
import 'utils.dart';

class CacheManager {
  static const int maxCacheAge = 7; // days
  static const int maxCacheSize = 500; // MB

  /// Clear all cached images
  static Future<void> clearImageCache() async {
    try {
      await CachedNetworkImage.evictFromCache("");
      debugPrint('Image cache cleared successfully');
    } catch (e) {
      final context = Get.context;
      if (context != null) {
        showTastySnackbar(
            'Something went wrong', 'Please try again later', context,
            backgroundColor: kRed);
      }
    }
  }

  /// Clear all cached video thumbnails
  static Future<void> clearVideoThumbnailCache() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final cacheDir = Directory('${tempDir.path}/video_thumbnails');

      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
        debugPrint('Video thumbnail cache cleared successfully');
      }
    } catch (e) {
      final context = Get.context;
      if (context != null) {
        showTastySnackbar(
            'Something went wrong', 'Please try again later', context,
            backgroundColor: kRed);
      }
    }
  }

  /// Clear all cached videos
  static Future<void> clearVideoCache() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final cacheDir = Directory('${tempDir.path}/video_cache');

      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
        debugPrint('Video cache cleared successfully');
      }
    } catch (e) {
      final context = Get.context;
      if (context != null) {
        showTastySnackbar(
            'Something went wrong', 'Please try again later', context,
            backgroundColor: kRed);
      }
    }
  }

  /// Clear all cache (images, video thumbnails, and videos)
  static Future<void> clearAllCache() async {
    await Future.wait([
      clearImageCache(),
      clearVideoThumbnailCache(),
      clearVideoCache(),
    ]);
    debugPrint('All cache cleared successfully');
  }

  /// Get cache size in MB
  static Future<double> getCacheSize() async {
    try {
      double totalSize = 0;

      // Get video thumbnail cache size
      final tempDir = await getTemporaryDirectory();
      final videoThumbnailDir = Directory('${tempDir.path}/video_thumbnails');
      if (await videoThumbnailDir.exists()) {
        totalSize += await _getDirectorySize(videoThumbnailDir);
      }

      // Get video cache size
      final videoCacheDir = Directory('${tempDir.path}/video_cache');
      if (await videoCacheDir.exists()) {
        totalSize += await _getDirectorySize(videoCacheDir);
      }

      // Convert bytes to MB
      return totalSize / (1024 * 1024);
    } catch (e) {
      final context = Get.context;
      if (context != null) {
        showTastySnackbar(
            'Something went wrong', 'Please try again later', context,
            backgroundColor: kRed);
      }
      return 0;
    }
  }

  static Future<double> _getDirectorySize(Directory directory) async {
    double size = 0;

    await for (FileSystemEntity entity in directory.list(recursive: true)) {
      if (entity is File) {
        size += await entity.length();
      }
    }

    return size;
  }

  /// Clean old cache files (older than maxCacheAge days)
  static Future<void> cleanOldCache() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final now = DateTime.now();
      final cutoffDate = now.subtract(Duration(days: maxCacheAge));

      // Clean video thumbnails
      final videoThumbnailDir = Directory('${tempDir.path}/video_thumbnails');
      if (await videoThumbnailDir.exists()) {
        await _cleanOldFilesInDirectory(videoThumbnailDir, cutoffDate);
      }

      // Clean video cache
      final videoCacheDir = Directory('${tempDir.path}/video_cache');
      if (await videoCacheDir.exists()) {
        await _cleanOldFilesInDirectory(videoCacheDir, cutoffDate);
      }

      debugPrint('Old cache files cleaned successfully');
    } catch (e) {
      final context = Get.context;
      if (context != null) {
        showTastySnackbar(
            'Something went wrong', 'Please try again later', context,
            backgroundColor: kRed);
      }
    }
  }

  static Future<void> _cleanOldFilesInDirectory(
      Directory directory, DateTime cutoffDate) async {
    await for (FileSystemEntity entity in directory.list(recursive: true)) {
      if (entity is File) {
        final stat = await entity.stat();
        if (stat.modified.isBefore(cutoffDate)) {
          await entity.delete();
        }
      }
    }
  }

  /// Check if cache size exceeds limit and clean if necessary
  static Future<void> manageCacheSize() async {
    try {
      final cacheSize = await getCacheSize();

      if (cacheSize > maxCacheSize) {
        debugPrint(
            'Cache size (${cacheSize.toStringAsFixed(2)}MB) exceeds limit (${maxCacheSize}MB). Cleaning...');
        await cleanOldCache();

        // If still over limit, clear all cache
        final newCacheSize = await getCacheSize();
        if (newCacheSize > maxCacheSize) {
          debugPrint(
              'Still over limit after cleaning old files. Clearing all cache...');
          await clearAllCache();
        }
      }
    } catch (e) {
      final context = Get.context;
      if (context != null) {
        showTastySnackbar(
            'Something went wrong', 'Please try again later', context,
            backgroundColor: kRed);
      }
    }
  }
}
