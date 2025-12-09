# Design Document: Bluetooth Enhancement

## Overview

This design enhances the existing Bluetooth mesh network implementation to achieve greater range, improved stability, and robust auto-reconnection capabilities. The solution builds upon the current modular architecture (BluetoothService, ConnectionManager, PayloadHandler, MeshNetworkManager) by adding new components and enhancing existing ones.

The key improvements include:
1. **Range Optimization**: Configure Nearby Connections API parameters for maximum range
2. **Persistent Discovery**: Continuous scanning with adaptive frequency based on connection count
3. **Auto-Reconnection System**: Queue-based reconnection with exponential backoff
4. **Enhanced Health Monitoring**: Faster detection of dead connections with proactive cleanup
5. **Adaptive Connection Strategy**: Dynamic timeout adjustment based on success rates
6. **Connection Quality Management**: Limit connections to maintain reliability
7. **Comprehensive Metrics**: Detailed logging and analytics for debugging

## Architecture

### Component Overview

```
BluetoothService (Enhanced)
├── ConnectionManager (Enhanced)
│   ├── ReconnectionManager (NEW)
│   └── ConnectionMetrics (NEW)
├── PayloadHandler (Existing)
├── MeshNetworkManager (Existing)
└── PermissionManager (Existing)
```

### New Components

#### ReconnectionManager
Manages automatic reconnection attempts for lost connections.

**Responsibilities:**
- Maintain queue of endpoints requiring reconnection
- Execute reconnection attempts with exponential backoff
- Track retry counts and remove exhausted attempts
- Coordinate with ConnectionManager for reconnection requests

**State:**
- `Map<String, ReconnectionEntry>` - Queue of endpoints to reconnect
- `Timer` - Periodic reconnection attempt timer

#### ConnectionMetrics
Tracks connection statistics for adaptive strategy.

**Responsibilities:**
- Record connection attempt outcomes (success/failure)
- Calculate success rates over sliding windows
- Provide recommendations for timeout adjustments
- Log detailed connection events for debugging

**State:**
- `List<ConnectionAttempt>` - Recent connection attempts (last 10)
- `int currentTimeout` - Current connection timeout value
- `Map<String, ConnectionEvent>` - Event log with timestamps

### Enhanced Components

#### ConnectionManager (Enhanced)
Extended with adaptive discovery and connection limits.

**New Features:**
- Adaptive discovery frequency based on connection count
- Connection limit enforcement (max 8 devices)
- Discovery restart mechanism
- Enhanced error recovery

**New State:**
- `int maxConnections` - Maximum allowed connections (default: 8)
- `DateTime lastDiscoveryRestart` - Timestamp of last discovery restart
- `int consecutiveErrors` - Counter for API error tracking

#### BluetoothService (Enhanced)
Extended with lifecycle management and metrics integration.

**New Features:**
- Integration with ReconnectionManager
- Integration with ConnectionMetrics
- Background/foreground transition handling
- Bluetooth state change monitoring
- Full reset capability for error recovery

**New Methods:**
- `handleAppLifecycleChange(AppLifecycleState state)`
- `handleBluetoothStateChange(bool enabled)`
- `performFullReset()`

## Components and Interfaces

### ReconnectionManager Interface

```dart
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
  });
}

class ReconnectionManager {
  static const int maxRetries = 5;
  static const int retryIntervalSeconds = 5;
  
  final Map<String, ReconnectionEntry> _reconnectionQueue = {};
  Timer? _reconnectionTimer;
  
  // Callbacks
  Function(String endpointId)? onReconnectAttempt;
  Function(String endpointId)? onReconnectSuccess;
  Function(String endpointId)? onReconnectExhausted;
  
  void addToQueue(String endpointId, String endpointName);
  void removeFromQueue(String endpointId);
  void startReconnectionLoop();
  void stopReconnectionLoop();
  Future<void> attemptReconnections();
  bool shouldAttemptReconnection(ReconnectionEntry entry);
}
```

### ConnectionMetrics Interface

```dart
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
}

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
}

class ConnectionMetrics {
  static const int windowSize = 10;
  static const double lowSuccessThreshold = 0.5;
  static const double highSuccessThreshold = 0.8;
  static const int defaultTimeout = 5000;
  static const int increasedTimeout = 10000;
  
  final List<ConnectionAttempt> _recentAttempts = [];
  final Map<String, ConnectionEvent> _eventLog = {};
  int _currentTimeout = defaultTimeout;
  
  void recordAttempt(String endpointId, bool success, {String? error});
  void recordEvent(String endpointId, String eventType, Map<String, dynamic> metadata);
  double calculateSuccessRate();
  int getRecommendedTimeout();
  void updateTimeout();
  List<ConnectionEvent> getRecentEvents({int limit = 50});
  Map<String, dynamic> getStatistics();
}
```

