import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import '../../domain/entities/control_message.dart';
import '../../domain/services_interfaces/i_messaging_service.dart';

class SocketMessagingService implements IMessagingService {
  final _controller = StreamController<ControlMessage>.broadcast();
  final _statusController = StreamController<MessagingConnectionState>.broadcast();
  ServerSocket? _server;
  Socket? _client;
  final _connections = <Socket>[];

  @override
  Stream<ControlMessage> get messages$ => _controller.stream;
  @override
  Stream<MessagingConnectionState> get status$ => _statusController.stream;

  @override
  Future<void> connect({required String host, required int port}) async {
    await disconnect();
    _statusController.add(MessagingConnectionState.connecting);
    _client = await Isolate.run(() => Socket.connect(host, port));
    _statusController.add(MessagingConnectionState.connected);
    _client!.listen(_handleIncoming, onDone: _handleDisconnect, onError: (_) => _handleDisconnect());
  }

  void _handleDisconnect() {
    _client = null;
    _statusController.add(MessagingConnectionState.disconnected);
  }

  @override
  Future<void> disconnect() async {
    await _client?.close();
    _client = null;
    _statusController.add(MessagingConnectionState.disconnected);
  }

  @override
  Future<void> send(ControlMessage message) async {
    if (_client != null) {
      _client!.writeln(jsonEncode(message.toJson()));
      return;
    }
    final payload = jsonEncode(message.toJson());
    for (final socket in _connections) {
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
      } catch (_) {
        // swallow invalid payloads for now
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
    _server = await Isolate.run(() => ServerSocket.bind(InternetAddress.anyIPv4, port));
    _statusController.add(MessagingConnectionState.connected);
    _server!.listen((client) {
      _connections.add(client);
      client.listen(
        (data) => _handleIncoming(data, origin: client),
        onDone: () => _connections.remove(client),
        onError: (_) => _connections.remove(client),
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
  }
}
