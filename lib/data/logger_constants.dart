// SPDX-FileCopyrightText: 2025 Benoit Rolandeau <benoit.rolandeau@allcircuits.com>
//
// SPDX-License-Identifier: MIT

library;

import 'package:logger/logger.dart';

/// This is the default log level for the logger
const Level defaultLogLevel = Level.trace;

/// This allow to manage the uncatched errors
/// If true, the logger will catch all the uncatched errors and log them
const bool manageUncatchedErrors = false;
