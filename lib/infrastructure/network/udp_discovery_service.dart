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
  bool _listening = false;
  Timer? _announceTimer;
  SessionSummary? _currentAnnouncement;

  @override
  Stream<List<SessionSummary>> get sessions$ => _controller.stream;

  @override
  Future<void> startAnnouncing(SessionSummary summary) async {
    _logger.info('Start announcing ${summary.name}');
    _currentAnnouncement = summary;
    _announceTimer ??= Timer.periodic(_announceInterval, (_) {
      final payload = jsonEncode(
        {
          'type': 'SESSION_ANNOUNCE',
          'id': summary.id,
          'name': summary.name,
          'hostName': summary.hostName,
          'ip': summary.ip,
          'port': summary.port,
        },
      );
      RawDatagramSocket.bind(InternetAddress.anyIPv4, 0).then((socket) {
        socket.send(payload.codeUnits, InternetAddress(_multicastAddress), _multicastPort);
        socket.close();
      });
    });
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
    if (_listening) {
      return;
    }
    _listening = true;
    _logger.info('Discovery listening on $_multicastAddress:$_multicastPort');
    final socket = await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      _multicastPort,
      reuseAddress: true,
      reusePort: true,
    );
    _socket = socket;
    socket.joinMulticast(InternetAddress(_multicastAddress));
    socket.listen(_handlePacket);
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
    if (!_listening) {
      return;
    }
    _listening = false;
    _socket?.close();
    _socket = null;
  }
}
