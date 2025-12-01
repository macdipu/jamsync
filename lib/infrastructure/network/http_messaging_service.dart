import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

import '../../core/logging/app_logger.dart';
import '../../domain/entities/control_message.dart';
import '../../domain/services_interfaces/i_messaging_service.dart';

/// HTTP-based messaging service for control messages between devices
/// Uses HTTP polling for simplicity and reliability
class HttpMessagingService implements IMessagingService {
  HttpMessagingService({AppLogger? logger}) : _logger = logger;

  final AppLogger? _logger;
  final _controller = StreamController<ControlMessage>.broadcast();
  final _statusController = StreamController<MessagingConnectionState>.broadcast();

  HttpServer? _server;
  int? _serverPort;

  // For client mode - polling target
  String? _hubHost;
  int? _hubPort;
  Timer? _pollingTimer;

  // Message queue for hub to distribute
  final _messageQueue = <ControlMessage>[];
  final _maxQueueSize = 100;

  // Connected clients (for hub mode)
  final _connectedClients = <String, DateTime>{};

  @override
  Stream<ControlMessage> get messages$ => _controller.stream;

  @override
  Stream<MessagingConnectionState> get status$ => _statusController.stream;

  @override
  Future<void> startHub({required int port}) async {
    if (_server != null) {
      _logger?.warn('HTTP hub already running on port $_serverPort');
      return;
    }

    try {
      _logger?.info('Starting HTTP messaging hub on port $port');
      _statusController.add(MessagingConnectionState.connecting);

      final handler = const Pipeline()
          .addMiddleware(_corsMiddleware())
          .addMiddleware(logRequests())
          .addHandler(_handleRequest);

      _server = await shelf_io.serve(handler, InternetAddress.anyIPv4, port);
      _serverPort = _server!.port;

      _statusController.add(MessagingConnectionState.connected);
      _logger?.info('HTTP messaging hub started on port $_serverPort');
    } catch (e, stackTrace) {
      _logger?.error('Failed to start HTTP hub: $e', e, stackTrace);
      _statusController.add(MessagingConnectionState.disconnected);
      rethrow;
    }
  }

  @override
  Future<void> stopHub() async {
    await _server?.close(force: true);
    _server = null;
    _serverPort = null;
    _messageQueue.clear();
    _connectedClients.clear();
    _statusController.add(MessagingConnectionState.disconnected);
    _logger?.info('HTTP messaging hub stopped');
  }

  @override
  Future<void> connect({required String host, required int port}) async {
    if (_hubHost != null && _hubPort != null) {
      _logger?.warn('Already connected to $_hubHost:$_hubPort');
      return;
    }

    try {
      _logger?.info('Connecting to HTTP hub at $host:$port');
      _statusController.add(MessagingConnectionState.connecting);

      _hubHost = host;
      _hubPort = port;

      // Test connection
      final client = HttpClient();
      try {
        final request = await client.getUrl(Uri.parse('http://$host:$port/health'));
        final response = await request.close();
        if (response.statusCode == 200) {
          _statusController.add(MessagingConnectionState.connected);
          _startPolling();
          _logger?.info('Connected to HTTP hub at $host:$port');
        } else {
          throw Exception('Hub returned status ${response.statusCode}');
        }
      } finally {
        client.close();
      }
    } catch (e, stackTrace) {
      _logger?.error('Failed to connect to hub: $e', e, stackTrace);
      _hubHost = null;
      _hubPort = null;
      _statusController.add(MessagingConnectionState.disconnected);
      rethrow;
    }
  }

  @override
  Future<void> disconnect() async {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _hubHost = null;
    _hubPort = null;
    _statusController.add(MessagingConnectionState.disconnected);
    _logger?.info('Disconnected from HTTP hub');
  }

  @override
  Future<void> send(ControlMessage message) async {
    if (_server != null) {
      // Hub mode - queue message for distribution
      _messageQueue.add(message);
      if (_messageQueue.length > _maxQueueSize) {
        _messageQueue.removeAt(0);
      }
      _logger?.info('Message queued: ${message.type.name}');
    } else if (_hubHost != null && _hubPort != null) {
      // Client mode - send to hub
      try {
        final client = HttpClient();
        try {
          final request = await client.postUrl(
            Uri.parse('http://$_hubHost:$_hubPort/messages'),
          );
          request.headers.contentType = ContentType.json;
          request.write(jsonEncode(message.toJson()));
          final response = await request.close();

          if (response.statusCode != 200) {
            _logger?.warn('Failed to send message, status: ${response.statusCode}');
          }
        } finally {
          client.close();
        }
      } catch (e) {
        _logger?.error('Error sending message: $e', e);
      }
    }
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(milliseconds: 200), (_) async {
      await _pollMessages();
    });
  }

  Future<void> _pollMessages() async {
    if (_hubHost == null || _hubPort == null) {
      return;
    }

    try {
      final client = HttpClient();
      try {
        final request = await client.getUrl(
          Uri.parse('http://$_hubHost:$_hubPort/messages'),
        );
        final response = await request.close();

        if (response.statusCode == 200) {
          final body = await response.transform(utf8.decoder).join();
          final data = jsonDecode(body) as Map<String, dynamic>;
          final messages = data['messages'] as List<dynamic>? ?? [];

          for (final msgJson in messages) {
            try {
              final message = ControlMessage.fromJson(msgJson as Map<String, dynamic>);
              _controller.add(message);
            } catch (e) {
              _logger?.warn('Failed to parse message: $e');
            }
          }
        }
      } finally {
        client.close();
      }
    } catch (e) {
      // Silent fail for polling errors to avoid spam
      // Connection issues will be detected on next poll
    }
  }

  Future<Response> _handleRequest(Request request) async {
    final path = request.url.path;

    if (path == 'health') {
      return Response.ok('OK');
    } else if (path == 'messages') {
      if (request.method == 'GET') {
        return _handleGetMessages(request);
      } else if (request.method == 'POST') {
        return _handlePostMessage(request);
      }
    }

    return Response.notFound('Not found');
  }

  Future<Response> _handleGetMessages(Request request) async {
    // Return queued messages
    final messages = List<ControlMessage>.from(_messageQueue);
    _messageQueue.clear();

    final response = {
      'messages': messages.map((m) => m.toJson()).toList(),
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    return Response.ok(
      jsonEncode(response),
      headers: {'Content-Type': 'application/json'},
    );
  }

  Future<Response> _handlePostMessage(Request request) async {
    try {
      final body = await request.readAsString();
      final json = jsonDecode(body) as Map<String, dynamic>;
      final message = ControlMessage.fromJson(json);

      // Add to queue for distribution
      _messageQueue.add(message);
      if (_messageQueue.length > _maxQueueSize) {
        _messageQueue.removeAt(0);
      }

      // Also emit locally if we're the hub
      _controller.add(message);

      _logger?.info('Received message: ${message.type.name}');

      return Response.ok('OK');
    } catch (e) {
      _logger?.error('Error handling message: $e', e);
      return Response.badRequest(body: 'Invalid message format');
    }
  }

  Middleware _corsMiddleware() {
    return (Handler handler) {
      return (Request request) async {
        if (request.method == 'OPTIONS') {
          return Response.ok('', headers: _corsHeaders);
        }

        final response = await handler(request);
        return response.change(headers: _corsHeaders);
      };
    };
  }

  final _corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Origin, Content-Type',
  };
}

