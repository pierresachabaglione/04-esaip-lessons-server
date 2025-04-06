import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:esaip_lessons_server/database/database_functions.dart';
import 'package:esaip_lessons_server/managers/global_manager.dart'; // For updating the UI when a request is received
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// The server that allows interaction with the devices.
class WebSocketServer {
  HttpServer? _server;
  final Map<String, WebSocketChannel> _clients =
      {}; // Track clients by uniqueId.

  /// Starts the WebSocket server.
  Future<void> start({String ipAddress = '0.0.0.0', int port = 1111}) async {
    _server = await HttpServer.bind(InternetAddress(ipAddress), port);
    print('WebSocket server running on ws://$ipAddress:$port');
    _server?.transform(WebSocketTransformer()).listen(_handleConnection);
  }

  /// Handles new WebSocket connections.
  void _handleConnection(WebSocket socket) {
    final channel = IOWebSocketChannel(socket);
    print('New client connected');
    channel.stream.listen(
      (message) async => _handleMessage(channel, message as String),
      onDone: () => _handleDisconnect(channel),
      onError: (error) => print('Error: $error'),
    );
  }

  /// Main message handler that checks for device registration before other actions.
  Future<void> _handleMessage(WebSocketChannel channel, String message) async {
    try {
      final data = jsonDecode(message) as Map<String, dynamic>;
      final action = data['action'] as String;
      final uniqueId = data['uniqueId'] as String?;

      // For actions other than 'register' and 'hello', check API key.
      if (action != 'register' && action != 'hello') {
        final providedKey = data['apiKey'] as String?;
        if (providedKey == null) {
          channel.sink.add(jsonEncode({'status': 'error', 'message': 'Missing API key'}));
          return;
        }
        final deviceRecords = await DatabaseFunctions().getDevice(uniqueId!);
        if (deviceRecords.isEmpty || deviceRecords.first['apiKey'] != providedKey) {
          channel.sink.add(jsonEncode({'status': 'error', 'message': 'Invalid API key'}));
          return;
        }
        // We check if the device is banned
        if (deviceRecords.first['isBanned'] == 1) {
          await DatabaseFunctions().logRequest(uniqueId, 'WARN', 'banned device connection attempt', 'banned device connection attempt from ID : $uniqueId');
          GlobalManager.instance.notifyDatabaseChange();
          channel.sink.add(jsonEncode({'status': 'error', 'message': 'Device is banned'}));
          return;
        }
        // Additional check for monbile phones
        if (uniqueId.contains('CC-MP')) {
          final username = data['username'] as String?;
          final password = data['password'] as String?;
          if (username == null || password == null) {
            channel.sink.add(jsonEncode({
              'status': 'error',
              'message': 'Missing username or password for CC-MP device'
            }));
            return;
          }
          final user = await DatabaseFunctions().authenticateUser(username, password);
          if (user == null) {
            channel.sink.add(jsonEncode({
              'status': 'error',
              'message': 'Invalid username or password for CC-MP device'
            }));
            return;
          }
          // NEW: Check if the user is banned.
          if (user['isBanned'] == 1) {
            channel.sink.add(jsonEncode({
              'status': 'error',
              'message': 'User is banned'
            }));
            await DatabaseFunctions().logRequest(uniqueId, 'WARN', 'banned user action attempt', 'banned user action attempt from user : $username device: $uniqueId');
            return;
          }
        }
      }

      switch (action) {
        case 'hello':
          channel.sink.add(jsonEncode({'status': 'success', 'message': 'Hello from server!'}));
          break;
        case 'register':
          await _handleRegister(channel, data);
          break;
        case 'unregister':
          await _handleUnregister(channel, data);
          break;
        case 'sendData':
          await _handleData(channel, data);
          break;
        case 'sendMessageToClient':
          await _handleSendMessageToClient(channel, data);
          break;
        case 'getStoredData':
          await _handleGetStoredData(channel, data);
          break;
        case 'setAttribute':
          await _handleSetAttribute(channel, data);
          break;
        case 'deleteAttribute':
          await _handleDeleteAttribute(channel, data);
          break;
        case 'getAttributes':
          await _handleGetAttributes(channel, data);
          break;
        default:
          channel.sink.add(jsonEncode({'status': 'error', 'message': 'Unknown action'}));
      }
    } catch (e) {
      channel.sink.add(jsonEncode({'status': 'error', 'message': 'Invalid JSON format'}));
    }
  }

