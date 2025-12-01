import 'dart:typed_data';

import '../entities/track.dart';

/// Service for streaming audio over HTTP
abstract class IAudioStreamService {
  /// Start HTTP server to stream audio
  /// Returns the port the server is running on
  Future<int> startServer({required int port});

  /// Stop the HTTP server
  Future<void> stopServer();

  /// Stream a track over HTTP
  /// Returns the URL to access the stream
  Future<String> streamTrack(Track track);

  /// Get the current stream URL if active
  String? get currentStreamUrl;

  /// Check if server is running
  bool get isServerRunning;

  /// Stream status
  Stream<AudioStreamStatus> get status$;

  /// Stream position updates (for host to broadcast)
  Stream<Duration> get position$;
}

/// Service for receiving audio streams
abstract class IAudioStreamClient {
  /// Connect to an HTTP audio stream
  Future<void> connectToStream(String url);

  /// Disconnect from the current stream
  Future<void> disconnect();

  /// Check if connected
  bool get isConnected;

  /// Stream of audio data
  Stream<Uint8List> get audioData$;

  /// Connection status
  Stream<StreamClientStatus> get status$;
}

enum AudioStreamStatus {
  idle,
  starting,
  streaming,
  stopped,
  error,
}

enum StreamClientStatus {
  disconnected,
  connecting,
  connected,
  buffering,
  error,
}

