import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:on_audio_query/on_audio_query.dart';

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
import '../infrastructure/audio/just_audio_playback_service.dart';
import '../infrastructure/audio/local_media_scanner.dart';
import '../infrastructure/network/socket_messaging_service.dart';
import '../infrastructure/network/udp_discovery_service.dart';
import '../infrastructure/sync/sync_engine_impl.dart';
import '../infrastructure/application/role_service_impl.dart';
import '../infrastructure/application/session_service_impl.dart';
import '../infrastructure/application/device_service_impl.dart';
import '../infrastructure/storage/local_settings_storage.dart';

Future<void> configureDependencies({bool listenForDiscovery = true}) async {
  if (Get.isRegistered<AppLogger>()) {
    return;
  }

  Get.put<AppLogger>(AppLogger());

  Get.lazyPut<IPlaybackService>(JustAudioPlaybackService.new, fenix: true);
  Get.lazyPut<IMessagingService>(SocketMessagingService.new, fenix: true);
  Get.lazyPut<IDiscoveryService>(
    () => UdpDiscoveryService(logger: Get.find<AppLogger>()),
    fenix: true,
  );
  Get.lazyPut<ISyncEngine>(SyncEngineImpl.new, fenix: true);
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
  Get.lazyPut<ILocalStorageService>(LocalSettingsStorage.new, fenix: true);
  Get.lazyPut<IMediaScannerService>(
    () => LocalMediaScanner(OnAudioQuery()),
    fenix: true,
  );

  if (listenForDiscovery && !kIsWeb && !Platform.isIOS) {
    await Get.find<IDiscoveryService>().startListening();
  }
}
