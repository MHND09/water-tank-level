import '../config/app_config.dart';

enum LevelStatus { ok, belowRange, noReading, stale }

LevelStatus levelStatusFromJson(String? value) {
  switch (value) {
    case 'ok': return LevelStatus.ok;
    case 'below_range': return LevelStatus.belowRange;
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
  const LevelResponse({required this.distanceCm, required this.ageSeconds, required this.status, required this.firmware, this.rawCm, this.blindCm});
  final double? distanceCm;
  final int? ageSeconds;
  final LevelStatus status;
  final String firmware;

  /// Blind-zone artifact echo reported alongside `below_range`. Diagnostics only —
  /// never a real distance, so never feed it to [TankSettings.calculateLevelPercent].
  final double? rawCm;

  /// Blind distance the firmware itself gates on, so the app can detect drift
  /// against its own setting. Null on firmware older than 1.1.0.
  final double? blindCm;

  factory LevelResponse.fromJson(Map<String, dynamic> json) => LevelResponse(
    distanceCm: (json['distance_cm'] as num?)?.toDouble(),
    ageSeconds: (json['age_s'] as num?)?.toInt(),
    status: levelStatusFromJson(json['status'] as String?),
    firmware: json['fw'] as String? ?? 'unknown',
    rawCm: (json['raw_cm'] as num?)?.toDouble(),
    blindCm: (json['blind_cm'] as num?)?.toDouble(),
  );
}

class StoredReading {
  const StoredReading({required this.level, required this.recordedAt});
  final LevelResponse level;
  final DateTime recordedAt;
}

class TankSettings {
  const TankSettings({
    required this.baseUrl,
    required this.emptyDistanceCm,
    required this.fullDistanceCm,
    required this.pollInterval,
    this.blindDistanceCm = AppConfig.defaultBlindDistanceCm,
  });

  final String baseUrl;

  /// Sensor to water surface with the tank at its 0% line. Tank geometry.
  final double emptyDistanceCm;

  /// Sensor to water surface at maximum fill. Tank geometry — measure it for real,
  /// even when it falls inside the blind zone. Never substitute the sensor limit
  /// here: that compresses the scale and over-reports every level.
  final double fullDistanceCm;

  /// Closest distance the sensor can measure. Sensor hardware, not tank geometry.
  final double blindDistanceCm;

  final Duration pollInterval;

  static const defaults = TankSettings(
    baseUrl: AppConfig.defaultEsp32BaseUrl,
    emptyDistanceCm: AppConfig.defaultEmptyDistanceCm,
    fullDistanceCm: AppConfig.defaultFullDistanceCm,
    blindDistanceCm: AppConfig.defaultBlindDistanceCm,
    pollInterval: AppConfig.defaultPollInterval,
  );

  /// Hard errors only. A full line inside the blind zone is a fact about the
  /// install, not invalid input — see [hasBlindBand].
  String? validate() {
    if (baseUrl.trim().isEmpty) return 'ESP32 address is required.';
    final uri = Uri.tryParse(baseUrl.trim());
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) return 'Enter a valid HTTP address.';
    if (emptyDistanceCm <= 0 || fullDistanceCm <= 0 || blindDistanceCm <= 0) return 'Distances must be positive.';
    if (emptyDistanceCm <= fullDistanceCm) return 'Empty distance must be greater than full distance.';
    if (emptyDistanceCm <= blindDistanceCm) return 'Empty distance must be greater than the blind distance.';
    if (pollInterval <= Duration.zero) return 'Poll interval must be positive.';
    return null;
  }

  /// True level on the real tank scale, from real geometry.
  double calculateLevelPercent(double distanceCm) {
    final raw = (emptyDistanceCm - distanceCm) / (emptyDistanceCm - fullDistanceCm) * 100;
    return raw.clamp(0, 100).toDouble();
  }

  /// Closest surface the sensor can still report a distance for.
  double get measurableFullDistanceCm => fullDistanceCm > blindDistanceCm ? fullDistanceCm : blindDistanceCm;

  /// Highest level the sensor can resolve. 100 when the blind zone sits above the
  /// full line, i.e. when the sensor is mounted clear of it.
  double get measurableCeilingPercent => calculateLevelPercent(measurableFullDistanceCm);

  /// True when maximum fill sits inside the blind zone, leaving an unmeasurable
  /// band at the top of the tank.
  bool get hasBlindBand => blindDistanceCm > fullDistanceCm;
}
