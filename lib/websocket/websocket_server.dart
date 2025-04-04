import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:esaip_lessons_server/database/database_functions.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// The server that allows interaction with the devices.
class WebSocketServer {
  HttpServer? _server;
  final Map<String, WebSocketChannel> _clients = {}; // Track clients by uniqueId.

  /// Starts the WebSocket server.
  Future<void> start({int port = 8888}) async {
    _server = await HttpServer.bind(InternetAddress.anyIPv4, port);
    print('WebSocket server running on ws://localhost:$port');
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

      if (uniqueId == null) {
        channel.sink.add(jsonEncode({'status': 'error', 'message': 'Missing uniqueId'}));
        return;
      }

      // Bypass API key check for trivial actions.
      if (action != 'register' && action != 'hello') {
        final providedKey = data['apiKey'] as String?;
        if (providedKey == null) {
          channel.sink.add(jsonEncode({'status': 'error', 'message': 'Missing API key'}));
          return;
        }
        final deviceRecords = await DatabaseFunctions().getDevice(uniqueId);
        if (deviceRecords.isEmpty || deviceRecords.first['apiKey'] != providedKey) {
          channel.sink.add(jsonEncode({'status': 'error', 'message': 'Invalid API key'}));
          return;
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
      channel.sink.add(jsonEncode({'status': 'error', 'message': 'Missing registration fields'}));
      return;
    }

    final regExp = RegExp(r'^CC-(TS|YT)-\d{5}$');
    if (!regExp.hasMatch(uniqueId)) {
      channel.sink.add(jsonEncode({'status': 'error', 'message': 'Invalid uniqueId format'}));
      return;
    }

    final existingDevice = await DatabaseFunctions().getDevice(uniqueId);
    if (existingDevice.isNotEmpty) {
      channel.sink.add(jsonEncode({'status': 'error', 'message': 'Device already registered'}));
      return;
    }

    final apiKey = await DatabaseFunctions().registerDevice(uniqueId, type);
    _clients[uniqueId] = channel;
    channel.sink.add(jsonEncode({
      'status': 'success',
      'message': 'Device registered',
      'apiKey': apiKey
    }));
  }

  /// Unregistration handler.
  Future<void> _handleUnregister(WebSocketChannel channel, Map<String, dynamic> data) async {
    final uniqueId = data['uniqueId'] as String?;
    if (uniqueId == null) {
      channel.sink.add(jsonEncode({'status': 'error', 'message': 'Missing uniqueId'}));
      return;
    }
    final isRegistered = await DatabaseFunctions().isDeviceRegistered(uniqueId);
    if (!isRegistered) {
      channel.sink.add(jsonEncode({'status': 'error', 'message': 'Device not registered'}));
      return;
    }
    await DatabaseFunctions().unregisterDevice(uniqueId);
    _clients.remove(uniqueId);
    channel.sink.add(jsonEncode({'status': 'success', 'message': 'Device unregistered'}));
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
        // we use a batch to insert multiple entries at once in the database
        print("recognised as map");
        final db = await DatabaseFunctions().database;
        final batch = db.batch();
        for (final entry in payload.entries) {
          batch.insert(
            'stored_data',
            {
              'uniqueId': uniqueId,
              'key': entry.key,
              'value': entry.value.toString()
            },
          );
        }
        await batch.commit(noResult: true);
        channel.sink.add(jsonEncode({'status': 'success', 'message': 'Data stored'}));
        return;
      } else if (payload is String) {
        print("recongised as string");
        // If the payload is only a string we store it using a default key.
        await DatabaseFunctions().insertStoredData(uniqueId, 'data', payload);
        channel.sink.add(jsonEncode({'status': 'success', 'message': 'Data stored'}));
        return;
      }
    }
    else if (data.containsKey('key')) {
      final key = data['key'] as String?;
      final value = data['value'] as String?;
      if (key == null || value == null) {
        channel.sink.add(jsonEncode({'status': 'error', 'message': 'Missing key or value'}));
        return;
      }
      await DatabaseFunctions().insertStoredData(uniqueId, key, value);
      channel.sink.add(jsonEncode({'status': 'success', 'message': 'Data stored'}));
    } else {
      channel.sink.add(jsonEncode({'status': 'error', 'message': 'Invalid data format'}));
    }

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
  Future<void> _handleSendMessageToClient(WebSocketChannel sender, Map<String, dynamic> data) async {
    final targetId = data['targetId'] as String?;
    final message = data['message'] as String?;
    if (targetId == null || message == null) {
      sender.sink.add(jsonEncode({'status': 'error', 'message': 'Missing targetId or message'}));
      return;
    }
    final targetClient = _clients[targetId];
    if (targetClient != null) {
      targetClient.sink.add(jsonEncode({'status': 'success', 'message': message}));
      sender.sink.add(jsonEncode({'status': 'success', 'message': 'Message sent to $targetId'}));
    } else {
      sender.sink.add(jsonEncode({'status': 'error', 'message': 'Client not found'}));
    }
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
