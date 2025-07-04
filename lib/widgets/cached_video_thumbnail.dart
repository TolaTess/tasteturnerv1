import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../constants.dart';

class CachedVideoThumbnail extends StatefulWidget {
  final String videoUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  final BorderRadius? borderRadius;

  const CachedVideoThumbnail({
    super.key,
    required this.videoUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
    this.borderRadius,
  });

  @override
  State<CachedVideoThumbnail> createState() => _CachedVideoThumbnailState();
}

class _CachedVideoThumbnailState extends State<CachedVideoThumbnail> {
  String? _cachedThumbnailPath;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadThumbnail();
  }

  String _generateCacheKey(String videoUrl) {
    // Generate a unique cache key based on video URL
    final bytes = utf8.encode(videoUrl);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<void> _loadThumbnail() async {
    try {
      final cacheKey = _generateCacheKey(widget.videoUrl);
      final tempDir = await getTemporaryDirectory();
      final cacheDir = Directory('${tempDir.path}/video_thumbnails');

      if (!await cacheDir.exists()) {
        await cacheDir.create(recursive: true);
      }

      final cachedFile = File('${cacheDir.path}/$cacheKey.jpg');

      // Check if thumbnail already exists in cache
      if (await cachedFile.exists()) {
        setState(() {
          _cachedThumbnailPath = cachedFile.path;
          _isLoading = false;
        });
        return;
      }

      // Generate thumbnail if not cached
      final Uint8List? thumbnailData = await VideoThumbnail.thumbnailData(
        video: widget.videoUrl,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 400,
        quality: 75,
      );

      if (thumbnailData != null) {
        // Save to cache
        await cachedFile.writeAsBytes(thumbnailData);

        setState(() {
          _cachedThumbnailPath = cachedFile.path;
          _isLoading = false;
        });
      } else {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading video thumbnail: $e');
      setState(() {
        _hasError = true;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget content;

    if (_isLoading) {
      content = widget.placeholder ??
          Container(
            color: Colors.grey[300],
            child: const Center(
              child: CircularProgressIndicator(color: kAccent),
            ),
          );
    } else if (_hasError || _cachedThumbnailPath == null) {
      content = widget.errorWidget ??
          Container(
            color: kBlueLight.withOpacity(0.5),
            child: const Center(
              child: Icon(
                Icons.videocam,
                color: kWhite,
                size: 32,
              ),
            ),
          );
    } else {
      content = Image.file(
        File(_cachedThumbnailPath!),
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        errorBuilder: (context, error, stackTrace) {
          return widget.errorWidget ??
              Container(
                color: kBlueLight.withOpacity(0.5),
                child: const Center(
                  child: Icon(
                    Icons.videocam,
                    color: kWhite,
                    size: 32,
                  ),
                ),
              );
        },
      );
    }

    if (widget.borderRadius != null) {
      content = ClipRRect(
        borderRadius: widget.borderRadius!,
        child: content,
      );
    }

    return content;
  }
}
