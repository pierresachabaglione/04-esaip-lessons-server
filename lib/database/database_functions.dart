/// Here are the functions needed that will facilitate the interaction between
/// the application/manager and the sqlite database.
library;

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:logger/logger.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

/// The main handler function to interact with the database.
class DatabaseFunctions {
  /// A singleton instance.
  static final DatabaseFunctions _instance = DatabaseFunctions._internal();

  /// Factory constructor.
  factory DatabaseFunctions() => _instance;

  /// The SQLite [Database] instance.
  static Database? _database;

  /// Logger instance for production logging.
  final Logger _logger = Logger();

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
    //await deleteDatabase(path);
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
      timestamp TEXT NOT NULL,
      isBanned INTEGER NOT NULL DEFAULT 0
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

    // Create the attributes table.
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

    // Create the user/password table.
    await db.execute('''
    CREATE TABLE users (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      username TEXT UNIQUE NOT NULL,
      passwordHash TEXT NOT NULL,
      uniqueId TEXT,
      timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
      isBanned INTEGER NOT NULL DEFAULT 0,
      FOREIGN KEY(uniqueId) REFERENCES devices(uniqueId) ON DELETE CASCADE
    )
  ''');

   //Create logs table for request logging.
    await db.execute('''
    CREATE TABLE logs (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      timestamp TEXT NOT NULL,
      source TEXT NOT NULL,
      logLevel TEXT NOT NULL,
      category TEXT NOT NULL,
      message TEXT NOT NULL
    )
  ''');
  }

  /// Registers a device using its [uniqueId] and [type], then returns a unique API key.
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

  /// Deletes a device from the database by its [uniqueId].
  Future<void> unregisterDevice(String uniqueId) async {
    final db = await database;
    await db.delete('devices', where: 'uniqueId = ?', whereArgs: [uniqueId]);
  }

  /// Checks if a device is registered by its [uniqueId].
  Future<bool> isDeviceRegistered(String uniqueId) async {
    final db = await database;
    final result = await db.query(
      'devices',
      where: 'uniqueId = ?',
      whereArgs: [uniqueId],
    );
    return result.isNotEmpty;
  }

  /// Retrieves a device from the devices table by [uniqueId].
  Future<List<Map<String, dynamic>>> getDevice(String uniqueId) async {
    final db = await database;
    return db.query('devices', where: 'uniqueId = ?', whereArgs: [uniqueId]);
  }

  /// Retrieves all devices stored in the database.
  Future<List<Map<String, dynamic>>> getDevices() async {
    final db = await database;
    return db.query('devices');
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
      _logger.e('Error inserting stored data: $e');
    }
  }

  /// Retrieves all telemetry data associated with a device identified by [uniqueId].
  Future<List<Map<String, dynamic>>> getStoredData(String uniqueId) async {
    final db = await database;
    return db.query(
      'stored_data',
      where: 'uniqueId = ?',
      whereArgs: [uniqueId],
    );
  }

  /// Retrieves all telemetry data from the stored_data table.
  Future<List<Map<String, dynamic>>> getAllStoredData() async {
    final db = await database;
    return db.query('stored_data');
  }

  /// Retrieves all attributes from the settings table.
  Future<List<Map<String, dynamic>>> getAllAttributes() async {
    final db = await database;
    return db.query('settings');
  }

  /// Retrieves all users from the users table.
  Future<List<Map<String, dynamic>>> getAllUsers() async {
    final db = await database;
    return db.query('users');
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

  /// Retrieves attributes for a device identified by [uniqueId].
  /// If [attributeType] is provided, it filters by that type.
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

  /// Registers a user by inserting into the users table.
  Future<int> registerUser(String username, String password, {String? uniqueId}) async {
    final db = await database;
    final passwordHash = sha512.convert(utf8.encode(password)).toString();
    return db.insert('users', {
      'username': username,
      'passwordHash': passwordHash,
      'uniqueId': uniqueId,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
    });
  }

  /// Authenticates a user by checking the provided [username] and [password].
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
    final providedHash = sha512.convert(utf8.encode(password)).toString();
    if (providedHash == storedHash) {
      return user;
    }
    return null;
  }

  /// Checks if a user already exists by [username].
  Future<bool> userExists(String username) async {
    final db = await database;
    final results = await db.query(
      'users',
      where: 'username = ?',
      whereArgs: [username],
    );
    return results.isNotEmpty;
  }
  ///Checks if a device is banned thanks to its serial number.
  Future<void> updateDeviceBanStatus(String uniqueId, bool isBanned) async {
    final db = await database;
    await db.update('devices', {'isBanned': isBanned ? 1 : 0},
        where: 'uniqueId = ?', whereArgs: [uniqueId]);
  }

  /// Updates the ban status of a user thanks to its username.
  Future<void> updateUserBanStatus(String username, bool isBanned) async {
    final db = await database;
    await db.update('users', {'isBanned': isBanned ? 1 : 0},
        where: 'username = ?', whereArgs: [username]);
  }

  ///Fetch logs by category
  Future<void> logRequest(
      String source,
      String logLevel,
      String category,
      String message,
      ) async {
    final db = await database;
    await db.insert('logs', {
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'source': source,
      'logLevel': logLevel,
      'category': category,
      'message': message,
    });
  }

  /// Nfzetch all logs.
  Future<List<Map<String, dynamic>>> getLogs() async {
    final db = await database;
    return db.query('logs', orderBy: 'timestamp DESC');
  }
}
