import 'dart:async';
import 'package:flutter/foundation.dart';
import 'models/reconnection_entry.dart';

/// Manages automatic reconnection attempts for lost connections
/// 
/// This manager maintains a queue of endpoints that need reconnection
/// and periodically attempts to reconnect with exponential backoff.
class ReconnectionManager {
  static const int maxRetries = 5;
  static const int retryIntervalSeconds = 5;
  static const int timerIntervalSeconds = 2;
  
  final Map<String, ReconnectionEntry> _reconnectionQueue = {};
  Timer? _reconnectionTimer;
  
  // Callbacks
  Function(String endpointId)? onReconnectAttempt;
  Function(String endpointId)? onReconnectSuccess;
  Function(String endpointId)? onReconnectExhausted;
  
  /// Add an endpoint to the reconnection queue
  /// 
  /// This should be called when a connection is lost unexpectedly.
  /// The endpoint will be added to the queue and reconnection attempts
  /// will begin on the next timer cycle.
  void addToQueue(String endpointId, String endpointName) {
    if (_reconnectionQueue.containsKey(endpointId)) {
      if (kDebugMode) {
        print('🔄 Endpoint already in reconnection queue: $endpointId');
      }
      return;
    }
    
    final entry = ReconnectionEntry(
      endpointId: endpointId,
      endpointName: endpointName,
      firstAttempt: DateTime.now(),
    );
    
    _reconnectionQueue[endpointId] = entry;
    
    if (kDebugMode) {
      print('➕ Added to reconnection queue: $endpointName ($endpointId)');
      print('   Queue size: ${_reconnectionQueue.length}');
    }
  }
  
  /// Remove an endpoint from the reconnection queue
  /// 
  /// This should be called when a reconnection succeeds or when
  /// the endpoint should no longer be reconnected.
  void removeFromQueue(String endpointId) {
    final entry = _reconnectionQueue.remove(endpointId);
    
    if (entry != null && kDebugMode) {
      print('➖ Removed from reconnection queue: ${entry.endpointName} ($endpointId)');
      print('   Queue size: ${_reconnectionQueue.length}');
    }
  }
  
  /// Start the periodic reconnection loop
  /// 
  /// This starts a timer that checks the reconnection queue every
  /// [timerIntervalSeconds] seconds and attempts reconnections for
  /// endpoints that are ready to retry.
  void startReconnectionLoop() {
    if (_reconnectionTimer != null && _reconnectionTimer!.isActive) {
      if (kDebugMode) {
        print('🔄 Reconnection loop already running');
      }
      return;
    }
    
    _reconnectionTimer = Timer.periodic(
      Duration(seconds: timerIntervalSeconds),
      (timer) async {
        await attemptReconnections();
      },
    );
    
    if (kDebugMode) {
      print('▶️  Started reconnection loop (interval: ${timerIntervalSeconds}s)');
    }
  }
  
  /// Stop the periodic reconnection loop
  void stopReconnectionLoop() {
    _reconnectionTimer?.cancel();
    _reconnectionTimer = null;
    
    if (kDebugMode) {
      print('⏸️  Stopped reconnection loop');
    }
  }
  
  /// Attempt reconnections for all eligible endpoints in the queue
  /// 
  /// This method is called periodically by the timer. It checks each
  /// endpoint in the queue and attempts reconnection if the backoff
  /// period has elapsed and the retry limit hasn't been reached.
  Future<void> attemptReconnections() async {
    if (_reconnectionQueue.isEmpty) {
      return;
    }
    
    final now = DateTime.now();
    final entriesToProcess = _reconnectionQueue.values.toList();
    
    for (final entry in entriesToProcess) {
      if (shouldAttemptReconnection(entry, now)) {
        await _attemptSingleReconnection(entry);
      }
    }
  }
  
  /// Check if a reconnection attempt should be made for an entry
  /// 
  /// Returns true if:
  /// - The entry hasn't exhausted its retry attempts
  /// - The backoff period has elapsed since the last attempt
  bool shouldAttemptReconnection(ReconnectionEntry entry, [DateTime? now]) {
    now ??= DateTime.now();
    
    // Check if exhausted
    if (entry.isExhausted) {
      if (kDebugMode) {
        print('⏭️  Entry exhausted: ${entry.endpointName} (${entry.attemptCount}/$maxRetries)');
      }
      return false;
    }
    
    // Check if enough time has passed
    if (now.isBefore(entry.nextAttemptTime)) {
      return false;
    }
    
    return true;
  }
  
  /// Attempt reconnection for a single entry
  Future<void> _attemptSingleReconnection(ReconnectionEntry entry) async {
    entry.incrementAttempt();
    
    if (kDebugMode) {
      print('🔄 Attempting reconnection: ${entry.endpointName}');
      print('   Attempt: ${entry.attemptCount}/$maxRetries');
      print('   Next attempt: ${entry.nextAttemptTime}');
    }
    
    // Notify callback that we're attempting reconnection
    onReconnectAttempt?.call(entry.endpointId);
    
    // Check if this was the last attempt
    if (entry.isExhausted) {
      if (kDebugMode) {
        print('❌ Reconnection attempts exhausted: ${entry.endpointName}');
      }
      
      // Remove from queue and notify
      removeFromQueue(entry.endpointId);
      onReconnectExhausted?.call(entry.endpointId);
    }
  }
  
  /// Get the current size of the reconnection queue
  int get queueSize => _reconnectionQueue.length;
  
  /// Get a list of all endpoint IDs in the queue
  List<String> get queuedEndpoints => _reconnectionQueue.keys.toList();
  
  /// Check if an endpoint is in the reconnection queue
  bool isInQueue(String endpointId) => _reconnectionQueue.containsKey(endpointId);
  
  /// Clear the entire reconnection queue
  void clearQueue() {
    _reconnectionQueue.clear();
    
    if (kDebugMode) {
      print('🧹 Cleared reconnection queue');
    }
  }
  
  /// Dispose of resources
  void dispose() {
    stopReconnectionLoop();
    clearQueue();
  }
  
  /// Get a reconnection entry for testing purposes
  /// This method is intended for testing only
  @visibleForTesting
  ReconnectionEntry? getEntryForTesting(String endpointId) {
    return _reconnectionQueue[endpointId];
  }
}
