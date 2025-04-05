import 'dart:io';
import 'dart:async';
import 'package:esaip_lessons_server/database/database_functions.dart';
import 'package:esaip_lessons_server/managers/global_manager.dart';
import 'package:flutter/material.dart';

/// Model representing a request log entry.
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

/// Model representing a telemetry data entry.
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

/// Model representing an attribute entry.
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

/// Model representing a registered device.
class RegisteredThing {
  final String uniqueId;
  final String type;
  final String apiKey;
  bool isBanned;

  RegisteredThing({
    required this.uniqueId,
    required this.type,
    required this.apiKey,
    this.isBanned = false,
  });
}

/// Model representing a user.
class UserData {
  String username;
  String userId;
  String password;
  bool isBanned;

  UserData({
    required this.username,
    required this.userId,
    required this.password,
    this.isBanned = false,
  });
}

/// The [ServerDashboardPage] widget displays production data fetched from the database.
class ServerDashboardPage extends StatefulWidget {
  const ServerDashboardPage({super.key});

  @override
  ServerDashboardPageState createState() => ServerDashboardPageState();
}

/// The state for [ServerDashboardPage].
class ServerDashboardPageState extends State<ServerDashboardPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Data lists populated from the real database.
  List<RequestLog> requestLogs = [];
  List<TelemetryData> telemetryDataList = [];
  List<AttributeData> thingAttributes = [];
  List<AttributeData> mobileAttributes = [];
  List<RegisteredThing> registeredThings = [];
  List<UserData> users = [];

  // Server settings.
  String ipAddress = "127.0.0.1";
  final TextEditingController _ipController = TextEditingController();
  final TextEditingController _portController = TextEditingController();

  // Controllers for the user form.
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _userIdController = TextEditingController();

  bool isModifyMode = false;
  String? selectedLogLevel;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 8, vsync: this);
    _ipController.text = ipAddress;
    _portController.text = '8888';
    _loadLocalIpAddress();
    _fetchData();
    GlobalManager.instance.databaseChangeStream.listen((_) {
      _fetchData();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _ipController.dispose();
    _portController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _userIdController.dispose();
    super.dispose();
  }
  ///Mehod to load the local IP address.
  Future<void> _loadLocalIpAddress() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );
      if (interfaces.isNotEmpty && interfaces.first.addresses.isNotEmpty) {
        setState(() {
          ipAddress = interfaces.first.addresses.first.address;
          _ipController.text = ipAddress;
        });
      }
    } catch (e) {
      print("local ip fetch error $e");
    }
  }

  /// Fetches all production data from the database.
  Future<void> _fetchData() async {
    await _fetchRegisteredThings();
    await _fetchTelemetryData();
    await _fetchAttributes();
    await _fetchUsers();
    await _fetchLogs();
  }

  Future<void> _fetchRegisteredThings() async {
    final devices = await DatabaseFunctions().getDevices();
    setState(() {
      registeredThings = devices.map((device) => RegisteredThing(
        uniqueId: device['uniqueId'] as String,
        type: device['type'] as String,
        apiKey: device['apiKey'] as String,
        isBanned: (device['isBanned'] as int) == 1,
      )).toList();
    });
  }

  Future<void> _fetchTelemetryData() async {
    final data = await DatabaseFunctions().getAllStoredData();
    setState(() {
      telemetryDataList = data
          .map((row) => TelemetryData(
        timestamp: DateTime.parse(row['timestamp'] as String),
        source: row['uniqueId'] as String,
        key: row['key'] as String,
        value: row['value'] as String,
      ))
          .toList();
    });
  }

  Future<void> _fetchAttributes() async {
    final attrs = await DatabaseFunctions().getAllAttributes();
    setState(() {
      thingAttributes = attrs
          .where((a) => a['type'] == 'client')
          .map((a) => AttributeData(
        timestamp: DateTime.parse(a['timestamp'] as String),
        source: a['uniqueId'] as String,
        key: a['key'] as String,
        value: a['value'] as String,
      ))
          .toList();
      mobileAttributes = attrs
          .where((a) => a['type'] == 'server')
          .map((a) => AttributeData(
        timestamp: DateTime.parse(a['timestamp'] as String),
        source: a['uniqueId'] as String,
        key: a['key'] as String,
        value: a['value'] as String,
      ))
          .toList();
    });
  }

  Future<void> _fetchUsers() async {
    final usersData = await DatabaseFunctions().getAllUsers();
    setState(() {
      users = usersData.map((u) => UserData(
        username: u['username'] as String,
        userId: u['id'].toString(),
        password: u['passwordHash'] as String,
        isBanned: (u['isBanned'] as int) == 1,
      )).toList();
    });
  }

  Future<void> _fetchLogs() async {
    final logsData = await DatabaseFunctions().getLogs();
    setState(() {
      requestLogs = logsData
          .map((log) => RequestLog(
        timestamp: DateTime.parse(log['timestamp'] as String),
        source: log['source'] as String,
        logLevel: log['logLevel'] as String,
        message: '[${log['category']}] ${log['message']}',
      ))
          .toList();
    });
  }

  void _kickDevice(RegisteredThing thing) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Kicked device ${thing.uniqueId}')),
    );
  }

  void _banDevice(RegisteredThing thing) async {
    setState(() {
      thing.isBanned = !thing.isBanned;
    });
    await DatabaseFunctions()
        .updateDeviceBanStatus(thing.uniqueId, thing.isBanned);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(thing.isBanned
              ? 'Banned device ${thing.uniqueId}'
              : 'Unbanned device ${thing.uniqueId}')),
    );
  }

  void _kickUser(UserData user) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Kicked user ${user.username}')),
    );
  }

  void _banUser(UserData user) async {
    setState(() {
      user.isBanned = !user.isBanned;
    });
    await DatabaseFunctions().updateUserBanStatus(user.username, user.isBanned);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(user.isBanned
              ? 'Banned user ${user.username}'
              : 'Unbanned user ${user.username}')),
    );
  }

  void _createUser(String username, String password) {
    final newUser = UserData(
      username: username,
      userId: 'u${users.length + 1}',
      password: password,
    );
    setState(() {
      users.add(newUser);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Created user $username')),
    );
  }

  void _modifyUser(String userId, String newUsername, String newPassword) {
    final index = users.indexWhere((user) => user.userId == userId);
    if (index != -1) {
      setState(() {
        users[index].username = newUsername;
        users[index].password = newPassword;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Modified user $userId')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not found')),
      );
    }
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

  /// Updates the server settings (IP and port).
  void _updateServerSettings() {
    setState(() {
      ipAddress = _ipController.text;
    });
    int port = int.tryParse(_portController.text) ?? 8888;
    GlobalManager.instance.restartServer(ipAddress: ipAddress, port: port);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Server settings updated to $ipAddress:$port')),
    );
  }

  Widget _buildUserForm() => Card(
    elevation: 4,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text(
            isModifyMode ? 'Modify User' : 'Create User',
            style:
            const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _userIdController,
            decoration: const InputDecoration(
              labelText: 'User ID (for modification only)',
              prefixIcon: Icon(Icons.confirmation_number),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _usernameController,
            decoration: const InputDecoration(
              labelText: 'Username',
              prefixIcon: Icon(Icons.person),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _passwordController,
            decoration: const InputDecoration(
              labelText: 'Password',
              prefixIcon: Icon(Icons.lock),
            ),
            obscureText: true,
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(
                onPressed: () {
                  if (isModifyMode) {
                    _modifyUser(
                      _userIdController.text,
                      _usernameController.text,
                      _passwordController.text,
                    );
                  } else {
                    _createUser(
                      _usernameController.text,
                      _passwordController.text,
                    );
                  }
                  _userIdController.clear();
                  _usernameController.clear();
                  _passwordController.clear();
                },
                child: Text(isModifyMode ? 'Modify User' : 'Create User'),
              ),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    isModifyMode = !isModifyMode;
                  });
                },
                child: Text(isModifyMode ? 'Switch to Create' : 'Switch to Modify'),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Server Dashboard'),
      bottom: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabs: const [
          Tab(icon: Icon(Icons.request_page), text: 'Requests'),
          Tab(icon: Icon(Icons.sensors), text: 'Telemetry'),
          Tab(icon: Icon(Icons.list_alt), text: 'Thing Attributes'),
          Tab(icon: Icon(Icons.phone_android), text: 'Mobile Attributes'),
          Tab(icon: Icon(Icons.devices), text: 'Registered Things'),
          Tab(icon: Icon(Icons.supervisor_account), text: 'Users'),
          Tab(icon: Icon(Icons.settings), text: 'Settings'),
          Tab(icon: Icon(Icons.person), text: 'User Form'),
        ],
      ),
    ),
    body: TabBarView(
      controller: _tabController,
      children: [
        // Requests View
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
        // Telemetry Data View
        ListView(
          children: telemetryDataList
              .map((data) => Card(
            child: ListTile(
              leading: const Icon(Icons.thermostat),
              title: Text(
                  '${data.source} - ${data.key}: ${data.value}'),
              subtitle: Text(data.timestamp.toIso8601String()),
            ),
          ))
              .toList(),
        ),
        // Thing Attributes View
        ListView(
          children: thingAttributes
              .map((attr) => Card(
            child: ListTile(
              leading: const Icon(Icons.settings),
              title: Text(
                  '${attr.source} - ${attr.key}: ${attr.value}'),
              subtitle: Text(attr.timestamp.toIso8601String()),
            ),
          ))
              .toList(),
        ),
        // Mobile Attributes View
        ListView(
          children: mobileAttributes
              .map((attr) => Card(
            child: ListTile(
              leading: const Icon(Icons.phone_android),
              title: Text(
                  '${attr.source} - ${attr.key}: ${attr.value}'),
              subtitle: Text(attr.timestamp.toIso8601String()),
            ),
          ))
              .toList(),
        ),
        // Registered Things View
        ListView(
          children: registeredThings
              .map((thing) => Card(
            child: ListTile(
              leading: Icon(
                  thing.isBanned ? Icons.block : Icons.device_hub),
              title: Text('${thing.uniqueId} (${thing.type})'),
              subtitle: Text('API Key: ${thing.apiKey}'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.logout),
                    tooltip: 'Kick Device',
                    onPressed: () => _kickDevice(thing),
                  ),
                  IconButton(
                    icon: Icon(thing.isBanned
                        ? Icons.lock_open
                        : Icons.lock),
                    tooltip: thing.isBanned
                        ? 'Unban Device'
                        : 'Ban Device',
                    onPressed: () => _banDevice(thing),
                  ),
                ],
              ),
            ),
          ))
              .toList(),
        ),
        // Users Management Tab
        ListView(
          children: users
              .map((user) => Card(
            child: ListTile(
              leading: Icon(user.isBanned
                  ? Icons.person_off
                  : Icons.person),
              title: Text(user.username),
              subtitle: Text(
                  'User ID: ${user.userId} - Password: ${user.password}'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.logout),
                    tooltip: 'Kick User',
                    onPressed: () => _kickUser(user),
                  ),
                  IconButton(
                    icon: Icon(user.isBanned
                        ? Icons.lock_open
                        : Icons.lock),
                    tooltip: user.isBanned
                        ? 'Unban User'
                        : 'Ban User',
                    onPressed: () => _banUser(user),
                  ),
                ],
              ),
            ),
          ))
              .toList(),
        ),
        // Settings Tab (Updated with IP and Port)
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Server Settings:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _ipController,
                decoration: const InputDecoration(
                  labelText: 'IP Address',
                  hintText: 'Enter IP address',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _portController,
                decoration: const InputDecoration(
                  labelText: 'Port',
                  hintText: 'Enter Port',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: _updateServerSettings,
                child: const Text('Update Server Settings'),
              ),
            ],
          ),
        ),
        // User Form Tab
        SingleChildScrollView(
          child: _buildUserForm(),
        ),
      ],
    ),
  );
}
