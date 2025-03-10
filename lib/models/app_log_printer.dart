// SPDX-FileCopyrightText: 2025 Benoit Rolandeau <benoit.rolandeau@allcircuits.com>
//
// SPDX-License-Identifier: MIT

import 'package:logger/logger.dart';

/// Application specific log print
class AppLogPrinter extends LogPrinter {
  /// The method called to transform a [LogEvent] object to printable logs
  @override
  List<String> log(LogEvent event) => [defaultFormatLogEvent(event)];

  /// This method formats the log event with the default format used in all the ACT apps
  static String defaultFormatLogEvent(LogEvent event) =>
      "${DateTime.now().toIso8601String()}-[${event.level.name}]: ${event.message}";
}
