import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../core/logging/app_logger.dart';
import '../../domain/entities/control_message.dart';
import '../../domain/services_interfaces/i_messaging_service.dart';

class _PeerConnection {
  _PeerConnection(this.socket)
      : label = '${socket.remoteAddress.address}:${socket.remotePort}';

  final Socket socket;
  final String label;
  final StringBuffer buffer = StringBuffer();

  void dispose() {
    buffer.clear();
    socket.destroy();
  }
}

class SocketMessagingService implements IMessagingService {
  SocketMessagingService({AppLogger? logger}) : _logger = logger;

  final _controller = StreamController<ControlMessage>.broadcast();
  final _statusController = StreamController<MessagingConnectionState>.broadcast();
  ServerSocket? _server;
  Socket? _client;
  final _connections = <_PeerConnection>[];
  final _clientBuffer = StringBuffer();
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
    _clientBuffer.clear();
  }

  @override
  Future<void> send(ControlMessage message) async {
    if (_client != null) {
      _logger?.info('Sending message ${message.type} to server');
      await _safeWrite(_client!, jsonEncode(message.toJson()));
      return;
    }
    final payload = jsonEncode(message.toJson());
    for (final peer in _connections) {
      _logger?.info('Broadcasting message ${message.type} to ${peer.label}');
      unawaited(_safeWrite(peer.socket, payload));
    }
  }

  void _handleIncoming(List<int> data, {StringBuffer? buffer, _PeerConnection? origin}) {
    final sink = buffer ?? _clientBuffer;
    final chunk = utf8.decode(data);
    if (sink.isNotEmpty) {
      sink.write(chunk);
    } else {
      sink.write(chunk);
    }
    final combined = sink.toString();
    final lines = combined.split('\n');
    final hasTrailing = !combined.endsWith('\n');
    sink
      ..clear()
      ..write(hasTrailing ? lines.removeLast() : '');
    for (final line in lines.where((line) => line.trim().isNotEmpty)) {
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

  void _broadcast(ControlMessage message, {_PeerConnection? origin}) {
    final payload = jsonEncode(message.toJson());
    for (final peer in _connections.where((peer) => peer != origin)) {
      unawaited(_safeWrite(peer.socket, payload));
    }
  }

  @override
  Future<void> startHub({required int port}) async {
    await stopHub();
    _server = await ServerSocket.bind(InternetAddress.anyIPv4, port);
    _statusController.add(MessagingConnectionState.connected);
    _logger?.info('Messaging hub started on port $port');
    _server!.listen((client) {
      final peer = _PeerConnection(client);
      _connections.add(peer);
      _logger?.info('Client connected: ${peer.label}');
      client.listen(
        (data) => _handleIncoming(data, buffer: peer.buffer, origin: peer),
        onDone: () {
          _connections.remove(peer);
          _logger?.info('Client disconnected: ${peer.label}');
          peer.dispose();
        },
        onError: (error, stackTrace) {
          _connections.remove(peer);
          _logger?.error('Client socket error (${peer.label}): $error', error, stackTrace);
          peer.dispose();
        },
        cancelOnError: true,
      );
    });
  }

  @override
  Future<void> stopHub() async {
    for (final peer in _connections) {
      await peer.socket.close();
    }
    _connections.clear();
    await _server?.close();
    _server = null;
    _statusController.add(MessagingConnectionState.disconnected);
    _logger?.info('Messaging hub stopped');
  }

  Future<void> _safeWrite(Socket socket, String payload) async {
    try {
      socket.write(payload);
      if (!payload.endsWith('\n')) {
        socket.write('\n');
      }
      await socket.flush();
    } on Object catch (error, stackTrace) {
      _logger?.error('Failed to write to socket: $error', error, stackTrace);
    }
  }
}
