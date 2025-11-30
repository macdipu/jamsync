import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../domain/entities/control_message.dart';
import '../../domain/services_interfaces/i_messaging_service.dart';

class SocketMessagingService implements IMessagingService {
  final _controller = StreamController<ControlMessage>.broadcast();
  ServerSocket? _server;
  Socket? _client;
  final _connections = <Socket>[];

  @override
  Stream<ControlMessage> get messages$ => _controller.stream;

  @override
  Future<void> connect({required String host, required int port}) async {
    await disconnect();
    _client = await Socket.connect(host, port);
    _client!.listen(_handleIncoming, onDone: disconnect, onError: (_) => disconnect());
  }

  @override
  Future<void> disconnect() async {
    await _client?.close();
    _client = null;
  }

  @override
  Future<void> send(ControlMessage message) async {
    final socket = _client;
    if (socket == null) {
      throw StateError('Not connected');
    }
    socket.writeln(jsonEncode(message.toJson()));
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
    _server = await ServerSocket.bind(InternetAddress.anyIPv4, port);
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
  }
}
