/// Model representing a connection attempt for metrics tracking
class ConnectionAttempt {
  final String endpointId;
  final DateTime timestamp;
  final bool success;
  final String? errorMessage;

  ConnectionAttempt({
    required this.endpointId,
    required this.timestamp,
    required this.success,
    this.errorMessage,
  });

  /// Convert to JSON for serialization
  Map<String, dynamic> toJson() => {
        'endpointId': endpointId,
        'timestamp': timestamp.toIso8601String(),
        'success': success,
        'errorMessage': errorMessage,
      };

  /// Create from JSON
  factory ConnectionAttempt.fromJson(Map<String, dynamic> json) {
    return ConnectionAttempt(
      endpointId: json['endpointId'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      success: json['success'] as bool,
      errorMessage: json['errorMessage'] as String?,
    );
  }

  @override
  String toString() {
    return 'ConnectionAttempt(id: $endpointId, success: $success, time: $timestamp, error: $errorMessage)';
  }
}
