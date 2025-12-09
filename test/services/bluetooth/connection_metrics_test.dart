import 'package:flutter_test/flutter_test.dart';
import 'package:bluetooth_hopping_app/services/bluetooth/connection_metrics.dart';
import 'package:bluetooth_hopping_app/services/bluetooth/models/bluetooth_constants.dart';
import 'dart:math';

void main() {
  group('ConnectionMetrics - Timeout Adaptation', () {
    late ConnectionMetrics metrics;

    setUp(() {
      metrics = ConnectionMetrics();
    });

    test('Low success rate (< 50%) increases timeout', () {
      // Requirements: 5.2
      // Arrange: Record 10 attempts with 40% success rate (4 success, 6 failures)
      for (int i = 0; i < 4; i++) {
        metrics.recordAttempt('endpoint_$i', true);
      }
      for (int i = 4; i < 10; i++) {
        metrics.recordAttempt('endpoint_$i', false, error: 'Connection failed');
      }

      // Act
      final successRate = metrics.calculateSuccessRate();
      final recommendedTimeout = metrics.getRecommendedTimeout();

      // Assert
      expect(successRate, equals(0.4));
      expect(successRate, lessThan(BluetoothConstants.lowSuccessThreshold));
      expect(recommendedTimeout, equals(BluetoothConstants.adaptiveTimeoutMax));
      expect(recommendedTimeout, equals(10000)); // Increased timeout
    });

    test('High success rate (> 80%) decreases timeout', () {
      // Requirements: 5.3
      // Arrange: Record 10 attempts with 90% success rate (9 success, 1 failure)
      for (int i = 0; i < 9; i++) {
        metrics.recordAttempt('endpoint_$i', true);
      }
      metrics.recordAttempt('endpoint_9', false, error: 'Connection failed');

      // Act
      final successRate = metrics.calculateSuccessRate();
      final recommendedTimeout = metrics.getRecommendedTimeout();

      // Assert
      expect(successRate, equals(0.9));
      expect(successRate, greaterThan(BluetoothConstants.highSuccessThreshold));
      expect(recommendedTimeout, equals(BluetoothConstants.adaptiveTimeoutMin));
      expect(recommendedTimeout, equals(5000)); // Decreased timeout
    });

    test('Medium success rate maintains current timeout', () {
      // Arrange: Record 10 attempts with 60% success rate (6 success, 4 failures)
      for (int i = 0; i < 6; i++) {
        metrics.recordAttempt('endpoint_$i', true);
      }
      for (int i = 6; i < 10; i++) {
        metrics.recordAttempt('endpoint_$i', false, error: 'Connection failed');
      }

      final initialTimeout = metrics.currentTimeout;

      // Act
      final successRate = metrics.calculateSuccessRate();
      final recommendedTimeout = metrics.getRecommendedTimeout();

      // Assert
      expect(successRate, equals(0.6));
      expect(successRate, greaterThanOrEqualTo(BluetoothConstants.lowSuccessThreshold));
      expect(successRate, lessThanOrEqualTo(BluetoothConstants.highSuccessThreshold));
      expect(recommendedTimeout, equals(initialTimeout));
    });

    test('updateTimeout() adjusts current timeout based on success rate', () {
      // Arrange: Start with default timeout
      expect(metrics.currentTimeout, equals(BluetoothConstants.adaptiveTimeoutMin));

      // Record low success rate
      for (int i = 0; i < 3; i++) {
        metrics.recordAttempt('endpoint_$i', true);
      }
      for (int i = 3; i < 10; i++) {
        metrics.recordAttempt('endpoint_$i', false, error: 'Connection failed');
      }

      // Act
      metrics.updateTimeout();

      // Assert
      expect(metrics.currentTimeout, equals(BluetoothConstants.adaptiveTimeoutMax));
    });

    test('Empty attempts default to 100% success rate', () {
      // Arrange: No attempts recorded

      // Act
      final successRate = metrics.calculateSuccessRate();
      final recommendedTimeout = metrics.getRecommendedTimeout();

      // Assert
      expect(successRate, equals(1.0));
      expect(recommendedTimeout, equals(BluetoothConstants.adaptiveTimeoutMin));
    });
  });

  group('ConnectionMetrics - Property Tests', () {
    late ConnectionMetrics metrics;

    setUp(() {
      metrics = ConnectionMetrics();
    });

    test('Property 15: Connection attempts are recorded - Feature: bluetooth-enhancement', () {
      // **Feature: bluetooth-enhancement, Property 15: Connection attempts are recorded**
      // **Validates: Requirements 5.1**
      // Property: For any connection attempt (success or failure), 
      // the system should record the outcome in the metrics tracker.
      
      final random = Random();
      const iterations = 100;

      for (int i = 0; i < iterations; i++) {
        // Generate random connection attempt data
        final endpointId = 'endpoint_${random.nextInt(1000)}';
        final success = random.nextBool();
        final error = success ? null : 'Error_${random.nextInt(100)}';
        
        // Record the initial state
        final initialCount = metrics.recentAttempts.length;
        
        // Act: Record the attempt
        metrics.recordAttempt(endpointId, success, error: error);
        
        // Assert: The attempt should be recorded
        final newCount = metrics.recentAttempts.length;
        
        // The count should increase by 1, unless we're at the window size limit
        if (initialCount < BluetoothConstants.metricsWindowSize) {
          expect(newCount, equals(initialCount + 1),
              reason: 'Attempt $i: Recording should increase count when below window size');
        } else {
          expect(newCount, equals(BluetoothConstants.metricsWindowSize),
              reason: 'Attempt $i: Recording should maintain window size when at limit');
        }
        
        // The most recent attempt should match what we recorded
        final lastAttempt = metrics.recentAttempts.last;
        expect(lastAttempt.endpointId, equals(endpointId),
            reason: 'Attempt $i: Endpoint ID should match');
        expect(lastAttempt.success, equals(success),
            reason: 'Attempt $i: Success status should match');
        expect(lastAttempt.errorMessage, equals(error),
            reason: 'Attempt $i: Error message should match');
        expect(lastAttempt.timestamp, isNotNull,
            reason: 'Attempt $i: Timestamp should be recorded');
      }
    });

    test('Property 23: State changes trigger logging - Feature: bluetooth-enhancement', () {
      // **Feature: bluetooth-enhancement, Property 23: State changes trigger logging**
      // **Validates: Requirements 8.1**
      // Property: For any connection state change, the system should log 
      // the endpoint ID, new state, and timestamp.
      
      final random = Random();
      const iterations = 100;
      
      // Define possible state change event types
      final stateChangeTypes = ['discovered', 'connected', 'disconnected', 'failed'];

      for (int i = 0; i < iterations; i++) {
        // Generate random state change data
        final endpointId = 'endpoint_${random.nextInt(1000)}';
        final eventType = stateChangeTypes[random.nextInt(stateChangeTypes.length)];
        final metadata = {
          'signal': random.nextInt(100),
          'reason': 'test_reason_${random.nextInt(10)}',
          'iteration': i,
        };
        
        // Record the time before the event
        final beforeTime = DateTime.now();
        
        // Act: Record the state change event
        metrics.recordEvent(endpointId, eventType, metadata);
        
        // Record the time after the event
        final afterTime = DateTime.now();
        
        // Assert: The event should be logged with all required fields
        final events = metrics.getRecentEvents();
        
        // Find the event we just recorded
        final recordedEvent = events.firstWhere(
          (e) => e.endpointId == endpointId && e.eventType == eventType,
          orElse: () => throw Exception('Event not found for iteration $i'),
        );
        
        // Verify endpoint ID is logged
        expect(recordedEvent.endpointId, equals(endpointId),
            reason: 'Iteration $i: Endpoint ID should be logged');
        
        // Verify state (eventType) is logged
        expect(recordedEvent.eventType, equals(eventType),
            reason: 'Iteration $i: Event type (state) should be logged');
        
        // Verify timestamp is logged and is reasonable
        expect(recordedEvent.timestamp, isNotNull,
            reason: 'Iteration $i: Timestamp should be logged');
        expect(recordedEvent.timestamp.isAfter(beforeTime.subtract(Duration(seconds: 1))),
            isTrue,
            reason: 'Iteration $i: Timestamp should be after or near the event time');
        expect(recordedEvent.timestamp.isBefore(afterTime.add(Duration(seconds: 1))),
            isTrue,
            reason: 'Iteration $i: Timestamp should be before or near the event time');
        
        // Verify metadata is preserved
        expect(recordedEvent.metadata, isNotNull,
            reason: 'Iteration $i: Metadata should be logged');
        expect(recordedEvent.metadata['iteration'], equals(i),
            reason: 'Iteration $i: Metadata should be preserved');
      }
    });
  });

  group('ConnectionMetrics - Success Rate Calculation', () {
    late ConnectionMetrics metrics;

    setUp(() {
      metrics = ConnectionMetrics();
    });

    test('calculateSuccessRate() with empty list returns 1.0', () {
      // Requirements: 5.1
      // Arrange: No attempts recorded

      // Act
      final successRate = metrics.calculateSuccessRate();

      // Assert
      expect(successRate, equals(1.0));
    });

    test('calculateSuccessRate() with all successes returns 1.0', () {
      // Requirements: 5.1
      // Arrange: Record 10 successful attempts
      for (int i = 0; i < 10; i++) {
        metrics.recordAttempt('endpoint_$i', true);
      }

      // Act
      final successRate = metrics.calculateSuccessRate();

      // Assert
      expect(successRate, equals(1.0));
      expect(metrics.recentAttempts.length, equals(10));
    });

    test('calculateSuccessRate() with all failures returns 0.0', () {
      // Requirements: 5.1
      // Arrange: Record 10 failed attempts
      for (int i = 0; i < 10; i++) {
        metrics.recordAttempt('endpoint_$i', false, error: 'Connection failed');
      }

      // Act
      final successRate = metrics.calculateSuccessRate();

      // Assert
      expect(successRate, equals(0.0));
      expect(metrics.recentAttempts.length, equals(10));
    });

    test('calculateSuccessRate() with 50% success pattern returns 0.5', () {
      // Requirements: 5.1
      // Arrange: Record alternating success/failure pattern
      for (int i = 0; i < 10; i++) {
        if (i % 2 == 0) {
          metrics.recordAttempt('endpoint_$i', true);
        } else {
          metrics.recordAttempt('endpoint_$i', false, error: 'Failed');
        }
      }

      // Act
      final successRate = metrics.calculateSuccessRate();

      // Assert
      expect(successRate, equals(0.5));
    });

    test('calculateSuccessRate() with 70% success pattern returns 0.7', () {
      // Requirements: 5.1
      // Arrange: Record 7 successes and 3 failures
      for (int i = 0; i < 7; i++) {
        metrics.recordAttempt('endpoint_$i', true);
      }
      for (int i = 7; i < 10; i++) {
        metrics.recordAttempt('endpoint_$i', false, error: 'Failed');
      }

      // Act
      final successRate = metrics.calculateSuccessRate();

      // Assert
      expect(successRate, equals(0.7));
    });

    test('calculateSuccessRate() with 30% success pattern returns 0.3', () {
      // Requirements: 5.1
      // Arrange: Record 3 successes and 7 failures
      for (int i = 0; i < 3; i++) {
        metrics.recordAttempt('endpoint_$i', true);
      }
      for (int i = 3; i < 10; i++) {
        metrics.recordAttempt('endpoint_$i', false, error: 'Failed');
      }

      // Act
      final successRate = metrics.calculateSuccessRate();

      // Assert
      expect(successRate, equals(0.3));
    });

    test('calculateSuccessRate() with single success returns 1.0', () {
      // Requirements: 5.1
      // Arrange: Record only one successful attempt
      metrics.recordAttempt('endpoint_1', true);

      // Act
      final successRate = metrics.calculateSuccessRate();

      // Assert
      expect(successRate, equals(1.0));
      expect(metrics.recentAttempts.length, equals(1));
    });

    test('calculateSuccessRate() with single failure returns 0.0', () {
      // Requirements: 5.1
      // Arrange: Record only one failed attempt
      metrics.recordAttempt('endpoint_1', false, error: 'Failed');

      // Act
      final successRate = metrics.calculateSuccessRate();

      // Assert
      expect(successRate, equals(0.0));
      expect(metrics.recentAttempts.length, equals(1));
    });

    test('calculateSuccessRate() respects sliding window of 10 attempts', () {
      // Requirements: 5.1
      // Arrange: Record 15 attempts (5 failures, then 10 successes)
      // The first 5 failures should be removed from the window
      for (int i = 0; i < 5; i++) {
        metrics.recordAttempt('endpoint_$i', false, error: 'Failed');
      }
      for (int i = 5; i < 15; i++) {
        metrics.recordAttempt('endpoint_$i', true);
      }

      // Act
      final successRate = metrics.calculateSuccessRate();

      // Assert
      expect(metrics.recentAttempts.length, equals(10));
      expect(successRate, equals(1.0)); // Only the last 10 (all successes) are counted
    });

    test('calculateSuccessRate() updates as new attempts are added', () {
      // Requirements: 5.1
      // Arrange & Act: Start with failures, then add successes
      for (int i = 0; i < 5; i++) {
        metrics.recordAttempt('endpoint_$i', false, error: 'Failed');
      }
      
      double rate1 = metrics.calculateSuccessRate();
      expect(rate1, equals(0.0));

      for (int i = 5; i < 10; i++) {
        metrics.recordAttempt('endpoint_$i', true);
      }
      
      double rate2 = metrics.calculateSuccessRate();
      expect(rate2, equals(0.5));

      for (int i = 10; i < 15; i++) {
        metrics.recordAttempt('endpoint_$i', true);
      }
      
      double rate3 = metrics.calculateSuccessRate();
      expect(rate3, equals(1.0)); // Last 10 are all successes
    });

    test('calculateSuccessRate() with clustered failures at start', () {
      // Requirements: 5.1
      // Arrange: 8 failures followed by 2 successes
      for (int i = 0; i < 8; i++) {
        metrics.recordAttempt('endpoint_$i', false, error: 'Failed');
      }
      for (int i = 8; i < 10; i++) {
        metrics.recordAttempt('endpoint_$i', true);
      }

      // Act
      final successRate = metrics.calculateSuccessRate();

      // Assert
      expect(successRate, equals(0.2));
    });

    test('calculateSuccessRate() with clustered failures at end', () {
      // Requirements: 5.1
      // Arrange: 2 successes followed by 8 failures
      for (int i = 0; i < 2; i++) {
        metrics.recordAttempt('endpoint_$i', true);
      }
      for (int i = 2; i < 10; i++) {
        metrics.recordAttempt('endpoint_$i', false, error: 'Failed');
      }

      // Act
      final successRate = metrics.calculateSuccessRate();

      // Assert
      expect(successRate, equals(0.2));
    });
  });

  group('ConnectionMetrics - Basic Functionality', () {
    late ConnectionMetrics metrics;

    setUp(() {
      metrics = ConnectionMetrics();
    });

    test('recordAttempt() stores connection outcomes', () {
      // Arrange & Act
      metrics.recordAttempt('endpoint_1', true);
      metrics.recordAttempt('endpoint_2', false, error: 'Timeout');

      // Assert
      expect(metrics.recentAttempts.length, equals(2));
      expect(metrics.recentAttempts[0].success, isTrue);
      expect(metrics.recentAttempts[1].success, isFalse);
      expect(metrics.recentAttempts[1].errorMessage, equals('Timeout'));
    });

    test('recordAttempt() maintains sliding window', () {
      // Arrange & Act: Record more than window size
      for (int i = 0; i < 15; i++) {
        metrics.recordAttempt('endpoint_$i', true);
      }

      // Assert: Should only keep last 10 (window size)
      expect(metrics.recentAttempts.length, equals(BluetoothConstants.metricsWindowSize));
      expect(metrics.recentAttempts.length, equals(10));
    });

    test('recordEvent() stores connection events', () {
      // Arrange & Act
      metrics.recordEvent('endpoint_1', 'connected', {'signal': 'strong'});
      metrics.recordEvent('endpoint_2', 'disconnected', {'reason': 'timeout'});

      // Assert
      final events = metrics.getRecentEvents();
      expect(events.length, equals(2));
      expect(events.any((e) => e.eventType == 'connected'), isTrue);
      expect(events.any((e) => e.eventType == 'disconnected'), isTrue);
    });

    test('getStatistics() returns comprehensive metrics', () {
      // Arrange
      metrics.recordAttempt('endpoint_1', true);
      metrics.recordAttempt('endpoint_2', true);
      metrics.recordAttempt('endpoint_3', false, error: 'Failed');

      // Act
      final stats = metrics.getStatistics();

      // Assert
      expect(stats['totalAttempts'], equals(3));
      expect(stats['successfulAttempts'], equals(2));
      expect(stats['failedAttempts'], equals(1));
      expect(stats['successRate'], closeTo(0.667, 0.01));
      expect(stats['currentTimeout'], isNotNull);
      expect(stats['recommendedTimeout'], isNotNull);
    });

    test('clear() resets all metrics', () {
      // Arrange
      metrics.recordAttempt('endpoint_1', true);
      metrics.recordEvent('endpoint_1', 'connected', {});
      metrics.updateTimeout();

      // Act
      metrics.clear();

      // Assert
      expect(metrics.recentAttempts.length, equals(0));
      expect(metrics.getRecentEvents().length, equals(0));
      expect(metrics.currentTimeout, equals(BluetoothConstants.adaptiveTimeoutMin));
    });
  });
}
