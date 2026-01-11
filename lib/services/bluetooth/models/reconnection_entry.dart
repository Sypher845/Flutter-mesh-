/// Model representing an endpoint that needs reconnection
class ReconnectionEntry {
  final String endpointId;
  final String endpointName;
  final DateTime firstAttempt;
  int attemptCount;
  DateTime nextAttemptTime;

  ReconnectionEntry({
    required this.endpointId,
    required this.endpointName,
    required this.firstAttempt,
    this.attemptCount = 0,
  }) : nextAttemptTime = DateTime.now();

  /// Check if this entry has exhausted all retry attempts
  bool get isExhausted => attemptCount >= 5; // maxRetries from ReconnectionManager

  /// Get the backoff duration for the next retry
  Duration get backoffDuration => const Duration(seconds: 5); // retryIntervalSeconds

  /// Increment the attempt count and update next attempt time
  void incrementAttempt() {
    attemptCount++;
    nextAttemptTime = DateTime.now().add(backoffDuration);
  }

  @override
  String toString() {
    return 'ReconnectionEntry(id: $endpointId, name: $endpointName, attempts: $attemptCount, next: $nextAttemptTime)';
  }
}
