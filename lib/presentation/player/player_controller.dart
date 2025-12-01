import 'dart:async';

import 'package:get/get.dart';

import '../../core/utils/time_utils.dart';
import '../../domain/entities/control_message.dart';
import '../../domain/entities/device.dart';
import '../../domain/entities/session.dart';
import '../../domain/entities/sync_packet.dart';
import '../../domain/entities/track.dart';
import '../../domain/services_interfaces/i_messaging_service.dart';
import '../../domain/services_interfaces/i_playback_service.dart';
import '../../domain/services_interfaces/i_media_scanner_service.dart';
import '../../domain/services_interfaces/i_audio_stream_service.dart';

class PlayerController extends GetxController {
  PlayerController({
    required IPlaybackService playbackService,
    required IMessagingService messagingService,
    required IAudioStreamService audioStreamService,
    IMediaScannerService? mediaScannerService,
  })  : _playbackService = playbackService,
        _messagingService = messagingService,
        _audioStreamService = audioStreamService,
        _mediaScannerService = mediaScannerService ?? Get.find<IMediaScannerService>();

  final IPlaybackService _playbackService;
  final IMessagingService _messagingService;
  final IAudioStreamService _audioStreamService;
  final IMediaScannerService _mediaScannerService;

  final currentSession = Rxn<Session>();
  final queue = <Track>[].obs;
  final selectedTrack = Rxn<Track>();
  final playbackPosition = Duration.zero.obs;
  final isPlaying = false.obs;
  final errorMessage = RxnString();
  final isScanning = false.obs;
  final isLooping = false.obs;
  final streamUrl = ''.obs;

  StreamSubscription<PlaybackState>? _playbackSubscription;
  StreamSubscription<bool>? _loopSubscription;
  StreamSubscription<ControlMessage>? _messageSubscription;
  Timer? _positionTimer;
  Timer? _syncTimer;

  @override
  void onClose() {
    _playbackSubscription?.cancel();
    _messageSubscription?.cancel();
    _loopSubscription?.cancel();
    _positionTimer?.cancel();
    _syncTimer?.cancel();
    _audioStreamService.stopServer();
    super.onClose();
  }

  void attachSession(Session session) async {
    currentSession.value = session;
    queue.assignAll(session.queue);
    selectedTrack.value = session.queue.isEmpty ? null : session.queue.first;
    _observePlayback();

    // Start HTTP audio stream server
    try {
      await _audioStreamService.startServer(port: 8888);
    } catch (e) {
      // Server might already be running
    }

    _subscribeToMessages(session.id);
    _startSyncTicks();
    _observeLoopMode();
    unawaited(scanLocalLibrary());
  }

  Future<void> scanLocalLibrary() async {
    if (isScanning.value) {
      return;
    }
    isScanning.value = true;
    try {
      final localTracks = await _mediaScannerService.scanLibrary();
      for (final local in localTracks) {
        final track = Track(
          id: local.id,
          title: local.title,
          artist: local.artist,
          source: local.uri,
          duration: local.duration,
        );
        if (!queue.any((existing) => existing.id == track.id)) {
          queue.add(track);
        }
      }
      if (queue.isNotEmpty && selectedTrack.value == null) {
        await loadTrack(queue.first);
      }
      await _broadcastQueueSafely();
    } finally {
      isScanning.value = false;
    }
  }

  Future<void> addTrack(Track track) async {
    queue.add(track);
    final session = currentSession.value;
    if (session != null) {
      final updatedQueue = [...queue];
      currentSession.value = session.copyWith(queue: updatedQueue);
      await _broadcastQueueSafely();
    }
    if (selectedTrack.value == null) {
      await loadTrack(track);
    }
  }

  Future<void> loadTrack(Track track) async {
    selectedTrack.value = track;
    await _playbackService.loadTrack(track);
    playbackPosition.value = Duration.zero;

    // Stream the track via HTTP and broadcast URL to all devices
    try {
      final url = await _audioStreamService.streamTrack(track);
      streamUrl.value = url;

      Get.log('🎵 Stream URL generated: $url');

      // Broadcast stream URL to all connected devices
      final session = currentSession.value;
      if (session != null) {
        Get.log('📡 Broadcasting stream URL to all devices in session ${session.id}');
        await _messagingService.send(ControlMessage(
          type: MessageType.streamUrl,
          payload: {
            'sessionId': session.id,
            'streamUrl': url,
          },
        ));
        Get.log('✅ Stream URL broadcast complete');
      }
    } catch (e) {
      // Stream setup failed - continue without streaming
      Get.log('❌ Failed to setup audio stream: $e');
      errorMessage.value = 'Failed to setup audio stream: $e';
    }

    await _broadcastPlaybackCommand(
      'load',
      {
        'track': track.toJson(),
        'positionMs': 0,
      },
    );
    isPlaying.value = false;
  }

