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
    ref.invalidate(tankRepositoryProvider);
    ref.invalidate(dashboardProvider);
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, TankSettings>(SettingsNotifier.new);
final languageProvider = NotifierProvider<LanguageNotifier, String?>(LanguageNotifier.new);

class LanguageNotifier extends Notifier<String?> {
  @override
  String? build() => ref.read(settingsStoreProvider).loadLanguage();

  Future<void> setLanguage(String? language) async {
    await ref.read(settingsStoreProvider).saveLanguage(language);
    state = language;
  }
}
final tankRepositoryProvider = Provider<TankRepository>((ref) {
  final settings = ref.watch(settingsProvider);
  final repository = HttpTankRepository(settings.baseUrl);
  ref.onDispose(repository.close);
  return repository;
});

enum DashboardStatus { connecting, live, unreachable, noReading, stale }

class DashboardState {
  const DashboardState({this.level, this.recordedAt, required this.status, this.isRefreshing = false, this.error});
  final LevelResponse? level;
  final DateTime? recordedAt;
  final DashboardStatus status;
  final bool isRefreshing;
  final Object? error;
  bool get isLive => status == DashboardStatus.live;

  DashboardState copyWith({LevelResponse? level, DateTime? recordedAt, DashboardStatus? status, bool? isRefreshing, Object? error, bool clearError = false}) => DashboardState(
    level: level ?? this.level,
    recordedAt: recordedAt ?? this.recordedAt,
    status: status ?? this.status,
    isRefreshing: isRefreshing ?? this.isRefreshing,
    error: clearError ? null : error ?? this.error,
  );
}

class DashboardNotifier extends Notifier<DashboardState> {
  Timer? _timer;

  @override
  DashboardState build() {
    final cached = ref.read(settingsStoreProvider).loadLastReading();
    ref.onDispose(() => _timer?.cancel());
    _schedulePolling();
    Future.microtask(refresh);
    return DashboardState(level: cached?.level, recordedAt: cached?.recordedAt, status: DashboardStatus.connecting);
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

  void pausePolling() {
    _timer?.cancel();
    _timer = null;
  }

  void resumePolling() {
    _schedulePolling();
    refresh();
  }

  Future<void> refresh() async {
    if (state.isRefreshing) return;
    state = state.copyWith(isRefreshing: true, clearError: true);
    try {
      final level = await _fetch().timeout(const Duration(seconds: 8));
      final recordedAt = DateTime.now().subtract(Duration(seconds: level.ageSeconds ?? 0));
      if (level.status == LevelStatus.ok) {
        await ref.read(settingsStoreProvider).saveLastReading(level, recordedAt);
      }
      if (level.status == LevelStatus.ok) {
        state = DashboardState(level: level, recordedAt: recordedAt, status: DashboardStatus.live, isRefreshing: false);
      } else {
        state = state.copyWith(
          status: level.status == LevelStatus.stale ? DashboardStatus.stale : DashboardStatus.noReading,
          isRefreshing: false,
          error: Exception(level.status.name),
        );
      }
    } catch (error) {
      state = state.copyWith(status: DashboardStatus.unreachable, isRefreshing: false, error: error);
    }
  }
}

final dashboardProvider = NotifierProvider<DashboardNotifier, DashboardState>(DashboardNotifier.new);