  /// Registration handler.
  Future<void> _handleRegister(WebSocketChannel channel, Map<String, dynamic> data) async {
    final uniqueId = data['uniqueId'] as String?;
    final type = data['type'] as String?;

    if (uniqueId == null || type == null) {
      channel.sink.add(
        jsonEncode({'status': 'error', 'message': 'Missing registration fields'}),
      );
      return;
    }

    // For mobile devices (or MP phones), require username and password.
    if (type == 'mobile' &&  RegExp(r'^CC-(MP)-\d{5}$').hasMatch(uniqueId)) {
      final password = data['password'] as String?;
      final username = data['username'] as String?;
      if (password == null || password.isEmpty || username == null || username.isEmpty) {
        channel.sink.add(
          jsonEncode({'status': 'error', 'message': 'Missing user / password for mobile registration'}),
        );
        return;
      }
      final existingDevice = await DatabaseFunctions().getDevice(uniqueId);
      if (existingDevice.isNotEmpty) {
        channel.sink.add(
          jsonEncode({'status': 'error', 'message': 'Device already registered'}),
        );
        return;
      }

      await DatabaseFunctions().registerUser(username, password, uniqueId: uniqueId);
      await DatabaseFunctions().logRequest(uniqueId, 'INFO', 'register', 'Mobile device Device ID : $uniqueId registered successfully');
      final apiKey = await DatabaseFunctions().registerDevice(uniqueId, type);
      GlobalManager.instance.notifyDatabaseChange();
      _clients[uniqueId] = channel;
      channel.sink.add(
        jsonEncode({
          'status': 'success',
          'message': 'Mobile device registered',
          'apiKey': apiKey,
        }),
      );
      return; // Exit after handling mobile registration.
    } else {
      // For sensor and other devices.
      final regExp = RegExp(r'^CC-(TS|YT)-\d{5}$');
      if (!regExp.hasMatch(uniqueId)) {
        channel.sink.add(jsonEncode({'status': 'error', 'message': 'Invalid uniqueId format'}));
        return;
      }
      final apiKey = await DatabaseFunctions().registerDevice(uniqueId, type);
      await DatabaseFunctions().logRequest(uniqueId, 'INFO', 'register', 'Device S/N : $uniqueId registered successfully');
      GlobalManager.instance.notifyDatabaseChange();
      _clients[uniqueId] = channel;
      // Update the message for sensor devices:
      String confirmationMessage = (type == 'sensor' || uniqueId.startsWith('CC-TS-'))
          ? 'Sensor connected successfully'
          : 'Device registered';
      channel.sink.add(
        jsonEncode({
          'status': 'success',
          'message': confirmationMessage,
          'apiKey': apiKey,
        }),
      );
      return; // Exit after handling sensor/other registration.
    }
  }
  /// Unregistration handler.
  Future<void> _handleUnregister(
    WebSocketChannel channel,
    Map<String, dynamic> data,
  ) async {
    final uniqueId = data['uniqueId'] as String?;
    if (uniqueId == null) {
      channel.sink.add(
        jsonEncode({'status': 'error', 'message': 'Missing uniqueId'}),
      );
      return;
    }
    final isRegistered = await DatabaseFunctions().isDeviceRegistered(uniqueId);
    if (!isRegistered) {
      channel.sink.add(
        jsonEncode({'status': 'error', 'message': 'Device not registered'}),
      );
      return;
    }
    await DatabaseFunctions().unregisterDevice(uniqueId);
    await DatabaseFunctions().logRequest(uniqueId, 'INFO', 'unregister', 'Device unregistered successfully');
    GlobalManager.instance.notifyDatabaseChange();
    _clients.remove(uniqueId);
    channel.sink.add(
      jsonEncode({'status': 'success', 'message': 'Device unregistered'}),
    );
  }

