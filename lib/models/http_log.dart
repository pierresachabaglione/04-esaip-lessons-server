// SPDX-FileCopyrightText: 2025 Benoit Rolandeau <benoit.rolandeau@allcircuits.com>
//
// SPDX-License-Identifier: MIT

import 'package:equatable/equatable.dart';
import 'package:logger/logger.dart';

/// Contains the log of an http request
class HttpLog extends Equatable {
  /// The timestamp of the log
  final DateTime timestamp;

  /// This is the unique id of the request
  final String requestId;

  /// The route of the request called
  final String route;

  /// The HTTP method of the request
  final String method;

  /// The log level of the message
  final Level logLevel;

  /// The message of the log
  final String message;

  /// The formatted log message
  String get formattedLogMsg => "[$requestId] - $route - $method - $message";

  /// Constructor
  const HttpLog({
    required this.timestamp,
    required this.requestId,
    required this.route,
    required this.method,
    required this.logLevel,
    required this.message,
  });

  /// Create a new HttpLog
  ///
  /// The [timestamp] is set to the current time in UTC
  HttpLog.now({
    required this.requestId,
    required this.route,
    required this.method,
    required this.logLevel,
    required this.message,
  }) : timestamp = DateTime.now().toUtc();

  /// {@macro equatable_props}
  @override
  List<Object?> get props => [timestamp, requestId, route, method, logLevel, message];
}
