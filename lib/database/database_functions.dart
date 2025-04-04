/// Here are the functions needed that will facilitate the interaction between
/// the application/manager and the sqlite database.
library;

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

/// The main handler function to interact with the database.
class DatabaseFunctions {
  /// A singleton instance.
  static final DatabaseFunctions _instance = DatabaseFunctions._internal();

  /// Factory constructor.
  factory DatabaseFunctions() => _instance;

  /// Ensure that there is only one instance of the database.
  static Database? _database;

  DatabaseFunctions._internal();

  /// Returns the database instance after initializing it.
  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }
    _database = await _initDatabase();
    return _database!;
  }

  /// Initializes the database and creates the necessary tables.
  Future<Database> _initDatabase() async {
    final path = join(await getDatabasesPath(), 'app_database.db');
    // Delete the database if it already exists.
    await deleteDatabase(path);
    return openDatabase(path, version: 1, onCreate: _onCreate);
  }
  /// Deletes the database and resets the instance.
  static void resetInstance() {
    _database = null;
  }
  Future<void> _onCreate(Database db, int version) async {
    // Create devices table.
    await db.execute('''
      CREATE TABLE devices (
        uniqueId TEXT PRIMARY KEY,
        type TEXT NOT NULL,
        apiKey TEXT NOT NULL,
        timestamp TEXT NOT NULL
      );
    ''');

    // Create stored_data table for telemetry history.
    await db.execute('''
       CREATE TABLE stored_data (
         id INTEGER PRIMARY KEY AUTOINCREMENT,
         uniqueId TEXT,
         key TEXT,
         value TEXT,
         timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
         FOREIGN KEY (uniqueId) REFERENCES devices(uniqueId) ON DELETE CASCADE
       )
     ''');
  }

  /// Registers a device using its uniqueId and type, then returns a unique API key.
  Future<String> registerDevice(String uniqueId, String type) async {
    final db = await database;
    final apiKey = const Uuid().v4();
    await db.insert('devices', {
      'uniqueId': uniqueId,
      'type': type,
      'apiKey': apiKey,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    return apiKey;
  }

  /// Deletes a device from the database.
  Future<void> unregisterDevice(String uniqueId) async {
    final db = await database;
    await db.delete('devices', where: 'uniqueId = ?', whereArgs: [uniqueId]);
  }

  /// Checks if a device is registered.
  Future<bool> isDeviceRegistered(String uniqueId) async {
    final db = await database;
    final result = await db.query('devices', where: 'uniqueId = ?', whereArgs: [uniqueId]);
    return result.isNotEmpty;
  }

  /// Retrieves a device from the devices table by uniqueId.
  Future<List<Map<String, dynamic>>> getDevice(String uniqueId) async {
    final db = await database;
    return db.query('devices', where: 'uniqueId = ?', whereArgs: [uniqueId]);
  }

  /// Inserts telemetry data into the stored_data table.
  Future<void> insertStoredData(String uniqueId, String key, String value) async {
    final db = await database;
    try {
      await db.insert(
        'stored_data',
        {'uniqueId': uniqueId, 'key': key, 'value': value},
      );
    } catch (e) {
      print('Error inserting stored data: $e');
    }
  }

  /// Retrieves all stored data associated with a device.
  Future<List<Map<String, dynamic>>> getStoredData(String uniqueId) async {
    final db = await database;
    return db.query('stored_data', where: 'uniqueId = ?', whereArgs: [uniqueId]);
  }

  /// Retrieves all devices stored in the database.
  Future<List<Map<String, dynamic>>> getDevices() async {
    final db = await database;
    return db.query('devices');
  }
}
