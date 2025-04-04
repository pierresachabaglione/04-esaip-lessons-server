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

  // Helper function to register a device and return the registration data.
  Future<Map<String, dynamic>> registerDevice(String uniqueId) async {
    final channel = IOWebSocketChannel.connect('ws://localhost:8888/ws');
    final queue = StreamQueue(channel.stream);
    final registerMessage = jsonEncode({
      'action': 'register',
      'uniqueId': uniqueId,
      'type': 'sensor',
    });
    channel.sink.add(registerMessage);
    final regResponse = await queue.next;
    final regData = jsonDecode(regResponse as String);
    await channel.sink.close();
    await queue.cancel();
    return regData as Map<String, dynamic>;
  }

  test('Set (Insert) Attribute for TS device', () async {
    final uniqueId = 'CC-TS-10001';
    final regData = await registerDevice(uniqueId);
    expect(regData['status'], equals('success'));
    final apiKey = regData['apiKey'];

    // Set an attribute.
    final channel = IOWebSocketChannel.connect('ws://localhost:8888/ws');
    final queue = StreamQueue(channel.stream);
    final setAttributeMessage = jsonEncode({
      'action': 'setAttribute',
      'uniqueId': uniqueId,
      'key': 'volume',
      'value': '80',
      'apiKey': apiKey,
    });
    channel.sink.add(setAttributeMessage);
    final setResponse = await queue.next;
    final setData = jsonDecode(setResponse as String);
    expect(setData['status'], equals('success'));
    // For a TS device, the attribute type is derived as "client".
    expect(setData['attributeType'], equals('client'));

    await channel.sink.close();
    await queue.cancel();
  });

  test('Modify (Update) Attribute for TS device', () async {
    final uniqueId = 'CC-TS-10002';
    final regData = await registerDevice(uniqueId);
    expect(regData['status'], equals('success'));
    final apiKey = regData['apiKey'];

    // Insert an attribute first.
    final channel1 = IOWebSocketChannel.connect('ws://localhost:8888/ws');
    final queue1 = StreamQueue(channel1.stream);
    final setAttributeMessage1 = jsonEncode({
      'action': 'setAttribute',
      'uniqueId': uniqueId,
      'key': 'brightness',
      'value': '50',
      'apiKey': apiKey,
    });
    channel1.sink.add(setAttributeMessage1);
    final setResponse1 = await queue1.next;
    final setData1 = jsonDecode(setResponse1 as String);
    expect(setData1['status'], equals('success'));
    await channel1.sink.close();
    await queue1.cancel();

    // Modify the attribute (update the value).
    final channel2 = IOWebSocketChannel.connect('ws://localhost:8888/ws');
    final queue2 = StreamQueue(channel2.stream);
    final modifyAttributeMessage = jsonEncode({
      'action': 'setAttribute',
      'uniqueId': uniqueId,
      'key': 'brightness',
      'value': '70', // New value
      'apiKey': apiKey,
    });
    channel2.sink.add(modifyAttributeMessage);
    final modifyResponse = await queue2.next;
    final modifyData = jsonDecode(modifyResponse as String);
    expect(modifyData['status'], equals('success'));
    expect(modifyData['attributeType'], equals('client'));
    await channel2.sink.close();
    await queue2.cancel();
  });

  test('Get Attributes for TS device', () async {
    final uniqueId = 'CC-TS-10003';
    final regData = await registerDevice(uniqueId);
    expect(regData['status'], equals('success'));
    final apiKey = regData['apiKey'];

    // Set an attribute first.
    final channelSet = IOWebSocketChannel.connect('ws://localhost:8888/ws');
    final queueSet = StreamQueue(channelSet.stream);
    final setAttributeMessage = jsonEncode({
      'action': 'setAttribute',
      'uniqueId': uniqueId,
      'key': 'temperature_threshold',
      'value': '75',
      'apiKey': apiKey,
    });
    channelSet.sink.add(setAttributeMessage);
    await queueSet.next;
    await channelSet.sink.close();
    await queueSet.cancel();

    // Retrieve attributes.
    final channelGet = IOWebSocketChannel.connect('ws://localhost:8888/ws');
    final queueGet = StreamQueue(channelGet.stream);
    final getAttributesMessage = jsonEncode({
      'action': 'getAttributes',
      'uniqueId': uniqueId,
      'apiKey': apiKey,
    });
    channelGet.sink.add(getAttributesMessage);
    final getResponse = await queueGet.next;
    final getData = jsonDecode(getResponse as String);
    expect(getData['status'], equals('success'));
    expect(getData['data'], isList);
    final attributes = getData['data'] as List<dynamic>;
    expect(attributes.any((attr) => attr['key'] == 'temperature_threshold'), true);
    await channelGet.sink.close();
    await queueGet.cancel();
  });

  test('Delete Attribute for TS device', () async {
    final uniqueId = 'CC-TS-10004';
    final regData = await registerDevice(uniqueId);
    expect(regData['status'], equals('success'));
    final apiKey = regData['apiKey'];

    // Set an attribute to delete.
    final channelSet = IOWebSocketChannel.connect('ws://localhost:8888/ws');
    final queueSet = StreamQueue(channelSet.stream);
    final setAttributeMessage = jsonEncode({
      'action': 'setAttribute',
      'uniqueId': uniqueId,
      'key': 'contrast',
      'value': '40',
      'apiKey': apiKey,
    });
    channelSet.sink.add(setAttributeMessage);
    await queueSet.next;
    await channelSet.sink.close();
    await queueSet.cancel();

    // Delete the attribute.
    final channelDel = IOWebSocketChannel.connect('ws://localhost:8888/ws');
    final queueDel = StreamQueue(channelDel.stream);
    final deleteAttributeMessage = jsonEncode({
      'action': 'deleteAttribute',
      'uniqueId': uniqueId,
      'key': 'contrast',
      'apiKey': apiKey,
    });
    channelDel.sink.add(deleteAttributeMessage);
    final deleteResponse = await queueDel.next;
    final deleteData = jsonDecode(deleteResponse as String);
    expect(deleteData['status'], equals('success'));
    await channelDel.sink.close();
    await queueDel.cancel();

    // Confirm deletion by retrieving attributes.
    final channelGet = IOWebSocketChannel.connect('ws://localhost:8888/ws');
    final queueGet = StreamQueue(channelGet.stream);
    final getAttributesMessage = jsonEncode({
      'action': 'getAttributes',
      'uniqueId': uniqueId,
      'apiKey': apiKey,
    });
    channelGet.sink.add(getAttributesMessage);
    final getResponse = await queueGet.next;
    final getData = jsonDecode(getResponse as String);
    final attributes = getData['data'] as List<dynamic>;
    expect(attributes.any((attr) => attr['key'] == 'contrast'), false);
    await channelGet.sink.close();
    await queueGet.cancel();
  });
}
