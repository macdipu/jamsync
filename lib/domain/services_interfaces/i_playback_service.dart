import '../entities/track.dart';

enum PlaybackState { stopped, playing, paused, buffering }

abstract class IPlaybackService {
  Future<void> loadTrack(Track track);
  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);
  Future<Duration> getPosition();
  Future<Duration?> getDuration();
  Stream<PlaybackState> get state$;
  Future<void> setLoopMode(bool looping);
  Stream<bool> get looping$;
}
