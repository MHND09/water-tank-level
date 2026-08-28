import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'providers/app_providers.dart';
import 'models/sensor_models.dart';
import 'l10n/app_localizations.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final preferences = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
      child: const AquaLevelApp(),
    ),
  );
}

class AquaLevelApp extends ConsumerWidget {
  const AquaLevelApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final language = ref.watch(languageProvider);
    return MaterialApp(
    title: 'Aqua Level',
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    locale: language == null ? null : Locale(language),
    localeResolutionCallback: (locale, supported) => supported.firstWhere((item) => item.languageCode == locale?.languageCode, orElse: () => const Locale('en')),
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      useMaterial3: true,
      textTheme: GoogleFonts.nunitoTextTheme(),
      appBarTheme: AppBarTheme(titleTextStyle: GoogleFonts.nunito(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.black87)),
    ),
    home: const DashboardScreen(),
    );
  }
}

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});
  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> with WidgetsBindingObserver {
  Timer? _relativeTimeTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startRelativeTimeTimer();
  }

  void _startRelativeTimeTimer() {
    _relativeTimeTimer?.cancel();
    _relativeTimeTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _relativeTimeTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startRelativeTimeTimer();
      ref.read(dashboardProvider.notifier).resumePolling();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _relativeTimeTimer?.cancel();
      ref.read(dashboardProvider.notifier).pausePolling();
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final dashboard = ref.watch(dashboardProvider);
    final settings = ref.watch(settingsProvider);
    return Scaffold(
      backgroundColor: const Color(0xffeef7ff),
      appBar: AppBar(
        backgroundColor: const Color(0xffeef7ff),
        surfaceTintColor: Colors.transparent,
        title: Text(strings.appTitle),
        actions: [
          IconButton(
            tooltip: strings.settings,
            icon: const Icon(Icons.settings_rounded, size: 21),
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
          IconButton(
            tooltip: strings.refresh,
            icon: dashboard.isRefreshing
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4))
                : const Icon(Icons.refresh_rounded, size: 21),
            onPressed: dashboard.isRefreshing ? null : () => ref.read(dashboardProvider.notifier).refresh(),
          ),
        ],
      ),
      body: _LevelView(
        level: dashboard.level ?? const LevelResponse(distanceCm: null, ageSeconds: null, status: LevelStatus.noReading, firmware: '—'),
        settings: settings,
        status: dashboard.status,
        isRefreshing: dashboard.isRefreshing,
        recordedAt: dashboard.recordedAt,
      ),
    );
  }
}

