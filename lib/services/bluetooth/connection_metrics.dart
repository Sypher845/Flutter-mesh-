import 'models/connection_attempt.dart';
import 'models/connection_event.dart';
import 'models/bluetooth_constants.dart';

/// Manages connection metrics and adaptive timeout strategy
class ConnectionMetrics {
  final List<ConnectionAttempt> _recentAttempts = [];
  final Map<String, ConnectionEvent> _eventLog = {};
  int _currentTimeout = BluetoothConstants.adaptiveTimeoutMin;

  /// Record a connection attempt outcome
  void recordAttempt(String endpointId, bool success, {String? error}) {
    final attempt = ConnectionAttempt(
      endpointId: endpointId,
      timestamp: DateTime.now(),
      success: success,
      errorMessage: error,
    );

    _recentAttempts.add(attempt);

    // Keep only the most recent attempts based on window size
    if (_recentAttempts.length > BluetoothConstants.metricsWindowSize) {
      _recentAttempts.removeAt(0);
    }
  }

  /// Record a connection event for detailed logging
  void recordEvent(String endpointId, String eventType, Map<String, dynamic> metadata) {
    final event = ConnectionEvent(
      endpointId: endpointId,
      eventType: eventType,
      timestamp: DateTime.now(),
      metadata: metadata,
    );

    _eventLog[endpointId] = event;
  }

  /// Calculate success rate from recent attempts
  double calculateSuccessRate() {
    if (_recentAttempts.isEmpty) {
      return 1.0; // Default to 100% if no attempts yet
    }

    final successCount = _recentAttempts.where((attempt) => attempt.success).length;
    return successCount / _recentAttempts.length;
  }

  /// Get recommended timeout based on success rate
  int getRecommendedTimeout() {
    final successRate = calculateSuccessRate();

    if (successRate < BluetoothConstants.lowSuccessThreshold) {
      // Low success rate: increase timeout
      return BluetoothConstants.adaptiveTimeoutMax;
    } else if (successRate > BluetoothConstants.highSuccessThreshold) {
      // High success rate: decrease timeout
      return BluetoothConstants.adaptiveTimeoutMin;
    } else {
      // Medium success rate: keep current timeout
      return _currentTimeout;
    }
  }

  /// Update the current timeout based on success rate
  void updateTimeout() {
    _currentTimeout = getRecommendedTimeout();
  }

  /// Get recent events with optional limit
  List<ConnectionEvent> getRecentEvents({int limit = 50}) {
    final events = _eventLog.values.toList();
    events.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    
    if (events.length <= limit) {
      return events;
    }
    
    return events.sublist(0, limit);
  }

  /// Get statistics for debugging
  Map<String, dynamic> getStatistics() {
    final successRate = calculateSuccessRate();
    final totalAttempts = _recentAttempts.length;
    final successfulAttempts = _recentAttempts.where((a) => a.success).length;
    final failedAttempts = totalAttempts - successfulAttempts;

    return {
      'currentTimeout': _currentTimeout,
      'successRate': successRate,
      'totalAttempts': totalAttempts,
      'successfulAttempts': successfulAttempts,
      'failedAttempts': failedAttempts,
      'recommendedTimeout': getRecommendedTimeout(),
      'totalEvents': _eventLog.length,
    };
  }

  /// Get current timeout value
  int get currentTimeout => _currentTimeout;

  /// Get all recent attempts
  List<ConnectionAttempt> get recentAttempts => List.unmodifiable(_recentAttempts);

  /// Clear all metrics (useful for testing)
  void clear() {
    _recentAttempts.clear();
    _eventLog.clear();
    _currentTimeout = BluetoothConstants.adaptiveTimeoutMin;
  }

  /// Log connection quality degradation with signal strength
  /// 
  /// Requirement 1.4: Log signal strength metrics when connection quality degrades
  void logConnectionQualityDegradation(
    String endpointId,
    int? signalStrength,
    String qualityLevel,
  ) {
    recordEvent(
      endpointId,
      'quality_degradation',
      {
        'timestamp': DateTime.now().toIso8601String(),
        'signal_strength': signalStrength,
        'quality_level': qualityLevel,
      },
    );
  }

  /// Get detailed metrics for debug mode
  /// 
  /// Requirement 8.5: Provide detailed connection metrics in debug mode
  Map<String, dynamic> getDetailedMetrics() {
    final stats = getStatistics();
    
    // Add detailed per-endpoint metrics
    final endpointMetrics = <String, Map<String, dynamic>>{};
    for (final event in _eventLog.values) {
      if (!endpointMetrics.containsKey(event.endpointId)) {
        endpointMetrics[event.endpointId] = {
          'events': <Map<String, dynamic>>[],
          'last_event_type': null,
          'last_event_time': null,
        };
      }
      
      endpointMetrics[event.endpointId]!['events'].add({
        'type': event.eventType,
        'timestamp': event.timestamp.toIso8601String(),
        'metadata': event.metadata,
      });
      
      endpointMetrics[event.endpointId]!['last_event_type'] = event.eventType;
      endpointMetrics[event.endpointId]!['last_event_time'] = event.timestamp.toIso8601String();
    }
    
    // Add attempt details
    final attemptDetails = _recentAttempts.map((attempt) => {
      'endpoint_id': attempt.endpointId,
      'timestamp': attempt.timestamp.toIso8601String(),
      'success': attempt.success,
      'error': attempt.errorMessage,
    }).toList();
    
    return {
      ...stats,
      'endpoint_metrics': endpointMetrics,
      'attempt_details': attemptDetails,
      'event_count_by_type': _getEventCountByType(),
    };
  }

  /// Get count of events by type for debugging
  Map<String, int> _getEventCountByType() {
    final counts = <String, int>{};
    for (final event in _eventLog.values) {
      counts[event.eventType] = (counts[event.eventType] ?? 0) + 1;
    }
    return counts;
  }
}
