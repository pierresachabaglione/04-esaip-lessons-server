// File: main.dart

import 'package:esaip_lessons_server/managers/global_manager.dart';
import 'package:esaip_lessons_server/ui/main_app/main_app_ui.dart';
import 'package:esaip_lessons_server/websocket/websocket_server.dart';
import 'package:flutter/material.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await GlobalManager.instance.initialize();

  // Initialize and start the WebSocket server.
  final webSocketServer = WebSocketServer();
  await webSocketServer.start();

  runApp(const MainAppUi());
}
