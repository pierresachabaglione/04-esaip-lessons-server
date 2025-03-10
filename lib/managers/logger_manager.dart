// SPDX-FileCopyrightText: 2025 Benoit Rolandeau <benoit.rolandeau@allcircuits.com>
//
// SPDX-License-Identifier: MIT

import 'dart:ui';

import 'package:esaip_lessons_server/data/logger_constants.dart' as logger_constants;
import 'package:esaip_lessons_server/managers/abstract_manager.dart';
import 'package:esaip_lessons_server/models/app_log_printer.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';

/// The logger manager to manage the logger
class LoggerManager extends AbstractManager {
  /// Instance of the logger
  late final Logger logger;

  /// {@macro abstract_manager.initialize}
  @override
  Future<void> initialize() async {
    logger = Logger(level: logger_constants.defaultLogLevel, printer: AppLogPrinter());
    logger.i('LoggerManager initialized');

    if (logger_constants.manageUncatchedErrors) {
      // Pass all uncaught asynchronous errors that aren't handled by the Flutter framework to
      // third parties.
      FlutterError.onError = _onFlutterError;

      // Pass all uncaught asynchronous errors that aren't handled by the platformas to
      // third parties.
      PlatformDispatcher.instance.onError = _onPlatformError;
    }
  }

  /// Called when a flutter error is thrown
  void _onFlutterError(FlutterErrorDetails details) {
    logger.e(details.exceptionAsString(), error: details.exception, stackTrace: details.stack);
  }

  /// Called when a platform error is thrown
  bool _onPlatformError(Object exception, StackTrace stackTrace) {
    logger.e(exception, error: exception, stackTrace: stackTrace);
    return true;
  }

  /// {@macro abstract_manager.dispose}
  @override
  Future<void> dispose() async {}
}