  /// Data store handler.
  Future<void> _handleData(WebSocketChannel channel, Map<String, dynamic> data) async {
    final uniqueId = data['uniqueId'] as String?;
    if (uniqueId == null) {
      channel.sink.add(jsonEncode({'status': 'error', 'message': 'Missing uniqueId'}));
      return;
    }
    if (data.containsKey('data')) {
      final payload = data['data'];
      if (payload is Map) {
        final db = await DatabaseFunctions().database;
        final batch = db.batch();
        for (final entry in payload.entries) {
          batch.insert('stored_data', {
            'uniqueId': uniqueId,
            'key': entry.key,
            'value': entry.value.toString(),
          });
        }
        await batch.commit(noResult: true);
        channel.sink.add(jsonEncode({'status': 'success', 'message': 'Data stored'}));
        // Log the telemetry data storage.
        await DatabaseFunctions().logRequest(uniqueId, 'INFO', 'telemetry request', 'Multiple telemetry data entries stored');
        GlobalManager.instance.notifyDatabaseChange();
        return;
      } else if (payload is String) {
        await DatabaseFunctions().insertStoredData(uniqueId, 'data', payload);
        channel.sink.add(jsonEncode({'status': 'success', 'message': 'Data stored'}));
        await DatabaseFunctions().logRequest(uniqueId, 'INFO', 'telemetry request', 'Telemetry data stored');
        GlobalManager.instance.notifyDatabaseChange();
        return;
      }
    } else if (data.containsKey('key')) {
      final key = data['key'] as String?;
      final value = data['value'] as String?;
      if (key == null || value == null) {
        channel.sink.add(jsonEncode({'status': 'error', 'message': 'Missing key or value'}));
        return;
      }
      await DatabaseFunctions().insertStoredData(uniqueId, key, value);
      channel.sink.add(jsonEncode({'status': 'success', 'message': 'Data stored'}));
      await DatabaseFunctions().logRequest(uniqueId, 'INFO', 'telemetry request', 'Telemetry data stored');
      GlobalManager.instance.notifyDatabaseChange();
      return;
    } else {
      channel.sink.add(jsonEncode({'status': 'error', 'message': 'Invalid data format'}));
    }
  }


  /// Retrieves stored data for a given device by its serial number.
  Future<void> _handleGetStoredData(WebSocketChannel channel, Map<String, dynamic> data) async {
    final requesterUniqueId = data['uniqueId'] as String?;
    final targetUniqueId = data['targetId'] as String?;

    if (requesterUniqueId == null || targetUniqueId == null) {
      channel.sink.add(jsonEncode({
        'status': 'error',
        'message': 'Missing fields for mobile sensor data request'
      }));
      return;
    }

    // Authenticate the mobile device using its uniqueId and API key.
    final mobileDevice = await DatabaseFunctions().getDevice(requesterUniqueId);
    if (mobileDevice.isEmpty) {
      channel.sink.add(jsonEncode({
        'status': 'error',
        'message': 'Invalid mobile device credentials'
      }));
      return;
    }

    // --- Authorization Check ---
    // If the requester is not asking for its own data, then
    //we allow only if requester is a mobile device and target is a sensor
    if (requesterUniqueId != targetUniqueId) {
      if (!(requesterUniqueId.startsWith('CC-MP-') && targetUniqueId.startsWith('CC-TS-'))) {
        channel.sink.add(jsonEncode({
          'status': 'error',
          'message': 'Unauthorized access to sensor data'
        }));
        return;
      }
    }

    // Retrieve sensor data for the targetUniqueId.
    final sensorData = await DatabaseFunctions().getStoredData(targetUniqueId);
    if (sensorData.isEmpty) {
      channel.sink.add(jsonEncode({
        'status': 'error',
        'message': 'No data found for sensor'
      }));
      return;
    }

    dynamic reconstructedData;
    // Reconstruct data based on the number of entries.
    if (sensorData.length == 1 && sensorData.first['key'] == 'data') {
      reconstructedData = sensorData.first['value'];
    } else {
      final dataMap = <String, dynamic>{};
      for (final entry in sensorData) {
        dataMap[entry['key'] as String] = entry['value'];
      }
      reconstructedData = dataMap;
    }

    channel.sink.add(jsonEncode({
      'status': 'success',
      'message': 'Stored sensor data retrieved successfully',
      'data': reconstructedData,
    }));

    GlobalManager.instance.notifyDatabaseChange();
    await DatabaseFunctions().logRequest(requesterUniqueId, 'INFO', 'telemetry request', 'Telemetry data sent to device : $requesterUniqueId');
  }


  /// Sends a broadcast message to all connected clients.
  void sendMessage(String message) {
    for (final channel in _clients.values) {
      channel.sink.add(message);
    }
  }

  /// Sends a message to a specific client.
  void sendMessageToClient(String targetId, String message) {
    final targetClient = _clients[targetId];
    if (targetClient != null) {
      targetClient.sink.add(message);
    }
  }

