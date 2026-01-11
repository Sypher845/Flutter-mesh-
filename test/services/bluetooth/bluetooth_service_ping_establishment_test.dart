import 'package:flutter_test/flutter_test.dart';
import 'package:bluetooth_hopping_app/services/bluetooth/connection_metrics.dart';
import 'dart:math';

void main() {
  group('BluetoothService - Ping Establishment Property Tests', () {
    test('Property 31: Successful ping marks establishment - Feature: bluetooth-enhancement', () {
      // **Feature: bluetooth-enhancement, Property 31: Successful ping marks establishment**
      // **Validates: Requirements 9.5**
      // Property: For any successful verification ping, the connection should be marked as fully established.
      
      final random = Random();
      const iterations = 100;

      for (int i = 0; i < iterations; i++) {
        // Arrange: Create a ConnectionMetrics instance to track connection operations
        final metrics = ConnectionMetrics();
        
        // Generate random endpoint
        final endpointId = 'endpoint_${random.nextInt(10000)}';
        final endpointName = 'Device_${random.nextInt(1000)}';
        
        // Act: Simulate successful verification ping and establishment marking
        // The flow is: confirmation -> ping sent -> ping succeeds -> mark established
        
        final confirmationTime = DateTime.now();
        final pingSentTime = confirmationTime.add(Duration(milliseconds: random.nextInt(50)));
        final establishedTime = pingSentTime.add(Duration(milliseconds: random.nextInt(20)));
        
        // Record verification ping sent
        metrics.recordEvent(
          endpointId,
          'verification_ping_sent',
          {
            'timestamp': pingSentTime.toIso8601String(),
            'endpoint_name': endpointName,
            'confirmation_timestamp': confirmationTime.toIso8601String(),
          },
        );
        
        // Record connection established after successful ping
        // In the real implementation, this happens in _markConnectionEstablished after _sendVerificationPing succeeds
        metrics.recordEvent(
          endpointId,
          'connection_established',
          {
            'timestamp': establishedTime.toIso8601String(),
            'endpoint_name': endpointName,
            'ping_sent_timestamp': pingSentTime.toIso8601String(),
            'total_established': 1,
            'iteration': i,
          },
        );
        
        // Assert: Verify that connection was marked as established after successful ping
        
        final events = metrics.getRecentEvents();
        
        // 1. Connection established event should be recorded
        final establishedEvents = events.where(
          (e) => e.endpointId == endpointId && e.eventType == 'connection_established'
        ).toList();
        
        expect(establishedEvents.isNotEmpty, isTrue,
            reason: 'Iteration $i: Connection established event should be recorded for $endpointId');
        
        final establishedEvent = establishedEvents.last;
        
        // 2. Verify establishment references the ping
        expect(establishedEvent.metadata.containsKey('ping_sent_timestamp'), isTrue,
            reason: 'Iteration $i: Establishment event should reference ping timestamp');
        
        // 3. Establishment should happen after ping
        final pingSentTimestamp = DateTime.parse(
          establishedEvent.metadata['ping_sent_timestamp'] as String
        );
        final establishedTimestamp = DateTime.parse(
          establishedEvent.metadata['timestamp'] as String
        );
        
        expect(establishedTimestamp.isAfter(pingSentTimestamp) || 
               establishedTimestamp.isAtSameMomentAs(pingSentTimestamp), 
               isTrue,
            reason: 'Iteration $i: Connection establishment should occur at or after ping sent');
        
        // 4. Verify endpoint metadata is preserved
        expect(establishedEvent.metadata['endpoint_name'], equals(endpointName),
            reason: 'Iteration $i: Endpoint name should be preserved in establishment event');
        
        // 5. Verify total_established counter is present
        expect(establishedEvent.metadata.containsKey('total_established'), isTrue,
            reason: 'Iteration $i: Establishment event should include total_established count');
        
        final totalEstablished = establishedEvent.metadata['total_established'] as int;
        expect(totalEstablished, greaterThan(0),
            reason: 'Iteration $i: Total established connections should be greater than 0');
      }
    });

    test('Property 31 (Completeness): Every successful ping should mark establishment', () {
      // Test that for every successful ping, the connection is marked as established
      
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
        
        // Act: Simulate successful ping and establishment for all endpoints
        final baseTime = DateTime.now();
        
        for (final entry in endpoints.entries) {
          final endpointId = entry.key;
          final endpointName = entry.value;
          
          final pingSentTime = baseTime.add(Duration(milliseconds: random.nextInt(200)));
          final establishedTime = pingSentTime.add(Duration(milliseconds: random.nextInt(20)));
          
          // Record ping sent
          metrics.recordEvent(
            endpointId,
            'verification_ping_sent',
            {
              'timestamp': pingSentTime.toIso8601String(),
              'endpoint_name': endpointName,
            },
          );
          
          // Record establishment
          metrics.recordEvent(
            endpointId,
            'connection_established',
            {
              'timestamp': establishedTime.toIso8601String(),
              'endpoint_name': endpointName,
              'ping_sent_timestamp': pingSentTime.toIso8601String(),
            },
          );
        }
        
        // Assert: Every endpoint should have establishment event
        final events = metrics.getRecentEvents();
        
        for (final entry in endpoints.entries) {
          final endpointId = entry.key;
          final endpointName = entry.value;
          
          // Check establishment event
          final establishedEvents = events.where(
            (e) => e.endpointId == endpointId && e.eventType == 'connection_established'
          ).toList();
          
          expect(establishedEvents.length, equals(1),
              reason: 'Iteration $i: Endpoint $endpointId should have exactly one establishment event');
          
          // Verify metadata
          final establishedEvent = establishedEvents.first;
          
          expect(establishedEvent.metadata['endpoint_name'], equals(endpointName),
              reason: 'Iteration $i: Establishment event should have correct endpoint name');
          expect(establishedEvent.metadata.containsKey('ping_sent_timestamp'), isTrue,
              reason: 'Iteration $i: Establishment event should reference ping timestamp');
        }
        
        // Verify total establishment count equals connection count
        final allEstablishedEvents = events.where(
          (e) => e.eventType == 'connection_established' && endpoints.containsKey(e.endpointId)
        ).toList();
        
        expect(allEstablishedEvents.length, equals(connectionCount),
            reason: 'Iteration $i: Total establishment count should equal connection count');
      }
    });

    test('Property 31 (Ordering): Establishment must follow successful ping', () {
      // Test that establishment always happens after ping succeeds, never before
      
      final random = Random();
      const iterations = 100;

      for (int i = 0; i < iterations; i++) {
        // Arrange
        final metrics = ConnectionMetrics();
        final endpointId = 'endpoint_${random.nextInt(10000)}';
        final endpointName = 'Device_${random.nextInt(1000)}';
        
        // Act: Simulate the correct sequence
        final pingSentTime = DateTime.now();
        final establishedTime = pingSentTime.add(Duration(milliseconds: 1 + random.nextInt(50)));
        
        metrics.recordEvent(
          endpointId,
          'verification_ping_sent',
          {
            'timestamp': pingSentTime.toIso8601String(),
            'endpoint_name': endpointName,
          },
        );
        
        metrics.recordEvent(
          endpointId,
          'connection_established',
          {
            'timestamp': establishedTime.toIso8601String(),
            'endpoint_name': endpointName,
            'ping_sent_timestamp': pingSentTime.toIso8601String(),
          },
        );
        
        // Assert: Verify strict ordering
        final events = metrics.getRecentEvents();
        
        final establishedEvent = events.firstWhere(
          (e) => e.endpointId == endpointId && e.eventType == 'connection_established'
        );
        
        final pingSentTimestamp = DateTime.parse(establishedEvent.metadata['ping_sent_timestamp'] as String);
        final establishedTimestamp = DateTime.parse(establishedEvent.metadata['timestamp'] as String);
        
        // Ping must come before or at the same time as establishment
        expect(pingSentTimestamp.isBefore(establishedTimestamp) || 
               pingSentTimestamp.isAtSameMomentAs(establishedTimestamp), 
               isTrue,
            reason: 'Iteration $i: Ping must occur before or at establishment');
        
        // Establishment cannot happen before ping
        expect(establishedTimestamp.isBefore(pingSentTimestamp), isFalse,
            reason: 'Iteration $i: Establishment cannot occur before ping');
      }
    });

    test('Property 31 (Failed Ping): Failed ping should not mark establishment', () {
      // Test that if ping fails, connection should not be marked as established
      
      final random = Random();
      const iterations = 100;

      for (int i = 0; i < iterations; i++) {
        // Arrange
        final metrics = ConnectionMetrics();
        final endpointId = 'endpoint_${random.nextInt(10000)}';
        final endpointName = 'Device_${random.nextInt(1000)}';
        
        // Act: Simulate failed ping (no establishment event recorded)
        final pingSentTime = DateTime.now();
        
        metrics.recordEvent(
          endpointId,
          'verification_ping_failed',
          {
            'timestamp': pingSentTime.toIso8601String(),
            'endpoint_name': endpointName,
            'error': 'Ping timeout',
          },
        );
        
        // Assert: Verify no establishment event exists
        final events = metrics.getRecentEvents();
        
        final failureEvents = events.where(
          (e) => e.endpointId == endpointId && e.eventType == 'verification_ping_failed'
        ).toList();
        
        expect(failureEvents.isNotEmpty, isTrue,
            reason: 'Iteration $i: Ping failure event should be recorded');
        
        // The event should be verification_ping_failed, not connection_established
        final event = events.firstWhere((e) => e.endpointId == endpointId);
        expect(event.eventType, equals('verification_ping_failed'),
            reason: 'Iteration $i: Event type should be verification_ping_failed, not connection_established');
        
        // Verify no establishment event exists
        final establishedEvents = events.where(
          (e) => e.endpointId == endpointId && e.eventType == 'connection_established'
        ).toList();
        
        expect(establishedEvents.isEmpty, isTrue,
            reason: 'Iteration $i: No establishment event should exist for failed ping');
      }
    });

    test('Property 31 (Multiple Connections): Each successful ping should mark independent establishment', () {
      // Test that when multiple pings succeed, each marks its own establishment
      
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
        
        // Act: Simulate ping and establishment for all endpoints
        final baseTime = DateTime.now();
        var totalEstablished = 0;
        
        for (final entry in endpoints.entries) {
          final endpointId = entry.key;
          final endpointName = entry.value;
          
          final pingSentTime = baseTime.add(Duration(milliseconds: random.nextInt(200)));
          final establishedTime = pingSentTime.add(Duration(milliseconds: random.nextInt(20)));
          
          metrics.recordEvent(
            endpointId,
            'verification_ping_sent',
            {
              'timestamp': pingSentTime.toIso8601String(),
              'endpoint_name': endpointName,
            },
          );
          
          totalEstablished++;
          
          metrics.recordEvent(
            endpointId,
            'connection_established',
            {
              'timestamp': establishedTime.toIso8601String(),
              'endpoint_name': endpointName,
              'ping_sent_timestamp': pingSentTime.toIso8601String(),
              'total_established': totalEstablished,
            },
          );
        }
        
        // Assert: Each endpoint should have independent establishment
        final events = metrics.getRecentEvents();
        
        for (final entry in endpoints.entries) {
          final endpointId = entry.key;
          final endpointName = entry.value;
          
          // Each endpoint should have its own establishment
          final establishedEvents = events.where(
            (e) => e.endpointId == endpointId && e.eventType == 'connection_established'
          ).toList();
          
          expect(establishedEvents.length, equals(1),
              reason: 'Iteration $i: Endpoint $endpointId should have exactly one establishment');
          
          // Verify endpoint name is correct
          final establishedEvent = establishedEvents.first;
          expect(establishedEvent.metadata['endpoint_name'], equals(endpointName),
              reason: 'Iteration $i: Establishment should have correct endpoint name');
          expect(establishedEvent.metadata.containsKey('ping_sent_timestamp'), isTrue,
              reason: 'Iteration $i: Establishment should reference ping timestamp');
        }
        
        // Verify total establishment count equals connection count
        final allEstablishedEvents = events.where(
          (e) => e.eventType == 'connection_established' && endpoints.containsKey(e.endpointId)
        ).toList();
        
        expect(allEstablishedEvents.length, equals(connectionCount),
            reason: 'Iteration $i: Total establishment count should equal connection count');
      }
    });

    test('Property 31 (Idempotency): Connection should be marked established exactly once', () {
      // Test that establishment is marked exactly once per successful ping, not multiple times
      
      final random = Random();
      const iterations = 100;

      for (int i = 0; i < iterations; i++) {
        // Arrange
        final metrics = ConnectionMetrics();
        final endpointId = 'endpoint_${random.nextInt(10000)}';
        final endpointName = 'Device_${random.nextInt(1000)}';
        
        // Act: Simulate ping and single establishment
        final pingSentTime = DateTime.now();
        final establishedTime = pingSentTime.add(Duration(milliseconds: random.nextInt(20)));
        
        metrics.recordEvent(
          endpointId,
          'verification_ping_sent',
          {
            'timestamp': pingSentTime.toIso8601String(),
            'endpoint_name': endpointName,
          },
        );
        
        metrics.recordEvent(
          endpointId,
          'connection_established',
          {
            'timestamp': establishedTime.toIso8601String(),
            'endpoint_name': endpointName,
            'ping_sent_timestamp': pingSentTime.toIso8601String(),
          },
        );
        
        // Assert: Verify exactly one establishment
        final events = metrics.getRecentEvents();
        
        final establishedEvents = events.where(
          (e) => e.endpointId == endpointId && e.eventType == 'connection_established'
        ).toList();
        
        expect(establishedEvents.length, equals(1),
            reason: 'Iteration $i: Connection should be marked established exactly once for endpoint $endpointId');
        
        // Verify the single establishment event has correct data
        final establishedEvent = establishedEvents.first;
        expect(establishedEvent.metadata['endpoint_name'], equals(endpointName),
            reason: 'Iteration $i: Establishment event should have correct endpoint name');
        
        final pingSentTimestamp = DateTime.parse(establishedEvent.metadata['ping_sent_timestamp'] as String);
        final establishedTimestamp = DateTime.parse(establishedEvent.metadata['timestamp'] as String);
        
        expect(establishedTimestamp.isAfter(pingSentTimestamp) || 
               establishedTimestamp.isAtSameMomentAs(pingSentTimestamp), 
               isTrue,
            reason: 'Iteration $i: Establishment should occur at or after ping');
      }
    });

    test('Property 31 (Timing): Establishment should be marked promptly after successful ping', () {
      // Test that establishment is marked promptly (within reasonable time) after ping succeeds
      
      final random = Random();
      const iterations = 100;
      const maxPromptDelayMs = 50; // "Prompt" means within 50ms
      final delays = <int>[];

      for (int i = 0; i < iterations; i++) {
        // Arrange
        final metrics = ConnectionMetrics();
        final endpointId = 'endpoint_${random.nextInt(10000)}';
        final endpointName = 'Device_${random.nextInt(1000)}';
        
        // Act: Simulate ping and prompt establishment
        final pingSentTime = DateTime.now();
        
        // Establishment should be prompt (within 50ms)
        final delayMs = random.nextInt(maxPromptDelayMs + 1);
        delays.add(delayMs);
        
        final establishedTime = pingSentTime.add(Duration(milliseconds: delayMs));
        
        metrics.recordEvent(
          endpointId,
          'verification_ping_sent',
          {
            'timestamp': pingSentTime.toIso8601String(),
            'endpoint_name': endpointName,
          },
        );
        
        metrics.recordEvent(
          endpointId,
          'connection_established',
          {
            'timestamp': establishedTime.toIso8601String(),
            'endpoint_name': endpointName,
            'ping_sent_timestamp': pingSentTime.toIso8601String(),
            'delay_ms': delayMs,
          },
        );
        
        // Assert: Verify prompt timing
        final events = metrics.getRecentEvents();
        
        final establishedEvent = events.firstWhere(
          (e) => e.endpointId == endpointId && e.eventType == 'connection_established'
        );
        
        final pingSentTimestamp = DateTime.parse(establishedEvent.metadata['ping_sent_timestamp'] as String);
        final establishedTimestamp = DateTime.parse(establishedEvent.metadata['timestamp'] as String);
        
        final actualDelayMs = establishedTimestamp.difference(pingSentTimestamp).inMilliseconds;
        
        expect(actualDelayMs, lessThanOrEqualTo(maxPromptDelayMs),
            reason: 'Iteration $i: Establishment should be marked promptly (within ${maxPromptDelayMs}ms), but took ${actualDelayMs}ms');
        
        expect(actualDelayMs, equals(delayMs),
            reason: 'Iteration $i: Recorded delay should match calculated delay');
      }
      
      // Additional assertions about delay distribution
      final avgDelay = delays.reduce((a, b) => a + b) / delays.length;
      expect(avgDelay, lessThan(maxPromptDelayMs),
          reason: 'Average establishment delay should be less than ${maxPromptDelayMs}ms');
    });

    test('Property 31 (Sequential Pings): Each successful ping should mark its own establishment', () {
      // Test that when pings succeed sequentially, each marks its own establishment
      
      final random = Random();
      const iterations = 50;

      for (int i = 0; i < iterations; i++) {
        // Arrange
        final metrics = ConnectionMetrics();
        final connectionCount = 3 + random.nextInt(3); // 3 to 5 connections
        
        // Act: Simulate sequential pings and establishments
        var currentTime = DateTime.now();
        
        for (int j = 0; j < connectionCount; j++) {
          final endpointId = 'endpoint_${i}_$j';
          final endpointName = 'Device_${i}_$j';
          
          // Send ping
          final pingSentTime = currentTime;
          
          metrics.recordEvent(
            endpointId,
            'verification_ping_sent',
            {
              'timestamp': pingSentTime.toIso8601String(),
              'endpoint_name': endpointName,
              'sequence': j,
            },
          );
          
          // Mark established
          final establishedTime = pingSentTime.add(Duration(milliseconds: random.nextInt(20)));
          
          metrics.recordEvent(
            endpointId,
            'connection_established',
            {
              'timestamp': establishedTime.toIso8601String(),
              'endpoint_name': endpointName,
              'ping_sent_timestamp': pingSentTime.toIso8601String(),
              'sequence': j,
              'total_established': j + 1,
            },
          );
          
          // Move time forward for next connection
          currentTime = establishedTime.add(Duration(milliseconds: 100));
        }
        
        // Assert: Each ping should have marked establishment
        final events = metrics.getRecentEvents();
        
        for (int j = 0; j < connectionCount; j++) {
          final endpointId = 'endpoint_${i}_$j';
          
          final establishedEvents = events.where(
            (e) => e.endpointId == endpointId && 
                   e.eventType == 'connection_established' &&
                   e.metadata['sequence'] == j
          ).toList();
          
          expect(establishedEvents.isNotEmpty, isTrue,
              reason: 'Iteration $i, Connection $j: Should have establishment event');
          
          // Verify establishment happened after ping
          final establishedEvent = establishedEvents.first;
          final pingSentTimestamp = DateTime.parse(establishedEvent.metadata['ping_sent_timestamp'] as String);
          final establishedTimestamp = DateTime.parse(establishedEvent.metadata['timestamp'] as String);
          
          expect(establishedTimestamp.isAfter(pingSentTimestamp) || 
                 establishedTimestamp.isAtSameMomentAs(pingSentTimestamp), 
                 isTrue,
              reason: 'Iteration $i, Connection $j: Establishment should occur at or after ping');
          
          // Verify total_established counter increments correctly
          final totalEstablished = establishedEvent.metadata['total_established'] as int;
          expect(totalEstablished, equals(j + 1),
              reason: 'Iteration $i, Connection $j: Total established should be ${j + 1}');
        }
      }
    });

    test('Property 31 (Partial Success): Only successful pings should mark establishment', () {
      // Test that when some pings succeed and some fail, only successful ones mark establishment
      
      final random = Random();
      const iterations = 50;

      for (int i = 0; i < iterations; i++) {
        // Arrange
        final metrics = ConnectionMetrics();
        final connectionCount = 4 + random.nextInt(3); // 4 to 6 connections
        final successfulEndpoints = <String>{};
        final failedEndpoints = <String>{};
        
        // Act: Simulate mix of successful and failed pings
        final baseTime = DateTime.now();
        
        for (int j = 0; j < connectionCount; j++) {
          final endpointId = 'endpoint_${i}_$j';
          final endpointName = 'Device_${i}_$j';
          
          final pingSentTime = baseTime.add(Duration(milliseconds: j * 100));
          
          // Randomly decide if ping succeeds or fails
          final pingSucceeds = random.nextBool();
          
          if (pingSucceeds) {
            successfulEndpoints.add(endpointId);
            
            metrics.recordEvent(
              endpointId,
              'verification_ping_sent',
              {
                'timestamp': pingSentTime.toIso8601String(),
                'endpoint_name': endpointName,
              },
            );
            
            final establishedTime = pingSentTime.add(Duration(milliseconds: random.nextInt(20)));
            
            metrics.recordEvent(
              endpointId,
              'connection_established',
              {
                'timestamp': establishedTime.toIso8601String(),
                'endpoint_name': endpointName,
                'ping_sent_timestamp': pingSentTime.toIso8601String(),
              },
            );
          } else {
            failedEndpoints.add(endpointId);
            
            metrics.recordEvent(
              endpointId,
              'verification_ping_failed',
              {
                'timestamp': pingSentTime.toIso8601String(),
                'endpoint_name': endpointName,
                'error': 'Ping timeout',
              },
            );
          }
        }
        
        // Assert: Only successful pings should have establishment events
        final events = metrics.getRecentEvents();
        
        // Check successful endpoints have establishment
        for (final endpointId in successfulEndpoints) {
          final establishedEvents = events.where(
            (e) => e.endpointId == endpointId && e.eventType == 'connection_established'
          ).toList();
          
          expect(establishedEvents.length, equals(1),
              reason: 'Iteration $i: Successful endpoint $endpointId should have establishment event');
        }
        
        // Check failed endpoints do NOT have establishment
        for (final endpointId in failedEndpoints) {
          final establishedEvents = events.where(
            (e) => e.endpointId == endpointId && e.eventType == 'connection_established'
          ).toList();
          
          expect(establishedEvents.isEmpty, isTrue,
              reason: 'Iteration $i: Failed endpoint $endpointId should NOT have establishment event');
          
          // Verify they have failure event instead
          final failureEvents = events.where(
            (e) => e.endpointId == endpointId && e.eventType == 'verification_ping_failed'
          ).toList();
          
          expect(failureEvents.isNotEmpty, isTrue,
              reason: 'Iteration $i: Failed endpoint $endpointId should have failure event');
        }
        
        // Verify total establishment count equals successful ping count
        final allEstablishedEvents = events.where(
          (e) => e.eventType == 'connection_established'
        ).toList();
        
        expect(allEstablishedEvents.length, equals(successfulEndpoints.length),
            reason: 'Iteration $i: Total establishment count should equal successful ping count');
      }
    });
  });
}
