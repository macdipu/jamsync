import 'dart:async';
import 'package:get/get.dart';

import '../../app/routes.dart';
import '../../domain/entities/device.dart';
import '../../domain/entities/session.dart';
import '../../domain/entities/session_summary.dart';
import '../../domain/services_interfaces/i_session_service.dart';
import '../../domain/services_interfaces/i_discovery_service.dart';

class HomeController extends GetxController {
  HomeController({
    required ISessionService sessionService,
    IDiscoveryService? discoveryService,
  })  : _sessionService = sessionService,
        _discoveryService = discoveryService ?? Get.find<IDiscoveryService>();

  final ISessionService _sessionService;
  final IDiscoveryService _discoveryService;

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
      await _sessionService.joinSession(summary);
      final admin = Device(
        id: summary.id,
        name: summary.hostName,
        ip: summary.ip,
        port: summary.port,
        role: DeviceRole.admin,
      );
      final session = Session(
        id: summary.id,
        name: summary.name,
        admin: admin,
        player: admin,
        members: [admin],
        queue: const [],
      );
      Get.toNamed(Routes.session, arguments: session);
    } finally {
      isLoading.value = false;
    }
  }
}
