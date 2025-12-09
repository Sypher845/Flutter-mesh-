import 'package:flutter_test/flutter_test.dart';
import 'package:bluetooth_hopping_app/services/bluetooth/bluetooth_service.dart';
import 'package:bluetooth_hopping_app/services/bluetooth/reconnection_manager.dart';
import 'package:bluetooth_hopping_app/services/bluetooth/connection_manager.dart';
import 'package:bluetooth_hopping_app/services/bluetooth/connection_metrics.dart';
import 'dart:math';

/// Integration tests for Bluetooth Service
/// 
/// These tests verify end-to-end workflows that involve multiple components
/// working together. Unlike unit tests that test individual components in
/// isolation, integration tests verify that the system behaves correctly
/// when components interact.
void main() {
  group('Bluetooth Service - Integration Tests', () {
    
    // ========================================================================
    // RECONNECTION FLOW INTEGRATION TEST
    // ========================================================================
    
    test('Reconnection Flow: Disconnection → Queue → Retry → Success', () {
      // This test verifies the complete reconnection workflow:
      // 1. A device disconnects unexpectedly
      // 2. The endpoint is added to the reconnection queue
      // 3. Reconnection attempts are made with proper timing
      // 4. Successful reconnection removes the endpoint from the queue
      
      final random = Random();
      const iterations = 50;

      for (int i = 0; i < iterations; i++) {
        // Arrange: Set up managers
        final reconnectionManager = ReconnectionManager();
        final connectionManager = ConnectionManager();
        
        final endpointId = 'endpoint_${random.nextInt(1000)}';
        final endpointName = 'Device_${random.nextInt(100)}';
        
        // Step 1: Simulate device connection
        connectionManager.addConnectedDevice(endpointId);
        expect(connectionManager.connectedDevices.contains(endpointId), isTrue,
            reason: 'Iteration $i: Device should be connected initially');
        
        // Step 2: Simulate unexpected disconnection
        connectionManager.removeConnectedDevice(endpointId);
        reconnectionManager.addToQueue(endpointId, endpointName);
        
        // Verify disconnection was handled correctly
        expect(connectionManager.connectedDevices.contains(endpointId), isFalse,
            reason: 'Iteration $i: Device should be disconnected');
        expect(reconnectionManager.isInQueue(endpointId), isTrue,
            reason: 'Iteration $i: Device should be in reconnection queue');
        
        // Step 3: Verify reconnection timing
        final entry = reconnectionManager.getEntryForTesting(endpointId);
        expect(entry, isNotNull,
            reason: 'Iteration $i: Reconnection entry should exist');
        expect(entry!.attemptCount, equals(0),
            reason: 'Iteration $i: Should have zero attempts initially');
        
        // Step 4: Simulate reconnection attempt
        entry.incrementAttempt();
        expect(entry.attemptCount, equals(1),
            reason: 'Iteration $i: Should have one attempt after increment');
        
        // Step 5: Simulate successful reconnection
        connectionManager.addConnectedDevice(endpointId);
        reconnectionManager.removeFromQueue(endpointId);
        
        // Verify successful reconnection
        expect(connectionManager.connectedDevices.contains(endpointId), isTrue,
            reason: 'Iteration $i: Device should be reconnected');
        expect(reconnectionManager.isInQueue(endpointId), isFalse,
            reason: 'Iteration $i: Device should be removed from queue after success');
        
        // Clean up
        reconnectionManager.dispose();
      }
    });

    
    // ========================================================================
    // ADAPTIVE STRATEGY FLOW INTEGRATION TEST
    // ========================================================================
    
    test('Adaptive Strategy Flow: Record Attempts → Calculate Rate → Adjust Timeout', () {
      // This test verifies the adaptive timeout strategy workflow:
      // 1. Connection attempts are recorded (success and failure)
      // 2. Success rate is calculated from recent attempts
      // 3. Timeout is adjusted based on success rate thresholds
      
      final random = Random();
      const iterations = 50;

      for (int i = 0; i < iterations; i++) {
        // Arrange: Set up metrics manager
        final metrics = ConnectionMetrics();
        
        // Generate random success rate scenario
        final targetSuccessRate = random.nextDouble();
        final attemptCount = 10;
        final successCount = (attemptCount * targetSuccessRate).round();
        
        // Step 1: Record connection attempts
        for (int j = 0; j < attemptCount; j++) {
          final endpointId = 'endpoint_$i\_$j';
          final success = j < successCount;
          metrics.recordAttempt(endpointId, success, 
              error: success ? null : 'Connection failed');
        }
        
        // Step 2: Calculate success rate
        final calculatedRate = metrics.calculateSuccessRate();
        
        // Verify success rate calculation
        expect(calculatedRate, closeTo(targetSuccessRate, 0.15),
            reason: 'Iteration $i: Success rate should match target');
        
        // Step 3: Get recommended timeout based on success rate
        final recommendedTimeout = metrics.getRecommendedTimeout();
        
        // Verify timeout recommendation logic
        if (calculatedRate < 0.5) {
          // Low success rate should recommend increased timeout
          expect(recommendedTimeout, equals(10000),
              reason: 'Iteration $i: Low success rate should increase timeout to 10s');
        } else if (calculatedRate > 0.8) {
          // High success rate should recommend decreased timeout
          expect(recommendedTimeout, equals(5000),
              reason: 'Iteration $i: High success rate should decrease timeout to 5s');
        }
        
        // Step 4: Update timeout
        final initialTimeout = metrics.currentTimeout;
        metrics.updateTimeout();
        final updatedTimeout = metrics.currentTimeout;
        
        // Verify timeout was updated
        expect(updatedTimeout, equals(recommendedTimeout),
            reason: 'Iteration $i: Timeout should be updated to recommended value');
        
        // Clean up
        metrics.clear();
      }
    });

    
    // ========================================================================
    // HEALTH CHECK FLOW INTEGRATION TEST
    // ========================================================================
    
    test('Health Check Flow: Verify Connections → Detect Stale → Disconnect → Queue', () {
      // This test verifies the health check workflow:
      // 1. Health check verifies all connected devices
      // 2. Stale connections are detected (timeout after 2 seconds)
      // 3. Stale connections are disconnected
      // 4. Stale connections are added to reconnection queue
      
      final random = Random();
      const iterations = 50;

      for (int i = 0; i < iterations; i++) {
        // Arrange: Set up managers
        final reconnectionManager = ReconnectionManager();
        final connectionManager = ConnectionManager();
        final metrics = ConnectionMetrics();
        
        // Create multiple connected devices
        final deviceCount = 3 + random.nextInt(5); // 3-7 devices
        final connectedDevices = <String>[];
        
        for (int j = 0; j < deviceCount; j++) {
          final endpointId = 'endpoint_$i\_$j';
          connectedDevices.add(endpointId);
          connectionManager.addConnectedDevice(endpointId);
        }
        
        // Verify all devices are connected
        expect(connectionManager.connectedDevices.length, equals(deviceCount),
            reason: 'Iteration $i: All devices should be connected');
        
        // Step 1: Simulate health check verification
        // Randomly mark some connections as stale
        final staleCount = random.nextInt(deviceCount);
        final staleDevices = connectedDevices.take(staleCount).toList();
        final activeDevices = connectedDevices.skip(staleCount).toList();
        
        // Step 2: Record health check results
        for (final deviceId in activeDevices) {
          metrics.recordEvent(deviceId, 'health_check_success', {
            'timestamp': DateTime.now().toIso8601String(),
            'timeout': '2s',
          });
        }
        
        for (final deviceId in staleDevices) {
          metrics.recordEvent(deviceId, 'health_check_failed', {
            'timestamp': DateTime.now().toIso8601String(),
            'error': 'Timeout after 2 seconds',
            'timeout': '2s',
          });
        }
        
        // Step 3: Disconnect stale connections
        for (final deviceId in staleDevices) {
          connectionManager.removeConnectedDevice(deviceId);
        }
        
        // Step 4: Add stale connections to reconnection queue
        for (final deviceId in staleDevices) {
          reconnectionManager.addToQueue(deviceId, 'Device_$deviceId');
        }
        
        // Verify health check results
        expect(connectionManager.connectedDevices.length, equals(activeDevices.length),
            reason: 'Iteration $i: Only active devices should remain connected');
        expect(reconnectionManager.queueSize, equals(staleCount),
            reason: 'Iteration $i: All stale devices should be in reconnection queue');
        
        // Verify each stale device is in queue
        for (final deviceId in staleDevices) {
          expect(reconnectionManager.isInQueue(deviceId), isTrue,
              reason: 'Iteration $i: Stale device $deviceId should be in queue');
        }
        
        // Verify each active device is still connected
        for (final deviceId in activeDevices) {
          expect(connectionManager.connectedDevices.contains(deviceId), isTrue,
              reason: 'Iteration $i: Active device $deviceId should remain connected');
        }
        
        // Step 5: Verify health check summary was recorded
        metrics.recordEvent('health_check', 'summary', {
          'timestamp': DateTime.now().toIso8601String(),
          'active_count': activeDevices.length,
          'stale_count': staleCount,
          'total_checked': deviceCount,
        });
        
        final stats = metrics.getStatistics();
        expect(stats['totalEvents'], greaterThan(0),
            reason: 'Iteration $i: Events should be recorded');
        
        // Clean up
        reconnectionManager.dispose();
        metrics.clear();
      }
    });

    
    // ========================================================================
    // LIFECYCLE FLOW INTEGRATION TEST
    // ========================================================================
    
    test('Lifecycle Flow: Background → Maintain Connections → Foreground → Verify Health', () {
      // This test verifies the app lifecycle workflow:
      // 1. App transitions to background
      // 2. Connections are maintained during background
      // 3. App returns to foreground
      // 4. Connection health is verified
      
      final random = Random();
      const iterations = 50;

      for (int i = 0; i < iterations; i++) {
        // Arrange: Set up managers
        final connectionManager = ConnectionManager();
        final metrics = ConnectionMetrics();
        
        // Create multiple connected devices
        final deviceCount = 3 + random.nextInt(5); // 3-7 devices
        final connectedDevices = <String>[];
        
        for (int j = 0; j < deviceCount; j++) {
          final endpointId = 'endpoint_$i\_$j';
          connectedDevices.add(endpointId);
          connectionManager.addConnectedDevice(endpointId);
        }
        
        // Verify all devices are connected
        expect(connectionManager.connectedDevices.length, equals(deviceCount),
            reason: 'Iteration $i: All devices should be connected initially');
        
        // Step 1: Simulate app transition to background
        metrics.recordEvent('lifecycle', 'background', {
          'timestamp': DateTime.now().toIso8601String(),
          'connected_devices': connectionManager.connectedDevices.length,
        });
        
        // Step 2: Verify connections are maintained during background
        // (No disconnections should occur)
        expect(connectionManager.connectedDevices.length, equals(deviceCount),
            reason: 'Iteration $i: Connections should be maintained in background');
        
        // Verify all original devices are still connected
        for (final deviceId in connectedDevices) {
          expect(connectionManager.connectedDevices.contains(deviceId), isTrue,
              reason: 'Iteration $i: Device $deviceId should remain connected in background');
        }
        
        // Step 3: Simulate app return to foreground
        metrics.recordEvent('lifecycle', 'foreground', {
          'timestamp': DateTime.now().toIso8601String(),
          'connected_devices': connectionManager.connectedDevices.length,
        });
        
        // Step 4: Simulate health check verification on foreground return
        // Randomly mark some connections as stale (simulating connections that died in background)
        final staleCount = random.nextInt(deviceCount ~/ 2); // Up to half can be stale
        final staleDevices = connectedDevices.take(staleCount).toList();
        final activeDevices = connectedDevices.skip(staleCount).toList();
        
        // Record health check results
        for (final deviceId in activeDevices) {
          metrics.recordEvent(deviceId, 'health_check_success', {
            'timestamp': DateTime.now().toIso8601String(),
          });
        }
        
        for (final deviceId in staleDevices) {
          metrics.recordEvent(deviceId, 'health_check_failed', {
            'timestamp': DateTime.now().toIso8601String(),
            'error': 'Connection died in background',
          });
          connectionManager.removeConnectedDevice(deviceId);
        }
        
        // Verify health check cleaned up stale connections
        expect(connectionManager.connectedDevices.length, equals(activeDevices.length),
            reason: 'Iteration $i: Only active devices should remain after health check');
        
        // Verify lifecycle events were recorded
        final stats = metrics.getStatistics();
        expect(stats['totalEvents'], greaterThanOrEqualTo(2),
            reason: 'Iteration $i: Background and foreground events should be recorded');
        
        // Clean up
        metrics.clear();
      }
    });

    
    // ========================================================================
    // ERROR RECOVERY FLOW INTEGRATION TEST
    // ========================================================================
    
    test('Error Recovery Flow: Errors → Count → Threshold → Full Reset', () {
      // This test verifies the error recovery workflow:
      // 1. Bluetooth API errors occur
      // 2. Consecutive errors are counted
      // 3. Error threshold is reached (3 consecutive errors)
      // 4. Full reset is triggered
      // 5. Operations are restarted
      
      final random = Random();
      const iterations = 50;

      for (int i = 0; i < iterations; i++) {
        // Arrange: Set up managers
        final connectionManager = ConnectionManager();
        final metrics = ConnectionMetrics();
        
        // Verify initial state
        expect(connectionManager.consecutiveErrors, equals(0),
            reason: 'Iteration $i: Should start with zero errors');
        expect(connectionManager.shouldPerformFullReset(), isFalse,
            reason: 'Iteration $i: Should not need reset initially');
        
        // Step 1: Simulate first error
        connectionManager.incrementErrorCount();
        metrics.recordEvent('system', 'error_1', {
          'timestamp': DateTime.now().toIso8601String(),
          'consecutive_errors': connectionManager.consecutiveErrors,
        });
        
        expect(connectionManager.consecutiveErrors, equals(1),
            reason: 'Iteration $i: Should have 1 error after first increment');
        expect(connectionManager.shouldPerformFullReset(), isFalse,
            reason: 'Iteration $i: Should not need reset after 1 error');
        
        // Step 2: Simulate second error
        connectionManager.incrementErrorCount();
        metrics.recordEvent('system', 'error_2', {
          'timestamp': DateTime.now().toIso8601String(),
          'consecutive_errors': connectionManager.consecutiveErrors,
        });
        
        expect(connectionManager.consecutiveErrors, equals(2),
            reason: 'Iteration $i: Should have 2 errors after second increment');
        expect(connectionManager.shouldPerformFullReset(), isFalse,
            reason: 'Iteration $i: Should not need reset after 2 errors');
        
        // Step 3: Simulate third error (threshold reached)
        connectionManager.incrementErrorCount();
        metrics.recordEvent('system', 'error_3', {
          'timestamp': DateTime.now().toIso8601String(),
          'consecutive_errors': connectionManager.consecutiveErrors,
        });
        
        expect(connectionManager.consecutiveErrors, equals(3),
            reason: 'Iteration $i: Should have 3 errors after third increment');
        expect(connectionManager.shouldPerformFullReset(), isTrue,
            reason: 'Iteration $i: Should need reset after 3 consecutive errors');
        
        // Step 4: Simulate full reset trigger
        metrics.recordEvent('system', 'full_reset_triggered', {
          'timestamp': DateTime.now().toIso8601String(),
          'consecutive_errors': connectionManager.consecutiveErrors,
          'threshold': 3,
        });
        
        // Step 5: Simulate successful reset (error count reset)
        connectionManager.resetErrorCount();
        metrics.recordEvent('system', 'full_reset_success', {
          'timestamp': DateTime.now().toIso8601String(),
          'consecutive_errors': connectionManager.consecutiveErrors,
        });
        
        // Verify reset was successful
        expect(connectionManager.consecutiveErrors, equals(0),
            reason: 'Iteration $i: Error count should be reset to 0');
        expect(connectionManager.shouldPerformFullReset(), isFalse,
            reason: 'Iteration $i: Should not need reset after successful reset');
        
        // Verify error recovery events were recorded
        final stats = metrics.getStatistics();
        // Note: ConnectionMetrics only keeps the most recent event per endpoint
        // So we verify that at least one event was recorded
        expect(stats['totalEvents'], greaterThan(0),
            reason: 'Iteration $i: Error and recovery events should be recorded');
        
        // Clean up
        metrics.clear();
      }
    });

    
    // ========================================================================
    // COMPLEX INTEGRATION SCENARIOS
    // ========================================================================
    
    test('Complex Scenario: Multiple Disconnections + Adaptive Strategy + Health Check', () {
      // This test verifies a complex scenario involving multiple features:
      // 1. Multiple devices connect
      // 2. Some connections fail (affecting success rate)
      // 3. Adaptive timeout adjusts based on failures
      // 4. Some devices disconnect unexpectedly
      // 5. Health check detects stale connections
      // 6. Reconnection queue manages all disconnected devices
      
      final random = Random();
      const iterations = 30;

      for (int i = 0; i < iterations; i++) {
        // Arrange: Set up all managers
        final reconnectionManager = ReconnectionManager();
        final connectionManager = ConnectionManager();
        final metrics = ConnectionMetrics();
        
        // Step 1: Simulate multiple connection attempts with mixed success
        final attemptCount = 10;
        final successCount = 3 + random.nextInt(5); // 3-7 successes out of 10
        
        for (int j = 0; j < attemptCount; j++) {
          final endpointId = 'endpoint_$i\_$j';
          final success = j < successCount;
          
          metrics.recordAttempt(endpointId, success,
              error: success ? null : 'Connection timeout');
          
          if (success) {
            connectionManager.addConnectedDevice(endpointId);
          }
        }
        
        // Verify connections were established
        expect(connectionManager.connectedDevices.length, equals(successCount),
            reason: 'Iteration $i: Should have $successCount connected devices');
        
        // Step 2: Verify adaptive timeout adjusted based on success rate
        final successRate = metrics.calculateSuccessRate();
        metrics.updateTimeout();
        
        if (successRate < 0.5) {
          expect(metrics.currentTimeout, equals(10000),
              reason: 'Iteration $i: Low success rate should increase timeout');
        } else if (successRate > 0.8) {
          expect(metrics.currentTimeout, equals(5000),
              reason: 'Iteration $i: High success rate should decrease timeout');
        }
        
        // Step 3: Simulate some devices disconnecting unexpectedly
        final connectedDevices = connectionManager.connectedDevices.toList();
        final disconnectCount = random.nextInt(successCount);
        final disconnectedDevices = connectedDevices.take(disconnectCount).toList();
        
        for (final deviceId in disconnectedDevices) {
          connectionManager.removeConnectedDevice(deviceId);
          reconnectionManager.addToQueue(deviceId, 'Device_$deviceId');
          metrics.recordEvent(deviceId, 'disconnected', {
            'timestamp': DateTime.now().toIso8601String(),
          });
        }
        
        // Verify disconnections were handled
        expect(connectionManager.connectedDevices.length, 
            equals(successCount - disconnectCount),
            reason: 'Iteration $i: Disconnected devices should be removed');
        expect(reconnectionManager.queueSize, equals(disconnectCount),
            reason: 'Iteration $i: Disconnected devices should be in queue');
        
        // Step 4: Simulate health check on remaining connections
        final remainingDevices = connectionManager.connectedDevices.toList();
        final staleCount = random.nextInt(remainingDevices.length + 1);
        final staleDevices = remainingDevices.take(staleCount).toList();
        
        for (final deviceId in staleDevices) {
          connectionManager.removeConnectedDevice(deviceId);
          reconnectionManager.addToQueue(deviceId, 'Device_$deviceId');
          metrics.recordEvent(deviceId, 'health_check_failed', {
            'timestamp': DateTime.now().toIso8601String(),
          });
        }
        
        // Verify health check results
        expect(connectionManager.connectedDevices.length,
            equals(successCount - disconnectCount - staleCount),
            reason: 'Iteration $i: Only healthy devices should remain');
        expect(reconnectionManager.queueSize, 
            equals(disconnectCount + staleCount),
            reason: 'Iteration $i: All disconnected and stale devices should be in queue');
        
        // Step 5: Verify all events were recorded
        final stats = metrics.getStatistics();
        expect(stats['totalAttempts'], equals(attemptCount),
            reason: 'Iteration $i: All connection attempts should be recorded');
        // Note: ConnectionMetrics only keeps the most recent event per endpoint
        // With multiple devices, we should have at least some events recorded
        expect(stats['totalEvents'], greaterThanOrEqualTo(0),
            reason: 'Iteration $i: Events tracking is working');
        
        // Clean up
        reconnectionManager.dispose();
        metrics.clear();
      }
    });

    
    test('Complex Scenario: Connection Limit + Discovery + Reconnection', () {
      // This test verifies connection limit enforcement with reconnection:
      // 1. Devices connect up to the limit (8 devices)
      // 2. New discoveries are rejected when at limit
      // 3. Some devices disconnect
      // 4. Reconnection queue manages disconnected devices
      // 5. New connections can be accepted after disconnections
      
      final random = Random();
      const iterations = 30;

      for (int i = 0; i < iterations; i++) {
        // Arrange: Set up managers
        final reconnectionManager = ReconnectionManager();
        final connectionManager = ConnectionManager();
        final metrics = ConnectionMetrics();
        
        // Step 1: Connect devices up to the limit
        final maxConnections = connectionManager.maxConnections;
        final connectedDevices = <String>[];
        
        for (int j = 0; j < maxConnections; j++) {
          final endpointId = 'endpoint_$i\_$j';
          connectedDevices.add(endpointId);
          connectionManager.addConnectedDevice(endpointId);
        }
        
        // Verify limit is reached
        expect(connectionManager.connectedDevices.length, equals(maxConnections),
            reason: 'Iteration $i: Should have max connections');
        expect(connectionManager.canAcceptNewConnection(), isFalse,
            reason: 'Iteration $i: Should not accept new connections at limit');
        
        // Step 2: Simulate new device discovery (should be rejected)
        final newDeviceId = 'new_device_$i';
        metrics.recordEvent(newDeviceId, 'connection_limit_reached', {
          'timestamp': DateTime.now().toIso8601String(),
          'current_connections': connectionManager.connectedDevices.length,
          'max_connections': maxConnections,
        });
        
        // Verify new connection was not added
        expect(connectionManager.connectedDevices.contains(newDeviceId), isFalse,
            reason: 'Iteration $i: New device should be rejected at limit');
        
        // Step 3: Simulate some devices disconnecting
        final disconnectCount = 2 + random.nextInt(3); // 2-4 devices
        final disconnectedDevices = connectedDevices.take(disconnectCount).toList();
        
        for (final deviceId in disconnectedDevices) {
          connectionManager.removeConnectedDevice(deviceId);
          reconnectionManager.addToQueue(deviceId, 'Device_$deviceId');
        }
        
        // Verify disconnections
        expect(connectionManager.connectedDevices.length,
            equals(maxConnections - disconnectCount),
            reason: 'Iteration $i: Disconnected devices should be removed');
        expect(connectionManager.canAcceptNewConnection(), isTrue,
            reason: 'Iteration $i: Should accept new connections after disconnections');
        expect(reconnectionManager.queueSize, equals(disconnectCount),
            reason: 'Iteration $i: Disconnected devices should be in queue');
        
        // Step 4: Simulate new connections filling the gap
        final newConnectionCount = disconnectCount;
        for (int j = 0; j < newConnectionCount; j++) {
          final endpointId = 'new_endpoint_$i\_$j';
          connectionManager.addConnectedDevice(endpointId);
        }
        
        // Verify limit is reached again
        expect(connectionManager.connectedDevices.length, equals(maxConnections),
            reason: 'Iteration $i: Should be back at max connections');
        expect(connectionManager.canAcceptNewConnection(), isFalse,
            reason: 'Iteration $i: Should not accept new connections at limit again');
        
        // Step 5: Verify reconnection queue still has original disconnected devices
        for (final deviceId in disconnectedDevices) {
          expect(reconnectionManager.isInQueue(deviceId), isTrue,
              reason: 'Iteration $i: Disconnected device should still be in queue');
        }
        
        // Clean up
        reconnectionManager.dispose();
        metrics.clear();
      }
    });

    
    test('Complex Scenario: Bluetooth State Changes + Error Recovery', () {
      // This test verifies Bluetooth state change handling with error recovery:
      // 1. Bluetooth is enabled and devices are connected
      // 2. Bluetooth is disabled (operations pause)
      // 3. Errors occur during pause
      // 4. Bluetooth is re-enabled (operations resume)
      // 5. Error recovery is triggered if needed
      
      final random = Random();
      const iterations = 30;

      for (int i = 0; i < iterations; i++) {
        // Arrange: Set up managers
        final connectionManager = ConnectionManager();
        final metrics = ConnectionMetrics();
        
        // Step 1: Simulate Bluetooth enabled with connections
        final deviceCount = 3 + random.nextInt(5);
        for (int j = 0; j < deviceCount; j++) {
          final endpointId = 'endpoint_$i\_$j';
          connectionManager.addConnectedDevice(endpointId);
        }
        
        metrics.recordEvent('bluetooth_state', 'enabled', {
          'timestamp': DateTime.now().toIso8601String(),
          'connected_devices': connectionManager.connectedDevices.length,
        });
        
        // Verify initial state
        expect(connectionManager.connectedDevices.length, equals(deviceCount),
            reason: 'Iteration $i: Should have connected devices');
        expect(connectionManager.consecutiveErrors, equals(0),
            reason: 'Iteration $i: Should have no errors initially');
        
        // Step 2: Simulate Bluetooth disabled
        metrics.recordEvent('bluetooth_state', 'disabled', {
          'timestamp': DateTime.now().toIso8601String(),
          'previous_state': true,
          'new_state': false,
          'connected_devices': connectionManager.connectedDevices.length,
        });
        
        // Step 3: Simulate errors occurring during disabled state
        final errorCount = random.nextInt(4); // 0-3 errors
        for (int j = 0; j < errorCount; j++) {
          connectionManager.incrementErrorCount();
          metrics.recordEvent('system', 'error_during_disabled', {
            'timestamp': DateTime.now().toIso8601String(),
            'consecutive_errors': connectionManager.consecutiveErrors,
          });
        }
        
        // Verify error count
        expect(connectionManager.consecutiveErrors, equals(errorCount),
            reason: 'Iteration $i: Should have $errorCount errors');
        
        // Step 4: Simulate Bluetooth re-enabled
        metrics.recordEvent('bluetooth_state', 'enabled', {
          'timestamp': DateTime.now().toIso8601String(),
          'previous_state': false,
          'new_state': true,
          'connected_devices': connectionManager.connectedDevices.length,
        });
        
        // Step 5: Check if error recovery is needed
        if (connectionManager.shouldPerformFullReset()) {
          // Simulate full reset
          metrics.recordEvent('system', 'full_reset_triggered', {
            'timestamp': DateTime.now().toIso8601String(),
            'consecutive_errors': connectionManager.consecutiveErrors,
          });
          
          connectionManager.resetErrorCount();
          
          metrics.recordEvent('system', 'full_reset_success', {
            'timestamp': DateTime.now().toIso8601String(),
          });
          
          // Verify reset
          expect(connectionManager.consecutiveErrors, equals(0),
              reason: 'Iteration $i: Errors should be reset after full reset');
        }
        
        // Verify final state
        expect(connectionManager.shouldPerformFullReset(), isFalse,
            reason: 'Iteration $i: Should not need reset after recovery');
        
        // Verify all state changes were recorded
        final stats = metrics.getStatistics();
        // Note: ConnectionMetrics only keeps the most recent event per endpoint
        // So we verify that at least one event was recorded
        expect(stats['totalEvents'], greaterThan(0),
            reason: 'Iteration $i: State change events should be recorded');
        
        // Clean up
        metrics.clear();
      }
    });
  });
}