class _LevelView extends StatelessWidget {
  const _LevelView({required this.level, required this.settings, required this.status, required this.isRefreshing, required this.recordedAt});
  final LevelResponse level;
  final TankSettings settings;
  final DashboardStatus status;
  final bool isRefreshing;
  final DateTime? recordedAt;
  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final hasReading = level.distanceCm != null;
    final isBelowRange = status == DashboardStatus.belowRange;
    final isHealthy = status == DashboardStatus.live || isBelowRange;
    final ceilingPercent = settings.measurableCeilingPercent;
    final statusLabel = switch (status) {
      DashboardStatus.connecting => strings.connecting,
      DashboardStatus.live => strings.online,
      DashboardStatus.belowRange => strings.aboveRange,
      DashboardStatus.unreachable => strings.notLive,
      DashboardStatus.noReading => strings.sensorWaiting,
      DashboardStatus.stale => strings.sensorStale,
    };
    final statusIcon = switch (status) {
      DashboardStatus.live => Icons.wifi_rounded,
      DashboardStatus.belowRange => Icons.arrow_circle_up_rounded,
      DashboardStatus.connecting => Icons.sync_rounded,
      DashboardStatus.noReading => Icons.hourglass_empty_rounded,
      DashboardStatus.stale => Icons.warning_amber_rounded,
      DashboardStatus.unreachable => Icons.wifi_off_rounded,
    };
    // below_range carries no distance by design: the surface is somewhere inside the
    // unmeasurable band, so fill to the ceiling and show the number as a lower bound.
    final percent = isBelowRange
        ? ceilingPercent
        : hasReading ? settings.calculateLevelPercent(level.distanceCm!) : 0.0;
    final percentText = isBelowRange
        ? strings.atLeastPercent(ceilingPercent.toStringAsFixed(0))
        : hasReading ? '${percent.toStringAsFixed(0)}%' : '—%';
    final firmwareBlindCm = level.blindCm;
    final hasBlindMismatch = firmwareBlindCm != null && (firmwareBlindCm - settings.blindDistanceCm).abs() > 0.5;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(color: const Color(0xffd9f2ff), borderRadius: BorderRadius.circular(14)),
                child: const Center(child: Icon(Icons.water_drop_rounded, color: Color(0xff087fbe), size: 23)),
              ),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(strings.tankOverview, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                Text(strings.liveMonitor, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.black54)),
              ]),
              const Spacer(),
              _StatusChip(label: statusLabel, color: isHealthy ? const Color(0xff168b63) : const Color(0xffd05b4d), icon: statusIcon),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 24),
            decoration: BoxDecoration(color: isHealthy ? const Color(0xff087fbe) : const Color(0xff607d91), borderRadius: BorderRadius.circular(30), boxShadow: const [BoxShadow(color: Color(0x26087fbe), blurRadius: 18, offset: Offset(0, 10))]),
            child: Stack(
              children: [
                Positioned(top: -34, right: -28, child: _DecorativeBubble(size: 105, color: Colors.white.withAlpha(12))),
                Positioned(bottom: -42, left: -38, child: _DecorativeBubble(size: 120, color: Colors.white.withAlpha(10))),
                Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(strings.currentLevel, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white70)),
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(color: Colors.white.withAlpha(28), shape: BoxShape.circle),
                      child: const Center(child: Icon(Icons.water_drop_rounded, color: Colors.white, size: 19)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(percentText, style: Theme.of(context).textTheme.displayMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w800, height: 1)),
                    const SizedBox(width: 10),
                    Padding(padding: const EdgeInsets.only(bottom: 4), child: Text(isRefreshing ? strings.retrying : strings.tankCapacity, style: TextStyle(color: Colors.white.withAlpha(190), fontWeight: FontWeight.w600))),
                  ],
                ),
                const SizedBox(height: 20),
                Center(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: percent / 100),
                    duration: const Duration(milliseconds: 900),
                    curve: Curves.easeOutCubic,
                    builder: (_, animatedLevel, __) => SizedBox(
                      width: 150,
                      height: 190,
                      child: CustomPaint(
                        painter: _TankPainter(
                          animatedLevel,
                          ceiling: ceilingPercent / 100,
                          band: !settings.hasBlindBand
                              ? _TankBand.none
                              : isBelowRange ? _TankBand.probable : _TankBand.unknown,
                        ),
                      ),
                    ),
                  ),
                ),
                if (settings.hasBlindBand) ...[
                  const SizedBox(height: 10),
                  Center(
                    child: Text(
                      strings.measurableUpTo(ceilingPercent.toStringAsFixed(0)),
                      style: TextStyle(color: Colors.white.withAlpha(180), fontWeight: FontWeight.w600, fontSize: 12),
                    ),
                  ),
                ],
              ],
                ),
              ],
            ),
          ),
          if (isBelowRange) ...[
            const SizedBox(height: 14),
            _StateNotice.info(icon: statusIcon, title: strings.aboveRange, detail: strings.belowRangeDetail),
          ] else if (!isHealthy) ...[
            const SizedBox(height: 14),
            _StateNotice(
              icon: statusIcon,
              title: statusLabel,
              detail: switch (status) {
                DashboardStatus.connecting => strings.connectingDetail,
                DashboardStatus.unreachable => strings.unreachableDetail,
                DashboardStatus.noReading => strings.noReadingDetail,
                DashboardStatus.stale => strings.staleDetail,
                DashboardStatus.live || DashboardStatus.belowRange => '',
              },
            ),
          ],
          if (hasBlindMismatch) ...[
            const SizedBox(height: 14),
            _StateNotice(
              icon: Icons.rule_rounded,
              title: strings.blindMismatchTitle,
              detail: strings.blindMismatch(firmwareBlindCm.toStringAsFixed(1), settings.blindDistanceCm.toStringAsFixed(1)),
            ),
          ],
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: _InfoTile(icon: Icons.schedule_rounded, label: strings.lastUpdate, value: recordedAt == null ? strings.unknown : strings.relativeTime(DateTime.now().difference(recordedAt!)), accent: const Color(0xffe66f51))),
            const SizedBox(width: 12),
            Expanded(child: _InfoTile(icon: Icons.memory_rounded, label: strings.firmware, value: level.firmware, accent: const Color(0xff7a68c7))),
          ]),
          const SizedBox(height: 16),
          Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: const Color(0xfffff4d8), borderRadius: BorderRadius.circular(22), border: Border.all(color: const Color(0xffffdf92))), child: Row(children: [Container(width: 42, height: 42, decoration: const BoxDecoration(color: Color(0xffffdf92), shape: BoxShape.circle), child: const Center(child: Icon(Icons.lightbulb_rounded, color: Color(0xffb96e00), size: 21))), const SizedBox(width: 12), Expanded(child: Text(strings.updateTip, style: const TextStyle(color: Color(0xff765013), fontWeight: FontWeight.w600)))])),
        ],
      ),
    );
  }
}

