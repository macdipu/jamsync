import 'package:get/get.dart';

import '../../app/routes.dart';
import '../../domain/entities/device.dart';
import '../../domain/entities/session.dart';
import '../../domain/services_interfaces/i_role_service.dart';

class SessionController extends GetxController {
  SessionController({
    required IRoleService roleService,
  }) : _roleService = roleService;

  final IRoleService _roleService;

  final currentSession = Rxn<Session>();
  final members = <Device>[].obs;

  void attachSession(Session session) {
    currentSession.value = session;
    members.assignAll(session.members);
  }

  Future<void> assignPlayer(Device device) async {
    final session = currentSession.value;
    if (session == null) {
      return;
    }
    final updated = await _roleService.assignPlayer(session, device);
    attachSession(updated);
  }

  Future<void> assignSpeaker(Device device) async {
    final session = currentSession.value;
    if (session == null) {
      return;
    }
    final updated = await _roleService.assignSpeaker(session, device);
    attachSession(updated);
  }

  void openPlayer(Device device) {
    final session = currentSession.value;
    if (session == null) {
      return;
    }
    Get.toNamed(Routes.player, arguments: session.copyWith(player: device));
  }

  void openSpeaker(Device device) {
    final session = currentSession.value;
    if (session == null) {
      return;
    }
    Get.toNamed(Routes.speaker, arguments: session.copyWith(player: device));
  }
}
