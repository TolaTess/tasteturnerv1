import 'package:flutter/material.dart';
import 'package:chewie/chewie.dart';
import 'package:video_player/video_player.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../constants.dart';
import '../helper/utils.dart';

class CachedVideoPlayer extends StatefulWidget {
  final String videoUrl;
  final bool autoPlay;
  final bool showControls;
  final bool allowFullScreen;

  const CachedVideoPlayer({
    Key? key,
    required this.videoUrl,
    this.autoPlay = false,
    this.showControls = true,
    this.allowFullScreen = true,
  }) : super(key: key);

  @override
  State<CachedVideoPlayer> createState() => _CachedVideoPlayerState();
}

class _CachedVideoPlayerState extends State<CachedVideoPlayer> {
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  bool _isInitialized = false;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializeVideoPlayer();
  }

  String _generateCacheKey(String videoUrl) {
    final bytes = utf8.encode(videoUrl);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<String> _getCachedVideoPath(String videoUrl) async {
    final cacheKey = _generateCacheKey(videoUrl);
    final tempDir = await getTemporaryDirectory();
    final cacheDir = Directory('${tempDir.path}/video_cache');

    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }

    final cachedFile = File('${cacheDir.path}/$cacheKey.mp4');

    // Check if video already exists in cache
    if (await cachedFile.exists()) {
      return cachedFile.path;
    }

    // If not cached and it's a small video, cache it
    // For now, we'll just return the original URL for streaming
    // You can implement full caching logic here if needed
    return videoUrl;
  }

  void _initializeVideoPlayer() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // For this implementation, we'll use direct streaming with local caching optimization
      // You can extend this to fully cache videos if needed
      final videoPath = await _getCachedVideoPath(widget.videoUrl);

      if (videoPath.startsWith('http')) {
        _videoPlayerController = VideoPlayerController.networkUrl(
          Uri.parse(videoPath),
        );
      } else {
        _videoPlayerController = VideoPlayerController.file(
          File(videoPath),
        );
      }

      await _videoPlayerController!.initialize();

      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController!,
        autoPlay: widget.autoPlay,
        looping: false,
        aspectRatio: _videoPlayerController!.value.aspectRatio,
        allowFullScreen: widget.allowFullScreen,
        allowMuting: true,
        showControls: widget.showControls,
        cupertinoProgressColors: ChewieProgressColors(
          playedColor: kAccent,
          handleColor: kAccent,
          backgroundColor: kWhite.withValues(alpha: 0.3),
          bufferedColor: kWhite.withValues(alpha: 0.5),
        ),
        materialProgressColors: ChewieProgressColors(
          playedColor: kAccent,
          handleColor: kAccent,
          backgroundColor: kWhite.withValues(alpha: 0.3),
          bufferedColor: kWhite.withValues(alpha: 0.5),
        ),
        placeholder: Container(
          color: Colors.black,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(color: kAccent),
                const SizedBox(height: 16),
                Text(
                  'Loading video...',
                  style: TextStyle(
                    color: kWhite,
                    fontSize: getTextScale(3, context),
                  ),
                ),
              ],
            ),
          ),
        ),
        errorBuilder: (context, errorMessage) {
          return Container(
            color: Colors.black,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: kWhite,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading video',
                    style: TextStyle(
                      color: kWhite,
                      fontSize: getTextScale(3, context),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    errorMessage,
                    style: TextStyle(
                      color: kWhite.withValues(alpha: 0.7),
                      fontSize: getTextScale(2, context),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        },
      );

      setState(() {
        _isInitialized = true;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isInitialized = false;
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  @override
  void dispose() {
    _videoPlayerController?.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        color: Colors.black.withValues(alpha: 0.5),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: kAccent),
              const SizedBox(height: 16),
              Text(
                'Loading video...',
                style: TextStyle(
                  color: kWhite,
                  fontSize: getTextScale(3, context),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_error != null || !_isInitialized || _chewieController == null) {
      return Container(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                color: kWhite,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                'Error loading video',
                style: TextStyle(
                  color: kWhite,
                  fontSize: getTextScale(3, context),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: TextStyle(
                    color: kWhite.withValues(alpha: 0.7),
                    fontSize: getTextScale(2, context),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Stack(
      children: [
        // Blurred background
        Positioned.fill(
          child: Container(
            color: Colors.black.withValues(alpha: 0.8),
          ),
        ),
        // Video player with natural aspect ratio
        Center(
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width,
              maxHeight: MediaQuery.of(context).size.height * 0.9,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Chewie(
                controller: _chewieController!,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
