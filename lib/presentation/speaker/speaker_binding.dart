import 'package:get/get.dart';

import '../../domain/services_interfaces/i_messaging_service.dart';
import '../../domain/services_interfaces/i_playback_service.dart';
import '../../domain/services_interfaces/i_sync_engine.dart';
import '../../domain/services_interfaces/i_audio_stream_service.dart';
import 'speaker_controller.dart';

class SpeakerBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<SpeakerController>(
      () => SpeakerController(
        playbackService: Get.find<IPlaybackService>(),
        syncEngine: Get.find<ISyncEngine>(),
        messagingService: Get.find<IMessagingService>(),
        audioStreamService: Get.find<IAudioStreamService>(),
      ),
    );
  }
}
