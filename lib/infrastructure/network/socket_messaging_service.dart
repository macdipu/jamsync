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
    const payloadType = MessageType.joinRequest;
    final announcement = jsonEncode({
      'type': payloadType.name,
      'payload': {'announce': true},
    });
    await _safeWrite(client, announcement);
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
    final payloadJson = jsonEncode(message.toJson());
    if (_client != null) {
      _logger?.info('Sending message ${message.type} to server');
      await _safeWrite(_client!, payloadJson);
      return;
    }
    await _broadcastPayload(payloadJson);
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
        unawaited(_broadcast(message, origin: origin));
      } catch (error, stackTrace) {
        _logger?.error('Invalid control message payload: $error', error, stackTrace);
      }
    }
  }

  Future<void> _broadcast(ControlMessage message, {_PeerConnection? origin}) async {
    final payload = jsonEncode(message.toJson());
    await _broadcastPayload(payload, origin: origin);
  }

  Future<void> _broadcastPayload(String payload, {_PeerConnection? origin}) async {
    final targets = List<_PeerConnection>.from(_connections);
    for (final peer in targets) {
      if (peer == origin) {
        continue;
      }
      final ok = await _safeWrite(peer.socket, payload);
      if (!ok) {
        _removeConnection(peer, reason: 'write failure');
      }
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
        onDone: () => _removeConnection(peer, reason: 'client closed'),
        onError: (error, stackTrace) => _removeConnection(peer, reason: '$error', stackTrace: stackTrace),
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

  Future<bool> _safeWrite(Socket socket, String payload) async {
    try {
      final framed = payload.endsWith('\n') ? payload : '$payload\n';
      socket.add(utf8.encode(framed));
      await socket.flush();
      return true;
    } on Object catch (error, stackTrace) {
      _logger?.error('Failed to write to socket: $error', error, stackTrace);
      return false;
    }
  }

  void _removeConnection(_PeerConnection peer, {String? reason, StackTrace? stackTrace}) {
    if (_connections.remove(peer)) {
      _logger?.error('Client disconnected: ${peer.label}${reason != null ? ' ($reason)' : ''}', stackTrace);
    }
    peer.dispose();
  }
}
