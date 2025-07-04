import 'package:flutter/material.dart';
import 'package:chewie/chewie.dart';
import 'package:video_player/video_player.dart';
import '../constants.dart';
import '../helper/utils.dart';
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