class _StateNotice extends StatelessWidget {
  const _StateNotice({required this.icon, required this.title, required this.detail})
      : background = const Color(0xffffeeee),
        border = const Color(0xffffc8c2),
        iconBackground = const Color(0xffffd6d1),
        iconColor = const Color(0xffbd493f),
        titleColor = const Color(0xff8f3029),
        detailColor = const Color(0xff76504d);

  /// Informational palette, for states that are expected rather than faults.
  const _StateNotice.info({required this.icon, required this.title, required this.detail})
      : background = const Color(0xffe7f3fb),
        border = const Color(0xffbcdcf0),
        iconBackground = const Color(0xffcfe8f7),
        iconColor = const Color(0xff0b5f8f),
        titleColor = const Color(0xff0b5f8f),
        detailColor = const Color(0xff44708c);

  final IconData icon;
  final String title;
  final String detail;
  final Color background, border, iconBackground, iconColor, titleColor, detailColor;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(18), border: Border.all(color: border)),
    child: Row(children: [
      Container(width: 38, height: 38, decoration: BoxDecoration(color: iconBackground, shape: BoxShape.circle), child: Icon(icon, color: iconColor, size: 20)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: TextStyle(fontWeight: FontWeight.w800, color: titleColor)), const SizedBox(height: 2), Text(detail, style: TextStyle(color: detailColor, fontSize: 13))])),
    ]),
  );
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color, required this.icon});
  final String label;
  final Color color;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: color.withAlpha(24), borderRadius: BorderRadius.circular(99)), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 15, color: color), const SizedBox(width: 5), Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12))]));
}

class _DecorativeBubble extends StatelessWidget {
  const _DecorativeBubble({required this.size, required this.color});
  final double size;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(width: size, height: size, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: color, width: 14)));
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.icon, required this.label, required this.value, required this.accent});
  final IconData icon;
  final String label, value;
  final Color accent;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: accent.withAlpha(35)), boxShadow: const [BoxShadow(color: Color(0x0b16324f), blurRadius: 12, offset: Offset(0, 5))]), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Container(width: 38, height: 38, decoration: BoxDecoration(color: accent.withAlpha(24), borderRadius: BorderRadius.circular(12)), child: Center(child: Icon(icon, size: 20, color: accent))), const SizedBox(height: 10), Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.black54)), const SizedBox(height: 3), Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800))]));
}

/// How to render the band above the sensor's measurable ceiling.
/// [none] when the sensor clears the full line, [unknown] when the surface is
/// measurable and the band is simply out of reach, [probable] when the surface is
/// confirmed to be somewhere inside the band.
enum _TankBand { none, unknown, probable }

class _TankPainter extends CustomPainter {
  const _TankPainter(this.level, {this.ceiling = 1.0, this.band = _TankBand.none});
  final double level;

