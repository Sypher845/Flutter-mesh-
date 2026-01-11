import 'package:flutter_test/flutter_test.dart';
import 'package:bluetooth_hopping_app/services/bluetooth/models/reconnection_entry.dart';
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
  group('ReconnectionEntry Property Tests', () {
    final random = Random();

    /// **Feature: bluetooth-enhancement, Property 9: Exhausted retries remove from queue**
    /// **Validates: Requirements 3.4**
    /// 
    /// Property: For any endpoint that reaches max retry count, 
    /// the endpoint should be removed from the reconnection queue.
    /// 
    /// This test verifies that when a ReconnectionEntry reaches the maximum
    /// number of retry attempts (5), it is marked as exhausted and should
    /// be removed from the queue.
    propertyTest(
      'Property 9: Exhausted retries remove from queue - '
      'For any ReconnectionEntry, when attemptCount reaches maxRetries (5), '
      'isExhausted should return true',
      () {
        // Generate random endpoint data
        final endpointId = generateRandomString(random);
        final endpointName = generateRandomString(random);
        final firstAttempt = DateTime.now().subtract(
          Duration(seconds: random.nextInt(3600))
        );

        // Create a reconnection entry
        final entry = ReconnectionEntry(
          endpointId: endpointId,
          endpointName: endpointName,
          firstAttempt: firstAttempt,
          attemptCount: 0,
        );

        // Verify that initially the entry is not exhausted
        expect(entry.isExhausted, isFalse,
          reason: 'Entry with 0 attempts should not be exhausted');

        // Increment attempts up to but not including maxRetries
        for (int i = 0; i < 4; i++) {
          entry.incrementAttempt();
          expect(entry.isExhausted, isFalse,
            reason: 'Entry with ${entry.attemptCount} attempts should not be exhausted');
        }

        // Verify attempt count is 4
        expect(entry.attemptCount, equals(4));

        // One more increment should reach maxRetries (5)
        entry.incrementAttempt();
        expect(entry.attemptCount, equals(5));

        // Now the entry should be exhausted
        expect(entry.isExhausted, isTrue,
          reason: 'Entry with 5 attempts should be exhausted (maxRetries reached)');

        // Further increments should keep it exhausted
        entry.incrementAttempt();
        expect(entry.isExhausted, isTrue,
          reason: 'Entry with more than maxRetries should remain exhausted');
      },
      iterations: 100,
    );

    propertyTest(
      'Property 9 (Edge Case): ReconnectionEntry created with high attemptCount '
      'should be immediately exhausted',
      () {
        // Generate random endpoint data
        final endpointId = generateRandomString(random);
        final endpointName = generateRandomString(random);
        final firstAttempt = DateTime.now();
        
        // Create entry with attemptCount >= maxRetries
        final attemptCount = 5 + random.nextInt(10); // 5 to 14
        final entry = ReconnectionEntry(
          endpointId: endpointId,
          endpointName: endpointName,
          firstAttempt: firstAttempt,
          attemptCount: attemptCount,
        );

        // Should be immediately exhausted
        expect(entry.isExhausted, isTrue,
          reason: 'Entry created with attemptCount >= 5 should be exhausted');
      },
      iterations: 100,
    );

    propertyTest(
      'Property 9 (Boundary): ReconnectionEntry at exactly maxRetries boundary',
      () {
        // Generate random endpoint data
        final endpointId = generateRandomString(random);
        final endpointName = generateRandomString(random);
        final firstAttempt = DateTime.now();

        // Test boundary conditions
        final boundaryValues = [0, 1, 4, 5, 6, 10];
        
        for (final attemptCount in boundaryValues) {
          final entry = ReconnectionEntry(
            endpointId: endpointId,
            endpointName: endpointName,
            firstAttempt: firstAttempt,
            attemptCount: attemptCount,
          );

          if (attemptCount >= 5) {
            expect(entry.isExhausted, isTrue,
              reason: 'Entry with attemptCount=$attemptCount should be exhausted');
          } else {
            expect(entry.isExhausted, isFalse,
              reason: 'Entry with attemptCount=$attemptCount should not be exhausted');
          }
        }
      },
      iterations: 100,
    );
  });
}
