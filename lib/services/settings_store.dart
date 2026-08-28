import 'package:shared_preferences/shared_preferences.dart';
import '../models/sensor_models.dart';
import '../config/app_config.dart';

class SettingsStore {
  const SettingsStore(this.preferences);
  final SharedPreferences preferences;

  TankSettings load() => TankSettings(
    baseUrl: preferences.getString('baseUrl') ?? AppConfig.defaultEsp32BaseUrl,
    emptyDistanceCm: preferences.getDouble('emptyDistanceCm') ?? AppConfig.defaultEmptyDistanceCm,
    fullDistanceCm: preferences.getDouble('fullDistanceCm') ?? AppConfig.defaultFullDistanceCm,
    blindDistanceCm: preferences.getDouble('blindDistanceCm') ?? AppConfig.defaultBlindDistanceCm,
    pollInterval: Duration(seconds: preferences.getInt('pollIntervalSeconds') ?? AppConfig.defaultPollInterval.inSeconds),
  );

  Future<void> save(TankSettings settings) async {
    await preferences.setString('baseUrl', settings.baseUrl);
    await preferences.setDouble('emptyDistanceCm', settings.emptyDistanceCm);
    await preferences.setDouble('fullDistanceCm', settings.fullDistanceCm);
    await preferences.setDouble('blindDistanceCm', settings.blindDistanceCm);
    await preferences.setInt('pollIntervalSeconds', settings.pollInterval.inSeconds);
  }

  String? loadLanguage() => preferences.getString('language');

  Future<void> saveLanguage(String? language) async {
    if (language == null || language == 'system') {
      await preferences.remove('language');
    } else {
      await preferences.setString('language', language);
    }
  }

  StoredReading? loadLastReading() {
    final recordedAtMs = preferences.getInt('lastGoodRecordedAtMs');
    if (recordedAtMs == null) return null;
    final wasBelowRange = preferences.getString('lastGoodStatus') == LevelStatus.belowRange.name;
    final distance = preferences.getDouble('lastGoodDistanceCm');
    if (!wasBelowRange && distance == null) return null;
    return StoredReading(
      level: LevelResponse(
        distanceCm: wasBelowRange ? null : distance,
        ageSeconds: 0,
        status: wasBelowRange ? LevelStatus.belowRange : LevelStatus.ok,
        firmware: preferences.getString('lastGoodFirmware') ?? 'unknown',
      ),
      recordedAt: DateTime.fromMillisecondsSinceEpoch(recordedAtMs),
    );
  }

  /// Caches `ok` and `below_range` alike. Caching `below_range` matters: without it a
  /// cold start over a dead network would restore the last `ok` percentage, which is
  /// wrong once the tank has filled above the measurable line.
  Future<void> saveLastReading(LevelResponse level, DateTime recordedAt) async {
    if (level.status == LevelStatus.ok && level.distanceCm != null) {
      await preferences.setDouble('lastGoodDistanceCm', level.distanceCm!);
    } else if (level.status == LevelStatus.belowRange) {
      await preferences.remove('lastGoodDistanceCm');
    } else {
      return;
    }
    await preferences.setString('lastGoodStatus', level.status.name);
    await preferences.setInt('lastGoodRecordedAtMs', recordedAt.millisecondsSinceEpoch);
    await preferences.setString('lastGoodFirmware', level.firmware);
  }
}
