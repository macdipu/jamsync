import 'package:audio_service/audio_service.dart';
import 'package:get/get.dart';

import 'jam_audio_handler.dart';

class AudioHandlerInitializer {
  AudioHandlerInitializer._();
  static Future<void> ensureInitialized() async {
    if (Get.isRegistered<JamAudioHandler>()) {
      return;
    }
    final handler = await AudioService.init(
      builder: JamAudioHandler.new,
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'jamsync.playback',
        androidNotificationChannelName: 'jamSync Playback',
        androidNotificationOngoing: false,
        androidStopForegroundOnPause: true,
      ),
    );
    Get.put<JamAudioHandler>(handler, permanent: true);
  }
}
