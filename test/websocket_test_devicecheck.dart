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

  /// Sets up the WebSocket server and database before each test
  setUp(() async {
    database = DatabaseFunctions();
    server = WebSocketServer();
    await database.database;
    await server.start();
  });

  /// Closes the WebSocket server after each test
  tearDown(() async {
    await server.close();
  });

  /// Test: WebSocket server starts and accepts connections
  test('WebSocket server starts and accepts connections', () async {
    final channel = await WebSocket.connect('ws://localhost:8080/ws');
    expect(channel.readyState, equals(WebSocket.open));
    await channel.close();
  });

  /// Test: Device registration with a valid uniqueId (good device)
  test('WebSocket server handles device registration with valid uniqueId', () async {
    final channel = IOWebSocketChannel.connect('ws://localhost:8080/ws');

    final testMessage = jsonEncode({
      'action': 'register',
      'uniqueId': 'CC-TS-00001',
      'type': 'sensor',
    });
    channel.sink.add(testMessage);

    final response = await channel.stream.first;
    final responseData = jsonDecode(response as String);

    // Verify the response
    expect(responseData['status'], equals('success'));
    expect(responseData['message'], contains('Device registered'));

    // Verify the database entry
    final devices = await database.database.then((db) {
      return db.query('devices', where: 'uniqueId = ?', whereArgs: ['CC-TS-00001']);
    });
    expect(devices.isNotEmpty, true);
    await channel.sink.close();
  });

  /// Test: Device registration fails with an invalid uniqueId
  test('WebSocket server rejects device registration with invalid uniqueId', () async {
    final channel = IOWebSocketChannel.connect('ws://localhost:8080/ws');

    final testMessage = jsonEncode({
      'action': 'register',
      // Invalid uniqueId
      'uniqueId': 'nonvousnepasserezpas',
      'type': 'sensor',
    });
    channel.sink.add(testMessage);

    final response = await channel.stream.first;
    final responseData = jsonDecode(response as String);

    // Verify the response is an error due to invalid uniqueId format.
    expect(responseData['status'], equals('error'));
    expect(responseData['message'], contains('Invalid uniqueId format'));

    await channel.sink.close();
  });

  /// Test: Sending data from a registered device
  test('Registered device can send data', () async {
    final channel = IOWebSocketChannel.connect('ws://localhost:8080/ws');

    // Convert the channel stream to a broadcast stream.
    final broadcastStream = channel.stream.asBroadcastStream();

    // Register device with a valid uniqueId.
    final registerMessage = jsonEncode({
      'action': 'register',
      'uniqueId': 'CC-TS-00088',
      'type': 'sensor',
    });
    channel.sink.add(registerMessage);

    // Wait for registration response.
    final registerResponse = await broadcastStream.first;
    final registerData = jsonDecode(registerResponse as String);
    expect(registerData['status'], equals('success'));

    // Send data (include the required 'type' field).
    final sendDataMessage = jsonEncode({
      'action': 'sendData',
      'key': 'temperature',
      'value': '25.5',
      'uniqueId': 'CC-TS-00088',
      'type': 'sensor',
    });
    channel.sink.add(sendDataMessage);

    // Wait for the response for sending data.
    final response = await broadcastStream.first;
    final responseData = jsonDecode(response as String);

    // Verify response.
    expect(responseData['status'], equals('success'));
    expect(responseData['message'], contains('Data stored'));

    await channel.sink.close();
  });

  /// Test: Client-to-client messaging works
  test('Client-to-client messaging works', () async {
    final sender = IOWebSocketChannel.connect('ws://localhost:8080/ws');
    final receiver = IOWebSocketChannel.connect('ws://localhost:8080/ws');

    // Convert the receiver stream to a broadcast stream so it can be listened to multiple times.
    final receiverStream = receiver.stream.asBroadcastStream();

    // Register both clients with valid uniqueIds.
    sender.sink.add(jsonEncode({
      'action': 'register',
      'uniqueId': 'CC-TS-00002',
      'type': 'sensor'
    }));
    receiver.sink.add(jsonEncode({
      'action': 'register',
      'uniqueId': 'CC-TS-00003',
      'type': 'sensor'
    }));

    // Drain the initial registration response from the receiver.
    await receiverStream.first;

    // Sender sends a message to the receiver.
    final messageToSend = jsonEncode({
      'action': 'sendMessageToClient',
      'uniqueId': 'CC-TS-00002',
      'targetId': 'CC-TS-00003',
      'message': 'Hello Receiver!',
    });
    sender.sink.add(messageToSend);

    // Wait for the client-to-client message.
    final response = await receiverStream.first;
    final responseData = jsonDecode(response as String);

    // Verify the message was received correctly.
    expect(responseData['status'], equals('success'));
    expect(responseData['message'], equals('Hello Receiver!'));

    await sender.sink.close();
    await receiver.sink.close();
  });
}
