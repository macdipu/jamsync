import 'dart:async';

import 'package:collection/collection.dart';
import 'package:get/get.dart';

import '../../core/utils/time_utils.dart';
import '../../domain/entities/control_message.dart';
import '../../domain/entities/device.dart';
import '../../domain/entities/session.dart';
import '../../domain/entities/sync_packet.dart';
import '../../domain/entities/track.dart';
import '../../domain/services_interfaces/i_messaging_service.dart';
import '../../domain/services_interfaces/i_playback_service.dart';

class PlayerController extends GetxController {
  PlayerController({
    required IPlaybackService playbackService,
    required IMessagingService messagingService,
  })  : _playbackService = playbackService,
        _messagingService = messagingService;

  final IPlaybackService _playbackService;
  final IMessagingService _messagingService;

  final currentSession = Rxn<Session>();
  final queue = <Track>[].obs;
  final selectedTrack = Rxn<Track>();
  final playbackPosition = Duration.zero.obs;
  final isPlaying = false.obs;

  StreamSubscription<PlaybackState>? _playbackSubscription;
  StreamSubscription<ControlMessage>? _messageSubscription;
  Timer? _positionTimer;
  Timer? _syncTimer;

  @override
  void onClose() {
    _playbackSubscription?.cancel();
    _messageSubscription?.cancel();
    _positionTimer?.cancel();
    _syncTimer?.cancel();
    super.onClose();
  }

  void attachSession(Session session) {
    currentSession.value = session;
    queue.assignAll(session.queue);
    selectedTrack.value = session.queue.isEmpty ? null : session.queue.first;
    _observePlayback();
    _startPositionPolling();
    _subscribeToMessages(session.id);
    _startSyncTicks();
  }

  Future<void> addTrack(Track track) async {
    queue.add(track);
    final session = currentSession.value;
    if (session != null) {
      final updatedQueue = [...queue];
      currentSession.value = session.copyWith(queue: updatedQueue);
      await _broadcastQueue();
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
    unawaited(_broadcastQueue());
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
      unawaited(_broadcastQueue());
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

  void _startSyncTicks() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      final session = currentSession.value;
      final track = selectedTrack.value;
      if (session == null || track == null) {
        return;
      }
      final position = await _playbackService.getPosition();
      final packet = SyncPacket(
        sessionId: session.id,
        trackId: track.id,
        position: position,
        networkTime: TimeUtils.nowMs(),
        sequence: TimeUtils.nowMs(),
      );
      final message = ControlMessage(
        type: MessageType.syncTick,
        payload: {
          'sessionId': packet.sessionId,
          'trackId': packet.trackId,
          'positionMs': packet.position.inMilliseconds,
          'networkTime': packet.networkTime,
          'sequence': packet.sequence,
        },
      );
      await _messagingService.send(message);
    });
  }

  void _subscribeToMessages(String sessionId) {
    _messageSubscription?.cancel();
    _messageSubscription = _messagingService.messages$.listen((message) {
      final targetSession = message.payload['sessionId'] as String?;
      if (targetSession != sessionId) {
        return;
      }
      switch (message.type) {
        case MessageType.queueUpdate:
          _applyQueueUpdate(message.payload['queue']);
          break;
        case MessageType.roleChange:
          _applyRoleChange(message.payload);
          break;
        case MessageType.ping:
          _handlePing(message.payload);
          break;
        default:
          break;
      }
    });
  }

  Future<void> _handlePing(Map<String, dynamic> payload) async {
    final session = currentSession.value;
    if (session == null) {
      return;
    }
    final message = ControlMessage(
      type: MessageType.pong,
      payload: {
        'sessionId': session.id,
        'clientTime': payload['clientTime'],
        'playerTime': TimeUtils.nowMs(),
      },
    );
    await _messagingService.send(message);
  }

  void _applyQueueUpdate(dynamic payload) {
    if (payload is! List) {
      return;
    }
    final tracks = payload
        .cast<Map<String, dynamic>>()
        .map(Track.fromJson)
        .toList();
    queue.assignAll(tracks);
    final session = currentSession.value;
    if (session != null) {
      currentSession.value = session.copyWith(queue: tracks);
    }
    if (selectedTrack.value == null && tracks.isNotEmpty) {
      selectedTrack.value = tracks.first;
    }
  }

  void _applyRoleChange(Map<String, dynamic> payload) {
    final session = currentSession.value;
    if (session == null) {
      return;
    }
    final members = [...session.members];
    final String? newPlayerId = payload['newPlayerId'] as String?;
    final String? speakerId = payload['speakerId'] as String?;
    if (newPlayerId != null) {
      final updatedMembers = members
          .map((device) => device.copyWith(role: device.id == newPlayerId ? DeviceRole.player : DeviceRole.speaker))
          .toList();
      final newPlayer = updatedMembers.firstWhereOrNull((device) => device.id == newPlayerId);
      currentSession.value = session.copyWith(player: newPlayer, members: updatedMembers);
      return;
    }
    if (speakerId != null) {
      final updatedMembers = members
          .map((device) => device.id == speakerId ? device.copyWith(role: DeviceRole.speaker) : device)
          .toList();
      currentSession.value = session.copyWith(members: updatedMembers);
    }
  }

  Future<void> _broadcastQueue() async {
    final session = currentSession.value;
    if (session == null) {
      return;
    }
    final message = ControlMessage(
      type: MessageType.queueUpdate,
      payload: {
        'sessionId': session.id,
        'queue': queue.map((track) => track.toJson()).toList(),
      },
    );
    await _messagingService.send(message);
  }
}
