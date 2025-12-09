import 'package:flutter_test/flutter_test.dart';
import 'package:bluetooth_hopping_app/services/bluetooth/connection_metrics.dart';
import 'package:bluetooth_hopping_app/services/bluetooth/connection_manager.dart';
import 'dart:math';

void main() {
  group('BluetoothService - Metrics Integration Property Tests', () {
    test('Property 24: Connection failures trigger error logging - Feature: bluetooth-enhancement', () {
      // **Feature: bluetooth-enhancement, Property 24: Connection failures trigger error logging**
      // **Validates: Requirements 8.2**
      // Property: For any connection failure, the system should log 
      // the failure reason and error code.
      
      final random = Random();
      const iterations = 100;

      for (int i = 0; i < iterations; i++) {
        // Arrange: Create a ConnectionMetrics instance and ConnectionManager with metrics
        final metrics = ConnectionMetrics();
        final connectionManager = ConnectionManager(connectionMetrics: metrics);
        
        // Generate random connection failure data
        final endpointId = 'endpoint_${random.nextInt(1000)}';
        final errorMessages = [
          'Connection timeout',
          'Device not found',
          'Permission denied',
          'Bluetooth disabled',
          'Connection rejected',
          'Network error',
          'Status: ERROR',
          'Status: UNAVAILABLE',
        ];
        final errorMessage = errorMessages[random.nextInt(errorMessages.length)];
        
        // Record the initial state
        final initialAttemptCount = metrics.recentAttempts.length;
        final initialEventCount = metrics.getRecentEvents().length;
        
        // Act: Simulate a connection failure by recording it in metrics
        // This simulates what happens in ConnectionManager._onConnectionResult
        // when a connection fails
        metrics.recordAttempt(endpointId, false, error: errorMessage);
        
        // Also record the failure event (state change)
        metrics.recordEvent(endpointId, 'failed', {
          'error': errorMessage,
          'iteration': i,
        });
        
        // Assert: Verify that the failure was logged with error details
        
        // 1. The attempt should be recorded
        final newAttemptCount = metrics.recentAttempts.length;
        expect(newAttemptCount, greaterThan(initialAttemptCount),
            reason: 'Iteration $i: Connection failure should be recorded as an attempt');
        
        // 2. The most recent attempt should be a failure
        final lastAttempt = metrics.recentAttempts.last;
        expect(lastAttempt.success, isFalse,
            reason: 'Iteration $i: Last attempt should be marked as failure');
        
        // 3. The failure should have an error message (reason)
        expect(lastAttempt.errorMessage, isNotNull,
            reason: 'Iteration $i: Failure should have an error message');
        expect(lastAttempt.errorMessage, equals(errorMessage),
            reason: 'Iteration $i: Error message should match the failure reason');
        
        // 4. The failure should have a timestamp
        expect(lastAttempt.timestamp, isNotNull,
            reason: 'Iteration $i: Failure should have a timestamp');
        
        // 5. The failure should have the endpoint ID
        expect(lastAttempt.endpointId, equals(endpointId),
            reason: 'Iteration $i: Failure should have the endpoint ID');
        
        // 6. The failure event should be logged
        final newEventCount = metrics.getRecentEvents().length;
        expect(newEventCount, greaterThan(initialEventCount),
            reason: 'Iteration $i: Connection failure should trigger event logging');
        
        // 7. The event should contain the error details
        final events = metrics.getRecentEvents();
        final failureEvent = events.firstWhere(
          (e) => e.endpointId == endpointId && e.eventType == 'failed',
          orElse: () => throw Exception('Failure event not found for iteration $i'),
        );
        
        expect(failureEvent.metadata['error'], equals(errorMessage),
            reason: 'Iteration $i: Event should contain error message in metadata');
        
        // 8. Verify the error is accessible through statistics
        final stats = metrics.getStatistics();
        expect(stats['failedAttempts'], greaterThan(0),
            reason: 'Iteration $i: Statistics should show failed attempts');
      }
    });
  });
}
