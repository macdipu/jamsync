import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:jamsync/domain/entities/control_message.dart';
import 'package:jamsync/domain/entities/sync_packet.dart';
import 'package:jamsync/domain/services_interfaces/i_playback_service.dart';
import 'package:jamsync/infrastructure/sync/sync_engine_impl.dart';

class _PlaybackMock extends Mock implements IPlaybackService {}

void main() {
  setUpAll(() {
    registerFallbackValue(Duration.zero);
  });

  group('SyncEngineImpl', () {
    test('bindPlayback assigns playback instance', () async {
      final engine = SyncEngineImpl(nowProvider: () => 1000);
      final playback = _PlaybackMock();
      engine.bindPlayback(playback);
      final message = ControlMessage(type: MessageType.pong, payload: {'clientTime': 1000, 'playerTime': 2000});
      engine.onPong(message);
      verifyNever(() => playback.seek(any()));
    });

    test('onSyncTick issues seek when drift high', () async {
      final playback = _PlaybackMock();
      when(() => playback.getPosition()).thenAnswer((_) async => const Duration(milliseconds: 0));
      when(() => playback.seek(any())).thenAnswer((_) async {});
      when(() => playback.play()).thenAnswer((_) async {});

      final engine = SyncEngineImpl(nowProvider: () => 2000)..bindPlayback(playback);
      final packet = SyncPacket(
        sessionId: 'id',
        trackId: 'track',
        position: const Duration(milliseconds: 0),
        networkTime: 1000,
        sequence: 1,
      );
      engine.onSyncTick(packet);
      await untilCalled(() => playback.seek(any()));
      verify(() => playback.seek(const Duration(milliseconds: 1000))).called(1);
    });
  });
}

