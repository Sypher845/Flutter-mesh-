import 'package:flutter/foundation.dart';

/// Simple logger utility for debug mode
class Logger {
  // Private constructor
  Logger._();

  /// Log info message
  static void info(String message) {
    if (kDebugMode) {
      print('ℹ️  $message');
    }
  }

  /// Log success message
  static void success(String message) {
    if (kDebugMode) {
      print('✅ $message');
    }
  }

  /// Log warning message
  static void warning(String message) {
    if (kDebugMode) {
      print('⚠️  $message');
    }
  }

  /// Log error message
  static void error(String message, [Object? error]) {
    if (kDebugMode) {
      print('❌ $message');
      if (error != null) {
        print('   Error: $error');
      }
    }
  }

  /// Log debug message
  static void debug(String message) {
    if (kDebugMode) {
      print('🔍 $message');
    }
  }

  /// Log bluetooth message
  static void bluetooth(String message) {
    if (kDebugMode) {
      print('📡 $message');
    }
  }

  /// Log network message
  static void network(String message) {
    if (kDebugMode) {
      print('🌐 $message');
    }
  }
}
