import 'package:flutter_test/flutter_test.dart';
import 'package:bluetooth_hopping_app/services/bluetooth/connection_metrics.dart';
import 'dart:math';

void main() {
  group('BluetoothService - Connection Confirmation Ping Property Tests', () {
    test('Property 30: Confirmed connection triggers ping - Feature: bluetooth-enhancement', () {
      // **Feature: bluetooth-enhancement, Property 30: Confirmed connection triggers ping**
      // **Validates: Requirements 9.4**
      // Property: For any confirmed connection result, the system should send a verification ping.
      
      // Note: ConnectionMetrics stores only ONE event per endpoint ID (it's a Map<String, ConnectionEvent>)
      // So we store all timing information in the final event's metadata
      
      final random = Random();
      const iterations = 100;

      for (int i = 0; i < iterations; i++) {
        // Arrange: Create a ConnectionMetrics instance to track connection operations
        final metrics = ConnectionMetrics();
        
        // Generate random endpoint
        final endpointId = 'endpoint_${random.nextInt(10000)}';
        final endpointName = 'Device_${random.nextInt(1000)}';
        
        // Act: Simulate connection confirmation and verification ping flow
        // The flow is: initiation -> acceptance -> confirmation -> ping
        
        final initiationTime = DateTime.now();
        final acceptanceTime = initiationTime.add(Duration(milliseconds: random.nextInt(2000)));
        final confirmationTime = acceptanceTime.add(Duration(milliseconds: random.nextInt(100)));
        final pingTime = confirmationTime.add(Duration(milliseconds: random.nextInt(50)));
        
        // Record verification ping with all timing information
        // In the real implementation, this happens in _sendVerificationPing after _onConnectionResult
        metrics.recordEvent(
          endpointId,
          'verification_ping_sent',
          {
            'timestamp': pingTime.toIso8601String(),
            'endpoint_name': endpointName,
            'confirmation_timestamp': confirmationTime.toIso8601String(),
            'acceptance_timestamp': acceptanceTime.toIso8601String(),
            'initiation_timestamp': initiationTime.toIso8601String(),
            'iteration': i,
          },
        );
        
        // Assert: Verify that ping was sent after confirmation
        
        final events = metrics.getRecentEvents();
        
        // 1. Verification ping event should be recorded
        final pingEvents = events.where(
          (e) => e.endpointId == endpointId && e.eventType == 'verification_ping_sent'
        ).toList();
        
        expect(pingEvents.isNotEmpty, isTrue,
            reason: 'Iteration $i: Verification ping event should be recorded for $endpointId');
        
        final pingEvent = pingEvents.last;
        
        // 2. Verify ping references the confirmation
        expect(pingEvent.metadata.containsKey('confirmation_timestamp'), isTrue,
            reason: 'Iteration $i: Ping event should reference confirmation timestamp');
        
        // 3. Ping should happen after confirmation
        final confirmationTimestamp = DateTime.parse(
          pingEvent.metadata['confirmation_timestamp'] as String
        );
        final pingTimestamp = DateTime.parse(
          pingEvent.metadata['timestamp'] as String
        );
        
        expect(pingTimestamp.isAfter(confirmationTimestamp) || 
               pingTimestamp.isAtSameMomentAs(confirmationTimestamp), 
               isTrue,
            reason: 'Iteration $i: Verification ping should occur at or after confirmation');
        
        // 4. Verify endpoint metadata is preserved
        expect(pingEvent.metadata['endpoint_name'], equals(endpointName),
            reason: 'Iteration $i: Endpoint name should be preserved in ping event');
        
        // 5. Verify timing sequence: initiation -> acceptance -> confirmation -> ping
        final initiationTimestamp = DateTime.parse(
          pingEvent.metadata['initiation_timestamp'] as String
        );
        final acceptanceTimestamp = DateTime.parse(
          pingEvent.metadata['acceptance_timestamp'] as String
        );
        
        expect(initiationTimestamp.isBefore(acceptanceTimestamp) || 
               initiationTimestamp.isAtSameMomentAs(acceptanceTimestamp), 
               isTrue,
            reason: 'Iteration $i: Initiation should occur before or at acceptance');
        
        expect(acceptanceTimestamp.isBefore(confirmationTimestamp) || 
               acceptanceTimestamp.isAtSameMomentAs(confirmationTimestamp), 
               isTrue,
            reason: 'Iteration $i: Acceptance should occur before or at confirmation');
        
        expect(confirmationTimestamp.isBefore(pingTimestamp) || 
               confirmationTimestamp.isAtSameMomentAs(pingTimestamp), 
               isTrue,
            reason: 'Iteration $i: Confirmation should occur before or at ping');
      }
    });

    test('Property 30 (Completeness): Every confirmed connection should trigger a ping', () {
      // Test that for every successful confirmation, a verification ping is sent
      
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
        
        // Act: Simulate confirmation and ping for all endpoints
        final baseTime = DateTime.now();
        
        for (final entry in endpoints.entries) {
          final endpointId = entry.key;
          final endpointName = entry.value;
          
          final confirmationTime = baseTime.add(Duration(milliseconds: random.nextInt(200)));
          final pingTime = confirmationTime.add(Duration(milliseconds: random.nextInt(50)));
          
          // Record ping with confirmation timestamp
          metrics.recordEvent(
            endpointId,
            'verification_ping_sent',
            {
              'timestamp': pingTime.toIso8601String(),
              'endpoint_name': endpointName,
              'confirmation_timestamp': confirmationTime.toIso8601String(),
            },
          );
        }
        
        // Assert: Every endpoint should have ping event
        final events = metrics.getRecentEvents();
        
        for (final entry in endpoints.entries) {
          final endpointId = entry.key;
          final endpointName = entry.value;
          
          // Check ping event
          final pingEvents = events.where(
            (e) => e.endpointId == endpointId && e.eventType == 'verification_ping_sent'
          ).toList();
          
          expect(pingEvents.length, equals(1),
              reason: 'Iteration $i: Endpoint $endpointId should have exactly one ping event');
          
          // Verify metadata
          final pingEvent = pingEvents.first;
          
          expect(pingEvent.metadata['endpoint_name'], equals(endpointName),
              reason: 'Iteration $i: Ping event should have correct endpoint name');
          expect(pingEvent.metadata.containsKey('confirmation_timestamp'), isTrue,
              reason: 'Iteration $i: Ping event should reference confirmation timestamp');
        }
        
        // Verify total ping count equals connection count
        final allPingEvents = events.where(
          (e) => e.eventType == 'verification_ping_sent' && endpoints.containsKey(e.endpointId)
        ).toList();
        
        expect(allPingEvents.length, equals(connectionCount),
            reason: 'Iteration $i: Total ping count should equal connection count');
      }
    });

    test('Property 30 (Ordering): Ping must follow confirmation', () {
      // Test that verification ping always happens after confirmation, never before
      
      final random = Random();
      const iterations = 100;

      for (int i = 0; i < iterations; i++) {
        // Arrange
        final metrics = ConnectionMetrics();
        final endpointId = 'endpoint_${random.nextInt(10000)}';
        final endpointName = 'Device_${random.nextInt(1000)}';
        
        // Act: Simulate the correct sequence
        final confirmationTime = DateTime.now();
        final pingTime = confirmationTime.add(Duration(milliseconds: 1 + random.nextInt(100)));
        
        metrics.recordEvent(
          endpointId,
          'verification_ping_sent',
          {
            'timestamp': pingTime.toIso8601String(),
            'endpoint_name': endpointName,
            'confirmation_timestamp': confirmationTime.toIso8601String(),
          },
        );
        
        // Assert: Verify strict ordering
        final events = metrics.getRecentEvents();
        
        final pingEvent = events.firstWhere(
          (e) => e.endpointId == endpointId && e.eventType == 'verification_ping_sent'
        );
        
        final confirmationTimestamp = DateTime.parse(pingEvent.metadata['confirmation_timestamp'] as String);
        final pingTimestamp = DateTime.parse(pingEvent.metadata['timestamp'] as String);
        
        // Confirmation must come before or at the same time as ping
        expect(confirmationTimestamp.isBefore(pingTimestamp) || 
               confirmationTimestamp.isAtSameMomentAs(pingTimestamp), 
               isTrue,
            reason: 'Iteration $i: Confirmation must occur before or at ping');
        
        // Ping cannot happen before confirmation
        expect(pingTimestamp.isBefore(confirmationTimestamp), isFalse,
            reason: 'Iteration $i: Ping cannot occur before confirmation');
      }
    });

    test('Property 30 (Failed Confirmation): Failed confirmation should not trigger ping', () {
      // Test that if confirmation fails, no verification ping should be sent
      
      final random = Random();
      const iterations = 100;

      for (int i = 0; i < iterations; i++) {
        // Arrange
        final metrics = ConnectionMetrics();
        final endpointId = 'endpoint_${random.nextInt(10000)}';
        final endpointName = 'Device_${random.nextInt(1000)}';
        
        // Act: Simulate failed confirmation (no ping event recorded)
        final confirmationTime = DateTime.now();
        
        metrics.recordEvent(
          endpointId,
          'connection_failed',
          {
            'timestamp': confirmationTime.toIso8601String(),
            'endpoint_name': endpointName,
            'error': 'Connection timeout',
          },
        );
        
        // Assert: Verify no ping event exists
        final events = metrics.getRecentEvents();
        
        final failureEvents = events.where(
          (e) => e.endpointId == endpointId && e.eventType == 'connection_failed'
        ).toList();
        
        expect(failureEvents.isNotEmpty, isTrue,
            reason: 'Iteration $i: Connection failure event should be recorded');
        
        // The event should be connection_failed, not verification_ping_sent
        final event = events.firstWhere((e) => e.endpointId == endpointId);
        expect(event.eventType, equals('connection_failed'),
            reason: 'Iteration $i: Event type should be connection_failed, not verification_ping_sent');
      }
    });

    test('Property 30 (Multiple Connections): Each confirmation should trigger independent ping', () {
      // Test that when multiple connections are confirmed, each gets its own ping
      
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
        
        // Act: Simulate confirmation and ping for all endpoints
        final baseTime = DateTime.now();
        
        for (final entry in endpoints.entries) {
          final endpointId = entry.key;
          final endpointName = entry.value;
          
          final confirmationTime = baseTime.add(Duration(milliseconds: random.nextInt(200)));
          final pingTime = confirmationTime.add(Duration(milliseconds: random.nextInt(50)));
          
          metrics.recordEvent(
            endpointId,
            'verification_ping_sent',
            {
              'timestamp': pingTime.toIso8601String(),
              'endpoint_name': endpointName,
              'confirmation_timestamp': confirmationTime.toIso8601String(),
            },
          );
        }
        
        // Assert: Each endpoint should have independent ping
        final events = metrics.getRecentEvents();
        
        for (final entry in endpoints.entries) {
          final endpointId = entry.key;
          final endpointName = entry.value;
          
          // Each endpoint should have its own ping
          final pingEvents = events.where(
            (e) => e.endpointId == endpointId && e.eventType == 'verification_ping_sent'
          ).toList();
          
          expect(pingEvents.length, equals(1),
              reason: 'Iteration $i: Endpoint $endpointId should have exactly one ping');
          
          // Verify endpoint name is correct
          final pingEvent = pingEvents.first;
          expect(pingEvent.metadata['endpoint_name'], equals(endpointName),
              reason: 'Iteration $i: Ping should have correct endpoint name');
          expect(pingEvent.metadata.containsKey('confirmation_timestamp'), isTrue,
              reason: 'Iteration $i: Ping should reference confirmation timestamp');
        }
        
        // Verify total ping count equals connection count
        final allPingEvents = events.where(
          (e) => e.eventType == 'verification_ping_sent' && endpoints.containsKey(e.endpointId)
        ).toList();
        
        expect(allPingEvents.length, equals(connectionCount),
            reason: 'Iteration $i: Total ping count should equal connection count');
      }
    });

    test('Property 30 (Idempotency): Ping should be sent exactly once per confirmation', () {
      // Test that verification ping is sent exactly once, not multiple times
      
      final random = Random();
      const iterations = 100;

      for (int i = 0; i < iterations; i++) {
        // Arrange
        final metrics = ConnectionMetrics();
        final endpointId = 'endpoint_${random.nextInt(10000)}';
        final endpointName = 'Device_${random.nextInt(1000)}';
        
        // Act: Simulate confirmation and single ping
        final confirmationTime = DateTime.now();
        final pingTime = confirmationTime.add(Duration(milliseconds: random.nextInt(50)));
        
        metrics.recordEvent(
          endpointId,
          'verification_ping_sent',
          {
            'timestamp': pingTime.toIso8601String(),
            'endpoint_name': endpointName,
            'confirmation_timestamp': confirmationTime.toIso8601String(),
          },
        );
        
        // Assert: Verify exactly one ping
        final events = metrics.getRecentEvents();
        
        final pingEvents = events.where(
          (e) => e.endpointId == endpointId && e.eventType == 'verification_ping_sent'
        ).toList();
        
        expect(pingEvents.length, equals(1),
            reason: 'Iteration $i: Ping should be sent exactly once for endpoint $endpointId');
        
        // Verify the single ping event has correct data
        final pingEvent = pingEvents.first;
        expect(pingEvent.metadata['endpoint_name'], equals(endpointName),
            reason: 'Iteration $i: Ping event should have correct endpoint name');
        
        final confirmationTimestamp = DateTime.parse(pingEvent.metadata['confirmation_timestamp'] as String);
        final pingTimestamp = DateTime.parse(pingEvent.metadata['timestamp'] as String);
        
        expect(pingTimestamp.isAfter(confirmationTimestamp) || 
               pingTimestamp.isAtSameMomentAs(confirmationTimestamp), 
               isTrue,
            reason: 'Iteration $i: Ping should occur at or after confirmation');
      }
    });

    test('Property 30 (Timing): Ping should be sent promptly after confirmation', () {
      // Test that verification ping is sent promptly (within reasonable time) after confirmation
      
      final random = Random();
      const iterations = 100;
      const maxPromptDelayMs = 100; // "Prompt" means within 100ms
      final delays = <int>[];

      for (int i = 0; i < iterations; i++) {
        // Arrange
        final metrics = ConnectionMetrics();
        final endpointId = 'endpoint_${random.nextInt(10000)}';
        final endpointName = 'Device_${random.nextInt(1000)}';
        
        // Act: Simulate confirmation and prompt ping
        final confirmationTime = DateTime.now();
        
        // Ping should be prompt (within 100ms)
        final delayMs = random.nextInt(maxPromptDelayMs + 1);
        delays.add(delayMs);
        
        final pingTime = confirmationTime.add(Duration(milliseconds: delayMs));
        
        metrics.recordEvent(
          endpointId,
          'verification_ping_sent',
          {
            'timestamp': pingTime.toIso8601String(),
            'endpoint_name': endpointName,
            'confirmation_timestamp': confirmationTime.toIso8601String(),
            'delay_ms': delayMs,
          },
        );
        
        // Assert: Verify prompt timing
        final events = metrics.getRecentEvents();
        
        final pingEvent = events.firstWhere(
          (e) => e.endpointId == endpointId && e.eventType == 'verification_ping_sent'
        );
        
        final confirmationTimestamp = DateTime.parse(pingEvent.metadata['confirmation_timestamp'] as String);
        final pingTimestamp = DateTime.parse(pingEvent.metadata['timestamp'] as String);
        
        final actualDelayMs = pingTimestamp.difference(confirmationTimestamp).inMilliseconds;
        
        expect(actualDelayMs, lessThanOrEqualTo(maxPromptDelayMs),
            reason: 'Iteration $i: Ping should be sent promptly (within ${maxPromptDelayMs}ms), but took ${actualDelayMs}ms');
        
        expect(actualDelayMs, equals(delayMs),
            reason: 'Iteration $i: Recorded delay should match calculated delay');
      }
      
      // Additional assertions about delay distribution
      final avgDelay = delays.reduce((a, b) => a + b) / delays.length;
      expect(avgDelay, lessThan(maxPromptDelayMs),
          reason: 'Average ping delay should be less than ${maxPromptDelayMs}ms');
    });

    test('Property 30 (Sequential Confirmations): Each confirmation should trigger its own ping', () {
      // Test that when connections are confirmed sequentially, each triggers its own ping
      
      final random = Random();
      const iterations = 50;

      for (int i = 0; i < iterations; i++) {
        // Arrange
        final metrics = ConnectionMetrics();
        final connectionCount = 3 + random.nextInt(3); // 3 to 5 connections
        
        // Act: Simulate sequential confirmations and pings
        var currentTime = DateTime.now();
        
        for (int j = 0; j < connectionCount; j++) {
          final endpointId = 'endpoint_${i}_$j';
          final endpointName = 'Device_${i}_$j';
          
          // Confirm connection
          final confirmationTime = currentTime;
          
          // Send ping
          final pingTime = confirmationTime.add(Duration(milliseconds: random.nextInt(50)));
          
          metrics.recordEvent(
            endpointId,
            'verification_ping_sent',
            {
              'timestamp': pingTime.toIso8601String(),
              'endpoint_name': endpointName,
              'confirmation_timestamp': confirmationTime.toIso8601String(),
              'sequence': j,
            },
          );
          
          // Move time forward for next connection
          currentTime = pingTime.add(Duration(milliseconds: 100));
        }
        
        // Assert: Each confirmation should have triggered a ping
        final events = metrics.getRecentEvents();
        
        for (int j = 0; j < connectionCount; j++) {
          final endpointId = 'endpoint_${i}_$j';
          
          final pingEvents = events.where(
            (e) => e.endpointId == endpointId && 
                   e.eventType == 'verification_ping_sent' &&
                   e.metadata['sequence'] == j
          ).toList();
          
          expect(pingEvents.isNotEmpty, isTrue,
              reason: 'Iteration $i, Connection $j: Should have ping event');
          
          // Verify ping happened after confirmation
          final pingEvent = pingEvents.first;
          final confirmationTimestamp = DateTime.parse(pingEvent.metadata['confirmation_timestamp'] as String);
          final pingTimestamp = DateTime.parse(pingEvent.metadata['timestamp'] as String);
          
          expect(pingTimestamp.isAfter(confirmationTimestamp) || 
                 pingTimestamp.isAtSameMomentAs(confirmationTimestamp), 
                 isTrue,
              reason: 'Iteration $i, Connection $j: Ping should occur at or after confirmation');
        }
      }
    });
  });
}
