// SPDX-FileCopyrightText: 2025 Benoit Rolandeau <benoit.rolandeau@allcircuits.com>
//
// SPDX-License-Identifier: MIT

/// Abstract class for all managers
abstract class AbstractManager {
  /// {@template abstract_manager.initialize}
  /// Initialize the manager
  /// {@endtemplate}
  Future<void> initialize();

  /// {@template abstract_manager.dispose}
  /// Dispose the manager
  /// {@endtemplate}
  Future<void> dispose();
}
