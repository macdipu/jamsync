import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../core/logging/app_logger.dart';
import '../../domain/entities/control_message.dart';
import '../../domain/services_interfaces/i_messaging_service.dart';

class SocketMessagingService implements IMessagingService {
  SocketMessagingService({AppLogger? logger}) : _logger = logger;

  final _controller = StreamController<ControlMessage>.broadcast();
  final _statusController = StreamController<MessagingConnectionState>.broadcast();
  ServerSocket? _server;
  Socket? _client;
  final _connections = <Socket>[];
  static const _connectTimeout = Duration(seconds: 5);
  final AppLogger? _logger;

  @override
  Stream<ControlMessage> get messages$ => _controller.stream;
  @override
  Stream<MessagingConnectionState> get status$ => _statusController.stream;

  @override
  Future<void> connect({required String host, required int port}) async {
    await disconnect();
    _statusController.add(MessagingConnectionState.connecting);
    _logger?.info('Connecting to $host:$port');
    try {
      _client = await Socket.connect(host, port).timeout(_connectTimeout);
      _statusController.add(MessagingConnectionState.connected);
      _logger?.info('Connected to $host:$port');
      _client!.listen(_handleIncoming, onDone: _handleDisconnect, onError: (_) => _handleDisconnect());
      await _announcePresence();
    } on SocketException catch (error) {
      _handleDisconnect();
      _logger?.error('SocketException while connecting to $host:$port: ${error.message}', error);
      throw SocketException('Unable to connect to $host:$port (${error.message})');
    } on TimeoutException {
      _handleDisconnect();
      _logger?.warn('Connection to $host:$port timed out');
      throw SocketException('Connection to $host:$port timed out');
    }
  }

  Future<void> _announcePresence() async {
    final client = _client;
    if (client == null) {
      return;
    }
    final announcement = jsonEncode({
      'type': MessageType.joinRequest.name,
      'payload': {'announce': true},
    });
    client.writeln(announcement);
  }

  void _handleDisconnect() {
    _client = null;
    _statusController.add(MessagingConnectionState.disconnected);
    _logger?.warn('Socket disconnected');
  }

  @override
  Future<void> disconnect() async {
    await _client?.close();
    _client = null;
    _statusController.add(MessagingConnectionState.disconnected);
    _logger?.info('Socket closed');
  }

  @override
  Future<void> send(ControlMessage message) async {
    if (_client != null) {
      _logger?.info('Sending message ${message.type} to server');
      _client!.writeln(jsonEncode(message.toJson()));
      return;
    }
    final payload = jsonEncode(message.toJson());
    for (final socket in _connections) {
      _logger?.info('Broadcasting message ${message.type} to ${socket.remoteAddress.address}:${socket.remotePort}');
      socket.writeln(payload);
    }
  }

  void _handleIncoming(List<int> data, {Socket? origin}) {
    final raw = utf8.decode(data);
    final lines = raw.split('\n');
    for (final line in lines.where((element) => element.trim().isNotEmpty)) {
      try {
        final json = jsonDecode(line) as Map<String, dynamic>;
        final message = ControlMessage.fromJson(json);
        _controller.add(message);
        _broadcast(message, origin: origin);
      } catch (error, stackTrace) {
        _logger?.error('Invalid control message payload: $error', error, stackTrace);
      }
    }
  }

  void _broadcast(ControlMessage message, {Socket? origin}) {
    final payload = jsonEncode(message.toJson());
    for (final socket in _connections.where((s) => s != origin)) {
      socket.writeln(payload);
    }
  }

  @override
  Future<void> startHub({required int port}) async {
    await stopHub();
    _server = await ServerSocket.bind(InternetAddress.anyIPv4, port);
    _statusController.add(MessagingConnectionState.connected);
    _logger?.info('Messaging hub started on port $port');
    _server!.listen((client) {
      _connections.add(client);
      _logger?.info('Client connected: ${client.remoteAddress.address}:${client.remotePort}');
      client.listen(
        (data) => _handleIncoming(data, origin: client),
        onDone: () {
          _connections.remove(client);
          _logger?.info('Client disconnected: ${client.remoteAddress.address}:${client.remotePort}');
        },
        onError: (error, stackTrace) {
          _connections.remove(client);
          _logger?.error('Client socket error: $error', error, stackTrace);
        },
      );
    });
  }

  @override
  Future<void> stopHub() async {
    for (final socket in _connections) {
      await socket.close();
    }
    _connections.clear();
    await _server?.close();
    _server = null;
    _statusController.add(MessagingConnectionState.disconnected);
    _logger?.info('Messaging hub stopped');
  }
}
