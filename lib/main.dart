// File: main.dart
import 'dart:io';
import 'package:esaip_lessons_server/managers/global_manager.dart';
import 'package:esaip_lessons_server/ui/main_app/main_app_ui.dart';
import 'package:esaip_lessons_server/websocket/websocket_server.dart';
import 'package:flutter/material.dart';

Future<String> getLocalIpAddress() async {
  try {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLoopback: false,
    );
    if (interfaces.isNotEmpty && interfaces.first.addresses.isNotEmpty) {
      return interfaces.first.addresses.first.address;
    }
  } catch (e) {
    print("IP address auto fetch error : $e");
  }
  return '127.0.0.1';
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await GlobalManager.instance.initialize();

  String localIp = await getLocalIpAddress();
  print("Server ip will be  : $localIp");

  final webSocketServer = WebSocketServer();
  await webSocketServer.start(ipAddress: localIp, port: 8888);

  runApp(const MainAppUi());
}