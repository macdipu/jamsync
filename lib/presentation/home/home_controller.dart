import 'dart:async';
import 'package:get/get.dart';

import '../../app/routes.dart';
import '../../core/logging/app_logger.dart';
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
    AppLogger? logger,
  })  : _sessionService = sessionService,
        _discoveryService = discoveryService ?? Get.find<IDiscoveryService>(),
        _deviceService = deviceService ?? Get.find<IDeviceService>(),
        _localStorage = localStorage ?? Get.find<ILocalStorageService>(),
        _logger = logger ?? Get.find<AppLogger>();

  final ISessionService _sessionService;
  final IDiscoveryService _discoveryService;
  final IDeviceService _deviceService;
  final ILocalStorageService _localStorage;
  final AppLogger _logger;

  final sessions = <Session>[].obs;
  final isLoading = false.obs;
  final lastSession = Rxn<SessionResumeData>();

  late final StreamSubscription<List<Session>> _sessionSubscription;

  Stream<List<SessionSummary>> get discoveredSessions$ => _discoveryService.sessions$;

  @override
  void onInit() {
    super.onInit();
    _sessionSubscription = _sessionService.sessions$.listen(sessions.assignAll);
    _loadLastSession();
  }

  @override
  void onClose() {
    _sessionSubscription.cancel();
    super.onClose();
  }

  Future<void> createSession(String name, Device admin) async {
    isLoading.value = true;
    final sw = Stopwatch()..start();
    _logger.info('createSession tapped with admin=${admin.name}');
    try {
      final session = await _sessionService.createSession(name: name, admin: admin);
      _logger.info('session created (${session.id}) after ${sw.elapsedMilliseconds}ms, announcing...');
      await _sessionService.announceSession(session);
      _deviceService.cacheDevice(admin);
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
      _logger.info('createSession completed total ${sw.elapsedMilliseconds}ms');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> createSessionFromInput(String name) async {
    _logger.info('Preparing local admin device for "$name"');
    final admin = await _deviceService.createLocalDevice(role: DeviceRole.admin);
    await createSession(name, admin);
  }

  Future<void> joinSession(SessionSummary summary) async {
    isLoading.value = true;
    final sw = Stopwatch()..start();
    _logger.info('joinSession requested for ${summary.name} @ ${summary.ip}:${summary.port}');
    try {
      final localDevice = await _deviceService.createLocalDevice(role: DeviceRole.speaker);
      final session = await _sessionService.joinSession(summary, localDevice);
      _deviceService.cacheDevice(localDevice);
      await _localStorage.saveSession(SessionResumeData(summary: summary, device: localDevice));
      lastSession.value = SessionResumeData(summary: summary, device: localDevice);
      Get.toNamed(Routes.session, arguments: session);
      _logger.info('joinSession completed in ${sw.elapsedMilliseconds}ms');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> resumeLastSession() async {
    final resumeData = lastSession.value;
    if (resumeData == null) {
      _logger.info('resumeLastSession called but no cached session found');
      return;
    }
    _logger.info('Attempting to resume session ${resumeData.summary.id}');
    await joinSession(resumeData.summary);
  }

  Future<void> _loadLastSession() async {
    _logger.info('Loading cached session from storage');
    final stored = await _localStorage.loadSession();
    if (stored != null) {
      _logger.info('Cached session ${stored.summary.id} restored');
      lastSession.value = stored;
    } else {
      _logger.info('No cached session found');
    }
  }
}
