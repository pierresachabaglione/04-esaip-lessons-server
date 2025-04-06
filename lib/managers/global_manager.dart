// global_manager.dart
import 'dart:async';
import 'package:esaip_lessons_server/database/database_functions.dart';
import 'package:esaip_lessons_server/websocket/websocket_server.dart';

/// GlobalManager is a singleton that manages application-wide state,
/// including database initialization, server management, and change notifications.
class GlobalManager {
  static GlobalManager? _instance;

  /// The [DatabaseFunctions] instance for database interactions.
  final DatabaseFunctions databaseFunctions;

  final StreamController<void> _databaseChangeController =
  StreamController<void>.broadcast();

  /// A stream notifying listeners of database changes.
  Stream<void> get databaseChangeStream => _databaseChangeController.stream;

  /// Notifies listeners that the database has changed.
  void notifyDatabaseChange() {
    _databaseChangeController.add(null);
  }

  /// Returns the singleton instance of [GlobalManager].
  static GlobalManager get instance {
    _instance ??= GlobalManager();
    return _instance!;
  }

  /// Creates a [GlobalManager] instance and initializes [databaseFunctions].
  GlobalManager() : databaseFunctions = DatabaseFunctions();

  /// Initializes the manager by ensuring the database is ready.
  Future<void> initialize() async {
    await databaseFunctions.database;
  }

  /// Disposes of resources used by the global manager.
  Future<void> dispose() async =>
      Future.wait([_databaseChangeController.close()]);

  /// Retrieves stored data for a device identified by [uniqueId].
  Future<List<Map<String, dynamic>>> getStoredData(String uniqueId) async =>
      databaseFunctions.getStoredData(uniqueId);

  /// Stores data for a device and notifies listeners.
  Future<void> storeStoredData(String uniqueId, String key, String value) async {
    await databaseFunctions.insertStoredData(uniqueId, key, value);
    notifyDatabaseChange();
  }

  /// Resets the database by clearing stored data, devices, settings, and users.
  Future<void> resetDatabase() async {
    final db = await databaseFunctions.database;
    await db.delete('stored_data');
    await db.delete('devices');
    await db.delete('settings');
    await db.delete('users');
    notifyDatabaseChange();
  }

  // --- New code for WebSocketServer management ---
  WebSocketServer? _server;

  /// Starts the WebSocket server on the specified IP and port.
  Future<void> startServer({String ipAddress = '0.0.0.0', int port = 8888}) async {
    _server = WebSocketServer();
    await _server!.start(ipAddress: ipAddress, port: port);
  }

  /// Restarts the WebSocket server using the new [ipAddress] and [port].
  Future<void> restartServer({required String ipAddress, required int port}) async {
    if (_server != null) {
      await _server!.close();
    }
    _server = WebSocketServer();
    await _server!.start(ipAddress: ipAddress, port: port);
  }
}
