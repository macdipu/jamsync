import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';

import '../../core/logging/app_logger.dart';
import '../../domain/entities/control_message.dart';
import '../../domain/services_interfaces/i_messaging_service.dart';

class WebSocketMessagingService implements IMessagingService {
  WebSocketMessagingService({AppLogger? logger}) : _logger = logger;

  final AppLogger? _logger;
  final _controller = StreamController<ControlMessage>.broadcast();
  final _statusController = StreamController<MessagingConnectionState>.broadcast();

  HttpServer? _server;
  final _channels = <WebSocketChannel>[];
  WebSocketChannel? _clientChannel;
  int? _serverPort;

  @override
  Stream<ControlMessage> get messages$ => _controller.stream;

  @override
  Stream<MessagingConnectionState> get status$ => _statusController.stream;

  @override
  Future<void> startHub({required int port}) async {
    if (_server != null) {
      _logger?.warn('WebSocket hub already running on port $_serverPort');
      return;
    }

    try {
      _logger?.info('Starting WebSocket hub on port $port');
      _server = await HttpServer.bind(InternetAddress.anyIPv4, port);
      _serverPort = port;

      _server!.transform(WebSocketTransformer()).listen((WebSocket webSocket) {
        final channel = IOWebSocketChannel(webSocket);
        _channels.add(channel);
        _logger?.info('WebSocket client connected. Total clients: ${_channels.length}');

        channel.stream.listen(
              (data) => _handleIncoming(data, origin: channel),
          onDone: () => _removeChannel(channel, reason: 'client disconnected'),
          onError: (error) => _removeChannel(channel, reason: 'error: $error'),
          cancelOnError: true,
        );
      });

      _statusController.add(MessagingConnectionState.connected);
      _logger?.info('WebSocket hub started on port $port');
    } catch (e, stackTrace) {
      _logger?.error('Failed to start WebSocket hub: $e', e, stackTrace);
      _statusController.add(MessagingConnectionState.disconnected);
      rethrow;
    }
  }

  @override
  Future<void> stopHub() async {
    for (final channel in _channels) {
      await channel.sink.close();
    }
    _channels.clear();

    await _server?.close(force: true);
    _server = null;
    _serverPort = null;

    _statusController.add(MessagingConnectionState.disconnected);
    _logger?.info('WebSocket hub stopped');
  }

  @override
  Future<void> connect({required String host, required int port}) async {
    await disconnect();

    try {
      _statusController.add(MessagingConnectionState.connecting);
      _logger?.info('Connecting to WebSocket server at ws://$host:$port');

      final uri = Uri.parse('ws://$host:$port');
      _clientChannel = IOWebSocketChannel.connect(uri);

      _clientChannel!.stream.listen(
        _handleIncoming,
        onDone: _handleDisconnect,
        onError: (error) {
          _logger?.error('WebSocket error: $error', error);
          _handleDisconnect();
        },
        cancelOnError: true,
      );

      _statusController.add(MessagingConnectionState.connected);
      _logger?.info('Connected to WebSocket server');

      // Announce presence
      await _announcePresence();
    } catch (e, stackTrace) {
      _logger?.error('Failed to connect to WebSocket: $e', e, stackTrace);
      _handleDisconnect();
      rethrow;
    }
  }

  @override
  Future<void> disconnect() async {
    await _clientChannel?.sink.close();
    _clientChannel = null;
    _statusController.add(MessagingConnectionState.disconnected);
    _logger?.info('Disconnected from WebSocket server');
  }

  @override
  Future<void> send(ControlMessage message) async {
    final payload = jsonEncode(message.toJson());

    // Send to server if connected as client
    if (_clientChannel != null) {
      try {
        _clientChannel!.sink.add(payload);
        _logger?.info('Sent message ${message.type} to server');
      } catch (e, stackTrace) {
        _logger?.error('Failed to send message: $e', e, stackTrace);
      }
      return;
    }

    // Broadcast to all clients if running as hub
    await _broadcast(payload);
  }

  Future<void> _announcePresence() async {
    final message = ControlMessage(
      type: MessageType.joinRequest,
      payload: {'announce': true},
    );
    await send(message);
  }

  void _handleIncoming(dynamic data, {WebSocketChannel? origin}) {
    try {
      final json = jsonDecode(data as String) as Map<String, dynamic>;
      final message = ControlMessage.fromJson(json);
      _controller.add(message);

      // Broadcast to other clients if we're the hub
      if (_server != null && origin != null) {
        final payload = jsonEncode(message.toJson());
        unawaited(_broadcast(payload, excludeChannel: origin));
      }
    } catch (e, stackTrace) {
      _logger?.error('Invalid WebSocket message: $e', e, stackTrace);
    }
  }

  void _handleDisconnect() {
    _clientChannel = null;
    _statusController.add(MessagingConnectionState.disconnected);
    _logger?.warn('WebSocket disconnected');
  }

  Future<void> _broadcast(String payload, {WebSocketChannel? excludeChannel}) async {
    final targets = List<WebSocketChannel>.from(_channels);
    for (final channel in targets) {
      if (channel == excludeChannel) {
        continue;
      }
      try {
        channel.sink.add(payload);
      } catch (e) {
        _logger?.error('Failed to broadcast to client: $e', e);
        _removeChannel(channel, reason: 'broadcast failure');
      }
    }
  }

  void _removeChannel(WebSocketChannel channel, {String? reason}) {
    if (_channels.remove(channel)) {
      _logger?.info('Client removed${reason != null ? ' ($reason)' : ''}. Remaining: ${_channels.length}');
    }
    channel.sink.close();
  }
}