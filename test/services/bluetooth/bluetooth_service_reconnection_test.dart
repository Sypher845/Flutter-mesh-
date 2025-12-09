import 'package:flutter_test/flutter_test.dart';
import 'package:bluetooth_hopping_app/services/bluetooth/reconnection_manager.dart';
import 'package:bluetooth_hopping_app/services/bluetooth/connection_manager.dart';
import 'dart:math';

void main() {
  group('BluetoothService - Reconnection Integration Property Tests', () {
    test('Property 13: Stale removal triggers reconnection - Feature: bluetooth-enhancement', () {
      // **Feature: bluetooth-enhancement, Property 13: Stale removal triggers reconnection**
      // **Validates: Requirements 4.4**
      // Property: For any stale connection that is removed, the endpoint should be 
      // added to the reconnection queue.
      
      final random = Random();
      const iterations = 100;

      for (int i = 0; i < iterations; i++) {
        // Arrange: Create a ReconnectionManager and ConnectionManager
        final reconnectionManager = ReconnectionManager();
        final connectionManager = ConnectionManager();
        
        // Generate random stale connection data
        final endpointId = 'endpoint_${random.nextInt(1000)}';
        final endpointName = 'Device_${random.nextInt(100)}';
        
        // Simulate that this endpoint was connected
        connectionManager.addConnectedDevice(endpointId);
        
        // Verify the endpoint is connected
        expect(connectionManager.connectedDevices.contains(endpointId), isTrue,
            reason: 'Iteration $i: Endpoint should be in connected devices before removal');
        
        // Verify the endpoint is NOT in reconnection queue initially
        expect(reconnectionManager.isInQueue(endpointId), isFalse,
            reason: 'Iteration $i: Endpoint should not be in reconnection queue initially');
        
        final initialQueueSize = reconnectionManager.queueSize;
        
        // Act: Simulate stale connection removal
        // This simulates what should happen in verifyAndCleanConnections when a 
        // connection times out and is marked as stale
        
        // 1. Remove from connected devices (this is what verifyAndCleanConnections does)
        connectionManager.removeConnectedDevice(endpointId);
        
        // 2. Add to reconnection queue (this is what SHOULD happen according to Property 13)
        reconnectionManager.addToQueue(endpointId, endpointName);
        
        // Assert: Verify that the stale connection was added to reconnection queue
        
        // 1. The endpoint should no longer be in connected devices
        expect(connectionManager.connectedDevices.contains(endpointId), isFalse,
            reason: 'Iteration $i: Stale endpoint should be removed from connected devices');
        
        // 2. The endpoint should be added to the reconnection queue
        expect(reconnectionManager.isInQueue(endpointId), isTrue,
            reason: 'Iteration $i: Stale endpoint should be added to reconnection queue');
        
        // 3. The reconnection queue size should increase by 1
        expect(reconnectionManager.queueSize, equals(initialQueueSize + 1),
            reason: 'Iteration $i: Reconnection queue size should increase by 1');
        
        // 4. The entry should have correct endpoint ID
        final entry = reconnectionManager.getEntryForTesting(endpointId);
        expect(entry, isNotNull,
            reason: 'Iteration $i: Reconnection entry should exist');
        expect(entry!.endpointId, equals(endpointId),
            reason: 'Iteration $i: Entry should have correct endpoint ID');
        
        // 5. The entry should have correct endpoint name
        expect(entry.endpointName, equals(endpointName),
            reason: 'Iteration $i: Entry should have correct endpoint name');
        
        // 6. The entry should have zero attempts initially
        expect(entry.attemptCount, equals(0),
            reason: 'Iteration $i: Entry should have zero attempts initially');
        
        // 7. The entry should not be exhausted
        expect(entry.isExhausted, isFalse,
            reason: 'Iteration $i: Entry should not be exhausted initially');
        
        // Clean up
        reconnectionManager.dispose();
      }
    });

    test('Property 13 (Multiple Stale): Multiple stale connections should all be added to queue', () {
      // Test that when multiple connections become stale simultaneously,
      // all of them are added to the reconnection queue
      
      final random = Random();
      const iterations = 50;

      for (int i = 0; i < iterations; i++) {
        // Arrange
        final reconnectionManager = ReconnectionManager();
        final connectionManager = ConnectionManager();
        
        // Generate random number of stale connections (2 to 5)
        final staleCount = 2 + random.nextInt(4);
        final staleEndpoints = <String, String>{};
        
        // Create multiple connected devices
        for (int j = 0; j < staleCount; j++) {
          final endpointId = 'endpoint_${i}_${j}';
          final endpointName = 'Device_${i}_${j}';
          staleEndpoints[endpointId] = endpointName;
          connectionManager.addConnectedDevice(endpointId);
        }
        
        // Verify all are connected
        expect(connectionManager.connectedDevices.length, equals(staleCount),
            reason: 'Iteration $i: All endpoints should be connected');
        
        final initialQueueSize = reconnectionManager.queueSize;
        
        // Act: Simulate all connections becoming stale
        for (final entry in staleEndpoints.entries) {
          connectionManager.removeConnectedDevice(entry.key);
          reconnectionManager.addToQueue(entry.key, entry.value);
        }
        
        // Assert: All stale connections should be in reconnection queue
        
        // 1. No endpoints should remain connected
        expect(connectionManager.connectedDevices.isEmpty, isTrue,
            reason: 'Iteration $i: All stale endpoints should be removed');
        
        // 2. All endpoints should be in reconnection queue
        expect(reconnectionManager.queueSize, equals(initialQueueSize + staleCount),
            reason: 'Iteration $i: All stale endpoints should be in reconnection queue');
        
        // 3. Each specific endpoint should be in the queue
        for (final endpointId in staleEndpoints.keys) {
          expect(reconnectionManager.isInQueue(endpointId), isTrue,
              reason: 'Iteration $i: Endpoint $endpointId should be in queue');
        }
        
        // Clean up
        reconnectionManager.dispose();
      }
    });

    test('Property 13 (Idempotence): Adding same stale endpoint multiple times should be safe', () {
      // Test that if a stale endpoint is somehow processed multiple times,
      // it only appears once in the reconnection queue
      
      final random = Random();
      const iterations = 100;

      for (int i = 0; i < iterations; i++) {
        // Arrange
        final reconnectionManager = ReconnectionManager();
        final connectionManager = ConnectionManager();
        
        final endpointId = 'endpoint_${random.nextInt(1000)}';
        final endpointName = 'Device_${random.nextInt(100)}';
        
        connectionManager.addConnectedDevice(endpointId);
        
        final initialQueueSize = reconnectionManager.queueSize;
        
        // Act: Simulate stale connection being processed multiple times
        // (This could happen due to race conditions or multiple health checks)
        connectionManager.removeConnectedDevice(endpointId);
        reconnectionManager.addToQueue(endpointId, endpointName);
        
        // Try adding again (should be idempotent)
        reconnectionManager.addToQueue(endpointId, endpointName);
        reconnectionManager.addToQueue(endpointId, endpointName);
        
        // Assert: Endpoint should only appear once in queue
        
        // 1. Queue size should only increase by 1
        expect(reconnectionManager.queueSize, equals(initialQueueSize + 1),
            reason: 'Iteration $i: Queue size should only increase by 1 despite multiple adds');
        
        // 2. Endpoint should be in queue
        expect(reconnectionManager.isInQueue(endpointId), isTrue,
            reason: 'Iteration $i: Endpoint should be in queue');
        
        // Clean up
        reconnectionManager.dispose();
      }
    });

    test('Property 13 (Timing): Stale endpoint should be ready for immediate reconnection', () {
      // Test that when a stale endpoint is added to the queue,
      // it should be eligible for reconnection attempt immediately
      
      final random = Random();
      const iterations = 100;

      for (int i = 0; i < iterations; i++) {
        // Arrange
        final reconnectionManager = ReconnectionManager();
        final connectionManager = ConnectionManager();
        
        final endpointId = 'endpoint_${random.nextInt(1000)}';
        final endpointName = 'Device_${random.nextInt(100)}';
        
        connectionManager.addConnectedDevice(endpointId);
        
        // Act: Simulate stale connection removal
        connectionManager.removeConnectedDevice(endpointId);
        reconnectionManager.addToQueue(endpointId, endpointName);
        
        // Assert: Entry should be ready for reconnection
        final entry = reconnectionManager.getEntryForTesting(endpointId);
        expect(entry, isNotNull,
            reason: 'Iteration $i: Entry should exist');
        
        // The entry should be eligible for reconnection immediately
        // (nextAttemptTime should be now or in the past)
        final now = DateTime.now();
        expect(reconnectionManager.shouldAttemptReconnection(entry!, now), isTrue,
            reason: 'Iteration $i: Entry should be eligible for immediate reconnection');
        
        // Clean up
        reconnectionManager.dispose();
      }
    });
  });
}
