import 'package:audioplayers/audioplayers.dart';

/// Lazy-loaded audio service to avoid initializing AudioPlayer at startup
class AudioService {
  static AudioPlayer? _player;

  /// Get the audio player instance, creating it lazily when first accessed
  static AudioPlayer get player {
    _player ??= AudioPlayer();
    return _player!;
  }

  /// Dispose the audio player when no longer needed
  static void dispose() {
    _player?.dispose();
    _player = null;
  }

  /// Check if audio player is initialized
  static bool get isInitialized => _player != null;
}
