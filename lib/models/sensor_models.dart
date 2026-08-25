enum LevelStatus { ok, noReading, stale }

LevelStatus levelStatusFromJson(String? value) {
  switch (value) {
    case 'ok': return LevelStatus.ok;
    case 'stale': return LevelStatus.stale;
    default: return LevelStatus.noReading;
  }
}

class PingResponse {
  const PingResponse({required this.status, required this.firmware});
  final String status;
  final String firmware;

  factory PingResponse.fromJson(Map<String, dynamic> json) => PingResponse(
    status: json['status'] as String? ?? 'unknown',
    firmware: json['fw'] as String? ?? 'unknown',
  );
}

class LevelResponse {
  const LevelResponse({required this.distanceCm, required this.ageSeconds, required this.status, required this.firmware});
  final double? distanceCm;
  final int? ageSeconds;
  final LevelStatus status;
  final String firmware;

  factory LevelResponse.fromJson(Map<String, dynamic> json) => LevelResponse(
    distanceCm: (json['distance_cm'] as num?)?.toDouble(),
    ageSeconds: (json['age_s'] as num?)?.toInt(),
    status: levelStatusFromJson(json['status'] as String?),
    firmware: json['fw'] as String? ?? 'unknown',
  );
}

class TankSettings {
  const TankSettings({required this.baseUrl, required this.emptyDistanceCm, required this.fullDistanceCm, required this.pollInterval});
  final String baseUrl;
  final double emptyDistanceCm;
  final double fullDistanceCm;
  final Duration pollInterval;

  static const defaults = TankSettings(
    baseUrl: 'http://192.168.1.12', emptyDistanceCm: 80, fullDistanceCm: 30,
    pollInterval: Duration(minutes: 2),
  );

  String? validate() {
    if (baseUrl.trim().isEmpty) return 'ESP32 address is required.';
    final uri = Uri.tryParse(baseUrl.trim());
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) return 'Enter a valid HTTP address.';
    if (emptyDistanceCm <= 0 || fullDistanceCm <= 0) return 'Distances must be positive.';
    if (emptyDistanceCm <= fullDistanceCm) return 'Empty distance must be greater than full distance.';
    if (fullDistanceCm < 30) return 'Full distance must be at least 30 cm.';
    if (pollInterval <= Duration.zero) return 'Poll interval must be positive.';
    return null;
  }

  double calculateLevelPercent(double distanceCm) {
    final raw = (emptyDistanceCm - distanceCm) / (emptyDistanceCm - fullDistanceCm) * 100;
    return raw.clamp(0, 100).toDouble();
  }
}
