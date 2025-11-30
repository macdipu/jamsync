import 'dart:async';

import 'package:get/get.dart';

import '../../domain/entities/device.dart';
import '../../domain/entities/session.dart';
import '../../domain/entities/track.dart';
import '../../domain/services_interfaces/i_playback_service.dart';

class PlayerController extends GetxController {
  PlayerController({
    required IPlaybackService playbackService,
  }) : _playbackService = playbackService;

  final IPlaybackService _playbackService;

  final currentSession = Rxn<Session>();
  final queue = <Track>[].obs;
  final selectedTrack = Rxn<Track>();
  final playbackPosition = Duration.zero.obs;
  final isPlaying = false.obs;

  StreamSubscription<PlaybackState>? _playbackSubscription;
  Timer? _positionTimer;

  @override
  void onClose() {
    _playbackSubscription?.cancel();
    _positionTimer?.cancel();
    super.onClose();
  }

  void attachSession(Session session) {
    currentSession.value = session;
    queue.assignAll(session.queue);
    selectedTrack.value = session.queue.isEmpty ? null : session.queue.first;
    _observePlayback();
    _startPositionPolling();
  }

  Future<void> addTrack(Track track) async {
    queue.add(track);
    final session = currentSession.value;
    if (session != null) {
      final updatedQueue = [...queue];
      currentSession.value = session.copyWith(queue: updatedQueue);
    }
    if (selectedTrack.value == null) {
      await loadTrack(track);
    }
  }

  Future<void> loadTrack(Track track) async {
    selectedTrack.value = track;
    await _playbackService.loadTrack(track);
    playbackPosition.value = Duration.zero;
  }

  Future<void> play() async {
    await _playbackService.play();
    isPlaying.value = true;
  }

  Future<void> pause() async {
    await _playbackService.pause();
    isPlaying.value = false;
  }

  Future<void> seek(Duration position) async {
    await _playbackService.seek(position);
    playbackPosition.value = position;
  }

  void removeTrack(Track track) {
    queue.remove(track);
    if (selectedTrack.value == track) {
      selectedTrack.value = queue.isEmpty ? null : queue.first;
    }
  }

  void reorderQueue(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    final track = queue.removeAt(oldIndex);
    queue.insert(newIndex, track);
    final session = currentSession.value;
    if (session != null) {
      currentSession.value = session.copyWith(queue: [...queue]);
    }
  }

  void updateMembers(List<Device> members) {
    final session = currentSession.value;
    if (session == null) {
      return;
    }
    currentSession.value = session.copyWith(members: members);
  }

  void _observePlayback() {
    _playbackSubscription?.cancel();
    _playbackSubscription = _playbackService.state$.listen((state) {
      isPlaying.value = state == PlaybackState.playing;
    });
  }

  void _startPositionPolling() {
    _positionTimer?.cancel();
    _positionTimer = Timer.periodic(const Duration(milliseconds: 500), (_) async {
      final position = await _playbackService.getPosition();
      playbackPosition.value = position;
    });
  }
}
