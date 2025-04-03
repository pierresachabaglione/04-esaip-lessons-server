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
    await Future.delayed(const Duration(milliseconds: 500));

    // Check if the device was registered in the `devices` table
    final devices = await database.database.then((db) {
      print('Checking devices table');

      return db.query('devices', where: 'uniqueId = ?', whereArgs: ['1234']);
    });

    expect(devices.isNotEmpty, true);

    await channel.sink.close();
  });
  test('WebSocket server handles unregistration with valid serial', () async {
    // Connect and convert the stream to broadcast
    final channel = IOWebSocketChannel.connect('ws://localhost:8080/ws');
    final broadcastStream = channel.stream.asBroadcastStream();

    // Register the device
    final registerMessage = jsonEncode({
      'action': 'register',
      'uniqueId': 'CC-TS-00010',
      'type': 'sensor',
    });
    channel.sink.add(registerMessage);

    // Wait for registration response
    final registerResponse = await broadcastStream.first;
    final registerData = jsonDecode(registerResponse as String);
    expect(registerData['status'], equals('success'));

    // Unregister the device
    final unregisterMessage = jsonEncode({
      'action': 'unregister',
      'uniqueId': 'CC-TS-00010',
    });
    channel.sink.add(unregisterMessage);

    // Wait for unregistration response
    final unregisterResponse = await broadcastStream.first;
    final unregisterData = jsonDecode(unregisterResponse as String);
    expect(unregisterData['status'], equals('success'));
    expect(unregisterData['message'], contains('Device unregistered'));

    // Verify the device is removed from the database
    final devices = await DatabaseFunctions().database.then((db) {
      return db.query('devices', where: 'uniqueId = ?', whereArgs: ['CC-TS-00010']);
    });
    expect(devices.isEmpty, isTrue);

    await channel.sink.close();
  });

  test('WebSocket server rejects unregistration with invalid serial', () async {
    // Connect and convert the stream to broadcast
    final channel = IOWebSocketChannel.connect('ws://localhost:8080/ws');
    final broadcastStream = channel.stream.asBroadcastStream();

    // Attempt to unregister a device that was never registered
    final unregisterMessage = jsonEncode({
      'action': 'unregister',
      'uniqueId': 'CC-TS-99999',
    });
    channel.sink.add(unregisterMessage);

    // Wait for response
    final response = await broadcastStream.first;
    final data = jsonDecode(response as String);
    expect(data['status'], equals('error'));
    expect(data['message'], contains('Device not registered'));

    await channel.sink.close();
  });
}
