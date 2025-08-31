import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'dart:async';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Toilet Tracker',
      theme: ThemeData(primarySwatch: Colors.indigo),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  Database? _db;
  int todayCount = 0;
  int tonightCount = 0;
  Map<String, List<int>> dayTimestamps = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initDb();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshCounts();
    }
  }

  Future<void> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'events.db');
    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('CREATE TABLE events(id INTEGER PRIMARY KEY, timestamp INTEGER)');
      },
    );
    _refreshCounts();
  }

  Future<void> addEvent() async {
    final ts = DateTime.now().millisecondsSinceEpoch;
    await _db?.insert('events', {'timestamp': ts});
    _refreshCounts();
  }

  Future<void> _refreshCounts() async {
    final now = DateTime.now();

    // Total du jour 08:00 → 08:00
    final startOfDay = DateTime(now.year, now.month, now.day, 8);
    final startMs = startOfDay.millisecondsSinceEpoch;
    final endMs = startOfDay.add(const Duration(days: 1)).millisecondsSinceEpoch;

    final todayRes = await _db?.rawQuery(
      'SELECT COUNT(*) as c FROM events WHERE timestamp BETWEEN ? AND ?',
      [startMs, endMs],
    );
    todayCount = todayRes?[0]['c'] as int? ?? 0;

    // Nuit 22:00 → 08:00
    final startNight = DateTime(now.year, now.month, now.day, 22).subtract(const Duration(days: 1));
    final endNight = DateTime(now.year, now.month, now.day, 8);
    final nightRes = await _db?.rawQuery(
      'SELECT COUNT(*) as c FROM events WHERE timestamp BETWEEN ? AND ?',
      [startNight.millisecondsSinceEpoch, endNight.millisecondsSinceEpoch],
    );
    tonightCount = nightRes?[0]['c'] as int? ?? 0;

    // Regrouper par journée 08:00 → 08:00
    final res = await _db?.rawQuery(
      'SELECT timestamp FROM events ORDER BY timestamp DESC',
    );
    dayTimestamps = {};
    if (res != null) {
      for (var row in res) {
        final ts = row['timestamp'] as int;
        final dt = DateTime.fromMillisecondsSinceEpoch(ts);
        // Calculer date de la journée 08:00→08:00
        DateTime day;
        if (dt.hour >= 8) {
          day = DateTime(dt.year, dt.month, dt.day, 8);
        } else {
          final prev = dt.subtract(const Duration(days: 1));
          day = DateTime(prev.year, prev.month, prev.day, 8);
        }
        final dayKey = day.toIso8601String().substring(0, 10);
        dayTimestamps.putIfAbsent(dayKey, () => []).add(ts);
      }
    }

    setState(() {});
  }

  String formatTimestamp(int ts) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ts);
    return "${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}:${dt.second.toString().padLeft(2,'0')}";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Toilet Tracker')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: dayTimestamps.entries.map((entry) {
            final day = entry.key;
            final timestamps = entry.value;
            final totalDay = timestamps.length;
            final totalNight = timestamps
                .where((ts) {
                  final dt = DateTime.fromMillisecondsSinceEpoch(ts);
                  return dt.hour >= 22 || dt.hour < 8;
                })
                .length;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(day, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const Divider(),
                Text("Total jour (08:00→08:00): $totalDay"),
                Text("Total nuit (22:00→08:00): $totalNight"),
                ...timestamps.map((ts) => Text(formatTimestamp(ts))).toList(),
                const SizedBox(height: 20),
              ],
            );
          }).toList(),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: addEvent,
        child: const Icon(Icons.add),
      ),
    );
  }
}
