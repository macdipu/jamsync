import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:just_audio/just_audio.dart';
import 'package:flutter/services.dart';

import '../../core/logging/app_logger.dart';
import '../../domain/entities/track.dart';
import '../../domain/services_interfaces/i_audio_stream_service.dart';

class HttpAudioStreamService implements IAudioStreamService {
  HttpAudioStreamService({AppLogger? logger}) : _logger = logger;

  final AppLogger? _logger;
  HttpServer? _server;
  AudioPlayer? _sourcePlayer;
  Track? _currentTrack;
  String? _currentStreamUrl;
  String? _cachedFilePath;  // Temporary file path for content URIs
  final _statusController = StreamController<AudioStreamStatus>.broadcast();
  final _positionController = StreamController<Duration>.broadcast();
  Timer? _positionTimer;
  int? _serverPort;

  @override
  Stream<AudioStreamStatus> get status$ => _statusController.stream;

  @override
  Stream<Duration> get position$ => _positionController.stream;

  @override
  String? get currentStreamUrl => _currentStreamUrl;

  @override
  bool get isServerRunning => _server != null;

  @override
  Future<int> startServer({required int port}) async {
    if (_server != null) {
      _logger?.warn('Server already running on port $_serverPort');
      return _serverPort!;
    }

    try {
      _statusController.add(AudioStreamStatus.starting);
      _logger?.info('Starting HTTP audio stream server on port $port');

      final handler = const Pipeline()
          .addMiddleware(_corsMiddleware())
          .addMiddleware(logRequests())
          .addHandler(_handleRequest);

      _server = await shelf_io.serve(handler, InternetAddress.anyIPv4, port);
      _serverPort = _server!.port;
      _statusController.add(AudioStreamStatus.idle);
      _logger?.info('HTTP audio stream server started on port $_serverPort');

      return _serverPort!;
    } catch (e, stackTrace) {
      _logger?.error('Failed to start HTTP server: $e', e, stackTrace);
      _statusController.add(AudioStreamStatus.error);
      rethrow;
    }
  }

  @override
  Future<void> stopServer() async {
    _positionTimer?.cancel();
    _positionTimer = null;

    await _sourcePlayer?.stop();
    await _sourcePlayer?.dispose();
    _sourcePlayer = null;

    // Clean up cached file
    if (_cachedFilePath != null) {
      try {
        final file = File(_cachedFilePath!);
        if (await file.exists()) {
          await file.delete();
          _logger?.info('Cleaned up cached file: $_cachedFilePath');
        }
      } catch (e) {
        _logger?.warn('Failed to delete cached file: $e');
      }
      _cachedFilePath = null;
    }

    await _server?.close(force: true);
    _server = null;
    _serverPort = null;
    _currentTrack = null;
    _currentStreamUrl = null;

    _statusController.add(AudioStreamStatus.stopped);
    _logger?.info('HTTP audio stream server stopped');
  }

  @override
  Future<String> streamTrack(Track track) async {
    if (_server == null) {
      throw StateError('Server not running. Call startServer() first.');
    }

    _logger?.info('Setting up stream for track: ${track.title}');

    // Stop current stream if any
    await _sourcePlayer?.stop();
    await _sourcePlayer?.dispose();
    _positionTimer?.cancel();

    // Clean up old cached file if exists
    if (_cachedFilePath != null) {
      try {
        final oldFile = File(_cachedFilePath!);
        if (await oldFile.exists()) {
          await oldFile.delete();
        }
      } catch (e) {
        _logger?.warn('Failed to delete old cached file: $e');
      }
      _cachedFilePath = null;
    }

    // Create new player for this track
    _sourcePlayer = AudioPlayer();
    _currentTrack = track;

    // For content:// URIs, we need to cache the file first
    final source = track.source;
    if (source.isScheme('content')) {
      _logger?.info('Content URI detected, caching file for HTTP streaming...');
      _cachedFilePath = await _cacheContentUri(source);
      _logger?.info('Content URI cached to: $_cachedFilePath');
    }

    // Load the track
    await _sourcePlayer!.setUrl(track.source.toString());

    // Start position broadcasting
    _startPositionBroadcast();

    // Generate stream URL
    final localIp = await _getLocalIpAddress();
    _currentStreamUrl = 'http://$localIp:$_serverPort/stream';

    _statusController.add(AudioStreamStatus.streaming);
    _logger?.info('Track stream ready at: $_currentStreamUrl');

    return _currentStreamUrl!;
  }

  void _startPositionBroadcast() {
    _positionTimer?.cancel();
    _positionTimer = Timer.periodic(const Duration(milliseconds: 100), (_) async {
      final position = _sourcePlayer?.position;
      if (position != null) {
        _positionController.add(position);
      }
    });
  }

  Future<Response> _handleRequest(Request request) async {
    final path = request.url.path;

    if (path == 'stream') {
      return _handleStreamRequest(request);
    } else if (path == 'metadata') {
      return _handleMetadataRequest(request);
    } else if (path == 'health') {
      return Response.ok('OK');
    }

    return Response.notFound('Not found');
  }

