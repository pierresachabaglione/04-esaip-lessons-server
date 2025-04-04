// File: server_dashboard_page.dart

import 'dart:async';
import 'package:flutter/material.dart';

/// Models for dashboard data.
class RequestLog {
  final DateTime timestamp;
  final String source;
  final String logLevel;
  final String message;

  RequestLog({
    required this.timestamp,
    required this.source,
    required this.logLevel,
    required this.message,
  });
}

class TelemetryData {
  final DateTime timestamp;
  final String source;
  final String key;
  final String value;

  TelemetryData({
    required this.timestamp,
    required this.source,
    required this.key,
    required this.value,
  });
}

class AttributeData {
  final DateTime timestamp;
  final String source;
  final String key;
  final String value;

  AttributeData({
    required this.timestamp,
    required this.source,
    required this.key,
    required this.value,
  });
}

class RegisteredThing {
  final String uniqueId;
  final String type;
  final String apiKey;

  RegisteredThing({
    required this.uniqueId,
    required this.type,
    required this.apiKey,
  });
}

/// The ServerDashboardPage widget implements the dashboard.
class ServerDashboardPage extends StatefulWidget {
  const ServerDashboardPage({super.key});

  @override
  _ServerDashboardPageState createState() => _ServerDashboardPageState();
}

