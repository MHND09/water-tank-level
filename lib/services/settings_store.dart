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
    pollInterval: Duration(seconds: preferences.getInt('pollIntervalSeconds') ?? AppConfig.defaultPollInterval.inSeconds),
  );

  Future<void> save(TankSettings settings) async {
    await preferences.setString('baseUrl', settings.baseUrl);
    await preferences.setDouble('emptyDistanceCm', settings.emptyDistanceCm);
    await preferences.setDouble('fullDistanceCm', settings.fullDistanceCm);
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
    final distance = preferences.getDouble('lastGoodDistanceCm');
    final recordedAtMs = preferences.getInt('lastGoodRecordedAtMs');
    if (distance == null || recordedAtMs == null) return null;
    return StoredReading(
      level: LevelResponse(
        distanceCm: distance,
        ageSeconds: 0,
        status: LevelStatus.ok,
        firmware: preferences.getString('lastGoodFirmware') ?? 'unknown',
      ),
      recordedAt: DateTime.fromMillisecondsSinceEpoch(recordedAtMs),
    );
  }

  Future<void> saveLastReading(LevelResponse level, DateTime recordedAt) async {
    if (level.distanceCm == null || level.status != LevelStatus.ok) return;
    await preferences.setDouble('lastGoodDistanceCm', level.distanceCm!);
    await preferences.setInt('lastGoodRecordedAtMs', recordedAt.millisecondsSinceEpoch);
    await preferences.setString('lastGoodFirmware', level.firmware);
  }
}
