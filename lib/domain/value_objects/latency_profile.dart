class LatencyProfile {
  const LatencyProfile({
    required this.offsetMs,
    required this.rttMs,
    required this.lastUpdated,
  });

  final double offsetMs;
  final int rttMs;
  final DateTime lastUpdated;

  LatencyProfile copyWith({
    double? offsetMs,
    int? rttMs,
    DateTime? lastUpdated,
  }) {
    return LatencyProfile(
      offsetMs: offsetMs ?? this.offsetMs,
      rttMs: rttMs ?? this.rttMs,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}

