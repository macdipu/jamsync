import 'dart:async';

import 'package:get/get.dart';

import '../../domain/entities/control_message.dart';
import '../../domain/entities/session.dart';
import '../../domain/entities/sync_packet.dart';
import '../../domain/services_interfaces/i_messaging_service.dart';
import '../../domain/services_interfaces/i_playback_service.dart';
import '../../domain/services_interfaces/i_sync_engine.dart';
import '../../domain/services_interfaces/i_audio_stream_service.dart';
import '../../domain/entities/track.dart';

class SpeakerController extends GetxController {
  SpeakerController({
    required IPlaybackService playbackService,
    required ISyncEngine syncEngine,
    required IMessagingService messagingService,
    required IAudioStreamService audioStreamService,
  })  : _playbackService = playbackService,
        _syncEngine = syncEngine,
        _messagingService = messagingService,
        _audioStreamService = audioStreamService;

  final IPlaybackService _playbackService;
  final ISyncEngine _syncEngine;
  final IMessagingService _messagingService;
  final IAudioStreamService _audioStreamService;

  final currentSession = Rxn<Session>();
  final playbackState = ''.obs;
  final driftMs = 0.0.obs;
  final latencyMs = 0.obs;
  final userOffset = 0.0.obs;
  final driftHistory = <double>[].obs;
  final queue = <Track>[].obs;
  final currentTrack = Rxn<Track>();
  final streamUrl = ''.obs;
  final streamStatus = AudioStreamStatus.idle.obs;
  final isStreamConnected = false.obs;
  final _pendingPlayCommand = Rxn<Map<String, dynamic>>();

  StreamSubscription<ControlMessage>? _messageSub;
  StreamSubscription<PlaybackState>? _playbackSub;
  StreamSubscription<AudioStreamStatus>? _streamStatusSub;

  Timer? _pingTimer;

  void attachSession(Session session) {
    currentSession.value = session;
    queue.assignAll(session.queue);
    currentTrack.value = session.queue.isEmpty ? null : session.queue.first;
    _syncEngine.bindPlayback(_playbackService);
    _observePlayback();
    _observeStreamStatus();
    _subscribeToMessages(session.id);
    _startPinging();
    _requestStateSnapshot();
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
    _streamStatusSub?.cancel();
    _pingTimer?.cancel();
    _audioStreamService.stopServer();
    super.onClose();
  }

  void _observePlayback() {
    _playbackSub?.cancel();
    _playbackSub = _playbackService.state$.listen((state) {
      playbackState.value = state.name;
    });
  }

  void _observeStreamStatus() {
    _streamStatusSub?.cancel();
    _streamStatusSub = _audioStreamService.status$.listen((status) {
      streamStatus.value = status;
    });
  }

  void _subscribeToMessages(String sessionId) {
    _messageSub?.cancel();
    _messageSub = _messagingService.messages$.listen((message) {
      final targetSession = message.payload['sessionId'] as String?;
      if (message.type == MessageType.joinRequest) {
        _requestStateSnapshot();
        return;
      }
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
        case MessageType.stateResponse:
          _handleStateResponse(message.payload);
          break;
        case MessageType.streamUrl:
          _handleStreamUrl(message.payload);
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
    driftMs.value = _syncEngine.lastDriftMs;
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

        // Just update current track - wait for stream URL before loading
        currentTrack.value = track;
        break;
      case 'play':
        // If track not loaded yet, defer play command
        final duration = await _playbackService.getDuration();
        if (duration == null) {
          _pendingPlayCommand.value = payload;
          return;
        }
        await _seekToPayloadPosition(payload);
        await _playbackService.play();
        _pendingPlayCommand.value = null;
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

  Future<void> _handleStateResponse(Map<String, dynamic> payload) async {
    final isPlaying = payload['isPlaying'] as bool? ?? false;
    final positionMs = payload['positionMs'] as int?;
    final trackJson = payload['track'] as Map<String, dynamic>?;

    if (trackJson != null) {
      final track = Track.fromJson(trackJson);
      if (currentTrack.value?.id != track.id) {
        // If we have a stream URL, use it; otherwise use track's source
        final url = streamUrl.value;
        final trackToLoad = url.isNotEmpty
            ? track.copyWith(source: Uri.parse(url))
            : track;

        await _playbackService.loadTrack(trackToLoad);
        currentTrack.value = track;
      }
    }

    if (positionMs != null) {
      await _playbackService.seek(Duration(milliseconds: positionMs));
    }

    if (isPlaying) {
      await _playbackService.play();
    }
  }

  Future<void> _handleStreamUrl(Map<String, dynamic> payload) async {
    final url = payload['streamUrl'] as String?;
    if (url == null || url.isEmpty) {
      Get.log('⚠️ Received empty or null stream URL');
      return;
    }

    Get.log('✅ Received stream URL: $url');
    streamUrl.value = url;
    final track = currentTrack.value;

    if (track != null) {
      try {
        Get.log('🔄 Loading track from stream URL...');
        final streamTrack = track.copyWith(source: Uri.parse(url));
        await _playbackService.loadTrack(streamTrack);

        Get.log('✅ Track loaded from stream! Setting connection status to true');
        isStreamConnected.value = true;

        final pendingPlay = _pendingPlayCommand.value;
        if (pendingPlay != null) {
          Get.log('▶️ Executing pending play command');
          await _seekToPayloadPosition(pendingPlay);
          await _playbackService.play();
          _pendingPlayCommand.value = null;
        }
      } catch (e) {
        Get.log('❌ Failed to load track from stream: $e');
        isStreamConnected.value = false;
      }
    } else {
      Get.log('⚠️ No current track to load stream URL into');
    }
  }
}
