import 'package:get/get.dart';

import '../../domain/services_interfaces/i_messaging_service.dart';
import '../../domain/services_interfaces/i_playback_service.dart';
import '../../domain/services_interfaces/i_audio_stream_service.dart';
import 'player_controller.dart';

class PlayerBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<PlayerController>(
      () => PlayerController(
        playbackService: Get.find<IPlaybackService>(),
        messagingService: Get.find<IMessagingService>(),
        audioStreamService: Get.find<IAudioStreamService>(),
      ),
    );
  }
}
