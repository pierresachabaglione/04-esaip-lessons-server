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

  test('Device can send multiple data parameters', () async {
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

    // We store the API key for later use.
    final apiKey = registerData['apiKey'];

    // we send the data with multiple entries
    final sendDataMessage = jsonEncode({
      'action': 'sendData',
      'uniqueId': uniqueId,
      'type': 'sensor',
      'apiKey': apiKey,
      'data': {
        'temperature': '25.5',
        'gps': '40.7128,-74.0060',
        'humidity': '60%'
      }
    });
    channel.sink.add(sendDataMessage);

    // we waite for the response
    final sendResponse = await queue.next;
    final sendResponseData = jsonDecode(sendResponse as String);
    expect(sendResponseData['status'], equals('success'));
    expect(sendResponseData['message'], contains('Data stored'));

    // Verify that the data was stored in the database.
    final storedData = await database.getStoredData(uniqueId);

    // Convert stored keys to a list for easy checking.
    final keys = storedData.map((entry) => entry['key']).toList();
    expect(keys, contains('temperature'));
    expect(keys, contains('gps'));
    expect(keys, contains('humidity'));

    // Optionally, verify the actual values.
    final temperatureEntry = storedData.firstWhere((entry) => entry['key'] == 'temperature');
    expect(temperatureEntry['value'], equals('25.5'));

    final gpsEntry = storedData.firstWhere((entry) => entry['key'] == 'gps');
    expect(gpsEntry['value'], equals('40.7128,-74.0060'));

    final humidityEntry = storedData.firstWhere((entry) => entry['key'] == 'humidity');
    expect(humidityEntry['value'], equals('60%'));

    await channel.sink.close();
  });
}
