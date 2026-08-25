import 'package:flutter_test/flutter_test.dart';
import 'package:aqua_level/models/sensor_models.dart';

void main() {
  test('parses level response with nullable fields', () {
    final response = LevelResponse.fromJson({'distance_cm': null, 'age_s': null, 'status': 'no_reading', 'fw': '1.0.0'});
    expect(response.distanceCm, isNull);
    expect(response.ageSeconds, isNull);
    expect(response.status, LevelStatus.noReading);
  });

  test('calculates and clamps percentage', () {
    const settings = TankSettings.defaults;
    expect(settings.calculateLevelPercent(55), closeTo(38, 0.01));
    expect(settings.calculateLevelPercent(100), 0);
    expect(settings.calculateLevelPercent(0), 100);
  });

  test('rejects unsafe calibration values', () {
    expect(const TankSettings(baseUrl: 'http://x', emptyDistanceCm: 30, fullDistanceCm: 40, pollInterval: Duration(minutes: 1)).validate(), isNotNull);
    expect(const TankSettings(baseUrl: 'http://x', emptyDistanceCm: 80, fullDistanceCm: 20, pollInterval: Duration(minutes: 1)).validate(), isNotNull);
  });
}
