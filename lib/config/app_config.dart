class AppConfig {
  static const defaultEsp32BaseUrl = 'http://192.168.1.12';

  /// Sensor to water surface with the tank at its 0% line. Tank geometry.
  static const defaultEmptyDistanceCm = 80.0;

  /// Sensor to water surface at maximum fill. Tank geometry — this sits inside the
  /// sensor blind zone on this tank, which is expected and handled, not an error.
  static const defaultFullDistanceCm = 5.0;

  /// Closest distance the sensor can still measure (JSN-SR04T). Sensor hardware,
  /// not tank geometry. Configurable for other sensors, but not expected to change.
  static const defaultBlindDistanceCm = 27.4;

  static const defaultPollInterval = Duration(minutes: 2);

  const AppConfig._();
}