  /// Sends a message to a specific client.
  Future<void> _handleSendMessageToClient(
    WebSocketChannel sender,
    Map<String, dynamic> data,
  ) async {
    final targetId = data['targetId'] as String?;
    final message = data['message'] as String?;
    if (targetId == null || message == null) {
      sender.sink.add(
        jsonEncode({
          'status': 'error',
          'message': 'Missing targetId or message',
        }),
      );
      return;
    }
    final targetClient = _clients[targetId];
    if (targetClient != null) {
      targetClient.sink.add(
        jsonEncode({'status': 'success', 'message': message}),
      );
      sender.sink.add(
        jsonEncode({
          'status': 'success',
          'message': 'Message sent to $targetId',
        }),
      );
    } else {
      sender.sink.add(
        jsonEncode({'status': 'error', 'message': 'Client not found'}),
      );
    }
  }

  /// Creates /Update a client/server attribute.
  /// The attribute type is determined by the uniqueId.
  /// TS attributes are for the things --> client
  /// YT attributes are for the connected apps --> server
  Future<void> _handleSetAttribute(
      WebSocketChannel channel, Map<String, dynamic> data) async {
    final uniqueId = data['uniqueId'] as String?;
    final key = data['key'] as String?;
    final value = data['value'] as String?;
    if (uniqueId == null || key == null || value == null) {
      channel.sink.add(jsonEncode({'status': 'error', 'message': 'Missing attribute fields'}));
      return;
    }
    // Determine attribute type from the uniqueId.
    final attributeType = uniqueId.contains('TS')
        ? 'client'
        : uniqueId.contains('YT')
        ? 'server'
        : null;
    if (attributeType == null) {
      channel.sink.add(jsonEncode({
        'status': 'error',
        'message': 'Invalid device type in uniqueId',
      }));
      return;
    }
    await DatabaseFunctions().setAttribute(uniqueId, attributeType, key, value);
    await DatabaseFunctions().logRequest(uniqueId, 'INFO', 'attribute request', 'Attribute $attributeType $key with value :  $value set');
    GlobalManager.instance.notifyDatabaseChange();
    channel.sink.add(jsonEncode({
      'status': 'success',
      'message': 'Attribute set',
      'attributeType': attributeType
    }));
  }

  /// Handles deletion of an attribute.
  Future<void> _handleDeleteAttribute(
      WebSocketChannel channel, Map<String, dynamic> data) async {
    final uniqueId = data['uniqueId'] as String?;
    final key = data['key'] as String?;
    if (uniqueId == null || key == null ) {
      channel.sink.add(jsonEncode({'status': 'error', 'message': 'Missing attribute fields'}));
      return;
    }
// Determine attribute type from the uniqueId.
    final attributeType = uniqueId.contains('TS')
        ? 'client'
        : uniqueId.contains('YT')
        ? 'server'
        : null;
    if (attributeType == null) {
      channel.sink.add(jsonEncode({
        'status': 'error',
        'message': 'Invalid device type in uniqueId',
      }));
      return;
    }
    await DatabaseFunctions().deleteAttribute(uniqueId, attributeType, key);
    await DatabaseFunctions().logRequest(uniqueId, 'INFO', 'attribute request', 'Attribute $attributeType $key deleted');
    GlobalManager.instance.notifyDatabaseChange();
    channel.sink.add(
      jsonEncode({'status': 'success', 'message': 'Attribute deleted'}),
    );
  }

  /// Handles retrieval of attributes, with optional filtering by type.
  /// TS attributes are for the things --> client
  /// YT attributes are for the connected apps --> server
  Future<void> _handleGetAttributes(
      WebSocketChannel channel, Map<String, dynamic> data) async {
    final uniqueId = data['uniqueId'] as String?;
    final filterType = data['filterType'] as String?; // Optional: "server" or "client"
    if (uniqueId == null) {
      channel.sink.add(
        jsonEncode({'status': 'error', 'message': 'Missing uniqueId'}),
      );
      return;
    }
    final attributes =
    await DatabaseFunctions().getAttributes(uniqueId, attributeType: filterType);
    await DatabaseFunctions().logRequest(uniqueId, 'INFO', 'attribute request', 'Attribute $filterType $attributes requested');
    GlobalManager.instance.notifyDatabaseChange();
    channel.sink.add(jsonEncode({
      'status': 'success',
      'message': 'Attributes retrieved',
      'data': attributes,
    }));
  }

  /// Handles client disconnection.
  void _handleDisconnect(WebSocketChannel channel) {
    _clients.removeWhere((id, client) => client == channel);
    print('Client disconnected');
  }

  /// Closes the WebSocket server.
  Future<void> close() async {
    await _server?.close();
    for (final channel in List.of(_clients.values)) {
      await channel.sink.close();
    }
    _clients.clear();
  }
}