### Enhanced ConnectionManager Interface

```dart
class ConnectionManager {
  // Existing fields...
  
  // New fields
  int maxConnections = 8;
  DateTime? lastDiscoveryRestart;
  int consecutiveErrors = 0;
  
  // New methods
  bool canAcceptNewConnection();
  Future<void> restartDiscovery();
  Future<void> performFullReset();
  void incrementErrorCount();
  void resetErrorCount();
  bool shouldPerformFullReset();
}
```

### Enhanced BluetoothService Interface

```dart
class BluetoothService extends ChangeNotifier {
  // Existing fields...
  
  // New fields
  late final ReconnectionManager _reconnectionManager;
  late final ConnectionMetrics _connectionMetrics;
  StreamSubscription<AppLifecycleState>? _lifecycleSubscription;
  
  // New methods
  void handleAppLifecycleChange(AppLifecycleState state);
  void handleBluetoothStateChange(bool enabled);
  Future<void> performFullReset();
  Map<String, dynamic> getConnectionStatistics();
}
```

## Data Models

### ReconnectionEntry Model

```dart
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
  
  bool get isExhausted => attemptCount >= ReconnectionManager.maxRetries;
  
  Duration get backoffDuration => 
    Duration(seconds: ReconnectionManager.retryIntervalSeconds);
  
  void incrementAttempt() {
    attemptCount++;
    nextAttemptTime = DateTime.now().add(backoffDuration);
  }
}
```

### ConnectionAttempt Model

```dart
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
  
  Map<String, dynamic> toJson() => {
    'endpointId': endpointId,
    'timestamp': timestamp.toIso8601String(),
    'success': success,
    'errorMessage': errorMessage,
  };
}
```

### ConnectionEvent Model

```dart
class ConnectionEvent {
  final String endpointId;
  final String eventType;
  final DateTime timestamp;
  final Map<String, dynamic> metadata;
  
  ConnectionEvent({
    required this.endpointId,
    required this.eventType,
    required this.timestamp,
    required this.metadata,
  });
  
  Map<String, dynamic> toJson() => {
    'endpointId': endpointId,
    'eventType': eventType,
    'timestamp': timestamp.toIso8601String(),
    'metadata': metadata,
  };
}
```

### Enhanced BluetoothConstants

```dart
class BluetoothConstants {
  // Existing constants...
  
  // New constants for reconnection
  static const int reconnectionMaxRetries = 5;
  static const int reconnectionIntervalSeconds = 5;
  static const int reconnectionTimerIntervalSeconds = 2;
  
  // New constants for adaptive strategy
  static const int metricsWindowSize = 10;
  static const double lowSuccessThreshold = 0.5;
  static const double highSuccessThreshold = 0.8;
  static const int adaptiveTimeoutMin = 5000;
  static const int adaptiveTimeoutMax = 10000;
  
  // New constants for connection management
  static const int maxConnections = 8;
  static const int discoveryRestartIntervalSeconds = 30;
  static const int fullResetErrorThreshold = 3;
  
  // New constants for range optimization
  static const int extendedConnectionTimeout = 10000;
  static const int discoveryHighFrequencySeconds = 5;
  static const int discoveryNormalFrequencySeconds = 30;
}
```



## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system-essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

### Property 1: Connection quality degradation triggers logging

*For any* connection quality degradation event, the system should log signal strength metrics with the endpoint ID and quality value.

**Validates: Requirements 1.4**

### Property 2: Advertising persistence

*For any* sequence of operations (send, receive, health check), if the application remains active, advertising should remain enabled.

**Validates: Requirements 2.2**

### Property 3: Discovery persistence

*For any* sequence of operations (send, receive, health check), if the application remains active, discovery should remain enabled.

**Validates: Requirements 2.3**

### Property 4: Automatic connection initiation

*For any* discovered endpoint with matching service ID, the system should automatically initiate a connection request.

**Validates: Requirements 2.4**

### Property 5: Connection retry scheduling

*For any* failed connection attempt, the system should schedule a retry after the backoff period.

**Validates: Requirements 2.5**

### Property 6: Disconnection triggers reconnection queue

*For any* unexpected disconnection event, the system should add the endpoint to the reconnection queue.

**Validates: Requirements 3.1**

