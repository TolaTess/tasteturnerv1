import 'package:flutter/material.dart';
import 'cached_video_player.dart';

class VideoPlayerWidget extends StatefulWidget {
  final String videoUrl;
  final bool autoPlay;

  const VideoPlayerWidget({
    Key? key,
    required this.videoUrl,
    this.autoPlay = false,
  }) : super(key: key);

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  @override
  Widget build(BuildContext context) {
    // Use the new cached video player for better performance
    return CachedVideoPlayer(
      videoUrl: widget.videoUrl,
      autoPlay: widget.autoPlay,
      showControls: true,
      allowFullScreen: true,
    );
  }
}

// Optimized video player widget for better performance in PageViews
class OptimizedVideoPlayerWidget extends StatefulWidget {
  final String videoUrl;
  final bool autoPlay;
  final bool preload;
  final VoidCallback? onVideoLoaded;
  final VoidCallback? onVideoDisposed;
  final bool enableControls;
  final bool showLoadingIndicator;
  final Duration bufferDuration;

  const OptimizedVideoPlayerWidget({
    Key? key,
    required this.videoUrl,
    this.autoPlay = false,
    this.preload = false,
    this.onVideoLoaded,
    this.onVideoDisposed,
    this.enableControls = true,
    this.showLoadingIndicator = true,
    this.bufferDuration = const Duration(seconds: 5),
  }) : super(key: key);

  @override
  State<OptimizedVideoPlayerWidget> createState() =>
      _OptimizedVideoPlayerWidgetState();
}

class _OptimizedVideoPlayerWidgetState
    extends State<OptimizedVideoPlayerWidget> {
  @override
  Widget build(BuildContext context) {
    return CachedVideoPlayer(
      videoUrl: widget.videoUrl,
      autoPlay: widget.autoPlay,
      showControls: widget.enableControls,
      allowFullScreen: true,
      // Pass optimization settings to the cached video player
      enableAutoReplay: false, // Disable auto-replay to save bandwidth
      showAutoReplayToggle: false,
    );
  }

  @override
  void initState() {
    super.initState();
    widget.onVideoLoaded?.call();
  }

  @override
  void dispose() {
    widget.onVideoDisposed?.call();
    super.dispose();
  }
}
