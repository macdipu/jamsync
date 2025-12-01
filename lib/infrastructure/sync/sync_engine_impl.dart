import 'dart:math';

import '../../core/logging/app_logger.dart';
import '../../core/utils/time_utils.dart';
import '../../domain/entities/control_message.dart';
import '../../domain/entities/sync_packet.dart';
import '../../domain/services_interfaces/i_playback_service.dart';
import '../../domain/services_interfaces/i_sync_engine.dart';

class SyncEngineImpl implements ISyncEngine {
  SyncEngineImpl({int Function()? nowProvider, AppLogger? logger})
      : _now = nowProvider ?? TimeUtils.nowMs,
        _logger = logger;

  IPlaybackService? _playback;
  Duration _userOffset = Duration.zero;
  double _clockOffsetMs = 0;
  double _lastDriftMs = 0;
  final int Function() _now;
  final AppLogger? _logger;

  @override
  void bindPlayback(IPlaybackService playback) {
    _playback = playback;
    _logger?.info('Playback bound to SyncEngine');
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
      _logger?.info('Sync tick drift: ${_lastDriftMs.toStringAsFixed(2)}ms');

      if (expectedPosition > Duration.zero) {
        if (driftMs < 30) {
          playback.play();
          return;
        }
        if (driftMs <= 150) {
          _logger?.info('Minor drift detected; nudging playback');
          playback.play();
          return;
        }
        _logger?.warn('Large drift detected (${driftMs}ms); seeking to aligned position');
        playback.seek(expectedPosition).then((_) => playback.play());
      }
    });
  }

  @override
  double get lastDriftMs => _lastDriftMs;

  @override
  void setUserOffset(Duration offset) {
    _userOffset = offset;
  }
}
