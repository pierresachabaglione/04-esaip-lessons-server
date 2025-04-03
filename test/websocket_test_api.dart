import 'dart:convert';
import 'dart:io';

import 'package:async/async.dart'; // For StreamQueue
import 'package:esaip_lessons_server/database/database_functions.dart';
import 'package:esaip_lessons_server/websocket/websocket_server.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:test/test.dart';
import 'package:web_socket_channel/io.dart';

void main() {
  late WebSocketServer server;
  late DatabaseFunctions database;

  // Initialize sqflite ffi for testing.
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

  test('Registration returns API key', () async {
    final channel = IOWebSocketChannel.connect('ws://localhost:8080/ws');
    // Use a StreamQueue to read messages sequentially.
    final queue = StreamQueue(channel.stream);

    final registerMessage = jsonEncode({
      'action': 'register',
      'uniqueId': 'CC-TS-00128',
      'type': 'sensor',
    });
    channel.sink.add(registerMessage);

    final response = await queue.next;
    final data = jsonDecode(response as String);
    expect(data['status'], equals('success'));
    expect(data['message'], contains('Device registered'));
    expect(data.containsKey('apiKey'), true);
    print(';API Key: ${data['apiKey']}');
    final apiKey = data['apiKey'];
    expect(apiKey, isNotNull);
    expect(apiKey, isA<String>());

    await channel.sink.close();
    await queue.cancel();
  });

  test('Authenticated fails without API key', () async {
    final channel = IOWebSocketChannel.connect('ws://localhost:8080/ws');
    final queue = StreamQueue(channel.stream);

    // Register the device.
    final registerMessage = jsonEncode({
      'action': 'register',
      'uniqueId': 'CC-TS-00188',
      'type': 'sensor',
    });
    channel.sink.add(registerMessage);
    final registerResponse = await queue.next;
    final registerData = jsonDecode(registerResponse as String);
    expect(registerData['status'], equals('success'));

    // Send sensor data without providing an API key.
    final sendDataMessageWithoutKey = jsonEncode({
      'action': 'sendData',
      'uniqueId': 'CC-TS-00002188',
      'value': '25.0',
      'type': 'sensor'
      // No apiKey field provided.
    });
    channel.sink.add(sendDataMessageWithoutKey);
    final responseWithoutKey = await queue.next;
    final dataWithoutKey = jsonDecode(responseWithoutKey as String);
    expect(dataWithoutKey['status'], equals('error'));
    expect(dataWithoutKey['message'], contains('Missing API key'));

    await channel.sink.close();
    await queue.cancel();
  });

  test('Authenticated action with invalid API key', () async {
    final channel = IOWebSocketChannel.connect('ws://localhost:8080/ws');
    final queue = StreamQueue(channel.stream);

    // Register the device.
    final registerMessage = jsonEncode({
      'action': 'register',
      'uniqueId': 'CC-TS-00003',
      'type': 'sensor',
    });
    channel.sink.add(registerMessage);
    final registerResponse = await queue.next;
    final registerData = jsonDecode(registerResponse as String);
    expect(registerData['status'], equals('success'));

    // Send sensor data with an incorrect API key.
    final sendDataMessageInvalidKey = jsonEncode({
      'action': 'sendData',
      'uniqueId': 'CC-TS-00984',
      'key': 'temperature',
      'value': '30.0',
      'type': 'sensor',
      'apiKey': 'invalid-api-key'
    });
    channel.sink.add(sendDataMessageInvalidKey);
    final responseInvalidKey = await queue.next;
    final dataInvalidKey = jsonDecode(responseInvalidKey as String);
    expect(dataInvalidKey['status'], equals('error'));
    expect(dataInvalidKey['message'], contains('Invalid API key'));

    await channel.sink.close();
    await queue.cancel();
  });

  test('Authenticated action with valid API key', () async {
    final channel = IOWebSocketChannel.connect('ws://localhost:8080/ws');
    final queue = StreamQueue(channel.stream);

    // Register the device.
    final registerMessage = jsonEncode({
      'action': 'register',
      'uniqueId': 'CC-TS-00984',
      'type': 'sensor',
    });
    channel.sink.add(registerMessage);
    final registerResponse = await queue.next;
    final registerData = jsonDecode(registerResponse as String);
    expect(registerData['status'], equals('success'));
    final apiKey = registerData['apiKey'];

    // Send sensor data with the valid API key.
    final sendDataMessage = jsonEncode({
      'action': 'sendData',
      'uniqueId': 'CC-TS-00984',
      'key': 'temperature',
      'value': '22.5',
      'type': 'sensor',
      'apiKey': apiKey,
    });
    channel.sink.add(sendDataMessage);
    final dataResponse = await queue.next;
    final dataResult = jsonDecode(dataResponse as String);
    expect(dataResult['status'], equals('success'));
    expect(dataResult['message'], contains('Data stored'));

    await channel.sink.close();
    await queue.cancel();
  });
}
