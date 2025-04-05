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
    final channel = IOWebSocketChannel.connect('ws://localhost:8888/ws');
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
    // Updated expectation: look for "Sensor connected successfully" instead of "Device registered"
    expect(data['message'], contains('Sensor connected successfully'));
    expect(data.containsKey('apiKey'), true);
    print(';API Key: ${data['apiKey']}');
    final apiKey = data['apiKey'];
    expect(apiKey, isNotNull);
    expect(apiKey, isA<String>());

    await channel.sink.close();
    await queue.cancel();
  });

  test('Authenticated fails without API key', () async {
    final channel = IOWebSocketChannel.connect('ws://localhost:8888/ws');
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
    final channel = IOWebSocketChannel.connect('ws://localhost:8888/ws');
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
    final channel = IOWebSocketChannel.connect('ws://localhost:8888/ws');
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
    print("seuccessfully registered");
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
    print("successfully sent data");
    final dataResponse = await queue.next;
    print("reponse: $dataResponse");
    final dataResult = jsonDecode(dataResponse as String);
    expect(dataResult['status'], equals('success'));
    expect(dataResult['message'], contains('Data stored'));
    await channel.sink.close();
    await queue.cancel();
  });

  test('Mobile registration requires username and password', () async {
    final channel = IOWebSocketChannel.connect('ws://localhost:8888/ws');
    final queue = StreamQueue(channel.stream);

    // Attempt mobile registration without username and password.
    final registerMessageMissingLogin = jsonEncode({
      'action': 'register',
      'uniqueId': 'CC-MP-12345',
      'type': 'mobile',
    });
    channel.sink.add(registerMessageMissingLogin);
    final responseMissingLogin = await queue.next;
    final dataMissingLogin = jsonDecode(responseMissingLogin as String);
    expect(dataMissingLogin['status'], equals('error'));
    expect(dataMissingLogin['message'], contains('Missing user / password for mobile registration'));

    await channel.sink.close();
    await queue.cancel();
  });

  test('Mobile registration with username and password succeeds', () async {
    final channel = IOWebSocketChannel.connect('ws://localhost:8888/ws');
    final queue = StreamQueue(channel.stream);

    // Register with valid username and password.
    final registerMessageWithLogin = jsonEncode({
      'action': 'register',
      'uniqueId': 'CC-MP-12346',
      'type': 'mobile',
      'username': 'testuser',
      'password': 'testpass',
    });
    channel.sink.add(registerMessageWithLogin);
    final responseWithLogin = await queue.next;
    final dataWithLogin = jsonDecode(responseWithLogin as String);
    expect(dataWithLogin['status'], equals('success'));
    expect(dataWithLogin['message'], contains('Mobile device registered'));
    expect(dataWithLogin.containsKey('apiKey'), true);

    await channel.sink.close();
    await queue.cancel();
  });

  test('Authenticated action with valid API key for sensor returns data stored', () async {
    final channel = IOWebSocketChannel.connect('ws://localhost:8888/ws');
    final queue = StreamQueue(channel.stream);

    // Register a sensor device.
    final registerMessage = jsonEncode({
      'action': 'register',
      'uniqueId': 'CC-TS-01925',
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
      'uniqueId': 'CC-TS-01925',
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

  /// a test to see if a basic flow : sensor sends data --> mobile app retrieves data
  /// works
  test('Mobile app retrieves sensor data', () async {
    // Register the sensor device.
    final sensorChannel = IOWebSocketChannel.connect('ws://localhost:8888/ws');
    final sensorQueue = StreamQueue(sensorChannel.stream);
    final sensorUniqueId = 'CC-TS-88888';
    final sensorRegMessage = jsonEncode({
      'action': 'register',
      'uniqueId': sensorUniqueId,
      'type': 'sensor',
    });
    sensorChannel.sink.add(sensorRegMessage);
    final sensorRegResponse = await sensorQueue.next;
    final sensorRegData = jsonDecode(sensorRegResponse as String);
    expect(sensorRegData['status'], equals('success'));
    final sensorApiKey = sensorRegData['apiKey'];

    // Send sensor data from the registered sensor.
    final sensorDataMessage = jsonEncode({
      'action': 'sendData',
      'uniqueId': sensorUniqueId,
      'key': 'temperature',
      'value': '23.0',
      'type': 'sensor',
      'apiKey': sensorApiKey,
    });
    sensorChannel.sink.add(sensorDataMessage);
    final sensorDataResponse = await sensorQueue.next;
    final sensorDataResult = jsonDecode(sensorDataResponse as String);
    expect(sensorDataResult['status'], equals('success'));
    expect(sensorDataResult['message'], contains('Data stored'));

    // Register the mobile device.
    final mobileChannel = IOWebSocketChannel.connect('ws://localhost:8888/ws');
    final mobileQueue = StreamQueue(mobileChannel.stream);
    final mobileUniqueId = 'CC-MP-77777';
    final mobileRegMessage = jsonEncode({
      'action': 'register',
      'uniqueId': mobileUniqueId,
      'type': 'mobile',
      'username': 'invisibleTouch',
      'password': "well i've been waiting, waiting here so looong",
    });
    mobileChannel.sink.add(mobileRegMessage);
    final mobileRegResponse = await mobileQueue.next;
    final mobileRegData = jsonDecode(mobileRegResponse as String);
    expect(mobileRegData['status'], equals('success'));
    expect(mobileRegData['message'], contains('Mobile device registered'));
    final mobileApiKey = mobileRegData['apiKey'];

    // Mobile app now requests sensor data.
    // IMPORTANT: Include the targetId (sensor's uniqueId) in the request.
    final mobileGetDataMessage = jsonEncode({
      'action': 'getStoredData',
      'uniqueId': mobileUniqueId,  // Mobile device's uniqueId.
      'targetId': sensorUniqueId,  // Target sensor uniqueId.
      'apiKey': mobileApiKey,
      'username': 'invisibleTouch',
      'password': "well i've been waiting, waiting here so looong",
    });
    mobileChannel.sink.add(mobileGetDataMessage);
    final mobileGetDataResponse = await mobileQueue.next;
    final mobileGetDataResult = jsonDecode(mobileGetDataResponse as String);
    expect(mobileGetDataResult['status'], equals('success'));
    expect(mobileGetDataResult['message'], contains('Stored sensor data retrieved successfully'));
    expect(mobileGetDataResult['data'], isA<Map>());
    final dataMap = mobileGetDataResult['data'] as Map<String, dynamic>;
    expect(dataMap['temperature'], equals('23.0'));

    // Close connections.
    await sensorChannel.sink.close();
    await mobileChannel.sink.close();
  });
}
