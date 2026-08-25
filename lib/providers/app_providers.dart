import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/sensor_models.dart';
import '../repositories/tank_repository.dart';
import '../services/settings_store.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) => throw UnimplementedError());
final settingsStoreProvider = Provider((ref) => SettingsStore(ref.watch(sharedPreferencesProvider)));

class SettingsNotifier extends Notifier<TankSettings> {
  @override
  TankSettings build() => ref.read(settingsStoreProvider).load();
  Future<void> save(TankSettings value) async {
    await ref.read(settingsStoreProvider).save(value);
    state = value;
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, TankSettings>(SettingsNotifier.new);
final tankRepositoryProvider = Provider<TankRepository>((ref) => FakeTankRepository());

class DashboardNotifier extends AsyncNotifier<LevelResponse> {
  Timer? _timer;

  @override
  Future<LevelResponse> build() async {
    ref.onDispose(() => _timer?.cancel());
    _schedulePolling();
    return _fetch();
  }

  Future<LevelResponse> _fetch() async {
    final repository = ref.read(tankRepositoryProvider);
    Object? lastError;
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        await repository.ping();
        return await repository.getLevel();
      } catch (error) {
        lastError = error;
        if (attempt < 2) await Future<void>.delayed(Duration(milliseconds: 300 * (attempt + 1)));
      }
    }
    throw lastError ?? Exception('ESP32 unreachable.');
  }

  void _schedulePolling() {
    _timer?.cancel();
    _timer = Timer.periodic(ref.read(settingsProvider).pollInterval, (_) => refresh());
  }

  Future<void> refresh() async {
    state = const AsyncLoading<LevelResponse>().copyWithPrevious(state);
    state = await AsyncValue.guard(_fetch);
  }
}

final dashboardProvider = AsyncNotifierProvider<DashboardNotifier, LevelResponse>(DashboardNotifier.new);
