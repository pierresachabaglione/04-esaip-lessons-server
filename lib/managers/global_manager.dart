// SPDX-FileCopyrightText: 2025 Pierre-Sacha Baglione
// SPDX-License-Identifier: MIT

import 'dart:async';
import 'package:esaip_lessons_server/database/database_functions.dart';

/// Global manager
class GlobalManager {
  /// Instance of the global manager
  static GlobalManager? _instance;

  /// Instance of the database functions manager.
  final DatabaseFunctions databaseFunctions;

  /// Stream controller for database changes.
  final StreamController<void> _databaseChangeController =
  StreamController<void>.broadcast();

  /// Stream of database changes.
  Stream<void> get databaseChangeStream => _databaseChangeController.stream;

  /// Notifies listeners of database changes.
  void notifyDatabaseChange() {
    _databaseChangeController.add(null);
  }

  /// Returns the singleton instance of GlobalManager.
  static GlobalManager get instance {
    _instance ??= GlobalManager();
    return _instance!;
  }

  /// Default constructor.
  GlobalManager() : databaseFunctions = DatabaseFunctions();

  /// Initializes the global manager.
  Future<void> initialize() async {
    await databaseFunctions.database;
  }

  /// Disposes the global manager.
  Future<void> dispose() async =>
      Future.wait([_databaseChangeController.close()]);

  /// Retrieves stored telemetry data for a given device.
  Future<List<Map<String, dynamic>>> getStoredData(String uniqueId) async =>
      databaseFunctions.getStoredData(uniqueId);

  /// Stores telemetry data for a given device.
  Future<void> storeStoredData(
      String uniqueId,
      String key,
      String value,
      ) async {
    await databaseFunctions.insertStoredData(uniqueId, key, value);
    notifyDatabaseChange();
  }
}
