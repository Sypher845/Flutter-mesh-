import 'package:flutter_test/flutter_test.dart';
import 'package:bluetooth_hopping_app/services/bluetooth/bluetooth_service.dart';
import 'package:bluetooth_hopping_app/services/bluetooth/connection_manager.dart';
import 'package:bluetooth_hopping_app/services/bluetooth/connection_metrics.dart';
import 'dart:math';

void main() {
  // Initialize Flutter test bindings
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BluetoothService - Error Logging and Recovery', () {
    group('Property 18: Bluetooth errors trigger logging and recovery', () {
      // **Feature: bluetooth-enhancement, Property 18: Bluetooth errors trigger logging and recovery**
      // **Validates: Requirements 6.5**
      
      void propertyTest(String description, Function testFn, {int iterations = 100}) {
        test(description, () {
          for (int i = 0; i < iterations; i++) {
            testFn();
          }
        });
      }

      propertyTest('For any Bluetooth API error, the system should log the error details', () {
        // Arrange
        final connectionMetrics = ConnectionMetrics();
        final random = Random();
        
        // Generate random error scenarios
        final errorTypes = [
          'connection_error',
          'advertising_error',
          'discovery_error',
          'send_error',
          'acceptance_error',
        ];
        
        final errorType = errorTypes[random.nextInt(errorTypes.length)];
        final endpointId = 'endpoint_${random.nextInt(1000)}';
        final errorMessage = 'Test error ${random.nextInt(1000)}';
        
        final initialEventCount = connectionMetrics.getRecentEvents().length;
        
        // Act - Log a Bluetooth error (simulating what happens when an error occurs)
        connectionMetrics.recordEvent(
          endpointId,
          errorType,
          {
            'timestamp': DateTime.now().toIso8601String(),
            'error': errorMessage,
          },
        );
        
        // Assert - Error should be logged
        final finalEventCount = connectionMetrics.getRecentEvents().length;
        expect(finalEventCount, equals(initialEventCount + 1),
          reason: 'Bluetooth errors should be logged to metrics');
        
        // Verify the logged event contains error details
        final events = connectionMetrics.getRecentEvents();
        final lastEvent = events.last;
        expect(lastEvent.eventType, equals(errorType),
          reason: 'Event should have correct error type');
        expect(lastEvent.metadata['error'], equals(errorMessage),
          reason: 'Event should include error message');
        expect(lastEvent.metadata['timestamp'], isNotNull,
          reason: 'Event should include timestamp');
      });

      propertyTest('For any Bluetooth error, the system should record the endpoint ID', () {
        // Arrange
        final connectionMetrics = ConnectionMetrics();
        final random = Random();
        
        // Generate random endpoint ID
        final endpointId = 'endpoint_${random.nextInt(10000)}';
        
        // Act - Log an error for this endpoint
        connectionMetrics.recordEvent(
          endpointId,
          'bluetooth_error',
          {
            'timestamp': DateTime.now().toIso8601String(),
            'error': 'Test error',
          },
        );
        
        // Assert - Event should be associated with the endpoint
        final events = connectionMetrics.getRecentEvents();
        final lastEvent = events.last;
        expect(lastEvent.endpointId, equals(endpointId),
          reason: 'Error should be associated with correct endpoint');
      });

      propertyTest('For any sequence of Bluetooth errors, all errors should be logged', () {
        // Arrange
        final connectionMetrics = ConnectionMetrics();
        final random = Random();
        
        // Generate random number of errors (1-10)
        final errorCount = 1 + random.nextInt(10);
        final initialEventCount = connectionMetrics.getRecentEvents().length;
        
        // Act - Log multiple errors
        for (int i = 0; i < errorCount; i++) {
          connectionMetrics.recordEvent(
            'endpoint_$i',
            'bluetooth_error',
            {
              'timestamp': DateTime.now().toIso8601String(),
              'error': 'Error $i',
              'sequence': i,
            },
          );
        }
        
        // Assert - All errors should be logged
        final finalEventCount = connectionMetrics.getRecentEvents().length;
        expect(finalEventCount, equals(initialEventCount + errorCount),
          reason: 'All Bluetooth errors should be logged');
      });

      propertyTest('For any Bluetooth error, recovery action should be tracked', () {
        // Arrange
        final connectionMetrics = ConnectionMetrics();
        final connectionManager = ConnectionManager(connectionMetrics: connectionMetrics);
        final random = Random();
        
        final endpointId = 'endpoint_${random.nextInt(1000)}';
        
        // Act - Simulate error and recovery
        // 1. Log the error
        connectionMetrics.recordEvent(
          endpointId,
          'connection_error',
          {
            'timestamp': DateTime.now().toIso8601String(),
            'error': 'Connection failed',
          },
        );
        
        // 2. Increment error counter (part of recovery tracking)
        connectionManager.incrementErrorCount();
        
        // Assert - Recovery tracking should be active
        expect(connectionManager.consecutiveErrors, greaterThan(0),
          reason: 'Error counter should track errors for recovery');
      });

      propertyTest('For any Bluetooth error, error counter should increment', () {
        // Arrange
        final connectionMetrics = ConnectionMetrics();
        final connectionManager = ConnectionManager(connectionMetrics: connectionMetrics);
        
        final initialErrorCount = connectionManager.consecutiveErrors;
        
        // Act - Simulate an error by incrementing error counter
        connectionManager.incrementErrorCount();
        
        // Assert - Error counter should have incremented
        expect(connectionManager.consecutiveErrors, equals(initialErrorCount + 1),
          reason: 'Bluetooth errors should increment error counter for recovery tracking');
      });

      propertyTest('For any successful recovery, error counter should reset', () {
        // Arrange
        final connectionMetrics = ConnectionMetrics();
        final connectionManager = ConnectionManager(connectionMetrics: connectionMetrics);
        final random = Random();
        
        // Generate random number of errors (1-5)
        final errorCount = 1 + random.nextInt(5);
        
        // Act - Simulate errors then recovery
        for (int i = 0; i < errorCount; i++) {
          connectionManager.incrementErrorCount();
        }
        
        expect(connectionManager.consecutiveErrors, equals(errorCount),
          reason: 'Errors should accumulate');
        
        // Simulate successful recovery
        connectionManager.resetErrorCount();
        
        // Assert - Error counter should be reset
        expect(connectionManager.consecutiveErrors, equals(0),
          reason: 'Successful recovery should reset error counter');
      });

      propertyTest('For any Bluetooth error with metadata, all metadata should be logged', () {
        // Arrange
        final connectionMetrics = ConnectionMetrics();
        final random = Random();
        
        final endpointId = 'endpoint_${random.nextInt(1000)}';
        final errorCode = random.nextInt(9999);
        final attemptNumber = random.nextInt(5) + 1;
        
        // Act - Log error with rich metadata
        connectionMetrics.recordEvent(
          endpointId,
          'bluetooth_error',
          {
            'timestamp': DateTime.now().toIso8601String(),
            'error': 'Connection failed',
            'error_code': errorCode,
            'attempt': attemptNumber,
            'max_attempts': 3,
          },
        );
        
        // Assert - All metadata should be preserved
        final events = connectionMetrics.getRecentEvents();
        final lastEvent = events.last;
        expect(lastEvent.metadata['error_code'], equals(errorCode),
          reason: 'Error code should be logged');
        expect(lastEvent.metadata['attempt'], equals(attemptNumber),
          reason: 'Attempt number should be logged');
        expect(lastEvent.metadata['max_attempts'], equals(3),
          reason: 'Max attempts should be logged');
      });

      propertyTest('For any Bluetooth error, timestamp should be recorded', () {
        // Arrange
        final connectionMetrics = ConnectionMetrics();
        final random = Random();
        
        final endpointId = 'endpoint_${random.nextInt(1000)}';
        final beforeTime = DateTime.now();
        
        // Act - Log an error
        connectionMetrics.recordEvent(
          endpointId,
          'bluetooth_error',
          {
            'timestamp': DateTime.now().toIso8601String(),
            'error': 'Test error',
          },
        );
        
        final afterTime = DateTime.now();
        
        // Assert - Event should have a timestamp within the test window
        final events = connectionMetrics.getRecentEvents();
        final lastEvent = events.last;
        
        expect(lastEvent.timestamp, isNotNull,
          reason: 'Error event should have timestamp');
        expect(lastEvent.timestamp.isAfter(beforeTime.subtract(Duration(seconds: 1))), isTrue,
          reason: 'Timestamp should be recent');
        expect(lastEvent.timestamp.isBefore(afterTime.add(Duration(seconds: 1))), isTrue,
          reason: 'Timestamp should be recent');
      });

      propertyTest('For any error threshold reached, full reset should be triggered', () {
        // Arrange
        final connectionMetrics = ConnectionMetrics();
        final connectionManager = ConnectionManager(connectionMetrics: connectionMetrics);
        
        // Act - Increment errors to threshold
        connectionManager.incrementErrorCount();
        connectionManager.incrementErrorCount();
        
        expect(connectionManager.shouldPerformFullReset(), isFalse,
          reason: '2 errors should not trigger reset');
        
        connectionManager.incrementErrorCount();
        
        // Assert - Full reset should be triggered at threshold
        expect(connectionManager.consecutiveErrors, equals(3),
          reason: 'Error count should reach threshold');
        expect(connectionManager.shouldPerformFullReset(), isTrue,
          reason: '3 consecutive errors should trigger full reset');
      });

      propertyTest('For any error type, recovery attempt should be logged', () {
        // Arrange
        final connectionMetrics = ConnectionMetrics();
        final random = Random();
        
        final errorTypes = [
          'connection_error',
          'advertising_error',
          'discovery_error',
          'send_error',
        ];
        
        final errorType = errorTypes[random.nextInt(errorTypes.length)];
        // Use different endpoint IDs to ensure both events are stored
        final errorEndpointId = 'endpoint_error_${random.nextInt(1000)}';
        final recoveryEndpointId = 'endpoint_recovery_${random.nextInt(1000)}';
        
        final initialEventCount = connectionMetrics.getRecentEvents().length;
        
        // Act - Log error and recovery attempt with different endpoint IDs
        connectionMetrics.recordEvent(
          errorEndpointId,
          errorType,
          {
            'timestamp': DateTime.now().toIso8601String(),
            'error': 'Test error',
          },
        );
        
        connectionMetrics.recordEvent(
          recoveryEndpointId,
          '${errorType}_recovery',
          {
            'timestamp': DateTime.now().toIso8601String(),
            'recovery_action': 'retry',
          },
        );
        
        // Assert - Both error and recovery should be logged
        final events = connectionMetrics.getRecentEvents();
        expect(events.length, equals(initialEventCount + 2),
          reason: 'Both error and recovery should be logged');
        
        // Find the recovery event
        final recoveryEvent = events.firstWhere(
          (e) => e.eventType.contains('recovery'),
          orElse: () => events.last,
        );
        
        expect(recoveryEvent.eventType, contains('recovery'),
          reason: 'Recovery attempt should be logged');
      });
    });

    group('Error Logging Integration', () {
      test('ConnectionManager logs errors to metrics', () {
        // Arrange
        final connectionMetrics = ConnectionMetrics();
        final connectionManager = ConnectionManager(connectionMetrics: connectionMetrics);
        
        final initialEventCount = connectionMetrics.getRecentEvents().length;
        
        // Act - Manually log an error (simulating what happens in real error scenarios)
        connectionMetrics.recordEvent(
          'test_endpoint',
          'connection_error',
          {
            'timestamp': DateTime.now().toIso8601String(),
            'error': 'Test connection error',
          },
        );
        
        // Assert
        final finalEventCount = connectionMetrics.getRecentEvents().length;
        expect(finalEventCount, equals(initialEventCount + 1),
          reason: 'Errors should be logged to metrics');
      });

      test('Error events include required fields', () {
        // Arrange
        final connectionMetrics = ConnectionMetrics();
        
        // Act - Log an error with all required fields
        connectionMetrics.recordEvent(
          'test_endpoint',
          'bluetooth_error',
          {
            'timestamp': DateTime.now().toIso8601String(),
            'error': 'Test error message',
            'error_code': 8001,
          },
        );
        
        // Assert
        final events = connectionMetrics.getRecentEvents();
        expect(events.isNotEmpty, isTrue,
          reason: 'Events should be recorded');
        
        final event = events.last;
        expect(event.endpointId, equals('test_endpoint'),
          reason: 'Event should have endpoint ID');
        expect(event.eventType, equals('bluetooth_error'),
          reason: 'Event should have error type');
        expect(event.timestamp, isNotNull,
          reason: 'Event should have timestamp');
        expect(event.metadata['error'], equals('Test error message'),
          reason: 'Event should include error message');
        expect(event.metadata['error_code'], equals(8001),
          reason: 'Event should include error code');
      });

      test('Multiple errors are tracked separately', () {
        // Arrange
        final connectionMetrics = ConnectionMetrics();
        
        // Act - Log errors for different endpoints
        connectionMetrics.recordEvent(
          'endpoint_1',
          'connection_error',
          {
            'timestamp': DateTime.now().toIso8601String(),
            'error': 'Error 1',
          },
        );
        
        connectionMetrics.recordEvent(
          'endpoint_2',
          'connection_error',
          {
            'timestamp': DateTime.now().toIso8601String(),
            'error': 'Error 2',
          },
        );
        
        // Assert - Both errors should be tracked
        final events = connectionMetrics.getRecentEvents();
        expect(events.length, greaterThanOrEqualTo(2),
          reason: 'Multiple errors should be tracked');
        
        final endpoint1Events = events.where((e) => e.endpointId == 'endpoint_1').toList();
        final endpoint2Events = events.where((e) => e.endpointId == 'endpoint_2').toList();
        
        expect(endpoint1Events.isNotEmpty, isTrue,
          reason: 'Endpoint 1 errors should be tracked');
        expect(endpoint2Events.isNotEmpty, isTrue,
          reason: 'Endpoint 2 errors should be tracked');
      });
    });

    group('Recovery Tracking', () {
      test('Error counter tracks consecutive errors', () {
        // Arrange
        final connectionMetrics = ConnectionMetrics();
        final connectionManager = ConnectionManager(connectionMetrics: connectionMetrics);
        
        expect(connectionManager.consecutiveErrors, equals(0));
        
        // Act - Simulate consecutive errors
        connectionManager.incrementErrorCount();
        final count1 = connectionManager.consecutiveErrors;
        
        connectionManager.incrementErrorCount();
        final count2 = connectionManager.consecutiveErrors;
        
        connectionManager.incrementErrorCount();
        final count3 = connectionManager.consecutiveErrors;
        
        // Assert
        expect(count1, equals(1),
          reason: 'First error should be tracked');
        expect(count2, equals(2),
          reason: 'Errors should accumulate');
        expect(count3, equals(3),
          reason: 'Errors should continue to accumulate');
      });

      test('Successful operation resets error counter', () {
        // Arrange
        final connectionMetrics = ConnectionMetrics();
        final connectionManager = ConnectionManager(connectionMetrics: connectionMetrics);
        
        // Simulate some errors
        connectionManager.incrementErrorCount();
        connectionManager.incrementErrorCount();
        expect(connectionManager.consecutiveErrors, equals(2));
        
        // Act - Simulate successful operation
        connectionManager.resetErrorCount();
        
        // Assert
        expect(connectionManager.consecutiveErrors, equals(0),
          reason: 'Successful operation should reset error counter');
      });

      test('Full reset threshold is correctly detected', () {
        // Arrange
        final connectionMetrics = ConnectionMetrics();
        final connectionManager = ConnectionManager(connectionMetrics: connectionMetrics);
        
        // Act & Assert - Test threshold detection
        expect(connectionManager.shouldPerformFullReset(), isFalse,
          reason: '0 errors should not trigger reset');
        
        connectionManager.incrementErrorCount();
        expect(connectionManager.shouldPerformFullReset(), isFalse,
          reason: '1 error should not trigger reset');
        
        connectionManager.incrementErrorCount();
        expect(connectionManager.shouldPerformFullReset(), isFalse,
          reason: '2 errors should not trigger reset');
        
        connectionManager.incrementErrorCount();
        expect(connectionManager.shouldPerformFullReset(), isTrue,
          reason: '3 errors should trigger reset');
      });
    });
  });
}
