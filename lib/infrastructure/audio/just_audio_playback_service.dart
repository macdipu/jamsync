import '../../domain/entities/track.dart';
import '../../domain/services_interfaces/i_playback_service.dart';
import 'jam_audio_handler.dart';

class JustAudioPlaybackService implements IPlaybackService {
  JustAudioPlaybackService({required JamAudioHandler handler})
      : _handler = handler;

  final JamAudioHandler _handler;

  @override
  Future<void> loadTrack(Track track) => _handler.loadTrack(track);

  @override
  Future<void> pause() => _handler.pause();

  @override
  Future<void> play() => _handler.play();

  @override
  Future<Duration?> getDuration() => _handler.duration();

  @override
  Future<Duration> getPosition() => _handler.position();

  @override
  Future<void> seek(Duration position) => _handler.seek(position);

  @override
  Stream<PlaybackState> get state$ => _handler.playbackStateStream
      .map((event) => event.playing ? PlaybackState.playing : PlaybackState.paused);
}
