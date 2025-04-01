import 'package:esaip_lessons_server/database/database_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  // Initialize sqflite for ffi
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('DatabaseFunctions', () {
    final dbFunctions = DatabaseFunctions();

    setUp(() async {
      // Ensure the database is initialized before each test
      await dbFunctions.database;
    });

    test('insertAttribute and getAttributes', () async {
      // Insert an attribute
      await dbFunctions.insertAttribute('testKey', 'testValue', 'testType');

      // Retrieve attributes
      final attributes = await dbFunctions.getAttributes();

      // Check if the inserted attribute is present
      expect(attributes, isNotEmpty);
      expect(attributes.first['key'], 'testKey');
      expect(attributes.first['value'], 'testValue');
      expect(attributes.first['type'], 'testType');
    });
    test('datetime test', () async {
      // Insert an attribute
      await dbFunctions.insertAttribute('testKey', 'testValue', 'testType');

      // Retrieve attributes
      final attributes = await dbFunctions.getAttributes();

      // Check if the inserted attribute is present
      expect(attributes, isNotEmpty);
      expect(attributes.first['timestamp'], isNotNull);
    });
  });
}
