import 'dart:convert';

import 'package:async/async.dart'; // For StreamQueue
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

  test('Device can send multiple data parameters and retrieve reconstructed data', () async {
    final channel = IOWebSocketChannel.connect('ws://localhost:8888/ws');
    final queue = StreamQueue(channel.stream);

    // Register the device.
    final uniqueId = 'CC-TS-00555';
    final registerMessage = jsonEncode({
      'action': 'register',
      'uniqueId': uniqueId,
      'type': 'sensor',
    });
    channel.sink.add(registerMessage);

    final registerResponse = await queue.next;
    final registerData = jsonDecode(registerResponse as String);
    expect(registerData['status'], equals('success'));

    // Store the API key for later use.
    final apiKey = registerData['apiKey'];

    // Send data with multiple entries.
    final sendDataMessage = jsonEncode({
      'action': 'sendData',
      'uniqueId': uniqueId,
      'type': 'sensor',
      'apiKey': apiKey,
      'data': {
        'temperature': '25.5',
        'gps': '40.7128,-74.0060',
        'humidity': '60%'
      },
    });
    channel.sink.add(sendDataMessage);

    // Wait for the sendData response.
    final sendResponse = await queue.next;
    final sendResponseData = jsonDecode(sendResponse as String);
    expect(sendResponseData['status'], equals('success'));
    expect(sendResponseData['message'], contains('Data stored'));

    // Request stored data through WebSocket.
    final getDataMessage = jsonEncode({
      'action': 'getStoredData',
      'uniqueId': uniqueId,
      'apiKey': apiKey,
    });
    channel.sink.add(getDataMessage);

    // Wait for the getStoredData response.
    final dataResponse = await queue.next;
    final responseData = jsonDecode(dataResponse as String);

    expect(responseData['status'], equals('success'));
    expect(responseData['message'], contains('Stored data retrieved successfully'));

    // With multiple entries, the server reconstructs the data as a Map.
    expect(responseData['data'], isA<Map>());
    final reconstructedData = responseData['data'] as Map<String, dynamic>;
    expect(reconstructedData['temperature'], equals('25.5'));
    expect(reconstructedData['gps'], equals('40.7128,-74.0060'));
    expect(reconstructedData['humidity'], equals('60%'));

    await channel.sink.close();
    await queue.cancel();
  });



}
