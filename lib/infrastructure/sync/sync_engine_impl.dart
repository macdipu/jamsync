import 'dart:math';

import '../../core/utils/time_utils.dart';
import '../../domain/entities/control_message.dart';
import '../../domain/entities/sync_packet.dart';
import '../../domain/services_interfaces/i_playback_service.dart';
import '../../domain/services_interfaces/i_sync_engine.dart';

class SyncEngineImpl implements ISyncEngine {
  SyncEngineImpl({int Function()? nowProvider}) : _now = nowProvider ?? TimeUtils.nowMs;

  IPlaybackService? _playback;
  Duration _userOffset = Duration.zero;
  double _clockOffsetMs = 0;
  double _lastDriftMs = 0;
  final int Function() _now;

  @override
  void bindPlayback(IPlaybackService playback) {
    _playback = playback;
  }

  @override
  void onPing(ControlMessage message) {}

  @override
  void onPong(ControlMessage message) {
    final payload = message.payload;
    final sent = payload['clientTime'] as int?;
    final playerTime = payload['playerTime'] as int?;
    if (sent == null || playerTime == null) {
      return;
    }
    final now = _now();
    final rtt = max(1, now - sent);
    _clockOffsetMs = playerTime - (sent + rtt / 2);
  }

  @override
  void onSyncTick(SyncPacket packet) {
    final playback = _playback;
    if (playback == null) {
      return;
    }
    final localNow = _now();
    final estimatedPlayerNow = localNow + _clockOffsetMs;
    final timeSinceTick = estimatedPlayerNow - packet.networkTime;
    final expectedPosition = packet.position + Duration(milliseconds: timeSinceTick.toInt()) + _userOffset;

    playback.getPosition().then((actual) {
      final drift = expectedPosition - actual;
      _lastDriftMs = drift.inMilliseconds.toDouble();
      final driftMs = _lastDriftMs.abs();
      if (driftMs < 30) {
        return;
      }
      if (driftMs <= 150) {
        playback.play();
        return;
      }
      playback.seek(expectedPosition);
    });
  }

  @override
  double get lastDriftMs => _lastDriftMs;

  @override
  void setUserOffset(Duration offset) {
    _userOffset = offset;
  }
}
