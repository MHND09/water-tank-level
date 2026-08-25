import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'providers/app_providers.dart';
import 'models/sensor_models.dart';

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

class AquaLevelApp extends StatelessWidget {
  const AquaLevelApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Aqua Level',
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      useMaterial3: true,
    ),
    home: const DashboardScreen(),
  );
}

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncLevel = ref.watch(dashboardProvider);
    final settings = ref.watch(settingsProvider);
    return Scaffold(
      backgroundColor: const Color(0xffeef7ff),
      appBar: AppBar(
        backgroundColor: const Color(0xffeef7ff),
        surfaceTintColor: Colors.transparent,
        title: const Text('Aqua Level'),
        actions: [
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(dashboardProvider.notifier).refresh(),
          ),
        ],
      ),
      body: asyncLevel.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _StatusView(
          title: 'ESP32 unreachable',
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
    if (level.status == LevelStatus.noReading) {
      return const _StatusView(
        title: 'Waiting for sensor',
        detail: 'No valid reading has been received yet.',
        icon: Icons.hourglass_empty,
      );
    }
    if (level.status == LevelStatus.stale) {
      return _StatusView(
        title: 'Sensor not responding',
        detail: 'Last reading is ${level.ageSeconds ?? '?'} seconds old.',
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
              const Icon(Icons.water_drop, color: Color(0xff087fbe), size: 22),
              const SizedBox(width: 8),
              Text('Tank overview', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
              const Spacer(),
              _StatusChip(label: 'Online', color: const Color(0xff168b63), icon: Icons.wifi),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
            decoration: BoxDecoration(
              color: const Color(0xff087fbe),
              borderRadius: BorderRadius.circular(28),
              boxShadow: const [BoxShadow(color: Color(0x26087fbe), blurRadius: 18, offset: Offset(0, 10))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Current level', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white70)),
                    Icon(Icons.water_drop_outlined, color: Colors.white.withAlpha(180), size: 24),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('${percent.toStringAsFixed(0)}%', style: Theme.of(context).textTheme.displayMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w800, height: 1)),
                    const SizedBox(width: 12),
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
          ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: _InfoTile(icon: Icons.schedule, label: 'Last update', value: '${level.ageSeconds ?? 0}s ago')),
            const SizedBox(width: 12),
            Expanded(child: _InfoTile(icon: Icons.memory, label: 'Firmware', value: level.firmware)),
          ]),
          const SizedBox(height: 16),
          Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xffd9eaf5))), child: const Row(children: [Icon(Icons.tips_and_updates_outlined, color: Color(0xffed9b2c)), SizedBox(width: 12), Expanded(child: Text('Level updates automatically while this app is open.'))])),
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

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label, value;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xffd9eaf5))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, color: const Color(0xff087fbe)), const SizedBox(height: 10), Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.black54)), const SizedBox(height: 3), Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700))]));
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
    final settings = TankSettings(
      baseUrl: _url.text.trim(),
      emptyDistanceCm: double.tryParse(_empty.text) ?? 0,
      fullDistanceCm: double.tryParse(_full.text) ?? 0,
      pollInterval: Duration(minutes: int.tryParse(_interval.text) ?? 0),
    );
    final error = settings.validate();
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
    appBar: AppBar(title: const Text('Settings')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        TextField(
          controller: _url,
          decoration: const InputDecoration(
            labelText: 'ESP32 address',
            hintText: 'http://192.168.1.12',
          ),
        ),
        TextField(
          controller: _empty,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Empty distance (cm)'),
        ),
        TextField(
          controller: _full,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Full distance (cm)'),
        ),
        TextField(
          controller: _interval,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Poll interval (minutes)',
          ),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: _save,
          icon: const Icon(Icons.save),
          label: const Text('Save settings'),
        ),
      ],
    ),
  );
}
