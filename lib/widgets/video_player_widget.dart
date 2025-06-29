import 'package:flutter/material.dart';
import 'package:appinio_video_player/appinio_video_player.dart';
import '../constants.dart';
import '../helper/utils.dart';

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
  late CachedVideoPlayerController _videoPlayerController;
  late CustomVideoPlayerController _customVideoPlayerController;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeVideoPlayer();
  }

  void _initializeVideoPlayer() async {
    _videoPlayerController =
        CachedVideoPlayerController.network(widget.videoUrl)
          ..initialize().then((_) {
            if (widget.autoPlay) {
              _videoPlayerController.play();
            }
            setState(() {
              _isInitialized = true;
            });
          });

    _customVideoPlayerController = CustomVideoPlayerController(
      context: context,
      videoPlayerController: _videoPlayerController,
      customVideoPlayerSettings: CustomVideoPlayerSettings(
        placeholderWidget: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                color: kAccent,
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
        settingsButtonAvailable: true,
        controlBarAvailable: true,
        showFullscreenButton: true,
        playButton: Icon(
          Icons.play_circle_fill,
          color: kWhite,
          size: getResponsiveBoxSize(context, 50, 50),
        ),
        pauseButton: Icon(
          Icons.pause_circle_filled,
          color: kWhite,
          size: getResponsiveBoxSize(context, 50, 50),
        ),
        enterFullscreenButton: Icon(
          Icons.fullscreen,
          color: kWhite,
          size: getResponsiveBoxSize(context, 30, 30),
        ),
        exitFullscreenButton: Icon(
          Icons.fullscreen_exit,
          color: kWhite,
          size: getResponsiveBoxSize(context, 30, 30),
        ),
        controlBarDecoration: BoxDecoration(
          color: kAccent.withOpacity(0.2),
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _videoPlayerController.dispose();
    _customVideoPlayerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return Container(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                color: kAccent,
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
      );
    }

    return Stack(
      children: [
        // Blurred background
        Positioned.fill(
          child: Container(
            color: Colors.black.withOpacity(0.8),
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
              child: CustomVideoPlayer(
                customVideoPlayerController: _customVideoPlayerController,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
