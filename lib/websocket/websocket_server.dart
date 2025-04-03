import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:esaip_lessons_server/database/database_functions.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// The server that allows interaction with the devices
class WebSocketServer {
  HttpServer? _server;
  final Map<String, WebSocketChannel> _clients = {}; // Map to track clients by uniqueId

  /// Start the WebSocket server
  Future<void> start({int port = 8080}) async {
    _server = await HttpServer.bind(InternetAddress.anyIPv4, port);
    print('WebSocket server running on ws://localhost:$port');

    _server?.transform(WebSocketTransformer()).listen(_handleConnection);
  }

  /// The WebSocket connection handler
  void _handleConnection(WebSocket socket) {
    final channel = IOWebSocketChannel(socket);

    print('New client connected');
    channel.stream.listen(
          (message) async => _handleMessage(channel, message as String),
      onDone: () => _handleDisconnect(channel),
      onError: (error) => print('Error: $error'),
    );
  }

  /// The main message handler that checks for device registration
  /// before any other action
  Future<void> _handleMessage(WebSocketChannel channel, String message) async {
    try {
      final data = jsonDecode(message) as Map<String, dynamic>;
      final action = data['action'] as String;
      final uniqueId = data['uniqueId'] as String?;

      if (uniqueId == null) {
        channel.sink.add(jsonEncode({'status': 'error', 'message': 'Missing uniqueId'}));
        return;
      }

      //bypassing the apicheck for trivial actions
      if (action != 'register' && action != 'hello') {
        final providedKey = data['apiKey'] as String?;
        if (providedKey == null) {
          channel.sink.add(jsonEncode({'status': 'error', 'message': 'Missing API key'}));
          return;
        }

        // Retrieve the device record to check its serial and apikey
        final deviceRecords = await DatabaseFunctions().getDevice(uniqueId);
        if (deviceRecords.isEmpty || deviceRecords.first['apiKey'] != providedKey) {
          channel.sink.add(jsonEncode({'status': 'error', 'message': 'Invalid API key'}));
          return;
        }
      }

      // Proceed with handling the request.
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
      // You might also add a case for 'hello' if needed.
        default:
          channel.sink.add(jsonEncode({'status': 'error', 'message': 'Unknown action'}));
      }
    } catch (e) {
      channel.sink.add(jsonEncode({'status': 'error', 'message': 'Invalid JSON format'}));
    }
  }

  /// The registration handler
  Future<void> _handleRegister(WebSocketChannel channel, Map<String, dynamic> data) async {
    final uniqueId = data['uniqueId'] as String?;
    final type = data['type'] as String?;

    if (uniqueId == null || type == null) {
      channel.sink.add(jsonEncode({'status': 'error', 'message': 'Missing registration fields'}));
      return;
    }

    // Validate uniqueId format…
    final regExp = RegExp(r'^CC-(TS|YT)-\d{5}$');
    if (!regExp.hasMatch(uniqueId)) {
      channel.sink.add(jsonEncode({'status': 'error', 'message': 'Invalid uniqueId format'}));
      return;
    }

    // Check if device already exists.
    final existingDevice = await DatabaseFunctions().getDevice(uniqueId);
    if (existingDevice.isNotEmpty) {
      channel.sink.add(jsonEncode({'status': 'error', 'message': 'Device already registered'}));
      return;
    }

    // Register the device and get the API key.
    final apiKey = await DatabaseFunctions().registerDevice(uniqueId, type);
    _clients[uniqueId] = channel; // Track the client connection
    channel.sink.add(jsonEncode({
      'status': 'success',
      'message': 'Device registered',
      'apiKey': apiKey
    }));
  }


  ///the unregister handler
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
    _clients.remove(uniqueId); // Remove from the active clients list
    channel.sink.add(jsonEncode({'status': 'success', 'message': 'Device unregistered'}));
  }


  /// The data store handler
  Future<void> _handleData(WebSocketChannel channel, Map<String, dynamic> data) async {
    final key = data['key'] as String?;
    final value = data['value'] as String?;
    final type = data['type'] as String?;

    if (key == null || value == null || type == null) {
      channel.sink.add(jsonEncode({'status': 'error', 'message': 'Missing data fields'}));
      return;
    }

    await DatabaseFunctions().insertAttribute(key, value, type);
    channel.sink.add(jsonEncode({'status': 'success', 'message': 'Data stored'}));
  }

  /// here we sends a message to all connected clients / broadcast
  void sendMessage(String message) {
    for (final channel in _clients.values) {
      channel.sink.add(message);
    }
  }

  /// a more orhtodax way to send a message to a specific client
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

  /// Handle client disconnection
  void _handleDisconnect(WebSocketChannel channel) {
    _clients.removeWhere((id, client) => client == channel);
    print('Client disconnected');
  }

  /// Close the WebSocket server
  Future<void> close() async {
    await _server?.close();
    // Iterate over a copy to avoid concurrent modification.
    for (final channel in List.of(_clients.values)) {
      await channel.sink.close();
    }
    _clients.clear();
  }

}
