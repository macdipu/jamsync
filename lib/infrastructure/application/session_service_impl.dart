import 'dart:async';

import 'package:uuid/uuid.dart';

import '../../core/logging/app_logger.dart';
import '../../domain/entities/device.dart';
import '../../domain/entities/session.dart';
import '../../domain/entities/session_summary.dart';
import '../../domain/services_interfaces/i_discovery_service.dart';
import '../../domain/services_interfaces/i_messaging_service.dart';
import '../../domain/services_interfaces/i_session_service.dart';

class SessionServiceImpl implements ISessionService {
  SessionServiceImpl({
    required IMessagingService messagingService,
    required IDiscoveryService discoveryService,
    required AppLogger logger,
  })  : _messagingService = messagingService,
        _discoveryService = discoveryService,
        _logger = logger;

  final IMessagingService _messagingService;
  final IDiscoveryService _discoveryService;
  final AppLogger _logger;
  Session? _currentSession;
  SessionSummary? _connectedSummary;
  final _sessionsController = StreamController<List<Session>>.broadcast();
  final _sessions = <Session>[];

  @override
  Stream<List<Session>> get sessions$ => _sessionsController.stream;

  @override
  Future<Session> createSession({required String name, required Device admin}) async {
    final session = Session(
      id: const Uuid().v4(),
      name: name,
      admin: admin,
      player: admin,
      members: [admin],
      queue: const [],
    );
    _currentSession = session;
    _sessions
      ..removeWhere((existing) => existing.id == session.id)
      ..add(session);
    _sessionsController.add(List.unmodifiable(_sessions));
    return session;
  }

  @override
  Future<void> announceSession(Session session) async {
    await _discoveryService.startAnnouncing(
      SessionSummary(
        id: session.id,
        name: session.name,
        hostName: session.admin.name,
        ip: session.admin.ip,
        port: session.admin.port,
      ),
    );
    await _messagingService.startHub(port: session.admin.port);
    _logger.info('Announcing session ${session.id}');
  }

  @override
  Future<void> stopSession(String sessionId) async {
    await _discoveryService.stopAnnouncing(sessionId);
    await _messagingService.stopHub();
    _sessions.removeWhere((session) => session.id == sessionId);
    _sessionsController.add(List.unmodifiable(_sessions));
    if (_currentSession?.id == sessionId) {
      _currentSession = null;
    }
    if (_connectedSummary?.id == sessionId) {
      _connectedSummary = null;
    }
  }

  @override
  Future<void> joinSession(SessionSummary summary) async {
    await _discoveryService.startListening();
    await _messagingService.connect(host: summary.ip, port: summary.port);
    _connectedSummary = summary;
    _logger.info('Joined session ${summary.id} @ ${summary.ip}:${summary.port}');
  }
}