  Future<void> play() async {
    await _playbackService.play();
    isPlaying.value = true;
    await _broadcastPlaybackCommand('play', {
      'positionMs': playbackPosition.value.inMilliseconds,
    });
  }

  Future<void> pause() async {
    await _playbackService.pause();
    isPlaying.value = false;
    await _broadcastPlaybackCommand('pause', {
      'positionMs': playbackPosition.value.inMilliseconds,
    });
  }

  Future<void> seek(Duration position) async {
    await _playbackService.seek(position);
    playbackPosition.value = position;
    await _broadcastPlaybackCommand('seek', {
      'positionMs': position.inMilliseconds,
    });
  }

  void removeTrack(Track track) {
    queue.remove(track);
    if (selectedTrack.value == track) {
      selectedTrack.value = queue.isEmpty ? null : queue.first;
    }
    unawaited(_broadcastQueueSafely());
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
      unawaited(_broadcastQueueSafely());
    }
  }

  void updateMembers(List<Device> members) {
    final session = currentSession.value;
    if (session == null) {
      return;
    }
    currentSession.value = session.copyWith(members: members);
  }

  void _observeLoopMode() {
    _loopSubscription?.cancel();
    _loopSubscription = _playbackService.looping$.listen((value) {
      isLooping.value = value;
    });
  }

  void _observePlayback() {
    _positionTimer?.cancel();
    _playbackSubscription?.cancel();
    _playbackSubscription = _playbackService.state$.listen((state) {
      isPlaying.value = state == PlaybackState.playing;
    });
  }

  Future<void> toggleLoop() async {
    final next = !isLooping.value;
    await _playbackService.setLoopMode(next);
    isLooping.value = next;
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
        case MessageType.stateRequest:
          _handleStateRequest(message.payload);
          break;
        default:
          break;
      }
    });
  }

  Future<void> _handleStateRequest(Map<String, dynamic> payload) async {
    final session = currentSession.value;
    final track = selectedTrack.value;
    if (session == null || track == null) {
      return;
    }
    final position = await _playbackService.getPosition();
    final commands = [
      ControlMessage(
        type: MessageType.queueUpdate,
        payload: {
          'sessionId': session.id,
          'queue': queue.map((t) => t.toJson()).toList(),
        },
      ),
      ControlMessage(
        type: MessageType.playbackCommand,
        payload: {
          'sessionId': session.id,
          'action': 'load',
          'track': track.toJson(),
          'positionMs': position.inMilliseconds,
        },
      ),
      // Send stream URL if available
      if (streamUrl.value.isNotEmpty)
        ControlMessage(
          type: MessageType.streamUrl,
          payload: {
            'sessionId': session.id,
            'streamUrl': streamUrl.value,
          },
        ),
      ControlMessage(
        type: MessageType.playbackCommand,
        payload: {
          'sessionId': session.id,
          'action': isPlaying.value ? 'play' : 'pause',
          'positionMs': position.inMilliseconds,
        },
      ),
    ];
    for (final command in commands) {
      await _messagingService.send(command);
    }
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

  Future<void> _broadcastQueueSafely() async {
    try {
      await _broadcastQueue();
    } catch (error) {
      errorMessage.value = 'Failed to sync queue: $error';
      Get.snackbar('Queue sync', errorMessage.value!, snackPosition: SnackPosition.BOTTOM);
    }
  }

  Future<void> _broadcastPlaybackCommand(String action, Map<String, dynamic> extraPayload) async {
    final session = currentSession.value;
    if (session == null) {
      return;
    }
    final message = ControlMessage(
      type: MessageType.playbackCommand,
      payload: {
        'sessionId': session.id,
        'action': action,
        ...extraPayload,
      },
    );
    await _messagingService.send(message);
  }
}
