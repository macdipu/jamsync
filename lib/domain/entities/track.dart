class Track {
  const Track({
    required this.id,
    required this.title,
    required this.artist,
    required this.source,
    this.duration,
  });

  final String id;
  final String title;
  final String artist;
  final Uri source;
  final Duration? duration;

  Track copyWith({
    String? id,
    String? title,
    String? artist,
    Uri? source,
    Duration? duration,
  }) {
    return Track(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      source: source ?? this.source,
      duration: duration ?? this.duration,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'source': source.toString(),
      'durationMs': duration?.inMilliseconds,
    };
  }

  factory Track.fromJson(Map<String, dynamic> json) {
    return Track(
      id: json['id'] as String,
      title: json['title'] as String,
      artist: json['artist'] as String? ?? 'Unknown',
      source: Uri.parse(json['source'] as String),
      duration: json['durationMs'] == null
          ? null
          : Duration(milliseconds: (json['durationMs'] as num).round()),
    );
  }
}
