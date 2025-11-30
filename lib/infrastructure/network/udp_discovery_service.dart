import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../core/logging/app_logger.dart';
import '../../domain/entities/session_summary.dart';
import '../../domain/services_interfaces/i_discovery_service.dart';

class UdpDiscoveryService implements IDiscoveryService {
  UdpDiscoveryService({AppLogger? logger}) : _logger = logger ?? AppLogger();

  static const _multicastAddress = '239.255.255.250';
  static const _multicastPort = 53333;
  static const _announceInterval = Duration(seconds: 2);

  final AppLogger _logger;
  final _controller = StreamController<List<SessionSummary>>.broadcast();
  final _sessions = <SessionSummary>[];
  RawDatagramSocket? _socket;
  Timer? _announceTimer;
  SessionSummary? _currentAnnouncement;

  @override
  Stream<List<SessionSummary>> get sessions$ => _controller.stream;

  @override
  Future<void> startAnnouncing(SessionSummary summary) async {
    _currentAnnouncement = summary;
    await _ensureSocket();
    _announceTimer?.cancel();
    _announceTimer = Timer.periodic(_announceInterval, (_) => _sendAnnouncement());
    _sendAnnouncement();
  }

  void _sendAnnouncement() {
    final socket = _socket;
    final announcement = _currentAnnouncement;
    if (socket == null || announcement == null) {
      return;
    }
    final payload = jsonEncode({
      'type': 'SESSION_ANNOUNCE',
      'sessionId': announcement.id,
      'sessionName': announcement.name,
      'hostName': announcement.hostName,
      'ip': announcement.ip,
      'port': announcement.port,
    });
    socket.send(utf8.encode(payload), InternetAddress(_multicastAddress), _multicastPort);
  }

  @override
  Future<void> stopAnnouncing(String sessionId) async {
    if (_currentAnnouncement?.id == sessionId) {
      _currentAnnouncement = null;
      _announceTimer?.cancel();
      _announceTimer = null;
    }
    _sessions.removeWhere((element) => element.id == sessionId);
    _controller.add(List.unmodifiable(_sessions));
  }

  @override
  Future<void> startListening() async {
    await _ensureSocket();
  }

  Future<void> _ensureSocket() async {
    if (_socket != null) {
      return;
    }
    final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, _multicastPort);
    socket.joinMulticast(InternetAddress(_multicastAddress));
    socket.readEventsEnabled = true;
    socket.listen(_handlePacket);
    _socket = socket;
    _logger.info('Discovery socket ready on $_multicastPort');
  }

  void _handlePacket(RawSocketEvent event) {
    if (event != RawSocketEvent.read) {
      return;
    }
    final socket = _socket;
    if (socket == null) {
      return;
    }
    final packet = socket.receive();
    if (packet == null) {
      return;
    }
    try {
      final data = utf8.decode(packet.data);
      final json = jsonDecode(data) as Map<String, dynamic>;
      if (json['type'] != 'SESSION_ANNOUNCE') {
        return;
      }
      final summary = SessionSummary(
        id: json['sessionId'] as String,
        name: json['sessionName'] as String,
        hostName: json['hostName'] as String,
        ip: json['ip'] as String,
        port: json['port'] as int,
      );
      final index = _sessions.indexWhere((element) => element.id == summary.id);
      if (index >= 0) {
        _sessions[index] = summary;
      } else {
        _sessions.add(summary);
      }
      _controller.add(List.unmodifiable(_sessions));
    } catch (error, stackTrace) {
      _logger.error('Failed to parse discovery packet', error, stackTrace);
    }
  }

  @override
  Future<void> stopListening() async {
    _announceTimer?.cancel();
    _announceTimer = null;
    _socket?.close();
    _socket = null;
    _sessions.clear();
    _controller.add(const []);
  }
}
