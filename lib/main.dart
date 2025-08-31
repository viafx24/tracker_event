import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:async';
import 'dart:io';

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
  List<Map<String, dynamic>> daysList = []; // Liste de jours pour ordre inversé
  static const platform = MethodChannel('quick_tile_channel');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initDb();

    // Quick Tile callback
    platform.setMethodCallHandler((call) async {
      if (call.method == "addEvent") {
        await addEvent();
      }
    });
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
    if (_db == null) return;

    final res = await _db!.query('events', orderBy: 'timestamp DESC');
    Map<String, Map<String, dynamic>> tempMap = {};

    for (var row in res) {
      final ts = row['timestamp'] as int;
      final dt = DateTime.fromMillisecondsSinceEpoch(ts);

      // Définir "jour" 8h → 8h
      DateTime dayStart = DateTime(dt.year, dt.month, dt.day, 8);
      if (dt.isBefore(dayStart)) {
        dayStart = dayStart.subtract(const Duration(days: 1));
      }
      final dayKey = dayStart.toIso8601String().substring(0, 10);

      tempMap.putIfAbsent(dayKey, () => {'total': 0, 'night': 0, 'timestamps': <DateTime>[]});
      tempMap[dayKey]!['total'] += 1;
      tempMap[dayKey]!['timestamps'].add(dt);

      // Comptage nuit 22h → 8h
      final nightStart = DateTime(dt.year, dt.month, dt.day, 22);
      final nightEnd = nightStart.add(const Duration(hours: 10));
      if (dt.isAfter(nightStart) || dt.isBefore(nightStart.subtract(const Duration(hours: 14)))) {
        tempMap[dayKey]!['night'] += 1;
      }
    }

    // Convertir map en liste pour contrôler l'ordre
    List<Map<String, dynamic>> tempList = tempMap.entries.map((e) {
      List<DateTime> times = List<DateTime>.from(e.value['timestamps']);
      times.sort((b, a) => a.compareTo(b)); // heures inverse
      return {'day': e.key, 'total': e.value['total'], 'night': e.value['night'], 'timestamps': times};
    }).toList();

    // Trier les jours en ordre inversé
    tempList.sort((b, a) => a['day'].compareTo(b['day']));

    setState(() {
      daysList = tempList;
    });
  }

  Future<void> exportJsonl() async {
    if (_db == null) return;

    final res = await _db!.query('events', orderBy: 'timestamp ASC');

    final dir = await Directory.systemTemp.createTemp();
    final file = File('${dir.path}/toilet_events.jsonl');
    final sink = file.openWrite();

    for (var row in res) {
      sink.writeln('{"id": ${row['id']}, "timestamp": ${row['timestamp']}}');
    }
    await sink.flush();
    await sink.close();

    await Share.shareXFiles([XFile(file.path)], text: 'Export Toilet Tracker Events');
  }

  String formatTime(DateTime dt) => "${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}:${dt.second.toString().padLeft(2,'0')}";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Toilet Tracker'),
        actions: [
          TextButton(
            onPressed: exportJsonl,
            child: const Text(
              'Exporter',
              style: TextStyle(color: Colors.black), // visible sur fond bleu
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: daysList.map((entry) {
            final day = entry['day'];
            final total = entry['total'];
            final night = entry['night'];
            final timestamps = entry['timestamps'] as List<DateTime>;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(),
                Text(day, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text('Total journée (8h-8h): $total'),
                Text('Total nuit (22h-8h): $night'),
                ...timestamps.map((ts) => Text(formatTime(ts))).toList(),
                const SizedBox(height: 8),
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
