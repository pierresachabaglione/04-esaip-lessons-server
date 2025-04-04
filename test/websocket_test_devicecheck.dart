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
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  // Set up the server and database before each test.
  setUp(() async {
    database = DatabaseFunctions();
    server = WebSocketServer();
    await database.database;
    await server.start();
  });

  // Clean up after each test.
  tearDown(() async {
    await server.close();
  });

  test('WebSocket server starts and accepts connections', () async {
    final channel = await WebSocket.connect('ws://localhost:8888/ws');
    expect(channel.readyState, equals(WebSocket.open));
    await channel.close();
  });

  test('WebSocket server handles device registration with valid uniqueId', () async {
    final channel = IOWebSocketChannel.connect('ws://localhost:8888/ws');
    final queue = StreamQueue(channel.stream);

    final testMessage = jsonEncode({
      'action': 'register',
      'uniqueId': 'CC-TS-00001',
      'type': 'sensor',
    });
    channel.sink.add(testMessage);

    final response = await queue.next;
    final responseData = jsonDecode(response as String);

    // Verify the registration response.
    expect(responseData['status'], equals('success'));
    expect(responseData['message'], contains('Device registered'));

    // Verify the device is added to the database.
    final devices = await database.database.then((db) {
      return db.query('devices', where: 'uniqueId = ?', whereArgs: ['CC-TS-00001']);
    });
    expect(devices.isNotEmpty, true);

    await channel.sink.close();
  });

  test('WebSocket server rejects device registration with invalid uniqueId', () async {
    final channel = IOWebSocketChannel.connect('ws://localhost:8888/ws');
    final queue = StreamQueue(channel.stream);

    final testMessage = jsonEncode({
      'action': 'register',
      'uniqueId': 'nonvousnepasserezpas', // Invalid format.
      'type': 'sensor',
    });
    channel.sink.add(testMessage);

    final response = await queue.next;
    final responseData = jsonDecode(response as String);

    // Verify that an error is returned.
    expect(responseData['status'], equals('error'));
    expect(responseData['message'], contains('Invalid uniqueId format'));

    await channel.sink.close();
  });

  test('Registered device can send data', () async {
    final channel = IOWebSocketChannel.connect('ws://localhost:8888/ws');
    final queue = StreamQueue(channel.stream);

    // Register the device.
    final registerMessage = jsonEncode({
      'action': 'register',
      'uniqueId': 'CC-TS-00088',
      'type': 'sensor',
    });
    channel.sink.add(registerMessage);

    final registerResponse = await queue.next;
    final registerData = jsonDecode(registerResponse as String);
    expect(registerData['status'], equals('success'));

    // Capture the API key from registration.
    final apiKey = registerData['apiKey'];
    print("API Key: $apiKey");

    // Send data using the valid API key.
    final sendDataMessage = jsonEncode({
      'action': 'sendData',
      'key': 'temperature',
      'value': '25.5',
      'uniqueId': 'CC-TS-00088',
      'type': 'sensor',
      'apiKey': apiKey,
    });
    channel.sink.add(sendDataMessage);
    print("Sending data: $sendDataMessage");

    // Wait for the sendData response.
    final sendResponse = await queue.next;
    final sendResponseData = jsonDecode(sendResponse as String);
    print("Send Response: $sendResponseData");
    expect(sendResponseData['status'], equals('success'));
    expect(sendResponseData['message'], contains('Data stored'));

    await channel.sink.close();
  });

  test('Client-to-client messaging works', () async {
    // Connect sender and receiver clients.
    final sender = IOWebSocketChannel.connect('ws://localhost:8888/ws');
    final receiver = IOWebSocketChannel.connect('ws://localhost:8888/ws');

    final senderQueue = StreamQueue(sender.stream);
    final receiverQueue = StreamQueue(receiver.stream);

    // Register the sender.
    sender.sink.add(jsonEncode({
      'action': 'register',
      'uniqueId': 'CC-TS-00002',
      'type': 'sensor',
    }));
    final senderRegResponse = await senderQueue.next;
    final senderRegData = jsonDecode(senderRegResponse as String);
    expect(senderRegData['status'], equals('success'));
    final senderApiKey = senderRegData['apiKey'];

    // Register the receiver.
    receiver.sink.add(jsonEncode({
      'action': 'register',
      'uniqueId': 'CC-TS-00003',
      'type': 'sensor',
    }));
    final receiverRegResponse = await receiverQueue.next;
    final receiverRegData = jsonDecode(receiverRegResponse as String);
    expect(receiverRegData['status'], equals('success'));

    // Sender sends a message to the receiver including its API key.
    final messageToSend = jsonEncode({
      'action': 'sendMessageToClient',
      'uniqueId': 'CC-TS-00002',
      'targetId': 'CC-TS-00003',
      'message': 'Hello Receiver!',
      'apiKey': senderApiKey,
    });
    sender.sink.add(messageToSend);

    // Wait for sender's confirmation response.
    final senderResponse = await senderQueue.next;
    final senderResponseData = jsonDecode(senderResponse as String);
    expect(senderResponseData['status'], equals('success'));
    expect(senderResponseData['message'], contains('Message sent to CC-TS-00003'));

    // We check the receiver's response.
    final receiverResponse = await receiverQueue.next;
    final receiverResponseData = jsonDecode(receiverResponse as String);
    expect(receiverResponseData['status'], equals('success'));
    expect(receiverResponseData['message'], equals('Hello Receiver!'));

    await sender.sink.close();
    await receiver.sink.close();
  });

  /// Test to check if the server can send messages to clients.
  test('Server-to-client messaging works', () async {
    // Connect a client.
    final client = IOWebSocketChannel.connect('ws://localhost:8888/ws');
    final queue = StreamQueue(client.stream);

    // Register the client so it is added to the server's client list.
    client.sink.add(jsonEncode({
      'action': 'register',
      'uniqueId': 'CC-TS-01010',
      'type': 'sensor',
    }));

    // Wait for the registration response.
    final regResponse = await queue.next;
    final regData = jsonDecode(regResponse as String);
    expect(regData['status'], equals('success'));

    // Create a broadcast message from the server.
    final serverMessage = jsonEncode({
      'status': 'success',
      'message': 'Hello from server!'
    });

    // Send the broadcast message from the server.
    server.sendMessage(serverMessage);

    // Wait for the client to receive the server's message.
    final receivedMessage = await queue.next;
    final receivedData = jsonDecode(receivedMessage as String);
    expect(receivedData['status'], equals('success'));
    expect(receivedData['message'], equals('Hello from server!'));

    await client.sink.close();
  });

  ///server to specific client messaging
  test('Individual server-to-client messaging works', () async {
    // Connect a client.
    final client = IOWebSocketChannel.connect('ws://localhost:8888/ws');
    final queue = StreamQueue(client.stream);

    // Register the client so that it's added to the server's client list.
    client.sink.add(jsonEncode({
      'action': 'register',
      'uniqueId': 'CC-TS-03030',
      'type': 'sensor',
    }));

    // Wait for the registration response.
    final regResponse = await queue.next;
    final regData = jsonDecode(regResponse as String);
    expect(regData['status'], equals('success'));

    // Prepare a targeted message.
    final targetMessage = jsonEncode({
      'status': 'success',
      'message': 'Hello, individual client!'
    });

    // Use the server's public method to send a message to this specific client.
    server.sendMessageToClient('CC-TS-03030', targetMessage);

    // Wait for the client to receive the targeted message.
    final msgResponse = await queue.next;
    final msgData = jsonDecode(msgResponse as String);
    expect(msgData['status'], equals('success'));
    expect(msgData['message'], equals('Hello, individual client!'));

    await client.sink.close();
  });

}
