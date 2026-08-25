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

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = AppLocalizations.of(context);
    final asyncLevel = ref.watch(dashboardProvider);
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
            icon: const Icon(Icons.refresh_rounded, size: 21),
            onPressed: () => ref.read(dashboardProvider.notifier).refresh(),
          ),
        ],
      ),
      body: asyncLevel.when(
        loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _StatusView(
          title: strings.unreachable,
          detail: error.toString(),
          icon: Icons.wifi_off,
        ),
        data: (level) => _LevelView(level: level, settings: settings),
      ),
    );
  }
}

class _LevelView extends StatelessWidget {
  const _LevelView({required this.level, required this.settings});
  final LevelResponse level;
  final TankSettings settings;
  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    if (level.status == LevelStatus.noReading) {
      return _StatusView(
        title: strings.waitingSensor,
        detail: strings.noReading,
        icon: Icons.hourglass_empty,
      );
    }
    if (level.status == LevelStatus.stale) {
      return _StatusView(
        title: strings.sensorNotResponding,
        detail: strings.lastReading(level.ageSeconds ?? '?'),
        icon: Icons.warning_amber,
      );
    }
    final percent = settings.calculateLevelPercent(
      level.distanceCm ?? settings.emptyDistanceCm,
    );
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
              _StatusChip(label: strings.online, color: const Color(0xff168b63), icon: Icons.wifi_rounded),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 24),
            decoration: BoxDecoration(color: const Color(0xff087fbe), borderRadius: BorderRadius.circular(30), boxShadow: const [BoxShadow(color: Color(0x26087fbe), blurRadius: 18, offset: Offset(0, 10))]),
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
                    Text('${percent.toStringAsFixed(0)}%', style: Theme.of(context).textTheme.displayMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w800, height: 1)),
                    const SizedBox(width: 10),
                    Padding(padding: const EdgeInsets.only(bottom: 4), child: Text(strings.tankCapacity, style: TextStyle(color: Colors.white.withAlpha(190), fontWeight: FontWeight.w600))),
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
                      child: CustomPaint(painter: _TankPainter(animatedLevel)),
                    ),
                  ),
                ),
              ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: _InfoTile(icon: Icons.schedule_rounded, label: strings.lastUpdate, value: strings.updatedAgo(level.ageSeconds ?? 0), accent: const Color(0xffe66f51))),
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

class _TankPainter extends CustomPainter {
  const _TankPainter(this.level);
  final double level;
  @override
  void paint(Canvas canvas, Size size) {
    final tank = RRect.fromRectAndRadius(Rect.fromLTWH(16, 12, size.width - 32, size.height - 20), const Radius.circular(18));
    canvas.drawRRect(tank, Paint()..color = Colors.white.withAlpha(65));
    final waterTop = 12 + (size.height - 20) * (1 - level.clamp(0, 1));
    canvas.save();
    canvas.clipRRect(tank);
    canvas.drawRect(Rect.fromLTWH(16, waterTop, size.width - 32, size.height), Paint()..color = Colors.white.withAlpha(190));
    canvas.drawCircle(Offset(38, waterTop + 2), 3, Paint()..color = Colors.white70);
    canvas.drawCircle(Offset(72, waterTop + 5), 2, Paint()..color = Colors.white70);
    canvas.restore();
    canvas.drawRRect(tank, Paint()..style = PaintingStyle.stroke..strokeWidth = 2..color = Colors.white70);
    canvas.drawLine(const Offset(30, 5), Offset(size.width - 30, 5), Paint()..strokeWidth = 5..strokeCap = StrokeCap.round..color = Colors.white);
    canvas.drawCircle(Offset(size.width / 2, 5), 4, Paint()..color = const Color(0xffffd166));
  }
  @override
  bool shouldRepaint(covariant _TankPainter oldDelegate) => oldDelegate.level != level;
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
  late final TextEditingController _url, _empty, _full, _interval;
  @override
  void initState() {
    super.initState();
    final s = ref.read(settingsProvider);
    _url = TextEditingController(text: s.baseUrl);
    _empty = TextEditingController(text: '${s.emptyDistanceCm}');
    _full = TextEditingController(text: '${s.fullDistanceCm}');
    _interval = TextEditingController(
      text: '${s.pollInterval.inSeconds ~/ 60}',
    );
  }

  @override
  void dispose() {
    _url.dispose();
    _empty.dispose();
    _full.dispose();
    _interval.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final strings = AppLocalizations.of(context);
    final settings = TankSettings(
      baseUrl: _url.text.trim(),
      emptyDistanceCm: double.tryParse(_empty.text) ?? 0,
      fullDistanceCm: double.tryParse(_full.text) ?? 0,
      pollInterval: Duration(minutes: int.tryParse(_interval.text) ?? 0),
    );
    final validationError = settings.validate();
    final error = switch (validationError) {
      null => null,
      'ESP32 address is required.' => strings.addressRequired,
      'Enter a valid HTTP address.' => strings.validAddress,
      'Distances must be positive.' => strings.positiveDistances,
      'Empty distance must be greater than full distance.' => strings.distanceOrder,
      'Full distance must be at least 30 cm.' => strings.blindZone,
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

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(AppLocalizations.of(context).settingsTitle)),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        TextField(
          controller: _url,
          decoration: InputDecoration(labelText: AppLocalizations.of(context).espAddress, hintText: AppLocalizations.of(context).defaultAddress),
        ),
        TextField(
          controller: _empty,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: AppLocalizations.of(context).emptyDistance),
        ),
        TextField(
          controller: _full,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: AppLocalizations.of(context).fullDistance),
        ),
        TextField(
          controller: _interval,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: AppLocalizations.of(context).pollInterval,
          ),
        ),
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
          label: Text(AppLocalizations.of(context).saveSettings),
        ),
      ],
    ),
  );
}
