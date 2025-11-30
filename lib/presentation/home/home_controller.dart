import 'dart:async';
import 'package:get/get.dart';

import '../../app/routes.dart';
import '../../domain/entities/device.dart';
import '../../domain/entities/session.dart';
import '../../domain/entities/session_summary.dart';
import '../../domain/services_interfaces/i_session_service.dart';
import '../../domain/services_interfaces/i_discovery_service.dart';
import '../../domain/services_interfaces/i_device_service.dart';

class HomeController extends GetxController {
  HomeController({
    required ISessionService sessionService,
    IDiscoveryService? discoveryService,
    IDeviceService? deviceService,
  })  : _sessionService = sessionService,
        _discoveryService = discoveryService ?? Get.find<IDiscoveryService>(),
        _deviceService = deviceService ?? Get.find<IDeviceService>();

  final ISessionService _sessionService;
  final IDiscoveryService _discoveryService;
  final IDeviceService _deviceService;

  final sessions = <Session>[].obs;
  final isLoading = false.obs;

  late final StreamSubscription<List<Session>> _sessionSubscription;

  Stream<List<SessionSummary>> get discoveredSessions$ => _discoveryService.sessions$;

  @override
  void onInit() {
    super.onInit();
    _sessionSubscription = _sessionService.sessions$.listen(sessions.assignAll);
    _discoveryService.startListening();
  }

  @override
  void onClose() {
    _sessionSubscription.cancel();
    _discoveryService.stopListening();
    super.onClose();
  }

  Future<void> createSession(String name, Device admin) async {
    isLoading.value = true;
    try {
      final session = await _sessionService.createSession(name: name, admin: admin);
      await _sessionService.announceSession(session);
      Get.toNamed(Routes.session, arguments: session);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> joinSession(SessionSummary summary) async {
    isLoading.value = true;
    try {
      final localDevice = await _deviceService.createLocalDevice(role: DeviceRole.speaker);
      final session = await _sessionService.joinSession(summary, localDevice);
      Get.toNamed(Routes.session, arguments: session);
    } finally {
      isLoading.value = false;
    }
  }
}
