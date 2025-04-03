import 'package:esaip_lessons_server/managers/global_manager.dart';
import 'package:esaip_lessons_server/ui/main_app/main_app_ui.dart';
import 'package:esaip_lessons_server/websocket/websocket_server.dart';
import 'package:flutter/material.dart';

/// Main function to run the app
Future<void> main() async {
  // This method forces all initialization async functions to be finished before running the app.
  // This way, we can launch functions at init before the UI is started.
  // Ths UI starts after these functions are finished.

  WidgetsFlutterBinding.ensureInitialized();

  await GlobalManager.instance.initialize();

  // Initialize and start the WebSocket server
  final webSocketServer = WebSocketServer();
  await webSocketServer.start();

  runApp(const MainAppUi());
}