class _ServerDashboardPageState extends State<ServerDashboardPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Lists to hold our simulated data.
  List<RequestLog> requestLogs = [];
  List<TelemetryData> telemetryDataList = [];
  List<AttributeData> thingAttributes = [];
  List<AttributeData> mobileAttributes = [];
  List<RegisteredThing> registeredThings = [];

  // For filtering requests by log level.
  String? selectedLogLevel;

  Timer? _dataSimulator;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);

    // Simulate some initial data.
    _initializeDummyData();

    // Simulate real-time updates by periodically adding dummy data.
    _dataSimulator = Timer.periodic(const Duration(seconds: 5), (_) {
      _simulateIncomingData();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _dataSimulator?.cancel();
    super.dispose();
  }

  /// Simulated initial data.
  void _initializeDummyData() {
    requestLogs = [
      RequestLog(
          timestamp: DateTime.now(),
          source: 'CC-TS-00001',
          logLevel: 'INFO',
          message: 'Device registered'),
      RequestLog(
          timestamp: DateTime.now(),
          source: 'CC-MP-12345',
          logLevel: 'ERROR',
          message: 'Login failed'),
    ];

    telemetryDataList = [
      TelemetryData(
          timestamp: DateTime.now(),
          source: 'CC-TS-00002',
          key: 'temperature',
          value: '25.5°C'),
    ];

    thingAttributes = [
      AttributeData(
          timestamp: DateTime.now(),
          source: 'CC-TS-00003',
          key: 'brightness',
          value: '70'),
    ];

    mobileAttributes = [
      AttributeData(
          timestamp: DateTime.now(),
          source: 'CC-MP-12346',
          key: 'volume',
          value: '80'),
    ];

    registeredThings = [
      RegisteredThing(
          uniqueId: 'CC-TS-00001', type: 'sensor', apiKey: 'abc123'),
      RegisteredThing(
          uniqueId: 'CC-MP-12345', type: 'mobile', apiKey: 'def456'),
    ];
  }

  /// Simulate incoming data.
  void _simulateIncomingData() {
    setState(() {
      // Add a new request log.
      requestLogs.add(RequestLog(
          timestamp: DateTime.now(),
          source: 'CC-TS-0000${requestLogs.length + 1}',
          logLevel: (requestLogs.length % 3 == 0) ? 'WARN' : 'INFO',
          message: 'Simulated request message'));

      // Add new telemetry data.
      telemetryDataList.add(TelemetryData(
          timestamp: DateTime.now(),
          source: 'CC-TS-0000${telemetryDataList.length + 2}',
          key: 'humidity',
          value: '${50 + telemetryDataList.length}%'));

      // Add new attributes.
      thingAttributes.add(AttributeData(
          timestamp: DateTime.now(),
          source: 'CC-TS-0000${thingAttributes.length + 3}',
          key: 'contrast',
          value: '${30 + thingAttributes.length}'));
      mobileAttributes.add(AttributeData(
          timestamp: DateTime.now(),
          source: 'CC-MP-0000${mobileAttributes.length + 4}',
          key: 'brightness',
          value: '${60 + mobileAttributes.length}'));

      // Add a new registered thing.
      registeredThings.add(RegisteredThing(
          uniqueId: 'CC-TS-0000${registeredThings.length + 1}',
          type: 'sensor',
          apiKey: 'key${registeredThings.length + 1}'));
    });
  }

  IconData _getIconForLogLevel(String logLevel) {
    switch (logLevel) {
      case 'ERROR':
        return Icons.error;
      case 'WARN':
        return Icons.warning;
      case 'DEBUG':
        return Icons.bug_report;
      default:
        return Icons.info;
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(
        title: const Text('Server Dashboard'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.request_page), text: 'Requests'),
            Tab(icon: Icon(Icons.sensors), text: 'Telemetry'),
            Tab(icon: Icon(Icons.list_alt), text: 'Thing Attributes'),
            Tab(icon: Icon(Icons.mobile_friendly), text: 'Mobile Attributes'),
            Tab(icon: Icon(Icons.devices), text: 'Registered Things'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // NWS19: Requests View
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8),
                child: DropdownButton<String>(
                  hint: const Text('Filter by log level'),
                  value: selectedLogLevel,
                  items: ['INFO', 'DEBUG', 'WARN', 'ERROR']
                      .map((level) => DropdownMenuItem<String>(
                    value: level,
                    child: Text(level),
                  ))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedLogLevel = value;
                    });
                  },
                ),
              ),
              Expanded(
                child: ListView(
                  children: requestLogs
                      .where((log) =>
                  selectedLogLevel == null ||
                      log.logLevel == selectedLogLevel)
                      .map((log) => Card(
                    child: ListTile(
                      leading: Icon(_getIconForLogLevel(log.logLevel)),
                      title: Text('${log.source} - ${log.logLevel}'),
                      subtitle: Text(
                          '${log.message}\n${log.timestamp.toIso8601String()}'),
                    ),
                  ))
                      .toList(),
                ),
              ),
            ],
          ),

          // NWS20: Telemetry Data View
          ListView(
            children: telemetryDataList
                .map((data) => Card(
              child: ListTile(
                leading: const Icon(Icons.thermostat),
                title:
                Text('${data.source} - ${data.key}: ${data.value}'),
                subtitle: Text(data.timestamp.toIso8601String()),
              ),
            ))
                .toList(),
          ),

          // NWS21: Attributes from Things View
          ListView(
            children: thingAttributes
                .map((attr) => Card(
              child: ListTile(
                leading: const Icon(Icons.settings),
                title:
                Text('${attr.source} - ${attr.key}: ${attr.value}'),
                subtitle: Text(attr.timestamp.toIso8601String()),
              ),
            ))
                .toList(),
          ),

          // NWS22: Attributes from Mobile App View
          ListView(
            children: mobileAttributes
                .map((attr) => Card(
              child: ListTile(
                leading: const Icon(Icons.phone_android),
                title:
                Text('${attr.source} - ${attr.key}: ${attr.value}'),
                subtitle: Text(attr.timestamp.toIso8601String()),
              ),
            ))
                .toList(),
          ),

          // NWS23: Registered Things View
          ListView(
            children: registeredThings
                .map((thing) => Card(
              child: ListTile(
                leading: const Icon(Icons.device_hub),
                title: Text('${thing.uniqueId} (${thing.type})'),
                subtitle: Text('API Key: ${thing.apiKey}'),
              ),
            ))
                .toList(),
          ),
        ],
      ),
    );
}
