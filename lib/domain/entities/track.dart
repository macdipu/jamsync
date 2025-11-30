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
}