  /// Measurable ceiling as a 0-1 fraction of tank height.
  final double ceiling;
  final _TankBand band;

  @override
  void paint(Canvas canvas, Size size) {
    final tank = RRect.fromRectAndRadius(Rect.fromLTWH(16, 12, size.width - 32, size.height - 20), const Radius.circular(18));
    canvas.drawRRect(tank, Paint()..color = Colors.white.withAlpha(65));
    final tankHeight = size.height - 20;
    final waterTop = 12 + tankHeight * (1 - level.clamp(0, 1));
    canvas.save();
    canvas.clipRRect(tank);
    canvas.drawRect(Rect.fromLTWH(16, waterTop, size.width - 32, size.height), Paint()..color = Colors.white.withAlpha(190));
    canvas.drawCircle(Offset(38, waterTop + 2), 3, Paint()..color = Colors.white70);
    canvas.drawCircle(Offset(72, waterTop + 5), 2, Paint()..color = Colors.white70);
    if (band != _TankBand.none) {
      final ceilingY = 12 + tankHeight * (1 - ceiling.clamp(0, 1));
      _paintBand(canvas, size, ceilingY);
    }
    canvas.restore();
    canvas.drawRRect(tank, Paint()..style = PaintingStyle.stroke..strokeWidth = 2..color = Colors.white70);
    canvas.drawLine(const Offset(30, 5), Offset(size.width - 30, 5), Paint()..strokeWidth = 5..strokeCap = StrokeCap.round..color = Colors.white);
    canvas.drawCircle(Offset(size.width / 2, 5), 4, Paint()..color = const Color(0xffffd166));
  }

  /// Called inside the tank clip, so the hatch follows the rounded corners.
  void _paintBand(Canvas canvas, Size size, double ceilingY) {
    const left = 16.0;
    final right = size.width - 16;
    final rect = Rect.fromLTRB(left, 12, right, ceilingY);
    if (rect.height <= 0) return;
    final isProbable = band == _TankBand.probable;
    if (isProbable) canvas.drawRect(rect, Paint()..color = Colors.white.withAlpha(40));

    canvas.save();
    canvas.clipRect(rect);
    final hatch = Paint()
      ..color = Colors.white.withAlpha(isProbable ? 110 : 70)
      ..strokeWidth = 1.5;
    // 45 degree lines: sweeping x from -height to width + height covers the band.
    for (var x = -rect.height; x < rect.width + rect.height; x += 8) {
      canvas.drawLine(Offset(left + x, ceilingY), Offset(left + x + rect.height, 12), hatch);
    }
    canvas.restore();

    final rule = Paint()
      ..color = Colors.white.withAlpha(140)
      ..strokeWidth = 1.5;
    for (var x = left; x < right; x += 9) {
      canvas.drawLine(Offset(x, ceilingY), Offset((x + 5).clamp(left, right), ceilingY), rule);
    }
  }

  @override
  bool shouldRepaint(covariant _TankPainter oldDelegate) =>
      oldDelegate.level != level || oldDelegate.ceiling != ceiling || oldDelegate.band != band;
}