  Future<Response> _handleStreamRequest(Request request) async {
    if (_currentTrack == null || _sourcePlayer == null) {
      return Response.notFound('No active stream');
    }

    try {
      _logger?.info('Client connected to stream: ${request.headers['user-agent']}');

      final source = _currentTrack!.source;

      _logger?.info('Stream source: ${source.toString()}, scheme: ${source.scheme}');

      // For content:// scheme (Android Media Store), use the cached file
      if (source.isScheme('content')) {
        if (_cachedFilePath == null) {
          _logger?.error('Content URI cached file not found');
          return Response.internalServerError(
            body: 'Content URI file not cached. Internal error.'
          );
        }

        try {
          final file = File(_cachedFilePath!);
          if (!await file.exists()) {
            _logger?.error('Cached file not found: $_cachedFilePath');
            return Response.notFound('Cached audio file not found');
          }

          final mimeType = _getMimeType(_cachedFilePath!);
          final length = await file.length();

          _logger?.info('Streaming cached content URI file: $_cachedFilePath, size: $length bytes');

          return Response.ok(
            file.openRead(),
            headers: {
              'Content-Type': mimeType,
              'Content-Length': length.toString(),
              'Accept-Ranges': 'bytes',
              'Cache-Control': 'no-cache',
            },
          );
        } catch (e, stackTrace) {
          _logger?.error('Error reading cached file: $e', e, stackTrace);
          return Response.internalServerError(body: 'Error reading cached file: $e');
        }
      }
      // For file:// scheme, stream the file directly
      else if (source.isScheme('file')) {
        try {
          final file = File(source.toFilePath());
          if (!await file.exists()) {
            _logger?.error('File not found: ${file.path}');
            return Response.notFound('Audio file not found: ${file.path}');
          }

          final mimeType = _getMimeType(file.path);
          final length = await file.length();

          _logger?.info('Streaming file: ${file.path}, size: $length bytes');

          return Response.ok(
            file.openRead(),
            headers: {
              'Content-Type': mimeType,
              'Content-Length': length.toString(),
              'Accept-Ranges': 'bytes',
              'Cache-Control': 'no-cache',
            },
          );
        } catch (e, stackTrace) {
          _logger?.error('Error reading file: $e', e, stackTrace);
          return Response.internalServerError(body: 'Error reading file: $e');
        }
      }
      // For http/https, proxy the stream
      else if (source.isScheme('http') || source.isScheme('https')) {
        final client = HttpClient();
        try {
          final uri = Uri.parse(source.toString());
          _logger?.info('Proxying remote URL: $uri');

          final httpRequest = await client.getUrl(uri);
          final httpResponse = await httpRequest.close();

          final contentType = httpResponse.headers.contentType?.toString() ?? 'audio/mpeg';

          return Response.ok(
            httpResponse,
            headers: {
              'Content-Type': contentType,
              'Cache-Control': 'no-cache',
            },
          );
        } catch (e, stackTrace) {
          _logger?.error('Error proxying URL: $e', e, stackTrace);
          return Response.internalServerError(body: 'Error proxying URL: $e');
        } finally {
          client.close();
        }
      }
      // Unknown scheme
      else {
        _logger?.error('Unsupported URI scheme: ${source.scheme}');
        return Response(400, body: 'Unsupported URI scheme: ${source.scheme}');
      }
    } catch (e, stackTrace) {
      _logger?.error('Stream error: $e', e, stackTrace);
      return Response.internalServerError(body: 'Stream error: $e');
    }
  }

  Future<Response> _handleMetadataRequest(Request request) async {
    if (_currentTrack == null) {
      return Response.notFound('No active stream');
    }

    final metadata = {
      'track': _currentTrack!.toJson(),
      'streamUrl': _currentStreamUrl,
      'isPlaying': _sourcePlayer?.playing ?? false,
    };

    return Response.ok(
      jsonEncode(metadata),
      headers: {'Content-Type': 'application/json'},
    );
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

  /// Cache a content URI to a temporary file for HTTP streaming
  Future<String> _cacheContentUri(Uri contentUri) async {
    try {
      // Use MethodChannel to read content URI on Android
      const platform = MethodChannel('com.chowdhuryelab.jamsync/content_resolver');

      final result = await platform.invokeMethod('copyContentToCache', {
        'uri': contentUri.toString(),
      });

      if (result == null) {
        throw Exception('Failed to cache content URI: null result');
      }

      return result as String;
    } catch (e) {
      _logger?.error('Failed to cache content URI: $e', e);
      rethrow;
    }
  }

  String _getMimeType(String path) {
    final extension = path.split('.').last.toLowerCase();
    switch (extension) {
      case 'mp3':
        return 'audio/mpeg';
      case 'mp4':
      case 'm4a':
        return 'audio/mp4';
      case 'ogg':
        return 'audio/ogg';
      case 'wav':
        return 'audio/wav';
      case 'flac':
        return 'audio/flac';
      default:
        return 'audio/mpeg';
    }
  }

  Future<String> _getLocalIpAddress() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );

      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          // Prefer non-loopback addresses
          if (!addr.isLoopback) {
            return addr.address;
          }
        }
      }

      // Fallback to localhost
      return 'localhost';
    } catch (e) {
      _logger?.error('Failed to get local IP: $e', e);
      return 'localhost';
    }
  }
}

