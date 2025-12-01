import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';

import '../../domain/entities/track.dart';
import '../../domain/services_interfaces/i_playback_service.dart';

class JustAudioPlaybackService implements IPlaybackService {
  JustAudioPlaybackService();

  final _player = AudioPlayer();
  bool _sessionConfigured = false;

  Future<void> _ensureSession() async {
    if (_sessionConfigured) {
      return;
    }
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
    _sessionConfigured = true;
  }

  @override
  Future<void> loadTrack(Track track) async {
    await _ensureSession();
    await _player.setUrl(track.source.toString());
  }

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> play() => _player.play();

  @override
  Future<Duration?> getDuration() async => _player.duration;

  @override
  Future<Duration> getPosition() async => _player.position;

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Stream<PlaybackState> get state$ {
    return _player.playerStateStream.map((state) {
      if (state.processingState == ProcessingState.buffering) {
        return PlaybackState.buffering;
      }
      if (state.playing) {
        return PlaybackState.playing;
      }
      return state.processingState == ProcessingState.completed
          ? PlaybackState.stopped
          : PlaybackState.paused;
    });
  }
}
