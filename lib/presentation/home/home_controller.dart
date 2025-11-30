import 'package:collection/collection.dart';
import 'package:get/get.dart';

import '../../app/routes.dart';
import '../../domain/entities/device.dart';
import '../../domain/entities/session.dart';
import '../../domain/services_interfaces/i_session_service.dart';
import '../../domain/services_interfaces/i_discovery_service.dart';

class HomeController extends GetxController {
  HomeController({required ISessionService sessionService})
      : _sessionService = sessionService;

  final ISessionService _sessionService;

  final sessions = <Session>[].obs;
  final isLoading = false.obs;

  late final Stream<List<Session>> _sessionStream;

  @override
  void onInit() {
    super.onInit();
    _sessionStream = _sessionService.sessions$;
    ever<List<Session>>(sessions, (_) {});
    _sessionStream.listen(sessions.assignAll);
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
      final session = sessions.firstWhereOrNull((element) => element.id == summary.id);
      if (session != null) {
        Get.toNamed(Routes.session, arguments: session);
      }
    } finally {
      isLoading.value = false;
    }
  }
}
