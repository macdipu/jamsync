abstract class IMediaScannerService {
  Future<List<LocalAudioTrack>> scanLibrary();
}

class LocalAudioTrack {
  LocalAudioTrack({
    required this.id,
    required this.title,
    required this.artist,
    required this.uri,
    this.duration,
  });

  final String id;
  final String title;
  final String artist;
  final Uri uri;
  final Duration? duration;
}

