import 'package:esaip_lessons_server/database/database_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  // Initialize sqflite for ffi.
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('DatabaseFunctions', () {
    final dbFunctions = DatabaseFunctions();

    setUp(() async {
      await dbFunctions.database;
    });

    test('insertStoredData and getStoredData', () async {
      // Insert stored data for a dummy uniqueId.
      await dbFunctions.insertStoredData('CC-TS-TEST', 'testKey', 'testValue');

      // Retrieve stored data.
      final storedData = await dbFunctions.getStoredData('CC-TS-TEST');

      // Check if the inserted stored data is present.
      expect(storedData, isNotEmpty);
      expect(storedData.first['key'], 'testKey');
      expect(storedData.first['value'], 'testValue');
    });

    test('timestamp test', () async {
      await dbFunctions.insertStoredData('CC-TS-TEST', 'testKey', 'testValue');
      final storedData = await dbFunctions.getStoredData('CC-TS-TEST');

      // Check that the stored data includes a timestamp.
      expect(storedData, isNotEmpty);
      expect(storedData.first['timestamp'], isNotNull);
    });

    test('devices table', () async {
      await dbFunctions.registerDevice('testUniqueId', 'testType');
      final devices = await dbFunctions.getDevices();

      expect(devices, isNotEmpty);
      expect(devices.first['uniqueId'], 'testUniqueId');
      expect(devices.first['type'], 'testType');
    });
  });
}