### Property 7: Reconnection attempt timing

*For any* endpoint in the reconnection queue, reconnection attempts should occur every 5 seconds until max retries (5) is reached.

**Validates: Requirements 3.2**

### Property 8: Successful reconnection removes from queue

*For any* successful reconnection attempt, the endpoint should be removed from the reconnection queue.

**Validates: Requirements 3.3**

### Property 9: Exhausted retries remove from queue

*For any* endpoint that reaches max retry count, the endpoint should be removed from the reconnection queue.

**Validates: Requirements 3.4**

### Property 10: Health check verifies all devices

*For any* health check trigger, verification should be performed on all currently connected devices.

**Validates: Requirements 4.1**

### Property 11: Timeout marks connection stale

*For any* connection verification that times out after 2 seconds, the connection should be marked as stale.

**Validates: Requirements 4.2**

### Property 12: Stale connections trigger disconnection

*For any* connection marked as stale, the system should initiate disconnection from that endpoint.

**Validates: Requirements 4.3**

### Property 13: Stale removal triggers reconnection

*For any* stale connection that is removed, the endpoint should be added to the reconnection queue.

**Validates: Requirements 4.4**

### Property 14: Health check scheduling with connections

*For any* state where connected devices exist, health checks should be scheduled every 30 seconds.

**Validates: Requirements 4.5**

### Property 15: Connection attempts are recorded

*For any* connection attempt (success or failure), the system should record the outcome in the metrics tracker.

**Validates: Requirements 5.1**

### Property 16: Discovery restart preserves connections

*For any* discovery restart operation, the set of connected device IDs should remain unchanged.

**Validates: Requirements 5.5**

### Property 17: Background transition preserves connections

*For any* foreground-to-background transition, all active connection IDs should be maintained.

**Validates: Requirements 6.1**

### Property 18: Bluetooth errors trigger logging and recovery

*For any* Bluetooth API error, the system should log the error details and attempt a recovery action.

**Validates: Requirements 6.5**

### Property 19: Connection limit maintains existing connections

*For any* new device discovery when at connection limit (8 devices), the existing connection set should remain unchanged.

**Validates: Requirements 7.2**

### Property 20: Parallel send to all devices

*For any* send operation with multiple connected devices, send attempts should be initiated for all devices.

**Validates: Requirements 7.3**

### Property 21: Failed send triggers retry

*For any* failed send operation to a device, the system should retry up to 3 times with exponential backoff.

**Validates: Requirements 7.4**

### Property 22: Exhausted send retries trigger health check

*For any* device where all send retry attempts fail, the connection should be marked for health check.

**Validates: Requirements 7.5**

### Property 23: State changes trigger logging

*For any* connection state change, the system should log the endpoint ID, new state, and timestamp.

**Validates: Requirements 8.1**

### Property 24: Connection failures trigger error logging

*For any* connection failure, the system should log the failure reason and error code.

**Validates: Requirements 8.2**

### Property 25: Health check triggers count logging

*For any* health check execution, the system should log the count of active and stale connections.

**Validates: Requirements 8.3**

### Property 26: Discovery triggers device logging

*For any* device discovered during discovery, the system should log the endpoint name and service ID.

**Validates: Requirements 8.4**

### Property 27: Multiple discoveries trigger parallel connections

*For any* set of simultaneously discovered endpoints, connection requests should be processed in parallel.

**Validates: Requirements 9.1**

### Property 28: Connection acceptance timing

*For any* connection initiation, acceptance should complete within 2 seconds.

**Validates: Requirements 9.2**

### Property 29: Acceptance triggers callback registration

*For any* completed connection acceptance, payload callbacks should be registered immediately.

**Validates: Requirements 9.3**

### Property 30: Confirmed connection triggers ping

*For any* confirmed connection result, the system should send a verification ping.

**Validates: Requirements 9.4**

### Property 31: Successful ping marks establishment

*For any* successful verification ping, the connection should be marked as fully established.

**Validates: Requirements 9.5**

### Property 32: Unexpected errors trigger retry

*For any* unexpected connection operation error, the system should log the error and schedule a retry after 1 second.

**Validates: Requirements 10.3**

### Property 33: Stop operation failures trigger state update

*For any* failed stopAdvertising or stopDiscovery operation, the system should log the error and update internal state.

**Validates: Requirements 10.4**

## Error Handling

### Connection Errors

**Error Type**: Connection timeout
- **Detection**: Connection attempt exceeds configured timeout (5-10 seconds)
- **Recovery**: Record failure in metrics, add to reconnection queue, update adaptive timeout
- **User Impact**: Status message indicates connection attempt failed