class _StatusView extends StatelessWidget {
  const _StatusView({
    required this.title,
    required this.detail,
    required this.icon,
  });
  final String title, detail;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 56),
          const SizedBox(height: 16),
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(detail, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});
  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late final TextEditingController _url, _empty, _full, _blind, _interval;
  @override
  void initState() {
    super.initState();
    final s = ref.read(settingsProvider);
    _url = TextEditingController(text: s.baseUrl);
    _empty = TextEditingController(text: '${s.emptyDistanceCm}');
    _full = TextEditingController(text: '${s.fullDistanceCm}');
    _blind = TextEditingController(text: '${s.blindDistanceCm}');
    _interval = TextEditingController(
      text: '${s.pollInterval.inSeconds ~/ 60}',
    );
  }

  @override
  void dispose() {
    _url.dispose();
    _empty.dispose();
    _full.dispose();
    _blind.dispose();
    _interval.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final strings = AppLocalizations.of(context);
    final settings = TankSettings(
      baseUrl: _url.text.trim(),
      emptyDistanceCm: double.tryParse(_empty.text) ?? 0,
      fullDistanceCm: double.tryParse(_full.text) ?? 0,
      blindDistanceCm: double.tryParse(_blind.text) ?? 0,
      pollInterval: Duration(minutes: int.tryParse(_interval.text) ?? 0),
    );
    final validationError = settings.validate();
    final error = switch (validationError) {
      null => null,
      'ESP32 address is required.' => strings.addressRequired,
      'Enter a valid HTTP address.' => strings.validAddress,
      'Distances must be positive.' => strings.positiveDistances,
      'Empty distance must be greater than full distance.' => strings.distanceOrder,
      'Empty distance must be greater than the blind distance.' => strings.distanceBlindOrder,
      'Poll interval must be positive.' => strings.positiveInterval,
      _ => validationError,
    };
    if (error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    await ref.read(settingsProvider.notifier).save(settings);
    if (mounted) Navigator.pop(context);
  }

  /// Blind band preview, driven by the typed values so the effect of a change is
  /// visible before saving. Absent when the sensor clears the full line.
  Widget? _blindBandNotice(AppLocalizations strings) {
    final empty = double.tryParse(_empty.text);
    final full = double.tryParse(_full.text);
    final blind = double.tryParse(_blind.text);
    if (empty == null || full == null || blind == null) return null;
    if (empty <= 0 || full <= 0 || blind <= 0 || empty <= full || empty <= blind) return null;
    final draft = TankSettings(
      baseUrl: _url.text,
      emptyDistanceCm: empty,
      fullDistanceCm: full,
      blindDistanceCm: blind,
      pollInterval: const Duration(minutes: 1),
    );
    if (!draft.hasBlindBand) return null;
    final ceiling = draft.measurableCeilingPercent;
    return _StateNotice.info(
      icon: Icons.grid_goldenratio_rounded,
      title: strings.unmeasurableBand,
      detail: '${strings.blindBandNotice((100 - ceiling).round())} ${strings.measurableUpTo(ceiling.toStringAsFixed(0))}.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final bandNotice = _blindBandNotice(strings);
    return Scaffold(
    appBar: AppBar(title: Text(strings.settingsTitle)),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        TextField(
          controller: _url,
          decoration: InputDecoration(labelText: strings.espAddress, hintText: strings.defaultAddress),
        ),
        TextField(
          controller: _empty,
          keyboardType: TextInputType.number,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(labelText: strings.emptyDistance),
        ),
        TextField(
          controller: _full,
          keyboardType: TextInputType.number,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(labelText: strings.fullDistance, helperText: strings.fullDistanceHelp, helperMaxLines: 3),
        ),
        TextField(
          controller: _blind,
          keyboardType: TextInputType.number,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(labelText: strings.blindDistance, helperText: strings.blindDistanceHelp, helperMaxLines: 3),
        ),
        TextField(
          controller: _interval,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: strings.pollInterval,
          ),
        ),
        if (bandNotice != null) ...[
          const SizedBox(height: 18),
          bandNotice,
        ],
        const SizedBox(height: 18),
        Consumer(builder: (context, ref, _) {
          final strings = AppLocalizations.of(context);
          final selectedLanguage = ref.watch(languageProvider) ?? 'system';
          return DropdownButtonFormField<String>(
            value: selectedLanguage,
            decoration: InputDecoration(labelText: strings.language, prefixIcon: const Icon(Icons.language_rounded)),
            items: [
              DropdownMenuItem(value: 'system', child: Text(strings.systemLanguage)),
              DropdownMenuItem(value: 'en', child: Text(strings.english)),
              DropdownMenuItem(value: 'fr', child: Text(strings.french)),
            ],
            onChanged: (value) => ref.read(languageProvider.notifier).setLanguage(value == 'system' ? null : value),
          );
        }),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: _save,
          icon: const Icon(Icons.save),
          label: Text(strings.saveSettings),
        ),
      ],
    ),
    );
  }
}
