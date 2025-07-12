import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import '../constants.dart';

class OptimizedImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final bool isProfileImage;
  final Widget? placeholder;
  final Widget? errorWidget;

  const OptimizedImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.isProfileImage = false,
    this.placeholder,
    this.errorWidget,
  });

  @override
  Widget build(BuildContext context) {
    // Handle local file paths
    if (imageUrl.startsWith('file://') || !imageUrl.startsWith('http')) {
      return ClipRRect(
        borderRadius: borderRadius ?? BorderRadius.circular(0),
        child: Image.file(
          File(imageUrl.replaceFirst('file://', '')),
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (context, error, stackTrace) =>
              errorWidget ?? Image.asset(intPlaceholderImage, fit: fit),
        ),
      );
    }

    // Handle network images with caching
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.circular(0),
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        width: width,
        height: height,
        fit: fit,
        placeholder: (context, url) =>
            placeholder ??
            Container(
              color: Colors.grey[300],
              child: const Center(
                child: CircularProgressIndicator(
                  color: kAccent,
                ),
              ),
            ),
        errorWidget: (context, url, error) {
          // Log the error for debugging but don't spam the console
          if (error.toString().contains('403')) {
            print('🚫 Image access denied (403): ${url.split('?').first}');
          } else {
            print('❌ Image load error: ${error.toString().split('\n').first}');
          }
          return errorWidget ?? Image.asset(intPlaceholderImage, fit: fit);
        },
        memCacheWidth: isProfileImage ? 200 : 800, // Optimize memory cache size
        memCacheHeight: isProfileImage ? 200 : 800,
        maxWidthDiskCache:
            isProfileImage ? 200 : 800, // Optimize disk cache size
        maxHeightDiskCache: isProfileImage ? 200 : 800,
        fadeInDuration: const Duration(milliseconds: 300),
        fadeOutDuration: const Duration(milliseconds: 300),
      ),
    );
  }
}
