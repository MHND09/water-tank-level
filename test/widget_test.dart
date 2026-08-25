import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aqua_level/main.dart';
import 'package:aqua_level/models/sensor_models.dart';
import 'package:aqua_level/providers/app_providers.dart';
import 'package:aqua_level/repositories/tank_repository.dart';

void main() {
  late SharedPreferences preferences;
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
  });

  testWidgets('dashboard displays fake tank level', (tester) async {
    await tester.pumpWidget(ProviderScope(overrides: [sharedPreferencesProvider.overrideWithValue(preferences)], child: const AquaLevelApp()));
    await tester.pumpAndSettle();
    expect(find.text('38%'), findsOneWidget);
  });

  testWidgets('dashboard displays no-reading state', (tester) async {
    final repository = FakeTankRepository(response: const LevelResponse(distanceCm: null, ageSeconds: null, status: LevelStatus.noReading, firmware: 'fake'));
    await tester.pumpWidget(ProviderScope(overrides: [sharedPreferencesProvider.overrideWithValue(preferences), tankRepositoryProvider.overrideWithValue(repository)], child: const AquaLevelApp()));
    await tester.pumpAndSettle();
    expect(find.text('Waiting for sensor'), findsOneWidget);
  });
}