**Error Type**: Connection rejected
- **Detection**: Remote device rejects connection request
- **Recovery**: Record failure in metrics, retry after backoff period
- **User Impact**: Status message indicates device unavailable

**Error Type**: Connection lost during operation
- **Detection**: Send operation fails or health check times out
- **Recovery**: Mark as stale, disconnect, add to reconnection queue
- **User Impact**: Status message indicates connection lost, automatic reconnection attempted

### API Errors

**Error Type**: STATUS_ALREADY_ADVERTISING (8001)
- **Detection**: startAdvertising() throws this error
- **Recovery**: Treat as success, update internal state to advertising=true
- **User Impact**: None, operation continues normally

**Error Type**: STATUS_ALREADY_DISCOVERING (8002)
- **Detection**: startDiscovery() throws this error
- **Recovery**: Treat as success, update internal state to discovering=true
- **User Impact**: None, operation continues normally

**Error Type**: Unexpected API error
- **Detection**: Any other error from Nearby Connections API
- **Recovery**: Log error, increment error counter, retry after 1 second
- **User Impact**: Status message indicates temporary issue

**Error Type**: Consecutive API errors (3+)
- **Detection**: Error counter reaches threshold
- **Recovery**: Perform full reset (stop all, clear state, restart)
- **User Impact**: Status message indicates system reset, brief interruption

### State Errors

**Error Type**: Bluetooth disabled
- **Detection**: Platform Bluetooth state change event
- **Recovery**: Pause all operations, show user notification
- **User Impact**: Clear message that Bluetooth must be enabled

**Error Type**: Permissions revoked
- **Detection**: Permission check fails during operation
- **Recovery**: Stop operations, request permissions again
- **User Impact**: Permission dialog shown to user

**Error Type**: App backgrounded
- **Detection**: App lifecycle state change
- **Recovery**: Maintain connections, pause non-essential operations
- **User Impact**: None, connections maintained

### Resource Errors

**Error Type**: Connection limit reached
- **Detection**: Connection count >= maxConnections (8)
- **Recovery**: Reject new incoming connections, maintain existing
- **User Impact**: Status message indicates network at capacity

**Error Type**: Reconnection queue full
- **Detection**: Queue size exceeds reasonable limit (20 entries)
- **Recovery**: Remove oldest entries, add new ones
- **User Impact**: None, automatic cleanup

**Error Type**: Memory pressure
- **Detection**: Platform memory warnings
- **Recovery**: Clear old metrics, limit queue sizes, reduce logging
- **User Impact**: None, automatic optimization

## Testing Strategy

### Unit Testing

Unit tests will verify specific behaviors and edge cases:

**ConnectionManager Tests:**
- Test that connection limit (8) is enforced
- Test that discovery restart maintains connections
- Test that error counter increments correctly
- Test that full reset clears all state

**ReconnectionManager Tests:**
- Test that disconnections add to queue
- Test that successful reconnections remove from queue
- Test that exhausted retries remove from queue
- Test that backoff timing is correct

**ConnectionMetrics Tests:**
- Test that attempts are recorded correctly
- Test that success rate calculation is accurate
- Test that timeout recommendations are correct
- Test that event logging captures all fields

**BluetoothService Tests:**
- Test lifecycle transitions maintain connections
- Test Bluetooth state changes pause/resume correctly
- Test full reset clears all managers

### Property-Based Testing

Property-based tests will verify universal properties across many inputs using the **test** package with **test_api** for property testing in Dart. Each test will run a minimum of 100 iterations.

**Property Test Configuration:**
```dart
// Use test package with custom generators
import 'package:test/test.dart';
import 'dart:math';

// Custom property test helper
void propertyTest(String description, Function testFn, {int iterations = 100}) {
  test(description, () {
    for (int i = 0; i < iterations; i++) {
      testFn();
    }
  });
}
```

**Property Tests:**

Each property-based test will be tagged with a comment explicitly referencing the correctness property from this design document using the format: **Feature: bluetooth-enhancement, Property {number}: {property_text}**

