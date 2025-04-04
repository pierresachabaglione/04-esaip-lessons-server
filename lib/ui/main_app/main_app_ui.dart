// File: main_app_ui.dart

// SPDX-FileCopyrightText: 2025 Pierre-Sacha Baglione
// SPDX-License-Identifier: MIT

import 'package:esaip_lessons_server/ui/dashboard/server_dashboard_page.dart';
import 'package:flutter/material.dart';

/// Main application widget
class MainAppUi extends StatelessWidget {
  /// Default constructor
  const MainAppUi({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'ServerApp',
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
    ),
    // Set the dashboard as the home screen.
    home: const ServerDashboardPage(),
  );
}
