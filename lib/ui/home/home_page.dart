import 'dart:async';
import 'package:esaip_lessons_server/managers/global_manager.dart';
import 'package:flutter/material.dart';

/// Home page of the app.
class HomePage extends StatefulWidget {
  /// Constructor for the home page.
  const HomePage({super.key, required this.title});

  /// Title of the home page.
  final String title;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // Subscription for database changes.
  StreamSubscription? _databaseChangeSubscription;

  // List to store telemetry data retrieved from the database.
  final List<Map<String, dynamic>> _telemetryData = [];

  @override
  void initState() {
    super.initState();
    // Listen to any changes in the database and refresh the data.
    _databaseChangeSubscription = GlobalManager.instance.databaseChangeStream
        .listen((_) async {
          await _refreshData();
        });
  }

  /// Generates test telemetry data using a fixed uniqueId.
  Future<void> _generateData() async {
    // In a real scenario, replace the test uniqueId with the actual device identifier.
    await GlobalManager.instance.storeStoredData(
      'CC-TS-00000',
      'testKey',
      'testValue',
    );
    setState(() {});
  }

  /// Refreshes telemetry data from the database.
  Future<void> _refreshData() async {
    final data = await GlobalManager.instance.getStoredData('CC-TS-00000');
    setState(() {
      _telemetryData
        ..clear()
        ..addAll(data);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: ListView(
        children: [
          for (final entry in _telemetryData)
            Card(
              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: ListTile(
                title: Text('Timestamp: ${entry['timestamp']}'),
                subtitle: Text(
                  'Key: ${entry['key']} - Value: ${entry['value']}',
                ),
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
              setState(_telemetryData.clear);
            },
            tooltip: 'Clear',
            child: const Icon(Icons.clear),
          ),
        ],
      ),
    );
  }

  @override
  Future<void> dispose() async {
    await _databaseChangeSubscription?.cancel();
    super.dispose();
  }
}
