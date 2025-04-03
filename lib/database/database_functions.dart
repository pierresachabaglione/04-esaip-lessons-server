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
