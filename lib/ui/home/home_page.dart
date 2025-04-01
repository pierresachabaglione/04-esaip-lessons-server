import 'dart:async';

import 'package:esaip_lessons_server/managers/global_manager.dart';
import 'package:esaip_lessons_server/models/http_log.dart';
import 'package:flutter/material.dart';

/// Home page of the app
class HomePage extends StatefulWidget {
  /// Title of the home page
  const HomePage({super.key, required this.title});

  /// Title of the home page
  final String title;

  @override
  State<HomePage> createState() => _HomePageState();
}

/// State of the home page
class _HomePageState extends State<HomePage> {
  /// Subscription to the log stream
  StreamSubscription? _logSubscription;

  /// Subscription to the database change stream
  StreamSubscription? _databaseChangeSubscription;

  /// List of logs
  final List<HttpLog> _logs;
  final List<Map<String, dynamic>> _logsCapteurs;

  /// Default constructor
  _HomePageState() : _logs = [], _logsCapteurs = [];

  @override
  void initState() {
    super.initState();
    _logSubscription = GlobalManager.instance.httpLoggingManager.logStream.listen((log) {
      setState(() {
        _logs.add(log);
      });
    });
    _databaseChangeSubscription = GlobalManager.instance.databaseChangeStream.listen((_) async {
      await _refreshData();
    });
  }

  /// Function to generate data
  Future<void> _generateData() async {
    await GlobalManager.instance.storeAttribute('testKey', 'testValue', 'testType');
    setState(() {});
  }

  /// Function to refresh data from the database
  Future<void> _refreshData() async {
    final logs = await GlobalManager.instance.getAttributes();
    setState(() {
      _logsCapteurs.clear();
      _logsCapteurs.addAll(logs);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(backgroundColor: theme.colorScheme.inversePrimary, title: Text(widget.title)),
      body: ListView(
        children: [
          for (final log in _logs)Card(
            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: ListTile(
              //the title of the card is the timestamp of the log
              title: Text(log.timestamp.toString()),

              leading: const Icon(Icons.http, color: Colors.blue),
            ),
          ),
          for (final log in _logsCapteurs)Card(
            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: ListTile(
              title: Text(log['timestamp'].toString()),

              subtitle: Text('Component ID: ${log['key']}, Type: ${log['type']}'),
              leading: const Icon(Icons.sensors, color: Colors.green),
            ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            onPressed: _generateData,
            tooltip: 'Generate Data',
            child: const Icon(Icons.add),
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            onPressed: _refreshData,
            tooltip: 'Refresh Data',
            child: const Icon(Icons.refresh),
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            onPressed: () {
              setState(() {
                _logs.clear();
                _logsCapteurs.clear();
              });
            },
            tooltip: 'Clear',
            child: const Icon(Icons.clear),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    unawaited(_logSubscription?.cancel());
    unawaited(_databaseChangeSubscription?.cancel());
    super.dispose();
  }
}
