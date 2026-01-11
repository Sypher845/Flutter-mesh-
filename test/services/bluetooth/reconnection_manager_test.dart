import 'package:flutter_test/flutter_test.dart';
import 'package:bluetooth_hopping_app/services/bluetooth/reconnection_manager.dart';
import 'dart:math';

/// Custom property test helper that runs a test function multiple times
void propertyTest(String description, Function testFn, {int iterations = 100}) {
  test(description, () {
    for (int i = 0; i < iterations; i++) {
      testFn();
    }
  });
}

/// Generator for random strings
String generateRandomString(Random random, {int maxLength = 20}) {
  final length = random.nextInt(maxLength) + 1;
  const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  return String.fromCharCodes(
    Iterable.generate(length, (_) => chars.codeUnitAt(random.nextInt(chars.length)))
  );
}

void main() {
  group('ReconnectionManager Property Tests', () {
    final random = Random();

    /// **Feature: bluetooth-enhancement, Property 6: Disconnection triggers reconnection queue**
    /// **Validates: Requirements 3.1**
    /// 
    /// Property: For any unexpected disconnection event, 
    /// the system should add the endpoint to the reconnection queue.
    /// 
    /// This test verifies that when addToQueue is called (simulating a disconnection),
    /// the endpoint is properly added to the reconnection queue and can be verified
    /// through queue inspection methods.
    propertyTest(
      'Property 6: Disconnection triggers reconnection queue - '
      'For any disconnection event, the endpoint should be added to the queue',
      () {
        // Create a fresh ReconnectionManager for each test iteration
        final manager = ReconnectionManager();

        // Generate random endpoint data (simulating a disconnected device)
        final endpointId = generateRandomString(random);
        final endpointName = generateRandomString(random);

        // Verify queue is initially empty
        expect(manager.queueSize, equals(0),
          reason: 'Queue should be empty initially');
        expect(manager.isInQueue(endpointId), isFalse,
          reason: 'Endpoint should not be in queue before disconnection');

        // Simulate a disconnection by adding to queue
        manager.addToQueue(endpointId, endpointName);

        // Verify the endpoint was added to the queue
        expect(manager.queueSize, equals(1),
          reason: 'Queue size should be 1 after adding endpoint');
        expect(manager.isInQueue(endpointId), isTrue,
          reason: 'Endpoint should be in queue after disconnection');
        expect(manager.queuedEndpoints, contains(endpointId),
          reason: 'Queued endpoints list should contain the endpoint ID');

        // Clean up
        manager.dispose();
      },
      iterations: 100,
    );

    propertyTest(
      'Property 6 (Multiple Disconnections): Multiple disconnection events '
      'should add multiple endpoints to the queue',
      () {
        final manager = ReconnectionManager();

        // Generate random number of disconnections (1 to 10)
        final numDisconnections = random.nextInt(10) + 1;
        final endpointIds = <String>[];

        // Simulate multiple disconnections
        for (int i = 0; i < numDisconnections; i++) {
          final endpointId = generateRandomString(random);
          final endpointName = generateRandomString(random);
          endpointIds.add(endpointId);

          manager.addToQueue(endpointId, endpointName);
        }

        // Verify all endpoints were added
        expect(manager.queueSize, equals(numDisconnections),
          reason: 'Queue size should match number of disconnections');

        for (final endpointId in endpointIds) {
          expect(manager.isInQueue(endpointId), isTrue,
            reason: 'Each disconnected endpoint should be in queue');
        }

        // Clean up
        manager.dispose();
      },
      iterations: 100,
    );

    propertyTest(
      'Property 6 (Idempotence): Adding the same endpoint multiple times '
      'should only add it once to the queue',
      () {
        final manager = ReconnectionManager();

        // Generate random endpoint data
        final endpointId = generateRandomString(random);
        final endpointName = generateRandomString(random);

        // Add the same endpoint multiple times (2 to 5 times)
        final numAttempts = random.nextInt(4) + 2;
        for (int i = 0; i < numAttempts; i++) {
          manager.addToQueue(endpointId, endpointName);
        }

        // Verify the endpoint was only added once
        expect(manager.queueSize, equals(1),
          reason: 'Queue size should be 1 even after multiple additions of same endpoint');
        expect(manager.isInQueue(endpointId), isTrue,
          reason: 'Endpoint should be in queue');

        // Clean up
        manager.dispose();
      },
      iterations: 100,
    );

    propertyTest(
      'Property 6 (Queue Persistence): Endpoints remain in queue until explicitly removed',
      () {
        final manager = ReconnectionManager();

        // Generate random endpoint data
        final endpointId = generateRandomString(random);
        final endpointName = generateRandomString(random);

        // Add endpoint to queue
        manager.addToQueue(endpointId, endpointName);

        // Verify it's in the queue
        expect(manager.isInQueue(endpointId), isTrue,
          reason: 'Endpoint should be in queue after addition');

        // Perform some operations that shouldn't affect the queue
        final otherEndpointId = generateRandomString(random);
        manager.isInQueue(otherEndpointId); // Check for non-existent endpoint
        final _ = manager.queueSize; // Get queue size

        // Verify endpoint is still in queue
        expect(manager.isInQueue(endpointId), isTrue,
          reason: 'Endpoint should remain in queue after other operations');

        // Clean up
        manager.dispose();
      },
      iterations: 100,
    );

    /// **Feature: bluetooth-enhancement, Property 7: Reconnection attempt timing**
    /// **Validates: Requirements 3.2**
    /// 
    /// Property: For any endpoint in the reconnection queue, reconnection attempts 
    /// should occur every 5 seconds until max retries (5) is reached.
    /// 
    /// This test verifies that:
    /// 1. Reconnection attempts respect the 5-second interval
    /// 2. Attempts continue until max retries (5) is reached
    /// 3. After max retries, the endpoint is removed from the queue
    propertyTest(
      'Property 7: Reconnection attempt timing - '
      'For any endpoint in queue, attempts should occur every 5 seconds for up to 5 attempts',
      () async {
        final manager = ReconnectionManager();

        // Generate random endpoint data
        final endpointId = generateRandomString(random);
        final endpointName = generateRandomString(random);

        // Track reconnection attempts
        int attemptCount = 0;
        int exhaustedCallCount = 0;

        // Set up callbacks to track attempts
        manager.onReconnectAttempt = (id) {
          if (id == endpointId) {
            attemptCount++;
          }
        };

        manager.onReconnectExhausted = (id) {
          if (id == endpointId) {
            exhaustedCallCount++;
          }
        };

        // Add endpoint to queue
        manager.addToQueue(endpointId, endpointName);

        // Verify endpoint is in queue
        expect(manager.isInQueue(endpointId), isTrue,
          reason: 'Endpoint should be in queue initially');

        // Simulate 5 reconnection attempts by manipulating time
        for (int i = 0; i < 5; i++) {
          // Get the entry and manipulate its nextAttemptTime to simulate time passing
          final entry = manager.getEntryForTesting(endpointId);
          expect(entry, isNotNull, reason: 'Entry should exist in queue');
          
          // Set nextAttemptTime to the past to allow immediate attempt
          entry!.nextAttemptTime = DateTime.now().subtract(Duration(milliseconds: 100));
          
          // Attempt reconnection
          await manager.attemptReconnections();
          
          // Verify attempt was made
          expect(attemptCount, equals(i + 1),
            reason: 'Should have made ${i + 1} attempts');
          
          if (i < 4) {
            // Before the 5th attempt, endpoint should still be in queue
            expect(manager.isInQueue(endpointId), isTrue,
              reason: 'Endpoint should remain in queue before max retries');
          }
        }

        // After 5 attempts, verify the results
        expect(attemptCount, equals(5),
          reason: 'Should make exactly 5 reconnection attempts');
        expect(exhaustedCallCount, equals(1),
          reason: 'onReconnectExhausted should be called once');
        expect(manager.isInQueue(endpointId), isFalse,
          reason: 'Endpoint should be removed from queue after 5 attempts');

        // Clean up
        manager.dispose();
      },
      iterations: 100,
    );

    propertyTest(
      'Property 7 (Timing Interval): Reconnection attempts should respect 5-second backoff',
      () async {
        final manager = ReconnectionManager();

        // Generate random endpoint data
        final endpointId = generateRandomString(random);
        final endpointName = generateRandomString(random);

        int attemptCount = 0;

        // Set up callback to track attempts
        manager.onReconnectAttempt = (id) {
          if (id == endpointId) {
            attemptCount++;
          }
        };

        // Add endpoint to queue
        manager.addToQueue(endpointId, endpointName);

        // Make first attempt
        final entry = manager.getEntryForTesting(endpointId);
        expect(entry, isNotNull, reason: 'Entry should exist');
        entry!.nextAttemptTime = DateTime.now().subtract(Duration(milliseconds: 100));
        
        await manager.attemptReconnections();
        expect(attemptCount, equals(1), reason: 'First attempt should succeed');

        // Verify nextAttemptTime is approximately 5 seconds in the future
        final timeDiff = entry.nextAttemptTime.difference(DateTime.now());
        expect(timeDiff.inSeconds, greaterThanOrEqualTo(4),
          reason: 'Next attempt should be at least 4 seconds in the future');
        expect(timeDiff.inSeconds, lessThanOrEqualTo(6),
          reason: 'Next attempt should be at most 6 seconds in the future');

        // Try to make another attempt immediately - should not happen
        await manager.attemptReconnections();
        expect(attemptCount, equals(1),
          reason: 'Should not make second attempt before 5-second interval');

        // Clean up
        manager.dispose();
      },
      iterations: 100,
    );

    propertyTest(
      'Property 7 (Max Retries): Reconnection should stop after exactly 5 attempts',
      () async {
        final manager = ReconnectionManager();

        // Generate random endpoint data
        final endpointId = generateRandomString(random);
        final endpointName = generateRandomString(random);

        int attemptCount = 0;
        bool exhaustedCalled = false;

        manager.onReconnectAttempt = (id) {
          if (id == endpointId) {
            attemptCount++;
          }
        };

        manager.onReconnectExhausted = (id) {
          if (id == endpointId) {
            exhaustedCalled = true;
          }
        };

        // Add endpoint to queue
        manager.addToQueue(endpointId, endpointName);

        // Perform 5 attempts by manipulating time
        for (int i = 0; i < 5; i++) {
          final entry = manager.getEntryForTesting(endpointId);
          if (entry != null) {
            entry.nextAttemptTime = DateTime.now().subtract(Duration(milliseconds: 100));
          }
          await manager.attemptReconnections();
        }

        // Verify exactly 5 attempts were made
        expect(attemptCount, equals(5),
          reason: 'Should make exactly 5 reconnection attempts');
        expect(exhaustedCalled, isTrue,
          reason: 'Should call onReconnectExhausted after max retries');
        expect(manager.isInQueue(endpointId), isFalse,
          reason: 'Endpoint should be removed after 5 attempts');

        // Try additional attempts - should not happen
        await manager.attemptReconnections();
        expect(attemptCount, equals(5),
          reason: 'Should not make additional attempts after max retries');

        // Clean up
        manager.dispose();
      },
      iterations: 100,
    );

    /// **Feature: bluetooth-enhancement, Property 8: Successful reconnection removes from queue**
    /// **Validates: Requirements 3.3**
    /// 
    /// Property: For any successful reconnection attempt, 
    /// the endpoint should be removed from the reconnection queue.
    /// 
    /// This test verifies that when removeFromQueue is called (simulating a successful
    /// reconnection), the endpoint is properly removed from the queue and no longer
    /// appears in queue inspection methods.
    propertyTest(
      'Property 8: Successful reconnection removes from queue - '
      'For any successful reconnection, the endpoint should be removed from the queue',
      () {
        final manager = ReconnectionManager();

        // Generate random endpoint data
        final endpointId = generateRandomString(random);
        final endpointName = generateRandomString(random);

        // Track success callback
        int successCallCount = 0;
        String? successEndpointId;

        manager.onReconnectSuccess = (id) {
          successCallCount++;
          successEndpointId = id;
        };

        // Add endpoint to queue (simulating a disconnection)
        manager.addToQueue(endpointId, endpointName);

        // Verify endpoint is in queue
        expect(manager.isInQueue(endpointId), isTrue,
          reason: 'Endpoint should be in queue after disconnection');
        expect(manager.queueSize, equals(1),
          reason: 'Queue size should be 1');
        expect(manager.queuedEndpoints, contains(endpointId),
          reason: 'Queued endpoints should contain the endpoint ID');

        // Simulate successful reconnection by removing from queue
        manager.removeFromQueue(endpointId);

        // Verify endpoint was removed from queue
        expect(manager.isInQueue(endpointId), isFalse,
          reason: 'Endpoint should not be in queue after successful reconnection');
        expect(manager.queueSize, equals(0),
          reason: 'Queue size should be 0 after removal');
        expect(manager.queuedEndpoints, isNot(contains(endpointId)),
          reason: 'Queued endpoints should not contain the endpoint ID after removal');

        // Verify the entry is truly gone by trying to get it
        final entry = manager.getEntryForTesting(endpointId);
        expect(entry, isNull,
          reason: 'Entry should be null after removal');

        // Clean up
        manager.dispose();
      },
      iterations: 100,
    );

    propertyTest(
      'Property 8 (Multiple Endpoints): Successful reconnection removes only the specific endpoint',
      () {
        final manager = ReconnectionManager();

        // Generate multiple random endpoints (2 to 5)
        final numEndpoints = random.nextInt(4) + 2;
        final endpointIds = <String>[];
        
        for (int i = 0; i < numEndpoints; i++) {
          final endpointId = generateRandomString(random);
          final endpointName = generateRandomString(random);
          endpointIds.add(endpointId);
          manager.addToQueue(endpointId, endpointName);
        }

        // Verify all endpoints are in queue
        expect(manager.queueSize, equals(numEndpoints),
          reason: 'All endpoints should be in queue');

        // Pick a random endpoint to "successfully reconnect"
        final reconnectedIndex = random.nextInt(numEndpoints);
        final reconnectedEndpointId = endpointIds[reconnectedIndex];

        // Remove the successfully reconnected endpoint
        manager.removeFromQueue(reconnectedEndpointId);

        // Verify only the reconnected endpoint was removed
        expect(manager.isInQueue(reconnectedEndpointId), isFalse,
          reason: 'Reconnected endpoint should be removed');
        expect(manager.queueSize, equals(numEndpoints - 1),
          reason: 'Queue size should decrease by 1');

        // Verify all other endpoints are still in queue
        for (int i = 0; i < numEndpoints; i++) {
          if (i != reconnectedIndex) {
            expect(manager.isInQueue(endpointIds[i]), isTrue,
              reason: 'Other endpoints should remain in queue');
          }
        }

        // Clean up
        manager.dispose();
      },
      iterations: 100,
    );

    propertyTest(
      'Property 8 (Idempotence): Removing an endpoint multiple times should be safe',
      () {
        final manager = ReconnectionManager();

        // Generate random endpoint data
        final endpointId = generateRandomString(random);
        final endpointName = generateRandomString(random);

        // Add endpoint to queue
        manager.addToQueue(endpointId, endpointName);

        // Verify endpoint is in queue
        expect(manager.isInQueue(endpointId), isTrue,
          reason: 'Endpoint should be in queue');

        // Remove the endpoint
        manager.removeFromQueue(endpointId);

        // Verify endpoint was removed
        expect(manager.isInQueue(endpointId), isFalse,
          reason: 'Endpoint should be removed');
        expect(manager.queueSize, equals(0),
          reason: 'Queue should be empty');

        // Try removing again (should be safe, no error)
        manager.removeFromQueue(endpointId);

        // Verify state is still consistent
        expect(manager.isInQueue(endpointId), isFalse,
          reason: 'Endpoint should still not be in queue');
        expect(manager.queueSize, equals(0),
          reason: 'Queue should still be empty');

        // Clean up
        manager.dispose();
      },
      iterations: 100,
    );

    propertyTest(
      'Property 8 (Non-existent Endpoint): Removing a non-existent endpoint should be safe',
      () {
        final manager = ReconnectionManager();

        // Generate random endpoint IDs
        final existingEndpointId = generateRandomString(random);
        final existingEndpointName = generateRandomString(random);
        final nonExistentEndpointId = generateRandomString(random);

        // Add only one endpoint to queue
        manager.addToQueue(existingEndpointId, existingEndpointName);

        // Verify initial state
        expect(manager.queueSize, equals(1),
          reason: 'Queue should have 1 endpoint');

        // Try to remove a non-existent endpoint (should be safe)
        manager.removeFromQueue(nonExistentEndpointId);

        // Verify the existing endpoint is still in queue
        expect(manager.isInQueue(existingEndpointId), isTrue,
          reason: 'Existing endpoint should remain in queue');
        expect(manager.queueSize, equals(1),
          reason: 'Queue size should still be 1');

        // Clean up
        manager.dispose();
      },
      iterations: 100,
    );

    propertyTest(
      'Property 8 (After Attempts): Successful reconnection can happen at any attempt count',
      () async {
        final manager = ReconnectionManager();

        // Generate random endpoint data
        final endpointId = generateRandomString(random);
        final endpointName = generateRandomString(random);

        // Add endpoint to queue
        manager.addToQueue(endpointId, endpointName);

        // Make a random number of failed attempts (0 to 4)
        final numFailedAttempts = random.nextInt(5);
        
        for (int i = 0; i < numFailedAttempts; i++) {
          final entry = manager.getEntryForTesting(endpointId);
          expect(entry, isNotNull, reason: 'Entry should exist');
          
          // Manipulate time to allow attempt
          entry!.nextAttemptTime = DateTime.now().subtract(Duration(milliseconds: 100));
          
          // Make attempt (but don't succeed yet)
          await manager.attemptReconnections();
        }

        // Verify endpoint is still in queue after failed attempts
        if (numFailedAttempts < 5) {
          expect(manager.isInQueue(endpointId), isTrue,
            reason: 'Endpoint should still be in queue after $numFailedAttempts failed attempts');
        }

        // Now simulate successful reconnection
        if (manager.isInQueue(endpointId)) {
          manager.removeFromQueue(endpointId);

          // Verify endpoint was removed
          expect(manager.isInQueue(endpointId), isFalse,
            reason: 'Endpoint should be removed after successful reconnection');
          expect(manager.queueSize, equals(0),
            reason: 'Queue should be empty');
        }

        // Clean up
        manager.dispose();
      },
      iterations: 100,
    );
  });

  group('ReconnectionManager Unit Tests - Backoff Calculation', () {
    test('Backoff timing: nextAttemptTime should be 5 seconds after incrementAttempt', () {
      final manager = ReconnectionManager();
      
      // Add an endpoint to the queue
      final endpointId = 'test-endpoint-1';
      final endpointName = 'Test Device';
      
      manager.addToQueue(endpointId, endpointName);
      
      // Get the entry
      final entry = manager.getEntryForTesting(endpointId);
      expect(entry, isNotNull, reason: 'Entry should exist in queue');
      
      // Record the time before increment
      final beforeIncrement = DateTime.now();
      
      // Increment the attempt
      entry!.incrementAttempt();
      
      // Record the time after increment
      final afterIncrement = DateTime.now();
      
      // Calculate the expected next attempt time range
      // It should be approximately 5 seconds from now
      final expectedMin = beforeIncrement.add(Duration(seconds: 5));
      final expectedMax = afterIncrement.add(Duration(seconds: 5));
      
      // Verify nextAttemptTime is within the expected range
      expect(entry.nextAttemptTime.isAfter(expectedMin) || 
             entry.nextAttemptTime.isAtSameMomentAs(expectedMin), 
             isTrue,
             reason: 'nextAttemptTime should be at least 5 seconds in the future');
      expect(entry.nextAttemptTime.isBefore(expectedMax) || 
             entry.nextAttemptTime.isAtSameMomentAs(expectedMax), 
             isTrue,
             reason: 'nextAttemptTime should be at most 5 seconds in the future');
      
      // Verify the backoff duration is exactly 5 seconds
      expect(entry.backoffDuration.inSeconds, equals(5),
        reason: 'Backoff duration should be exactly 5 seconds');
      
      manager.dispose();
    });

    test('Backoff timing: Multiple increments should each add 5 seconds', () {
      final manager = ReconnectionManager();
      
      // Add an endpoint to the queue
      final endpointId = 'test-endpoint-2';
      final endpointName = 'Test Device 2';
      
      manager.addToQueue(endpointId, endpointName);
      
      // Get the entry
      final entry = manager.getEntryForTesting(endpointId);
      expect(entry, isNotNull, reason: 'Entry should exist in queue');
      
      // Track the nextAttemptTime after each increment
      final attemptTimes = <DateTime>[];
      
      // Perform 3 increments and record the nextAttemptTime
      for (int i = 0; i < 3; i++) {
        entry!.incrementAttempt();
        attemptTimes.add(entry.nextAttemptTime);
      }
      
      // Verify each increment adds approximately 5 seconds
      for (int i = 0; i < attemptTimes.length - 1; i++) {
        final timeDiff = attemptTimes[i + 1].difference(attemptTimes[i]);
        
        // The difference should be close to 0 (since each increment resets to now + 5s)
        // or close to 5 seconds if there's processing delay
        expect(timeDiff.inSeconds.abs(), lessThanOrEqualTo(1),
          reason: 'Each increment should reset nextAttemptTime to approximately now + 5 seconds');
      }
      
      manager.dispose();
    });

    test('Backoff timing: Backoff duration remains constant at 5 seconds', () {
      final manager = ReconnectionManager();
      
      // Add an endpoint to the queue
      final endpointId = 'test-endpoint-3';
      final endpointName = 'Test Device 3';
      
      manager.addToQueue(endpointId, endpointName);
      
      // Get the entry
      final entry = manager.getEntryForTesting(endpointId);
      expect(entry, isNotNull, reason: 'Entry should exist in queue');
      
      // Verify backoff duration is 5 seconds initially
      expect(entry!.backoffDuration.inSeconds, equals(5),
        reason: 'Initial backoff duration should be 5 seconds');
      
      // Increment multiple times and verify backoff remains constant
      for (int i = 0; i < 4; i++) {
        entry.incrementAttempt();
        expect(entry.backoffDuration.inSeconds, equals(5),
          reason: 'Backoff duration should remain 5 seconds after ${i + 1} attempts');
      }
      
      manager.dispose();
    });

    test('Max retry limit: Entry should be exhausted after 5 attempts', () {
      final manager = ReconnectionManager();
      
      // Add an endpoint to the queue
      final endpointId = 'test-endpoint-4';
      final endpointName = 'Test Device 4';
      
      manager.addToQueue(endpointId, endpointName);
      
      // Get the entry
      final entry = manager.getEntryForTesting(endpointId);
      expect(entry, isNotNull, reason: 'Entry should exist in queue');
      
      // Verify initial state
      expect(entry!.attemptCount, equals(0),
        reason: 'Initial attempt count should be 0');
      expect(entry.isExhausted, isFalse,
        reason: 'Entry should not be exhausted initially');
      
      // Increment 4 times (attempts 1-4)
      for (int i = 0; i < 4; i++) {
        entry.incrementAttempt();
        expect(entry.attemptCount, equals(i + 1),
          reason: 'Attempt count should be ${i + 1}');
        expect(entry.isExhausted, isFalse,
          reason: 'Entry should not be exhausted at ${i + 1} attempts');
      }
      
      // 5th increment should reach the limit
      entry.incrementAttempt();
      expect(entry.attemptCount, equals(5),
        reason: 'Attempt count should be 5');
      expect(entry.isExhausted, isTrue,
        reason: 'Entry should be exhausted at 5 attempts (maxRetries)');
      
      manager.dispose();
    });

    test('Max retry limit: shouldAttemptReconnection returns false when exhausted', () {
      final manager = ReconnectionManager();
      
      // Add an endpoint to the queue
      final endpointId = 'test-endpoint-5';
      final endpointName = 'Test Device 5';
      
      manager.addToQueue(endpointId, endpointName);
      
      // Get the entry
      final entry = manager.getEntryForTesting(endpointId);
      expect(entry, isNotNull, reason: 'Entry should exist in queue');
      
      // Set nextAttemptTime to the past to allow attempts
      entry!.nextAttemptTime = DateTime.now().subtract(Duration(seconds: 1));
      
      // Should allow attempts initially
      expect(manager.shouldAttemptReconnection(entry), isTrue,
        reason: 'Should allow reconnection when not exhausted');
      
      // Increment to max retries
      for (int i = 0; i < 5; i++) {
        entry.incrementAttempt();
      }
      
      // Set nextAttemptTime to the past again
      entry.nextAttemptTime = DateTime.now().subtract(Duration(seconds: 1));
      
      // Should not allow attempts when exhausted
      expect(manager.shouldAttemptReconnection(entry), isFalse,
        reason: 'Should not allow reconnection when exhausted (5 attempts)');
      
      manager.dispose();
    });

    test('Max retry limit: Exhausted entries are removed from queue during attemptReconnections', () async {
      final manager = ReconnectionManager();
      
      // Add an endpoint to the queue
      final endpointId = 'test-endpoint-6';
      final endpointName = 'Test Device 6';
      
      bool exhaustedCallbackCalled = false;
      String? exhaustedEndpointId;
      
      manager.onReconnectExhausted = (id) {
        exhaustedCallbackCalled = true;
        exhaustedEndpointId = id;
      };
      
      manager.addToQueue(endpointId, endpointName);
      
      // Verify entry is in queue
      expect(manager.isInQueue(endpointId), isTrue,
        reason: 'Entry should be in queue initially');
      
      // Get the entry and increment to 4 attempts
      final entry = manager.getEntryForTesting(endpointId);
      expect(entry, isNotNull, reason: 'Entry should exist');
      
      for (int i = 0; i < 4; i++) {
        entry!.incrementAttempt();
      }
      
      // Set nextAttemptTime to the past to trigger the 5th attempt
      entry!.nextAttemptTime = DateTime.now().subtract(Duration(seconds: 1));
      
      // Attempt reconnections - this should trigger the 5th attempt and removal
      await manager.attemptReconnections();
      
      // Verify the entry was removed from queue
      expect(manager.isInQueue(endpointId), isFalse,
        reason: 'Entry should be removed from queue after 5th attempt');
      
      // Verify the exhausted callback was called
      expect(exhaustedCallbackCalled, isTrue,
        reason: 'onReconnectExhausted callback should be called');
      expect(exhaustedEndpointId, equals(endpointId),
        reason: 'Callback should receive the correct endpoint ID');
      
      manager.dispose();
    });

    test('Max retry limit: Constant maxRetries value is 5', () {
      // Verify the constant is set correctly
      expect(ReconnectionManager.maxRetries, equals(5),
        reason: 'maxRetries constant should be 5');
    });

    test('Backoff timing: Constant retryIntervalSeconds value is 5', () {
      // Verify the constant is set correctly
      expect(ReconnectionManager.retryIntervalSeconds, equals(5),
        reason: 'retryIntervalSeconds constant should be 5');
    });
  });
}
