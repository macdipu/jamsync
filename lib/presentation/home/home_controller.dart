import 'dart:async';
import 'package:get/get.dart';

import '../../app/routes.dart';
import '../../domain/entities/device.dart';
import '../../domain/entities/session.dart';
import '../../domain/entities/session_summary.dart';
import '../../domain/services_interfaces/i_session_service.dart';
import '../../domain/services_interfaces/i_discovery_service.dart';
import '../../domain/services_interfaces/i_device_service.dart';
import '../../domain/services_interfaces/i_local_storage_service.dart';
import '../../domain/value_objects/session_config.dart';

class HomeController extends GetxController {
  HomeController({
    required ISessionService sessionService,
    IDiscoveryService? discoveryService,
    IDeviceService? deviceService,
    ILocalStorageService? localStorage,
  })  : _sessionService = sessionService,
        _discoveryService = discoveryService ?? Get.find<IDiscoveryService>(),
        _deviceService = deviceService ?? Get.find<IDeviceService>(),
        _localStorage = localStorage ?? Get.find<ILocalStorageService>();

  final ISessionService _sessionService;
  final IDiscoveryService _discoveryService;
  final IDeviceService _deviceService;
  final ILocalStorageService _localStorage;

  final sessions = <Session>[].obs;
  final isLoading = false.obs;
  final lastSession = Rxn<SessionResumeData>();

  late final StreamSubscription<List<Session>> _sessionSubscription;

  Stream<List<SessionSummary>> get discoveredSessions$ => _discoveryService.sessions$;

  @override
  void onInit() {
    super.onInit();
    _sessionSubscription = _sessionService.sessions$.listen(sessions.assignAll);
    _discoveryService.startListening();
    _loadLastSession();
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
      await _localStorage.saveSession(SessionResumeData(
        summary: SessionSummary(
          id: session.id,
          name: session.name,
          hostName: session.admin.name,
          ip: session.admin.ip,
          port: session.admin.port,
        ),
        device: admin,
      ));
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
      await _localStorage.saveSession(SessionResumeData(summary: summary, device: localDevice));
      lastSession.value = SessionResumeData(summary: summary, device: localDevice);
      Get.toNamed(Routes.session, arguments: session);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> resumeLastSession() async {
    final resumeData = lastSession.value;
    if (resumeData == null) {
      return;
    }
    await joinSession(resumeData.summary);
  }

  Future<void> _loadLastSession() async {
    final stored = await _localStorage.loadSession();
    if (stored != null) {
      lastSession.value = stored;
    }
  }
}
