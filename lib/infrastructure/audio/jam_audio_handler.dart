import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';

import '../../domain/entities/track.dart';

class JamAudioHandler extends BaseAudioHandler with SeekHandler {
  JamAudioHandler() {
    _player.playbackEventStream.listen(_broadcastState);
    _player.playerStateStream.listen(_onPlayerStateChanged);
  }

  final AudioPlayer _player = AudioPlayer();
  MediaItem? _currentMediaItem;

  Future<void> loadTrack(Track track) async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
    final item = _toMediaItem(track);
    _currentMediaItem = item;
    mediaItem.add(item);
    queue.add([item]);

    await _player.setAudioSource(
      AudioSource.uri(
        track.source,
        tag: item,
      ),
    );

    playbackState.add(playbackState.value.copyWith(
      processingState: AudioProcessingState.ready,
    ));
  }

  Future<Duration> position() async => _player.position;

  Future<Duration?> duration() async => _player.duration;

  @override
  Future<void> play() async {
    await _player.play();
  }

  @override
  Future<void> pause() async {
    await _player.pause();
  }

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  Stream<PlaybackState> get playbackStateStream => playbackState;

  Stream<bool> get loopingStream =>
      _player.loopModeStream.map((mode) => mode == LoopMode.one);

  Future<void> setLoopMode(bool looping) =>
      _player.setLoopMode(looping ? LoopMode.one : LoopMode.off);

  MediaItem? get currentMediaItem => _currentMediaItem;

  MediaItem _toMediaItem(Track track) {
    return MediaItem(
      id: track.id,
      title: track.title,
      artist: track.artist,
      duration: track.duration,
      extras: track.toJson(),
    );
  }

  void _broadcastState(PlaybackEvent event) {
    final playing = _player.playing;
    playbackState.add(
      PlaybackState(
        controls: [
          MediaControl.skipToPrevious,
          if (playing) MediaControl.pause else MediaControl.play,
          MediaControl.skipToNext,
          MediaControl.stop,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.play,
          MediaAction.pause,
        },
        androidCompactActionIndices: const [1],
        processingState: _mapProcessingState(event.processingState),
        playing: playing,
        updatePosition: event.updatePosition,
        bufferedPosition: event.bufferedPosition,
        speed: _player.speed,
        updateTime: DateTime.now(),
      ),
    );
  }

  void _onPlayerStateChanged(PlayerState state) {
    if (state.processingState == ProcessingState.completed) {
      playbackState.add(
        playbackState.value.copyWith(playing: false, processingState: AudioProcessingState.completed),
      );
    }
  }

  AudioProcessingState _mapProcessingState(ProcessingState state) {
    switch (state) {
      case ProcessingState.idle:
        return AudioProcessingState.idle;
      case ProcessingState.loading:
        return AudioProcessingState.loading;
      case ProcessingState.buffering:
        return AudioProcessingState.buffering;
      case ProcessingState.ready:
        return AudioProcessingState.ready;
      case ProcessingState.completed:
        return AudioProcessingState.completed;
    }
  }
}
