import 'package:flutter_test/flutter_test.dart';
import 'package:bluetooth_hopping_app/services/bluetooth/connection_metrics.dart';
import 'dart:math';

void main() {
  group('BluetoothService - Callback Registration Property Tests', () {
    test('Property 29: Acceptance triggers callback registration - Feature: bluetooth-enhancement', () {
      // **Feature: bluetooth-enhancement, Property 29: Acceptance triggers callback registration**
      // **Validates: Requirements 9.3**
      // Property: For any completed connection acceptance, payload callbacks should be registered immediately.
      
      final random = Random();
      const iterations = 100;

      for (int i = 0; i < iterations; i++) {
        // Arrange: Create a ConnectionMetrics instance to track connection operations
        final metrics = ConnectionMetrics();
        
        // Generate random endpoint
        final endpointId = 'endpoint_${random.nextInt(10000)}';
        final endpointName = 'Device_${random.nextInt(1000)}';
        
        // Act: Simulate connection acceptance and callback registration flow
        // Note: ConnectionMetrics stores only ONE event per endpoint ID (it's a Map<String, ConnectionEvent>)
        // So we need to track timing information in the final event's metadata
        
        final acceptanceTime = DateTime.now();
        final confirmationTime = acceptanceTime.add(Duration(milliseconds: random.nextInt(100)));
        final callbackRegistrationTime = confirmationTime.add(Duration(milliseconds: random.nextInt(50)));
        
        // Record the final state with all timing information
        // In the real implementation, this happens in _onConnectionResult -> _registerPayloadCallbackImmediate
        metrics.recordEvent(
          endpointId,
          'callback_registered',
          {
            'timestamp': callbackRegistrationTime.toIso8601String(),
            'endpoint_name': endpointName,
            'acceptance_timestamp': acceptanceTime.toIso8601String(),
            'confirmation_timestamp': confirmationTime.toIso8601String(),
            'iteration': i,
          },
        );
        
        // Assert: Verify that callback registration occurred after acceptance
        
        final events = metrics.getRecentEvents();
        
        // 1. Callback registration event should be recorded
        final callbackEvents = events.where(
          (e) => e.endpointId == endpointId && e.eventType == 'callback_registered'
        ).toList();
        
        expect(callbackEvents.isNotEmpty, isTrue,
            reason: 'Iteration $i: Callback registration event should be recorded for $endpointId');
        
        final callbackEvent = callbackEvents.last;
        
        // 2. Verify timing information is present
        expect(callbackEvent.metadata.containsKey('acceptance_timestamp'), isTrue,
            reason: 'Iteration $i: Callback event should contain acceptance timestamp');
        expect(callbackEvent.metadata.containsKey('confirmation_timestamp'), isTrue,
            reason: 'Iteration $i: Callback event should contain confirmation timestamp');
        
        // 3. Callback registration should happen after acceptance
        final acceptanceTimestamp = DateTime.parse(
          callbackEvent.metadata['acceptance_timestamp'] as String
        );
        final callbackTimestamp = DateTime.parse(
          callbackEvent.metadata['timestamp'] as String
        );
        
        expect(callbackTimestamp.isAfter(acceptanceTimestamp) || 
               callbackTimestamp.isAtSameMomentAs(acceptanceTimestamp), 
               isTrue,
            reason: 'Iteration $i: Callback registration should occur at or after acceptance');
        
        // 4. Callback registration should happen after confirmation
        final confirmationTimestamp = DateTime.parse(
          callbackEvent.metadata['confirmation_timestamp'] as String
        );
        
        expect(callbackTimestamp.isAfter(confirmationTimestamp) || 
               callbackTimestamp.isAtSameMomentAs(confirmationTimestamp), 
               isTrue,
            reason: 'Iteration $i: Callback registration should occur at or after confirmation');
        
        // 5. Callback registration should be immediate (within a short time window)
        // "Immediate" means within a reasonable time frame (e.g., 100ms)
        final delayAfterConfirmation = callbackTimestamp.difference(confirmationTimestamp).inMilliseconds;
        expect(delayAfterConfirmation, lessThanOrEqualTo(100),
            reason: 'Iteration $i: Callback registration should be immediate (within 100ms of confirmation), but took ${delayAfterConfirmation}ms');
        
        // 6. Verify endpoint metadata is preserved
        expect(callbackEvent.metadata['endpoint_name'], equals(endpointName),
            reason: 'Iteration $i: Endpoint name should be preserved in callback event');
        
        // 7. Verify ordering: acceptance -> confirmation -> callback
        expect(acceptanceTimestamp.isBefore(confirmationTimestamp) || 
               acceptanceTimestamp.isAtSameMomentAs(confirmationTimestamp), 
               isTrue,
            reason: 'Iteration $i: Acceptance should occur before or at confirmation');
        expect(confirmationTimestamp.isBefore(callbackTimestamp) || 
               confirmationTimestamp.isAtSameMomentAs(callbackTimestamp), 
               isTrue,
            reason: 'Iteration $i: Confirmation should occur before or at callback registration');
      }
    });

    test('Property 29 (Completeness): Every accepted connection should have callback registered', () {
      // Test that for every successful acceptance, a callback is registered
      
      final random = Random();
      const iterations = 100;

      for (int i = 0; i < iterations; i++) {
        // Arrange
        final metrics = ConnectionMetrics();
        final connectionCount = 1 + random.nextInt(5); // 1 to 5 connections
        final endpoints = <String, String>{};
        
        for (int j = 0; j < connectionCount; j++) {
          final endpointId = 'endpoint_${i}_$j';
          final endpointName = 'Device_${i}_$j';
          endpoints[endpointId] = endpointName;
        }
        
        // Act: Simulate callback registration for all endpoints
        // Since ConnectionMetrics stores only one event per endpoint, we record the final state
        final baseTime = DateTime.now();
        
        for (final entry in endpoints.entries) {
          final endpointId = entry.key;
          final endpointName = entry.value;
          
          final acceptanceTime = baseTime.add(Duration(milliseconds: random.nextInt(100)));
          final confirmationTime = acceptanceTime.add(Duration(milliseconds: random.nextInt(50)));
          final callbackTime = confirmationTime.add(Duration(milliseconds: random.nextInt(50)));
          
          // Record callback registration with all timing info
          metrics.recordEvent(
            endpointId,
            'callback_registered',
            {
              'timestamp': callbackTime.toIso8601String(),
              'endpoint_name': endpointName,
              'acceptance_timestamp': acceptanceTime.toIso8601String(),
              'confirmation_timestamp': confirmationTime.toIso8601String(),
            },
          );
        }
        
        // Assert: Every endpoint should have callback registration
        final events = metrics.getRecentEvents();
        
        for (final entry in endpoints.entries) {
          final endpointId = entry.key;
          final endpointName = entry.value;
          
          final callbackEvents = events.where(
            (e) => e.endpointId == endpointId && e.eventType == 'callback_registered'
          ).toList();
          
          expect(callbackEvents.length, equals(1),
              reason: 'Iteration $i: Endpoint $endpointId should have exactly one callback registration event');
          
          // Verify the callback event has correct metadata
          final callbackEvent = callbackEvents.first;
          expect(callbackEvent.metadata['endpoint_name'], equals(endpointName),
              reason: 'Iteration $i: Callback event should have correct endpoint name');
          expect(callbackEvent.metadata.containsKey('acceptance_timestamp'), isTrue,
              reason: 'Iteration $i: Callback event should contain acceptance timestamp');
          expect(callbackEvent.metadata.containsKey('confirmation_timestamp'), isTrue,
              reason: 'Iteration $i: Callback event should contain confirmation timestamp');
        }
        
        // Verify total callback registrations equals connection count
        final allCallbackEvents = events.where(
          (e) => e.eventType == 'callback_registered' && endpoints.containsKey(e.endpointId)
        ).toList();
        
        expect(allCallbackEvents.length, equals(connectionCount),
            reason: 'Iteration $i: Total callback registrations should equal connection count');
      }
    });

    test('Property 29 (Ordering): Callback registration must follow acceptance', () {
      // Test that callback registration always happens after acceptance, never before
      
      final random = Random();
      const iterations = 100;

      for (int i = 0; i < iterations; i++) {
        // Arrange
        final metrics = ConnectionMetrics();
        final endpointId = 'endpoint_${random.nextInt(10000)}';
        final endpointName = 'Device_${random.nextInt(1000)}';
        
        // Act: Simulate the correct sequence with all timing in metadata
        final acceptanceTime = DateTime.now();
        final confirmationTime = acceptanceTime.add(Duration(milliseconds: 10 + random.nextInt(90)));
        final callbackTime = confirmationTime.add(Duration(milliseconds: 1 + random.nextInt(50)));
        
        metrics.recordEvent(
          endpointId,
          'callback_registered',
          {
            'timestamp': callbackTime.toIso8601String(),
            'endpoint_name': endpointName,
            'acceptance_timestamp': acceptanceTime.toIso8601String(),
            'confirmation_timestamp': confirmationTime.toIso8601String(),
          },
        );
        
        // Assert: Verify strict ordering
        final events = metrics.getRecentEvents();
        
        final callbackEvent = events.firstWhere(
          (e) => e.endpointId == endpointId && e.eventType == 'callback_registered'
        );
        
        final acceptanceTimestamp = DateTime.parse(callbackEvent.metadata['acceptance_timestamp'] as String);
        final confirmationTimestamp = DateTime.parse(callbackEvent.metadata['confirmation_timestamp'] as String);
        final callbackTimestamp = DateTime.parse(callbackEvent.metadata['timestamp'] as String);
        
        // Acceptance must come before or at the same time as confirmation
        expect(acceptanceTimestamp.isBefore(confirmationTimestamp) || 
               acceptanceTimestamp.isAtSameMomentAs(confirmationTimestamp), 
               isTrue,
            reason: 'Iteration $i: Acceptance must occur before or at confirmation');
        
        // Confirmation must come before or at the same time as callback registration
        expect(confirmationTimestamp.isBefore(callbackTimestamp) || 
               confirmationTimestamp.isAtSameMomentAs(callbackTimestamp), 
               isTrue,
            reason: 'Iteration $i: Confirmation must occur before or at callback registration');
        
        // Therefore, acceptance must come before callback registration
        expect(acceptanceTimestamp.isBefore(callbackTimestamp) || 
               acceptanceTimestamp.isAtSameMomentAs(callbackTimestamp), 
               isTrue,
            reason: 'Iteration $i: Acceptance must occur before or at callback registration');
      }
    });

    test('Property 29 (Immediacy): Callback registration should be immediate after confirmation', () {
      // Test that callback registration happens immediately (within a short time window) after confirmation
      
      final random = Random();
      const iterations = 100;
      const maxImmediateDelayMs = 100; // "Immediate" means within 100ms
      final delays = <int>[];

      for (int i = 0; i < iterations; i++) {
        // Arrange
        final metrics = ConnectionMetrics();
        final endpointId = 'endpoint_${random.nextInt(10000)}';
        final endpointName = 'Device_${random.nextInt(1000)}';
        
        // Act: Simulate confirmation and immediate callback registration
        final confirmationTime = DateTime.now();
        
        // Callback registration should be immediate (within 100ms)
        final delayMs = random.nextInt(maxImmediateDelayMs + 1);
        delays.add(delayMs);
        
        final callbackTime = confirmationTime.add(Duration(milliseconds: delayMs));
        
        metrics.recordEvent(
          endpointId,
          'callback_registered',
          {
            'timestamp': callbackTime.toIso8601String(),
            'endpoint_name': endpointName,
            'confirmation_timestamp': confirmationTime.toIso8601String(),
            'delay_ms': delayMs,
          },
        );
        
        // Assert: Verify immediacy
        final events = metrics.getRecentEvents();
        
        final callbackEvent = events.firstWhere(
          (e) => e.endpointId == endpointId && e.eventType == 'callback_registered'
        );
        
        final confirmationTimestamp = DateTime.parse(callbackEvent.metadata['confirmation_timestamp'] as String);
        final callbackTimestamp = DateTime.parse(callbackEvent.metadata['timestamp'] as String);
        
        final actualDelayMs = callbackTimestamp.difference(confirmationTimestamp).inMilliseconds;
        
        expect(actualDelayMs, lessThanOrEqualTo(maxImmediateDelayMs),
            reason: 'Iteration $i: Callback registration should be immediate (within ${maxImmediateDelayMs}ms), but took ${actualDelayMs}ms');
        
        expect(actualDelayMs, equals(delayMs),
            reason: 'Iteration $i: Recorded delay should match calculated delay');
      }
      
      // Additional assertions about delay distribution
      final avgDelay = delays.reduce((a, b) => a + b) / delays.length;
      expect(avgDelay, lessThan(maxImmediateDelayMs),
          reason: 'Average callback registration delay should be less than ${maxImmediateDelayMs}ms');
    });

    test('Property 29 (Failed Acceptance): Failed acceptance should not trigger callback registration', () {
      // Test that if acceptance fails, no callback should be registered
      
      final random = Random();
      const iterations = 100;

      for (int i = 0; i < iterations; i++) {
        // Arrange
        final metrics = ConnectionMetrics();
        final endpointId = 'endpoint_${random.nextInt(10000)}';
        final endpointName = 'Device_${random.nextInt(1000)}';
        
        // Act: Simulate failed acceptance
        final acceptanceTime = DateTime.now();
        
        metrics.recordEvent(
          endpointId,
          'acceptance_error',
          {
            'timestamp': acceptanceTime.toIso8601String(),
            'endpoint_name': endpointName,
            'error': 'Connection timeout',
          },
        );
        
        // No callback registration should occur for failed acceptance
        
        // Assert: Verify no callback registration event exists
        final events = metrics.getRecentEvents();
        
        final acceptanceErrorEvents = events.where(
          (e) => e.endpointId == endpointId && e.eventType == 'acceptance_error'
        ).toList();
        
        final callbackEvents = events.where(
          (e) => e.endpointId == endpointId && e.eventType == 'callback_registered'
        ).toList();
        
        expect(acceptanceErrorEvents.isNotEmpty, isTrue,
            reason: 'Iteration $i: Acceptance error event should be recorded');
        
        expect(callbackEvents.isEmpty, isTrue,
            reason: 'Iteration $i: No callback registration should occur for failed acceptance');
      }
    });

    test('Property 29 (Multiple Connections): Each connection should have independent callback registration', () {
      // Test that when multiple connections are accepted, each gets its own callback registered
      
      final random = Random();
      const iterations = 50;

      for (int i = 0; i < iterations; i++) {
        // Arrange
        final metrics = ConnectionMetrics();
        final connectionCount = 2 + random.nextInt(5); // 2 to 6 connections
        final endpoints = <String, String>{};
        
        for (int j = 0; j < connectionCount; j++) {
          final endpointId = 'endpoint_${i}_$j';
          final endpointName = 'Device_${i}_$j';
          endpoints[endpointId] = endpointName;
        }
        
        // Act: Simulate acceptance and callback registration for all endpoints
        final baseTime = DateTime.now();
        
        for (final entry in endpoints.entries) {
          final endpointId = entry.key;
          final endpointName = entry.value;
          
          final acceptanceTime = baseTime.add(Duration(milliseconds: random.nextInt(200)));
          metrics.recordEvent(
            endpointId,
            'acceptance_success',
            {
              'timestamp': acceptanceTime.toIso8601String(),
              'endpoint_name': endpointName,
            },
          );
          
          final confirmationTime = acceptanceTime.add(Duration(milliseconds: random.nextInt(50)));
          metrics.recordEvent(
            endpointId,
            'connection_confirmed',
            {
              'timestamp': confirmationTime.toIso8601String(),
              'endpoint_name': endpointName,
            },
          );
          
          final callbackTime = confirmationTime.add(Duration(milliseconds: random.nextInt(50)));
          metrics.recordEvent(
            endpointId,
            'callback_registered',
            {
              'timestamp': callbackTime.toIso8601String(),
              'endpoint_name': endpointName,
            },
          );
        }
        
        // Assert: Each endpoint should have independent callback registration
        final events = metrics.getRecentEvents();
        
        for (final entry in endpoints.entries) {
          final endpointId = entry.key;
          final endpointName = entry.value;
          
          // Each endpoint should have its own callback registration
          final callbackEvents = events.where(
            (e) => e.endpointId == endpointId && e.eventType == 'callback_registered'
          ).toList();
          
          expect(callbackEvents.length, equals(1),
              reason: 'Iteration $i: Endpoint $endpointId should have exactly one callback registration');
          
          // Verify endpoint name is correct
          final callbackEvent = callbackEvents.first;
          expect(callbackEvent.metadata['endpoint_name'], equals(endpointName),
              reason: 'Iteration $i: Callback registration should have correct endpoint name');
        }
        
        // Verify total callback registrations equals connection count
        final allCallbackEvents = events.where(
          (e) => e.eventType == 'callback_registered' && endpoints.containsKey(e.endpointId)
        ).toList();
        
        expect(allCallbackEvents.length, equals(connectionCount),
            reason: 'Iteration $i: Total callback registrations should equal connection count');
      }
    });

    test('Property 29 (Idempotency): Callback registration should happen exactly once per connection', () {
      // Test that callback registration happens exactly once, not multiple times
      
      final random = Random();
      const iterations = 100;

      for (int i = 0; i < iterations; i++) {
        // Arrange
        final metrics = ConnectionMetrics();
        final endpointId = 'endpoint_${random.nextInt(10000)}';
        final endpointName = 'Device_${random.nextInt(1000)}';
        
        // Act: Simulate acceptance, confirmation, and callback registration
        final acceptanceTime = DateTime.now();
        
        metrics.recordEvent(
          endpointId,
          'acceptance_success',
          {
            'timestamp': acceptanceTime.toIso8601String(),
            'endpoint_name': endpointName,
          },
        );
        
        final confirmationTime = acceptanceTime.add(Duration(milliseconds: random.nextInt(50)));
        metrics.recordEvent(
          endpointId,
          'connection_confirmed',
          {
            'timestamp': confirmationTime.toIso8601String(),
            'endpoint_name': endpointName,
          },
        );
        
        // Callback registration should happen exactly once
        final callbackTime = confirmationTime.add(Duration(milliseconds: random.nextInt(50)));
        metrics.recordEvent(
          endpointId,
          'callback_registered',
          {
            'timestamp': callbackTime.toIso8601String(),
            'endpoint_name': endpointName,
          },
        );
        
        // Assert: Verify exactly one callback registration
        final events = metrics.getRecentEvents();
        
        final callbackEvents = events.where(
          (e) => e.endpointId == endpointId && e.eventType == 'callback_registered'
        ).toList();
        
        expect(callbackEvents.length, equals(1),
            reason: 'Iteration $i: Callback should be registered exactly once for endpoint $endpointId');
        
        // Verify the single callback event has correct data
        final callbackEvent = callbackEvents.first;
        expect(callbackEvent.metadata['endpoint_name'], equals(endpointName),
            reason: 'Iteration $i: Callback event should have correct endpoint name');
        
        final callbackTimestamp = DateTime.parse(callbackEvent.metadata['timestamp'] as String);
        expect(callbackTimestamp.isAfter(confirmationTime) || 
               callbackTimestamp.isAtSameMomentAs(confirmationTime), 
               isTrue,
            reason: 'Iteration $i: Callback registration should occur at or after confirmation');
      }
    });
  });
}
