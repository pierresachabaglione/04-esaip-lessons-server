// SPDX-FileCopyrightText: 2025 Benoit Rolandeau <benoit.rolandeau@allcircuits.com>
//
// SPDX-License-Identifier: MIT

import 'dart:async';

import 'package:esaip_lessons_server/managers/abstract_manager.dart';
import 'package:esaip_lessons_server/managers/global_manager.dart';
import 'package:esaip_lessons_server/models/http_log.dart';

/// This class is used to manage the logging of http requests
class HttpLoggingManager extends AbstractManager {
  /// Stream controller for the http logs
  final StreamController<HttpLog> _logStreamController;

  /// Stream getter for the http logs
  Stream<HttpLog> get logStream => _logStreamController.stream;

  /// Default constructor
  HttpLoggingManager() : _logStreamController = StreamController<HttpLog>.broadcast();

  /// {@macro abstract_manager.initialize}
  @override
  Future<void> initialize() async {}

  /// Add a new log to the stream
  void addLog(HttpLog log) {
    GlobalManager.instance.loggerManager.logger.log(log.logLevel, log.formattedLogMsg);
    _logStreamController.add(log);
  }

  /// {@macro abstract_manager.dispose}
  @override
  Future<void> dispose() async {
    await _logStreamController.close();
  }
}
