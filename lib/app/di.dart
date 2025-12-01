import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:on_audio_query_pluse/on_audio_query.dart';

import '../core/logging/app_logger.dart';
import '../domain/services_interfaces/i_discovery_service.dart';
import '../domain/services_interfaces/i_device_service.dart';
import '../domain/services_interfaces/i_messaging_service.dart';
import '../domain/services_interfaces/i_playback_service.dart';
import '../domain/services_interfaces/i_role_service.dart';
import '../domain/services_interfaces/i_session_service.dart';
import '../domain/services_interfaces/i_sync_engine.dart';
import '../domain/services_interfaces/i_media_scanner_service.dart';
import '../domain/services_interfaces/i_local_storage_service.dart';
import '../domain/services_interfaces/i_audio_stream_service.dart';
import '../infrastructure/audio/just_audio_playback_service.dart';
import '../infrastructure/audio/local_media_scanner.dart';
import '../infrastructure/audio/jam_audio_handler.dart';
import '../infrastructure/audio/audio_handler_initializer.dart';
import '../infrastructure/audio/http_audio_stream_service.dart';
import '../infrastructure/network/http_messaging_service.dart';
import '../infrastructure/network/udp_discovery_service.dart';
import '../infrastructure/sync/sync_engine_impl.dart';
import '../infrastructure/application/role_service_impl.dart';
import '../infrastructure/application/session_service_impl.dart';
import '../infrastructure/application/device_service_impl.dart';
import '../infrastructure/storage/local_settings_storage.dart';

Future<void> configureDependencies({bool listenForDiscovery = true}) async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Get.isRegistered<AppLogger>()) {
    return;
  }

  Get.put<AppLogger>(AppLogger());
  await AudioHandlerInitializer.ensureInitialized(isTest: Platform.environment.containsKey('FLUTTER_TEST_ENV'));

  Get.lazyPut<IPlaybackService>(
    () => JustAudioPlaybackService(handler: Get.find<JamAudioHandler>()),
    fenix: true,
  );
  Get.lazyPut<IMessagingService>(
    () => HttpMessagingService(logger: Get.find<AppLogger>()),
    fenix: true,
  );
  Get.lazyPut<IDiscoveryService>(
    () => UdpDiscoveryService(logger: Get.find<AppLogger>()),
    fenix: true,
  );
  Get.lazyPut<ISyncEngine>(
    () => SyncEngineImpl(logger: Get.find<AppLogger>()),
    fenix: true,
  );
  Get.lazyPut<ISessionService>(
    () => SessionServiceImpl(
      messagingService: Get.find<IMessagingService>(),
      discoveryService: Get.find<IDiscoveryService>(),
      logger: Get.find<AppLogger>(),
    ),
    fenix: true,
  );
  Get.lazyPut<IRoleService>(
    () => RoleServiceImpl(
      messagingService: Get.find<IMessagingService>(),
      logger: Get.find<AppLogger>(),
    ),
    fenix: true,
  );
  Get.lazyPut<IDeviceService>(
    () => DeviceServiceImpl(logger: Get.find<AppLogger>()),
    fenix: true,
  );
  Get.lazyPut<ILocalStorageService>(
    () => LocalSettingsStorage(logger: Get.find<AppLogger>()),
    fenix: true,
  );
  Get.lazyPut<IMediaScannerService>(
    () => LocalMediaScanner(OnAudioQuery(), logger: Get.find<AppLogger>()),
    fenix: true,
  );
  Get.lazyPut<IAudioStreamService>(
    () => HttpAudioStreamService(logger: Get.find<AppLogger>()),
    fenix: true,
  );
  Get.lazyPut<JamAudioHandler>(JamAudioHandler.new, fenix: true);

  if (listenForDiscovery && !kIsWeb && !Platform.isIOS) {
    await Get.find<IDiscoveryService>().startListening();
  }
}
