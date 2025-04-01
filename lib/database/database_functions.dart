/// Here are the functions needed that will facilitate the interraction between
/// the application / mangager and the sqlite database.

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseFunctions {
  /// A singleton instance in order to have only one instance running
  static final DatabaseFunctions _instance = DatabaseFunctions._internal();
  /// A factory constructor to return the instance and only the specific
  /// isntance in the whole application
  factory DatabaseFunctions() => _instance;
  /// we ensure that there is only one instance of the database
  static Database? _database;

  DatabaseFunctions._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'app_database.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE attributes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        key TEXT NOT NULL,
        value TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        type TEXT NOT NULL
      )
    ''');
  }

  Future<void> insertAttribute(String key, String value, String type) async {
    final db = await database;
    await db.insert(
      'attributes',
      {
        'key': key,
        'value': value,
        'timestamp': DateTime.now().toUtc().toIso8601String(),
        'type': type,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getAttributes() async {
    final db = await database;
    return await db.query('attributes');
  }

  Future<List<Map<String, dynamic>>> getAttributesByKey(String key) async {
    final db = await database;
    return await db.query('attributes', where: 'key = ?', whereArgs: [key]);
  }

  Future<List<Map<String, dynamic>>> getAttrubuteByTimestamp(String time) async {
    final db = await database;
    return await db.query('attributes', where: 'timestamp = ?', whereArgs: [time]);
  }


}