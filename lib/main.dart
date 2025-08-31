import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tracker Event',
      theme: ThemeData(primarySwatch: Colors.blue),
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
  int _count = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadCount();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Recharge les données quand l’app reprend le focus
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadCount();
    }
  }

  Future<void> _loadCount() async {
    final dbPath = await getDatabasesPath();
    final db = await openDatabase('$dbPath/events.db');
    final result = await db.rawQuery(
        "SELECT COUNT(*) as count FROM events "
        "WHERE date(timestamp/1000, 'unixepoch', 'localtime') = date('now', 'localtime')");
    setState(() {
      _count = Sqflite.firstIntValue(result) ?? 0;
    });
    await db.close();
  }

  Future<void> _addEvent() async {
    final dbPath = await getDatabasesPath();
    final db = await openDatabase('$dbPath/events.db');
    final ts = DateTime.now().millisecondsSinceEpoch;
    await db.insert("events", {"timestamp": ts});
    await db.close();
    await _loadCount();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Tracker")),
      body: Center(
        child: Text(
          "Passages aujourd'hui : $_count",
          style: const TextStyle(fontSize: 22),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addEvent,
        child: const Icon(Icons.add),
      ),
    );
  }
}
