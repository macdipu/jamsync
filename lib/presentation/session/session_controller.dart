import 'dart:async';

import 'package:get/get.dart';

import '../../app/routes.dart';
import '../../domain/entities/device.dart';
import '../../domain/entities/session.dart';
import '../../domain/services_interfaces/i_messaging_service.dart';
import '../../domain/services_interfaces/i_role_service.dart';
import '../../domain/services_interfaces/i_session_service.dart';

class SessionController extends GetxController {
  SessionController({
    required IRoleService roleService,
    required ISessionService sessionService,
    IMessagingService? messagingService,
  })  : _roleService = roleService,
        _sessionService = sessionService,
        _messagingService = messagingService ?? Get.find<IMessagingService>();

  final IRoleService _roleService;
  final ISessionService _sessionService;
  final IMessagingService _messagingService;

  final currentSession = Rxn<Session>();
  final members = <Device>[].obs;
  final connectionState = MessagingConnectionState.disconnected.obs;
  final reconnecting = false.obs;
  final lastError = RxnString();
  Timer? _autoRetryTimer;
  MessagingConnectionState? _previousState;

  late final StreamSubscription<MessagingConnectionState> _statusSub;

  @override
  void onInit() {
    super.onInit();
    _statusSub = _messagingService.status$.listen((state) {
      final prev = _previousState;
      _previousState = state;
      connectionState.value = state;
      if (state == MessagingConnectionState.disconnected) {
        lastError.value = 'Connection lost. Retrying...';
        _scheduleAutoRetry();
        if (prev == MessagingConnectionState.connected) {
          Get.snackbar('Connection lost', 'Trying to reconnect...', snackPosition: SnackPosition.BOTTOM);
        }
      } else {
        _autoRetryTimer?.cancel();
        lastError.value = null;
        if (prev == MessagingConnectionState.disconnected) {
          Get.snackbar('Reconnected', 'Back on the network', snackPosition: SnackPosition.BOTTOM);
        }
      }
    });
  }

  @override
  void onClose() {
    _statusSub.cancel();
    _autoRetryTimer?.cancel();
    super.onClose();
  }

  void attachSession(Session session) {
    currentSession.value = session;
    members.assignAll(session.members);
  }

  void _scheduleAutoRetry() {
    _autoRetryTimer?.cancel();
    _autoRetryTimer = Timer(const Duration(seconds: 5), () async {
      await attemptReconnect(showToast: false);
    });
  }

  Future<void> attemptReconnect({bool showToast = true}) async {
    final session = currentSession.value;
    if (session == null || reconnecting.value) {
      return;
    }
    reconnecting.value = true;
    lastError.value = null;
    try {
      if (session.admin.isLocal) {
        await _sessionService.announceSession(session);
        connectionState.value = MessagingConnectionState.connected;
      } else {
        await _messagingService.connect(host: session.admin.ip, port: session.admin.port);
      }
      if (showToast) {
        Get.snackbar('Reconnected', 'jamSync is back online', snackPosition: SnackPosition.BOTTOM);
      }
    } catch (error) {
      final message = 'Reconnect failed: $error';
      lastError.value = message;
      if (showToast) {
        Get.snackbar('Reconnect failed', message, snackPosition: SnackPosition.BOTTOM);
      }
    } finally {
      reconnecting.value = false;
    }
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
