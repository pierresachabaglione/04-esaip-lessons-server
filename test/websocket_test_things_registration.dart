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
    // Optionally, add a method here to reset the database if required.
  });

  test('WebSocket server starts and accepts connections', () async {
    // Note: using port 8888.
    final channel = await WebSocket.connect('ws://localhost:8888/ws');
    expect(channel.readyState, equals(WebSocket.open));
    await channel.close();
  });

  test('WebSocket server handles registration message', () async {
    // Use a valid uniqueId that conforms to the regex pattern.
    final channel = IOWebSocketChannel.connect('ws://localhost:8888/ws');

    final testUniqueId = 'CC-TS-00110'; // valid uniqueId format
    final testMessage = jsonEncode({
      'action': 'register',
      'uniqueId': testUniqueId,
      'type': 'sensor',
    });
    channel.sink.add(testMessage);

    // Wait for processing.
    await Future.delayed(const Duration(milliseconds: 500));

    // Check if the device was registered in the `devices` table.
    final devices = await database.database.then((db) {
      print('Checking devices table');
      return db.query('devices', where: 'uniqueId = ?', whereArgs: [testUniqueId]);
    });

    expect(devices.isNotEmpty, true);

    await channel.sink.close();
  });

  test('WebSocket server handles unregistration with valid serial', () async {
    // Connect and convert the stream to broadcast.
    final channel = IOWebSocketChannel.connect('ws://localhost:8888/ws');
    final broadcastStream = channel.stream.asBroadcastStream();

    // Register the device.
    final registerMessage = jsonEncode({
      'action': 'register',
      'uniqueId': 'CC-TS-00111',
      'type': 'sensor',
    });
    channel.sink.add(registerMessage);

    // Wait for registration response.
    final registerResponse = await broadcastStream.first;
    final registerData = jsonDecode(registerResponse as String);
    expect(registerData['status'], equals('success'));

    // Use the valid API key returned during registration.
    final validApiKey = registerData['apiKey'];

    // Unregister the device by providing the valid API key.
    final unregisterMessage = jsonEncode({
      'action': 'unregister',
      'uniqueId': 'CC-TS-00111',
      'apiKey': validApiKey,
    });
    channel.sink.add(unregisterMessage);

    // Wait for unregistration response.
    final unregisterResponse = await broadcastStream.first;
    final unregisterData = jsonDecode(unregisterResponse as String);
    expect(unregisterData['status'], equals('success'));
    expect(unregisterData['message'], contains('Device unregistered'));

    // Verify the device is removed from the database.
    final devices = await DatabaseFunctions().database.then((db) {
      return db.query('devices', where: 'uniqueId = ?', whereArgs: ['CC-TS-00111']);
    });
    expect(devices.isEmpty, isTrue);

    await channel.sink.close();
  });

  test('WebSocket server rejects unregistration with invalid serial', () async {
    // Connect and convert the stream to broadcast.
    final channel = IOWebSocketChannel.connect('ws://localhost:8888/ws');
    final broadcastStream = channel.stream.asBroadcastStream();

    // Attempt to unregister a device that was never registered.
    // Provide a dummy API key.
    final unregisterMessage = jsonEncode({
      'action': 'unregister',
      'uniqueId': 'CC-TS-99999',
      'apiKey': 'dummy-api-key',
    });
    channel.sink.add(unregisterMessage);

    // Wait for response.
    final response = await broadcastStream.first;
    final data = jsonDecode(response as String);
    expect(data['status'], equals('error'));
    expect(data['message'], contains('Invalid API key'));

    await channel.sink.close();
  });
}
