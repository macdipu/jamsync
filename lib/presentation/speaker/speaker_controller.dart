import 'dart:async';

import 'package:get/get.dart';

import '../../domain/entities/control_message.dart';
import '../../domain/entities/session.dart';
import '../../domain/entities/sync_packet.dart';
import '../../domain/services_interfaces/i_messaging_service.dart';
import '../../domain/services_interfaces/i_playback_service.dart';
import '../../domain/services_interfaces/i_sync_engine.dart';
import '../../domain/entities/track.dart';

class SpeakerController extends GetxController {
  SpeakerController({
    required IPlaybackService playbackService,
    required ISyncEngine syncEngine,
    required IMessagingService messagingService,
  })  : _playbackService = playbackService,
        _syncEngine = syncEngine,
        _messagingService = messagingService;

  final IPlaybackService _playbackService;
  final ISyncEngine _syncEngine;
  final IMessagingService _messagingService;

  final currentSession = Rxn<Session>();
  final playbackState = ''.obs;
  final driftMs = 0.0.obs;
  final latencyMs = 0.obs;
  final userOffset = 0.0.obs;
  final driftHistory = <double>[].obs;
  final queue = <Track>[].obs;
  final currentTrack = Rxn<Track>();

  StreamSubscription<ControlMessage>? _messageSub;
  StreamSubscription<PlaybackState>? _playbackSub;

  Timer? _pingTimer;

  void attachSession(Session session) {
    currentSession.value = session;
    queue.assignAll(session.queue);
    currentTrack.value = session.queue.isEmpty ? null : session.queue.first;
    _syncEngine.bindPlayback(_playbackService);
    _observePlayback();
    _subscribeToMessages(session.id);
    _startPinging();
    _loadInitialTrack(session);
    _requestStateSnapshot();
  }

  Future<void> _loadInitialTrack(Session session) async {
    if (session.queue.isEmpty) {
      return;
    }
    final track = session.queue.first;
    await _playbackService.loadTrack(track);
    currentTrack.value = track;
  }

  void updateDrift(Duration expected, Duration actual) {
    driftMs.value = (expected - actual).inMilliseconds.toDouble();
  }

  void setUserOffset(double offset) {
    userOffset.value = offset;
    _syncEngine.setUserOffset(Duration(milliseconds: offset.round()));
  }

  @override
  void onClose() {
    _messageSub?.cancel();
    _playbackSub?.cancel();
    _pingTimer?.cancel();
    super.onClose();
  }

  void _observePlayback() {
    _playbackSub?.cancel();
    _playbackSub = _playbackService.state$.listen((state) {
      playbackState.value = state.name;
    });
  }

  void _subscribeToMessages(String sessionId) {
    _messageSub?.cancel();
    _messageSub = _messagingService.messages$.listen((message) {
      final targetSession = message.payload['sessionId'] as String?;
      if (targetSession != sessionId) {
        return;
      }
      switch (message.type) {
        case MessageType.syncTick:
          _handleSyncTick(message.payload);
          break;
        case MessageType.queueUpdate:
          _handleQueueUpdate(message.payload['queue']);
          break;
        case MessageType.playbackCommand:
          _handlePlaybackCommand(message.payload);
          break;
        case MessageType.pong:
          _handlePong(message.payload);
          break;
        default:
          break;
      }
    });
  }

  void _handleSyncTick(Map<String, dynamic> payload) {
    final packet = SyncPacket(
      sessionId: payload['sessionId'] as String,
      trackId: payload['trackId'] as String,
      position: Duration(milliseconds: payload['positionMs'] as int),
      networkTime: payload['networkTime'] as int,
      sequence: payload['sequence'] as int,
    );
    _syncEngine.onSyncTick(packet);
    driftHistory.add(driftMs.value);
    if (driftHistory.length > 20) {
      driftHistory.removeAt(0);
    }
  }

  void _startPinging() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      final session = currentSession.value;
      if (session == null) {
        return;
      }
      final message = ControlMessage(
        type: MessageType.ping,
        payload: {
          'sessionId': session.id,
          'clientTime': DateTime.now().millisecondsSinceEpoch,
        },
      );
      await _messagingService.send(message);
    });
  }

  void _handlePong(Map<String, dynamic> payload) {
    final message = ControlMessage(
      type: MessageType.pong,
      payload: payload,
    );
    _syncEngine.onPong(message);
    final clientTime = payload['clientTime'] as int? ?? 0;
    final playerTime = payload['playerTime'] as int? ?? 0;
    latencyMs.value = (playerTime - clientTime).abs();
    driftMs.value = _syncEngine.lastDriftMs;
  }

  Future<void> _requestStateSnapshot() async {
    final session = currentSession.value;
    if (session == null) {
      return;
    }
    final message = ControlMessage(
      type: MessageType.stateRequest,
      payload: {
        'sessionId': session.id,
      },
    );
    await _messagingService.send(message);
  }

  Future<void> _handlePlaybackCommand(Map<String, dynamic> payload) async {
    final action = payload['action'] as String?;
    if (action == null) {
      return;
    }
    switch (action) {
      case 'load':
        final trackJson = payload['track'] as Map<String, dynamic>?;
        if (trackJson == null) {
          return;
        }
        final track = Track.fromJson(trackJson);
        await _playbackService.loadTrack(track);
        currentTrack.value = track;
        break;
      case 'play':
        await _seekToPayloadPosition(payload);
        await _playbackService.play();
        break;
      case 'pause':
        await _playbackService.pause();
        break;
      case 'seek':
        await _seekToPayloadPosition(payload);
        break;
    }
  }

  Future<void> _seekToPayloadPosition(Map<String, dynamic> payload) async {
    final positionMs = payload['positionMs'] as int?;
    if (positionMs == null) {
      return;
    }
    await _playbackService.seek(Duration(milliseconds: positionMs));
  }

  void _handleQueueUpdate(dynamic payload) {
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
    if (currentTrack.value == null && tracks.isNotEmpty) {
      currentTrack.value = tracks.first;
    }
  }
}
