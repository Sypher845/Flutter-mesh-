/// Model representing a connection event for detailed logging
class ConnectionEvent {
  final String endpointId;
  final String eventType; // 'discovered', 'connected', 'disconnected', 'failed'
  final DateTime timestamp;
  final Map<String, dynamic> metadata;

  ConnectionEvent({
    required this.endpointId,
    required this.eventType,
    required this.timestamp,
    required this.metadata,
  });

  /// Convert to JSON for serialization
  Map<String, dynamic> toJson() => {
        'endpointId': endpointId,
        'eventType': eventType,
        'timestamp': timestamp.toIso8601String(),
        'metadata': metadata,
      };

  /// Create from JSON
  factory ConnectionEvent.fromJson(Map<String, dynamic> json) {
    return ConnectionEvent(
      endpointId: json['endpointId'] as String,
      eventType: json['eventType'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      metadata: Map<String, dynamic>.from(json['metadata'] as Map),
    );
  }

  @override
  String toString() {
    return 'ConnectionEvent(id: $endpointId, type: $eventType, time: $timestamp, metadata: $metadata)';
  }
}
