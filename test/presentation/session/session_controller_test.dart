import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:jamsync/domain/entities/device.dart';
import 'package:jamsync/domain/entities/session.dart';
import 'package:jamsync/domain/services_interfaces/i_messaging_service.dart';
import 'package:jamsync/domain/services_interfaces/i_role_service.dart';
import 'package:jamsync/domain/services_interfaces/i_session_service.dart';
import 'package:jamsync/presentation/session/session_controller.dart';

class _MessagingMock extends Mock implements IMessagingService {}

class _RoleServiceMock extends Mock implements IRoleService {}

class _SessionServiceMock extends Mock implements ISessionService {}

void main() {
  setUpAll(() {
    registerFallbackValue(_buildSession());
  });

  group('SessionController', () {
    late _MessagingMock messaging;
    late _RoleServiceMock roleService;
    late _SessionServiceMock sessionService;
    late StreamController<MessagingConnectionState> statusController;

    setUp(() {
      messaging = _MessagingMock();
      roleService = _RoleServiceMock();
      sessionService = _SessionServiceMock();
      statusController = StreamController<MessagingConnectionState>.broadcast();
      when(() => messaging.status$).thenAnswer((_) => statusController.stream);
    });

    tearDown(() async {
      await statusController.close();
    });

    test('updates connection state when messaging drops', () async {
      final controller = SessionController(
        roleService: roleService,
        sessionService: sessionService,
        messagingService: messaging,
      )..onInit();

      statusController.add(MessagingConnectionState.disconnected);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(controller.connectionState.value, MessagingConnectionState.disconnected);
      expect(controller.lastError.value, contains('Connection lost'));
      controller.onClose();
    });

    test('attemptReconnect re-announces when admin is local', () async {
      final session = _buildSession(isLocalAdmin: true);
      when(() => sessionService.announceSession(session)).thenAnswer((_) async {});

      final controller = SessionController(
        roleService: roleService,
        sessionService: sessionService,
        messagingService: messaging,
      )..onInit();

      controller.attachSession(session);
      await controller.attemptReconnect();

      verify(() => sessionService.announceSession(session)).called(1);
      expect(controller.connectionState.value, MessagingConnectionState.connected);
      controller.onClose();
    });

    test('attemptReconnect connects to remote admin when not local', () async {
      final session = _buildSession(isLocalAdmin: false);
      when(() => messaging.connect(host: session.admin.ip, port: session.admin.port)).thenAnswer((_) async {});

      final controller = SessionController(
        roleService: roleService,
        sessionService: sessionService,
        messagingService: messaging,
      )..onInit();

      controller.attachSession(session);
      await controller.attemptReconnect();

      verify(() => messaging.connect(host: session.admin.ip, port: session.admin.port)).called(1);
      controller.onClose();
    });
  });
}

Session _buildSession({bool isLocalAdmin = true}) {
  final admin = Device(
    id: 'admin-1',
    name: 'Admin',
    ip: '192.168.0.10',
    port: 51234,
    role: DeviceRole.admin,
    isLocal: isLocalAdmin,
  );
  return Session(
    id: 'session-1',
    name: 'Test Session',
    admin: admin,
    player: admin,
    members: [admin],
    queue: const [],
  );
}
