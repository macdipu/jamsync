import 'package:get/get.dart';

import '../../domain/entities/session.dart';
import '../../domain/services_interfaces/i_playback_service.dart';
import '../../domain/services_interfaces/i_sync_engine.dart';

class SpeakerController extends GetxController {
  SpeakerController({
    required IPlaybackService playbackService,
    required ISyncEngine syncEngine,
  })  : _playbackService = playbackService,
        _syncEngine = syncEngine;

  final IPlaybackService _playbackService;
  final ISyncEngine _syncEngine;

  final currentSession = Rxn<Session>();
  final playbackState = ''.obs;
  final driftMs = 0.0.obs;
  final latencyMs = 0.obs;
  final userOffset = 0.0.obs;

  void attachSession(Session session) {
    currentSession.value = session;
    _syncEngine.bindPlayback(_playbackService);
  }

  void updateDrift(Duration expected, Duration actual) {
    driftMs.value = (expected - actual).inMilliseconds.toDouble();
  }

  void setUserOffset(double offset) {
    userOffset.value = offset;
    _syncEngine.setUserOffset(Duration(milliseconds: offset.round()));
  }
}

