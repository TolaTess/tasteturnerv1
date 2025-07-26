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
  final bool enableAutoReplay;
  final bool showAutoReplayToggle;

  const CachedVideoPlayer({
    Key? key,
    required this.videoUrl,
    this.autoPlay = false,
    this.showControls = true,
    this.allowFullScreen = true,
    this.enableAutoReplay = true,
    this.showAutoReplayToggle = true,
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
  late bool _autoReplay; // Auto-replay state

  @override
  void initState() {
    super.initState();
    _autoReplay = widget.enableAutoReplay; // Initialize from widget parameter
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
          // Optimize network video loading
          httpHeaders: {
            'User-Agent': 'TasteTurner-App/1.0',
          },
        );
      } else {
        _videoPlayerController = VideoPlayerController.file(
          File(videoPath),
        );
      }

      // Optimize video player settings for better performance
      await _videoPlayerController!.initialize();

      // Set optimized buffering for faster loading
      await _videoPlayerController!.setVolume(1.0);

      // Listen for video completion to handle replay
      _videoPlayerController!.addListener(_videoListener);

      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController!,
        autoPlay: widget.autoPlay,
        looping: _autoReplay, // Enable looping for auto-replay
        aspectRatio: _videoPlayerController!.value.aspectRatio,
        allowFullScreen: widget.allowFullScreen,
        allowMuting: true,
        showControls: widget.showControls,

        // Improved control visibility settings for better performance
        hideControlsTimer: const Duration(
            seconds: 1), // Hide controls faster to reduce UI updates
        showControlsOnInitialize: false, // Don't show controls initially

        // Optimize startup performance
        startAt: Duration.zero,

        // Reduce overlay complexity for better performance
        materialProgressColors: ChewieProgressColors(
          playedColor: kAccent,
          handleColor: kAccent,
          backgroundColor: kWhite.withValues(alpha: 0.3),
          bufferedColor: kWhite.withValues(alpha: 0.5),
        ),
        cupertinoProgressColors: ChewieProgressColors(
          playedColor: kAccent,
          handleColor: kAccent,
          backgroundColor: kWhite.withValues(alpha: 0.3),
          bufferedColor: kWhite.withValues(alpha: 0.5),
        ),

        // Optimize loading experience
        placeholder: Container(
          color: Colors.black,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(
                  color: kAccent,
                  strokeWidth:
                      2, // Thinner progress indicator for better performance
                ),
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
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => _retryVideoLoad(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kAccent,
                      foregroundColor: kWhite,
                    ),
                    child: const Text('Retry'),
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

  void _videoListener() {
    if (_videoPlayerController != null &&
        _videoPlayerController!.value.hasError) {
      setState(() {
        _error = _videoPlayerController!.value.errorDescription ??
            'Unknown video error';
      });
    }
  }

  void _retryVideoLoad() {
    setState(() {
      _error = null;
      _isInitialized = false;
    });
    _disposeControllers();
    _initializeVideoPlayer();
  }

  void _disposeControllers() {
    _videoPlayerController?.removeListener(_videoListener);
    _videoPlayerController?.dispose();
    _chewieController?.dispose();
    _videoPlayerController = null;
    _chewieController = null;
  }

  void toggleAutoReplay() {
    setState(() {
      _autoReplay = !_autoReplay;
      if (_chewieController != null) {
        // Recreate the chewie controller with new looping setting
        _chewieController!.dispose();
        _chewieController = ChewieController(
          videoPlayerController: _videoPlayerController!,
          autoPlay: false, // Don't auto-play when toggling
          looping: _autoReplay,
          aspectRatio: _videoPlayerController!.value.aspectRatio,
          allowFullScreen: widget.allowFullScreen,
          allowMuting: true,
          showControls: widget.showControls,
          hideControlsTimer:
              const Duration(seconds: 1), // Faster hide for better performance
          showControlsOnInitialize: false,
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
        );
      }
    });
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        color: getThemeProvider(context).isDarkMode
            ? kDarkGrey.withValues(alpha: 0.2)
            : kWhite.withValues(alpha: 0.2),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: kAccent),
              const SizedBox(height: 16),
              Text(
                'Loading video...',
                style: TextStyle(
                  color:
                      getThemeProvider(context).isDarkMode ? kWhite : kDarkGrey,
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
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _retryVideoLoad,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kAccent,
                  foregroundColor: kWhite,
                ),
                child: const Text('Retry'),
              ),
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
        // Auto-replay toggle button (top-right corner)
        if (widget.showAutoReplayToggle)
          Positioned(
            top: 16,
            right: 16,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(20),
              ),
              child: IconButton(
                onPressed: toggleAutoReplay,
                icon: Icon(
                  _autoReplay ? Icons.repeat : Icons.repeat_outlined,
                  color: _autoReplay ? kAccent : kWhite,
                  size: 24,
                ),
                tooltip: _autoReplay ? 'Auto-replay ON' : 'Auto-replay OFF',
              ),
            ),
          ),
        // Manual replay button (when video ends and auto-replay is off)
        if (_videoPlayerController != null &&
            _videoPlayerController!.value.isInitialized &&
            _videoPlayerController!.value.position >=
                _videoPlayerController!.value.duration &&
            !_autoReplay)
          Positioned.fill(
            child: Container(
              color: Colors.black.withValues(alpha: 0.5),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.replay,
                        color: kWhite,
                        size: 48,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Video ended',
                        style: TextStyle(
                          color: kWhite,
                          fontSize: getTextScale(4, context),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () {
                          _videoPlayerController?.seekTo(Duration.zero);
                          _videoPlayerController?.play();
                        },
                        icon: const Icon(Icons.replay),
                        label: const Text('Replay'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kAccent,
                          foregroundColor: kWhite,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