1. **Property 1 Test**: Generate random connection quality events, verify logging occurs with correct data
2. **Property 2 Test**: Generate random operation sequences, verify advertising remains enabled
3. **Property 3 Test**: Generate random operation sequences, verify discovery remains enabled
4. **Property 4 Test**: Generate random discovered endpoints with matching service IDs, verify connection requests
5. **Property 5 Test**: Generate random connection failures, verify retry scheduling
6. **Property 6 Test**: Generate random disconnection events, verify queue additions
7. **Property 7 Test**: Generate random queue entries, verify reconnection timing
8. **Property 8 Test**: Generate random successful reconnections, verify queue removal
9. **Property 9 Test**: Generate random exhausted retry scenarios, verify queue removal
10. **Property 10 Test**: Generate random health check triggers, verify all devices checked
11. **Property 11 Test**: Generate random timeout scenarios, verify stale marking
12. **Property 12 Test**: Generate random stale connections, verify disconnection
13. **Property 13 Test**: Generate random stale removals, verify reconnection queue addition
14. **Property 14 Test**: Generate random connection states, verify health check scheduling
15. **Property 15 Test**: Generate random connection attempts, verify recording
16. **Property 16 Test**: Generate random discovery restarts, verify connection preservation
17. **Property 17 Test**: Generate random background transitions, verify connection preservation
18. **Property 18 Test**: Generate random Bluetooth errors, verify logging and recovery
19. **Property 19 Test**: Generate random discoveries at limit, verify connection preservation
20. **Property 20 Test**: Generate random send operations, verify parallel sends
21. **Property 21 Test**: Generate random send failures, verify retry logic
22. **Property 22 Test**: Generate random exhausted send retries, verify health check marking
23. **Property 23 Test**: Generate random state changes, verify logging
24. **Property 24 Test**: Generate random connection failures, verify error logging
25. **Property 25 Test**: Generate random health checks, verify count logging
26. **Property 26 Test**: Generate random discoveries, verify device logging
27. **Property 27 Test**: Generate random simultaneous discoveries, verify parallel processing
28. **Property 28 Test**: Generate random connection initiations, verify timing
29. **Property 29 Test**: Generate random acceptances, verify callback registration
30. **Property 30 Test**: Generate random confirmations, verify ping sending
31. **Property 31 Test**: Generate random successful pings, verify establishment marking
32. **Property 32 Test**: Generate random unexpected errors, verify retry scheduling
33. **Property 33 Test**: Generate random stop failures, verify state updates

### Integration Testing

Integration tests will verify end-to-end workflows:

- **Reconnection Flow**: Simulate disconnection, verify reconnection attempts, verify success
- **Adaptive Strategy Flow**: Simulate varying success rates, verify timeout adjustments
- **Health Check Flow**: Simulate stale connections, verify detection and cleanup
- **Lifecycle Flow**: Simulate app state changes, verify connection maintenance
- **Error Recovery Flow**: Simulate API errors, verify recovery and reset

### Manual Testing

Manual testing with physical devices will verify:

- Range testing at various distances (10m, 30m, 50m, 100m)
- Obstacle testing (walls, furniture, people)
- Multi-device mesh formation (3, 5, 8 devices)
- Connection stability over extended periods (30 min, 1 hour)
- Background/foreground transitions
- Bluetooth disable/enable scenarios
- Report sending and mesh propagation

## Implementation Notes

### Range Optimization

The Nearby Connections API does not expose direct control over Bluetooth transmit power or connection parameters. Range optimization will be achieved through:

1. **Strategy Selection**: P2P_CLUSTER strategy already optimizes for range over throughput
2. **Timeout Configuration**: Longer timeouts allow weaker signals to complete handshakes
3. **Retry Logic**: Multiple attempts increase success probability at range limits
4. **Connection Maintenance**: Keeping connections alive prevents re-establishment overhead

### Platform Differences

**Android:**
- Full support for Nearby Connections API
- Background operation limited by Android 10+ restrictions
- Location permissions required for Bluetooth scanning

**iOS:**
- Nearby Connections API support varies by iOS version
- Background Bluetooth more restricted than Android
- May require additional entitlements

### Performance Considerations

**Battery Impact:**
- Continuous discovery and advertising consume battery
- Health checks add periodic overhead
- Consider reducing frequency in production based on use case

**Memory Usage:**
- Reconnection queue limited to 20 entries
- Metrics window limited to 10 attempts
- Event log limited to 50 recent events

**Network Overhead:**
- Health check pings add small data overhead
- Verification pings on connection add latency
- Parallel sends optimize throughput

### Future Enhancements

1. **Signal Strength Monitoring**: If API exposes RSSI, use for connection quality decisions
2. **Intelligent Connection Pruning**: Replace weak connections with stronger ones
3. **Predictive Reconnection**: Reconnect before complete signal loss
4. **Mesh Topology Optimization**: Prefer connections that improve network coverage
5. **Bandwidth Adaptation**: Adjust payload sizes based on connection quality
