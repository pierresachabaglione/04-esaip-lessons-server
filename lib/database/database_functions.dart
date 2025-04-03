/// Here are the functions needed that will facilitate the interractionbetween
/// the application / mangager and the sqlite database.
library;

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// The main handler function to interact with the database
class DatabaseFunctions {
  /// A singleton instance in order to have only one instance running
  static final DatabaseFunctions _instance = DatabaseFunctions._internal();

  /// A factory constructor to return the instance and only the specific
  /// isntance in the whole application
  factory DatabaseFunctions() => _instance;

  /// we ensure that there is only one instance of the database
  static Database? _database;

  DatabaseFunctions._internal();

  /// This function will return the database instance after initializing it
  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }
    _database = await _initDatabase();
    return _database!;
  }

  /// This function will initialize the database and create the table
  Future<Database> _initDatabase() async {
    final path = join(await getDatabasesPath(), 'app_database.db');
    // Delete the database if it already exists
     await deleteDatabase(path);
    return openDatabase(path, version: 1, onCreate: _onCreate);
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE attributes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        key TEXT NOT NULL,
        value TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        type TEXT NOT NULL
      );
    ''');
    await db.execute('''
      CREATE TABLE devices (
        uniqueId TEXT PRIMARY KEY,
        type TEXT NOT NULL,
        timestamp TEXT NOT NULL
      );
    ''');

    await db.execute('''
       CREATE TABLE sensor_data (
         id INTEGER PRIMARY KEY AUTOINCREMENT,
         uniqueId TEXT,
         key TEXT,
         value TEXT,
         timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
         FOREIGN KEY (uniqueId) REFERENCES devices(uniqueId) ON DELETE CASCADE
       )
     ''');
  }

  /// This function will register a device using their uniqueId and type
  Future<void> registerDevice(String uniqueId, String type) async {
    final db = await database;
    await db.insert('devices', {
      'uniqueId': uniqueId,
      'type': type,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

/// function to delete a device from the database ny removing all its logs and
  /// data
  Future<void> unregisterDevice(String uniqueId) async {
    final db = await database;
    await db.delete('devices', where: 'uniqueId = ?', whereArgs: [uniqueId]);
  }

  /// Checks if the decice is already registered in the database
  /// Usage in the main manager to allow any communication with all the services
  Future<bool> isDeviceRegistered(String uniqueId) async {
    final db = await database;
    final result = await db.query(
      'devices',
      where: 'uniqueId = ?',
      whereArgs: [uniqueId],
    );
    return result.isNotEmpty;
  }


  /// Retrieves a device from the `devices` table by uniqueId
  Future<List<Map<String, dynamic>>> getDevice(String uniqueId) async {
    final db = await database;
    return await db.query('devices', where: 'uniqueId = ?', whereArgs: [uniqueId]);
  }

  /// Inserts sensor data into the `sensor_data` table
  Future<void> insertSensorData(String uniqueId, String key, String value) async {
    final db = await database;

    try {
      await db.insert(
        'sensor_data',
        {'uniqueId': uniqueId, 'key': key, 'value': value},
      );
    } catch (e) {
      print('Error inserting sensor data: $e');
    }
  }

  /// Retrieves all sensor data associated with a device
  Future<List<Map<String, dynamic>>> getSensorData(String uniqueId) async {
    final db = await database;
    return await db.query('sensor_data', where: 'uniqueId = ?', whereArgs: [uniqueId]);
  }

  /// This function will insert an attribute into the database using a key
  /// corresponding to the serial number of the device, a value corresponding
  /// to the value that the decive is sending and its associated 'type'
  Future<void> insertAttribute(String key, String value, String type) async {
    final db = await database;
    await db.insert('attributes', {
      'key': key,
      'value': value,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'type': type,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// This function will return all attributes stored the database
  Future<List<Map<String, dynamic>>> getAttributes() async {
    final db = await database;
    return db.query('attributes');
  }

  /// This function will return all the devices stored the database
  Future<List<Map<String, dynamic>>> getDevices() async {
    final db = await database;
    return db.query('devices');
  }

  /// This function will return all the entries stored the database corre
  /// sponding to a specific key
  Future<List<Map<String, dynamic>>> getAttributesByKey(String key) async {
    final db = await database;
    return db.query('attributes', where: 'key = ?', whereArgs: [key]);
  }

  /// This function will return all the entries stored the database corre
  /// sponding to a specific timestamp
  Future<List<Map<String, dynamic>>> getAttrubuteByTimestamp(
    String time,
  ) async {
    final db = await database;
    return db.query('attributes', where: 'timestamp = ?', whereArgs: [time]);
  }
}
