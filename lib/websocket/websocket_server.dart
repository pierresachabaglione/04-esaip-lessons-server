import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:esaip_lessons_server/database/database_functions.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// WebSocket server to handle incoming connections and messages
class WebSocketServer {
  late HttpServer _server;
  final List<WebSocket> _clients = [];
  final List<WebSocketChannel> _connections = [];
  final Router _router = Router();

  /// Constructor to initialize the WebSocket server
  WebSocketServer() {
    _router.get('/ws', _handleWebSocket);
  }

    ///Handling the http requests
  Handler get handler => _router.call;

  /// Start the WebSocket server
  Future<void> start() async {
    _server = await HttpServer.bind('localhost', 8080, shared: true);
    print('WebSocket server started on ws://${_server.address.address}:${_server.port}');
    _server.listen(_handleRequest);
  }

  Future<void> _handleRequest(HttpRequest request) async {
    if (request.headers['upgrade']?.first == 'websocket') {
      final webSocket = WebSocketTransformer.upgrade(request);
      _handleWebSocket(await webSocket);
    } else {
      request.response.statusCode = HttpStatus.badRequest;
      await request.response.close();
    }
  }

  void _handleWebSocket(WebSocket webSocket) {
    final channel = IOWebSocketChannel(webSocket);
    _connections.add(channel);

    channel.stream.listen((message) async {
      await _handleMessage(channel, message as String);
    }, onDone: () {
      _connections.remove(channel);
    });
  }

  Future<void> _handleMessage(WebSocketChannel channel, String message) async {
    final data = jsonDecode(message) as Map<String, dynamic>;
    final action = data['action'] as String;

    switch (action) {
      case 'register':
        await _handleRegister(channel, data);
        break;
      default:
        print('Unknown action: $action');
    }
  }

  Future<void> _handleRegister(WebSocketChannel channel, Map<String, dynamic> data) async {
    final uniqueId = data['uniqueId'] as String;
    final type = data['type'] as String;

    await DatabaseFunctions().registerDevice(uniqueId, type);

    channel.sink.add(jsonEncode({
      'uniqueId': uniqueId,
      'status': 'success',
      'message': 'Device registered successfully',
    }));
  }

  /// Close the WebSocket server and all its connections
  Future<void> close() async {
    // Create a copy of the list to avoid concurrent modification
    final clientsCopy = List<WebSocket>.from(_clients);
    for (final client in clientsCopy) {
      await client.close();
    }
    _clients.clear();
  }

  /// Send a message to all connected clients
  void sendMessage(String message) {
    for (final channel in _connections) {
      channel.sink.add(message);
    }
  }

  /// Send a message to a specific client
  void sendMessageToClient(WebSocketChannel channel, String message) {
    channel.sink.add(message);

  }

  /// Send a message to all clients except the server
  void sendMessageToAllExceptSender(WebSocketChannel sender, String message) {
    for (final channel in _connections) {
      if (channel != sender) {
        channel.sink.add(message);
      }
    }
  }
}
