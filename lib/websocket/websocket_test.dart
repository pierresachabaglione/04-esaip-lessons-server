import 'dart:convert';
import 'dart:io';
import 'package:esaip_lessons_server/database/database_functions.dart';

class WebSocketServer {
  late HttpServer _server;
  final Map<String, WebSocket> clients = {}; // Stores connected clients
  final DatabaseFunctions database = DatabaseFunctions();

  /// Starts the WebSocket server on localhost:8080
  Future<void> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 8080);
    print('WebSocket server running on ws://localhost:8080');

    // Listen for WebSocket connections
    _server.transform(WebSocketTransformer()).listen(_handleConnection);
  }

  /// Handles a new WebSocket client connection
  void _handleConnection(WebSocket ws) {
    print('New client connected');

    ws.listen(
          (message) => _handleMessage(ws, message as String),
      onDone: () {
        print('Client disconnected');
        clients.removeWhere((key, value) => value == ws); // Remove disconnected client
      },
      onError: (error) {
        print('Error: $error');
      },
    );
  }

  /// Processes incoming messages from WebSocket clients
  void _handleMessage(WebSocket ws, String message) async {
    final data = jsonDecode(message); // Convert message JSON into a Map

    if (data['action'] == 'register') {
      final uniqueId = data['uniqueId']?.toString();
      final type = data['type']?.toString() ?? 'unknown';

      if (uniqueId == null) {
        ws.add(jsonEncode({'status': 'error', 'message': 'Invalid uniqueId'}));
        return;
      }

      // Register the device in the database
      await database.registerDevice(uniqueId, type);
      clients[uniqueId] = ws; // Store the WebSocket connection

      // Send confirmation response
      ws.add(jsonEncode({'status': 'success', 'message': 'Device registered'}));
    }

    if (data['action'] == 'sendData') {
      final uniqueId = data['uniqueId']?.toString();
      final key = data['key']?.toString();
      final value = data['value']?.toString();

      if (uniqueId == null || key == null || value == null) {
        ws.add(jsonEncode({'status': 'error', 'message': 'Invalid data'}));
        return;
      }

      // Check if device exists before storing data
      final registeredDevices = await database.getDevice(uniqueId);
      if (registeredDevices.isEmpty) {
        ws.add(jsonEncode({'status': 'error', 'message': 'Device not registered'}));
        return;
      }

      // Store sensor data in the database
      await database.insertSensorData(uniqueId, key, value);
      ws.add(jsonEncode({'status': 'success', 'message': 'Data stored'}));
    }

    if (data['action'] == 'sendMessageToClient') {
      final senderId = data['uniqueId']?.toString();
      final targetId = data['targetId']?.toString();
      final messageText = data['message']?.toString();

      if (senderId == null || targetId == null || messageText == null) {
        ws.add(jsonEncode({'status': 'error', 'message': 'Invalid message data'}));
        return;
      }

      if (!clients.containsKey(targetId)) {
        ws.add(jsonEncode({'status': 'error', 'message': 'Client not found'}));
        return;
      }

      // Send the message to the target client
      clients[targetId]?.add(jsonEncode({'status': 'success', 'message': messageText}));
    }
  }

  /// Closes the WebSocket server and clears the client list
  Future<void> close() async {
    await _server.close(force: true);
    clients.clear();
  }
}
