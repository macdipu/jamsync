class SessionSummary {
  const SessionSummary({
    required this.id,
    required this.name,
    required this.hostName,
    required this.ip,
    required this.port,
  });

  final String id;
  final String name;
  final String hostName;
  final String ip;
  final int port;
}

