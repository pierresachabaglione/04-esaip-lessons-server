// SPDX-FileCopyrightText: 2025 Benoit Rolandeau <benoit.rolandeau@allcircuits.com>
//
// SPDX-License-Identifier: MIT

import 'dart:io';

import 'package:esaip_lessons_server/data/server_constants.dart' as server_constants;
import 'package:esaip_lessons_server/managers/abstract_manager.dart';
import 'package:esaip_lessons_server/managers/global_manager.dart';
import 'package:esaip_lessons_server/managers/http_logging_manager.dart';
import 'package:esaip_lessons_server/models/http_log.dart';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import 'package:uuid/uuid.dart';

/// This class is used to manage the http server
/// It will create a server and listen to the requests
class HttpServerManager extends AbstractManager {
  /// Instance of the http server
  late final HttpServer _server;

  /// Instance of the http logging manager
  late final HttpLoggingManager _httpLoggingManager;

  /// {@macro abstract_manager.initialize}
  @override
  Future<void> initialize() async {
    _httpLoggingManager = GlobalManager.instance.httpLoggingManager;
    final app = Router();

    app.get('/hello', _getHello);

    _server = await io.serve(
      app.call,
      server_constants.serverHostname,
      server_constants.serverPort,
    );
    _httpLoggingManager.addLog(
      HttpLog.now(
        requestId: "server-start",
        route: '/',
        method: '/',
        logLevel: Level.info,
        message: 'Server started on ${_server.address.host}:${_server.port}',
      ),
    );
  }

  /// Route to handle the hello request
  Future<Response> _getHello(Request request) =>
      _logRequest(request, (requestId) async => Response.ok('Hello, World!'));

  /// Useful method to wraps the request handling with logging
  Future<Response> _logRequest(
    Request request,
    Future<Response> Function(String requestId) handler,
  ) async {
    final requestId = shortHash(const Uuid().v1());

    _httpLoggingManager.addLog(
      HttpLog.now(
        requestId: requestId,
        route: request.requestedUri.path,
        method: request.method,
        logLevel: Level.info,
        message: "Received request",
      ),
    );
    final response = await handler(requestId);
    _httpLoggingManager.addLog(
      HttpLog.now(
        requestId: requestId,
        route: request.requestedUri.path,
        method: request.method,
        logLevel: Level.info,
        message: "Responded with status code ${response.statusCode}",
      ),
    );
    return response;
  }

  /// {@macro abstract_manager.dispose}
  @override
  Future<void> dispose() async {
    _httpLoggingManager.addLog(
      HttpLog.now(
        requestId: "server-close",
        route: '/',
        method: '/',
        logLevel: Level.info,
        message: 'Server closed on ${_server.address.host}:${_server.port}',
      ),
    );
    await _server.close(force: true);
  }
}
