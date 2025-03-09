// SPDX-FileCopyrightText: 2025 Benoit Rolandeau <benoit.rolandeau@allcircuits.com>
//
// SPDX-License-Identifier: MIT

import 'dart:async';

import 'package:esaip_lessons_server/managers/global_manager.dart';
import 'package:esaip_lessons_server/models/http_log.dart';
import 'package:flutter/material.dart';

/// Home page of the app
class HomePage extends StatefulWidget {
  /// Title of the home page
  const HomePage({super.key, required this.title});

  /// Title of the home page
  final String title;

  @override
  State<HomePage> createState() => _HomePageState();
}

/// State of the home page
class _HomePageState extends State<HomePage> {
  /// Subscription to the log stream
  StreamSubscription? _logSubscription;

  /// List of logs
  final List<HttpLog> _logs;

  /// Default constructor
  _HomePageState() : _logs = [];

  @override
  void initState() {
    super.initState();
    _logSubscription = GlobalManager.instance.httpLoggingManager.logStream.listen((log) {
      setState(() {
        _logs.add(log);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(backgroundColor: theme.colorScheme.inversePrimary, title: Text(widget.title)),
      body: ListView(
        children: _logs.map((log) => ListTile(title: Text(log.formattedLogMsg))).toList(),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => setState(_logs.clear),
        tooltip: '(TR) Clear',
        child: const Icon(Icons.clear),
      ),
    );
  }

  @override
  void dispose() {
    unawaited(_logSubscription?.cancel());
    super.dispose();
  }
}
