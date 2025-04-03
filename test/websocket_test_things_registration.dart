import 'dart:convert';
import 'dart:io';

import 'package:esaip_lessons_server/database/database_functions.dart';
import 'package:esaip_lessons_server/websocket/websocket_server.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:test/test.dart';
import 'package:web_socket_channel/io.dart';



void main() {
  late WebSocketServer server;
  late DatabaseFunctions database;
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  setUp(() async {
    database = DatabaseFunctions();
    server = WebSocketServer();
    await database.database;
    await server.start();
  });

  tearDown(() async {
    await server.close();
  });

  test('WebSocket server starts and accepts connections', () async {
    final channel = await WebSocket.connect('ws://localhost:8080/ws');
    expect(channel.readyState, equals(WebSocket.open));
    await channel.close();
  });

  test('WebSocket server handles registration message', () async {
    final channel = IOWebSocketChannel.connect('ws://localhost:8080/ws');

    final testMessage = jsonEncode({
      'action': 'register',
      'uniqueId': '1234',
      'type': 'sensor',
    });
    channel.sink.add(testMessage);

    // Wait for processing
    await Future.delayed(Duration(milliseconds: 500));

    // Check if the device was registered in the `devices` table
    final devices = await database.database.then((db) {
      print('Checking devices table');

      return db.query('devices', where: 'uniqueId = ?', whereArgs: ['1234']);
    });

    expect(devices.isNotEmpty, true);

    await channel.sink.close();
  });
}
