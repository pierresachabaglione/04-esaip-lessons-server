/// Here are the functions needed that will facilitate the interaction between
/// the application/manager and the sqlite database.
library;

import 'dart:convert';

import 'package:crypto/crypto.dart';
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

    //create the attributes table
    await db.execute('''
       CREATE TABLE settings (
         id INTEGER PRIMARY KEY AUTOINCREMENT,
         uniqueId TEXT NOT NULL,
         type TEXT NOT NULL,
         key TEXT NOT NULL,
         value TEXT NOT NULL,
         timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
         FOREIGN KEY(uniqueId) REFERENCES devices(uniqueId) ON DELETE CASCADE
       )
     ''');
    //we create the user / password table
    await db.execute('''
    CREATE TABLE users (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          username TEXT UNIQUE NOT NULL,
          passwordHash TEXT NOT NULL,
          uniqueId TEXT,
          timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
          FOREIGN KEY(uniqueId) REFERENCES devices(uniqueId) ON DELETE CASCADE
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
    final result = await db.query(
      'devices',
      where: 'uniqueId = ?',
      whereArgs: [uniqueId],
    );
    return result.isNotEmpty;
  }

  /// Retrieves a device from the devices table by uniqueId.
  Future<List<Map<String, dynamic>>> getDevice(String uniqueId) async {
    final db = await database;
    return db.query('devices', where: 'uniqueId = ?', whereArgs: [uniqueId]);
  }

  /// Inserts telemetry data into the stored_data table.
  Future<void> insertStoredData(
    String uniqueId,
    String key,
    String value,
  ) async {
    final db = await database;
    try {
      await db.insert('stored_data', {
        'uniqueId': uniqueId,
        'key': key,
        'value': value,
      });
    } catch (e) {
      print('Error inserting stored data: $e');
    }
  }

  /// Retrieves all stored data associated with a device.
  Future<List<Map<String, dynamic>>> getStoredData(String uniqueId) async {
    final db = await database;
    return db.query(
      'stored_data',
      where: 'uniqueId = ?',
      whereArgs: [uniqueId],
    );
  }

  /// Retrieves all devices stored in the database.
  Future<List<Map<String, dynamic>>> getDevices() async {
    final db = await database;
    return db.query('devices');
  }

  /// Creates or updates an attribute (setting) for a device.
  /// [attributeType] should be "server" or "client".
  Future<void> setAttribute(
      String uniqueId, String attributeType, String key, String value) async {
    final db = await database;
    await db.insert('settings', {
      'uniqueId': uniqueId,
      'type': attributeType,
      'key': key,
      'value': value,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Deletes an attribute (setting) for a device.
  Future<void> deleteAttribute(
      String uniqueId, String attributeType, String key) async {
    final db = await database;
    await db.delete('settings',
        where: 'uniqueId = ? AND type = ? AND key = ?',
        whereArgs: [uniqueId, attributeType, key]);
  }

  /// Retrieves attributes for a device.
  /// If [attributeType] is provided, it filters by that type
  /// client attributes are for the things
  /// server attributes are for the connected apps
  Future<List<Map<String, dynamic>>> getAttributes(String uniqueId,
      {String? attributeType}) async {
    final db = await database;
    if (attributeType != null) {
      return db.query('settings',
          where: 'uniqueId = ? AND type = ?', whereArgs: [uniqueId, attributeType]);
    } else {
      return db.query('settings', where: 'uniqueId = ?', whereArgs: [uniqueId]);
    }
  }
  /// Retrieves all attributes for a device.
  Future<int> registerUser(String username, String password, {String? uniqueId}) async{
    final db = await database;
    //we hash the password using sha512
    final passwordHash = sha512.convert(utf8.encode(password)).toString();
    return db.insert('users', {
      'username': username,
      'passwordHash': passwordHash,
      'uniqueId': uniqueId, // optionally associate with a device
      'timestamp': DateTime.now().toUtc().toIso8601String(),
    });
  }

  /// Authenticates a user by checking the provided username and password.
  Future<Map<String, dynamic>?> authenticateUser(String username, String password) async {
    final db = await database;
    final results = await db.query(
      'users',
      where: 'username = ?',
      whereArgs: [username],
    );

    if (results.isEmpty) {
      return null;
    }

    final user = results.first;
    final storedHash = user['passwordHash']! as String;
    //We check if the password hash is the same as the one in the database
    final providedHash = sha512.convert(utf8.encode(password)).toString();
    if (providedHash == storedHash) {
      return user;
    }
    return null;
  }

  ///function to check if the user already exists
  Future<bool> userExists(String username) async{
    final db = await database;
    final results = await db.query(
      'users',
      where: 'username = ?',
      whereArgs: [username],
    );
    return results.isNotEmpty;
  }



}
