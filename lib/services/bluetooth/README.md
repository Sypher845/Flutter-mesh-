# Bluetooth Service Architecture

This directory contains a modular, well-structured implementation of the Bluetooth mesh network service.

## 📁 Structure

```
bluetooth/
├── bluetooth_service.dart          # Main orchestrator service
├── connection_manager.dart         # Connection handling (advertising, discovery, connections)
├── reconnection_manager.dart       # Auto-reconnection with backoff (NEW)
├── connection_metrics.dart         # Connection statistics & adaptive strategy (NEW)
├── payload_handler.dart            # Payload sending/receiving logic
├── mesh_network_manager.dart       # Mesh network & rebroadcast logic
├── permission_manager.dart         # Permission handling
└── models/
    ├── bluetooth_constants.dart    # All constants in one place
    ├── received_data.dart          # ReceivedData model
    ├── reconnection_entry.dart     # Reconnection queue entry (NEW)
    ├── connection_attempt.dart     # Connection attempt record (NEW)
    └── connection_event.dart       # Connection event log entry (NEW)
```

## 🎯 Separation of Concerns

### **BluetoothService** (Main Orchestrator)
**Responsibility:** Coordinates all Bluetooth operations
- Initializes and manages all sub-managers
- Handles high-level operations (send report, receive data)
- Manages state and notifies listeners
- Provides public API for UI
- Handles app lifecycle transitions (NEW)
- Monitors Bluetooth state changes (NEW)

**Key Methods:**
- `sendReportData()` - Send a report to nearby devices
- `verifyAndCleanConnections()` - Health check connections
- `clearReceivedData()` - Clear received data list
- `handleAppLifecycleChange()` - Handle background/foreground (NEW)
- `handleBluetoothStateChange()` - Handle BT enable/disable (NEW)
- `getConnectionStatistics()` - Get metrics and stats (NEW)

---

### **ConnectionManager** (Enhanced)
**Responsibility:** Manages all connection-related operations
- Advertising (making device visible)
- Discovery (finding nearby devices)
- Connection establishment and teardown
- Connection state tracking
- Connection limit enforcement (max 8) (NEW)
- Adaptive discovery frequency (NEW)
- Error recovery and full reset (NEW)

**Key Methods:**
- `startAdvertising()` - Make device visible
- `startDiscovery()` - Find nearby devices (adaptive frequency)
- `requestConnection()` - Connect to a device
- `acceptConnection()` - Accept incoming connection
- `disconnectAll()` - Disconnect from all devices
- `canAcceptNewConnection()` - Check connection limit (NEW)
- `restartDiscovery()` - Refresh discovery scan (NEW)
- `performFullReset()` - Full reset on errors (NEW)

**Callbacks:**
- `onConnectionInitiated` - When connection starts
- `onConnectionResult` - When connection succeeds/fails
- `onDisconnected` - When device disconnects
- `onEndpointFound` - When device is discovered
- `onEndpointLost` - When device is lost

---

### **ReconnectionManager** (NEW)
**Responsibility:** Manages automatic reconnection for lost connections
- Queue-based reconnection management
- Exponential backoff timing
- Retry count tracking (max 5 attempts)
- Automatic cleanup of exhausted attempts

**Key Methods:**
- `addToQueue()` - Add disconnected endpoint to queue
- `removeFromQueue()` - Remove on successful reconnection
- `startReconnectionLoop()` - Start periodic reconnection timer
- `attemptReconnections()` - Process reconnection queue
- `shouldAttemptReconnection()` - Check backoff timing

**Callbacks:**
- `onReconnectAttempt` - When reconnection is attempted
- `onReconnectSuccess` - When reconnection succeeds
- `onReconnectExhausted` - When max retries reached

**Features:**
- 5 second intervals between attempts
- Maximum 5 retry attempts per endpoint
- Automatic queue cleanup
- Prevents duplicate queue entries

---

### **ConnectionMetrics** (NEW)
**Responsibility:** Tracks connection statistics for adaptive strategy
- Connection attempt tracking
- Success rate calculation
- Adaptive timeout adjustment
- Detailed event logging

**Key Methods:**
- `recordAttempt()` - Record connection outcome
- `recordEvent()` - Log detailed connection event
- `calculateSuccessRate()` - Compute success percentage
- `getRecommendedTimeout()` - Get adaptive timeout value
- `updateTimeout()` - Adjust timeout based on success rate
- `getStatistics()` - Get metrics summary

**Features:**
- Sliding window of last 10 attempts
- Adaptive timeout: 5s → 10s based on success rate
- < 50% success → increase timeout
- > 80% success → decrease timeout
- Event log with timestamps and metadata
- Statistics API for monitoring

---

### **PayloadHandler**
**Responsibility:** Handles all payload operations
- Sending bytes with retry logic
- Decoding received payloads
- Payload validation (size, format)
- Special payloads (ping, ack, pre-send check)

**Key Methods:**
- `sendBytesPayload()` - Send with retry and exponential backoff
- `sendWithRetry()` - Simple retry for rebroadcast
- `decodePayload()` - Decode bytes to JSON
- `validatePayloadSize()` - Check payload size limits
- `sendConnectionPing()` - Verify connection works
- `sendPreSendCheck()` - Quick connection test

---

### **MeshNetworkManager**
**Responsibility:** Manages mesh network operations
- UUID tracking for deduplication
- Hop count management
- Rebroadcasting logic
- Memory management (cleanup old UUIDs)

**Key Methods:**
- `hasReceivedReport()` - Check if UUID already received
- `addReceivedReport()` - Add UUID to tracking set
- `shouldRebroadcast()` - Check if report should be rebroadcasted
- `rebroadcastReport()` - Rebroadcast to other devices

**Features:**
- Prevents duplicate reports
- Limits hop count to prevent infinite loops
- Automatic cleanup of old UUIDs
- Increments hop count on rebroadcast

---

### **PermissionManager**
**Responsibility:** Handles all permission requests
- Bluetooth permissions (connect, scan, advertise)
- Location permissions (required for Bluetooth scanning)
- Nearby WiFi devices permission

**Key Methods:**
- `requestPermissions()` - Request all necessary permissions

**Features:**
- Tries multiple permission types (locationWhenInUse, location, locationAlways)
- Handles permission errors gracefully
- Returns clear success/failure status

---

### **Models**

#### **BluetoothConstants**
All constants in one place:
- Service ID and device name
- Retry counts and timeouts
- Mesh network settings (max hops, UUID limits)
- Payload size limits
- Payload type strings
- Reconnection settings (NEW)
- Adaptive strategy thresholds (NEW)
- Connection management limits (NEW)

#### **ReceivedData**
Model for received data:
- Sender information
- Payload data
- Timestamp
- Helper methods (dataType, reportUUID, hopCount)

#### **ReconnectionEntry** (NEW)
Model for reconnection queue entries:
- Endpoint ID and name
- First attempt timestamp
- Attempt count
- Next attempt time
- Helper methods (isExhausted, backoffDuration)

#### **ConnectionAttempt** (NEW)
Model for connection attempt records:
- Endpoint ID
- Timestamp
- Success/failure status
- Error message (if failed)
- JSON serialization

#### **ConnectionEvent** (NEW)
Model for detailed event logging:
- Endpoint ID
- Event type (discovered, connected, disconnected, failed)
- Timestamp
- Metadata (signal strength, error codes, etc.)
- JSON serialization

---

## 🔄 Data Flow

### **Receiving a Report:**

```
1. ConnectionManager receives payload
   ↓
2. Calls BluetoothService._onPayloadReceived()
   ↓
3. PayloadHandler.decodePayload() - Decode bytes to JSON
   ↓
4. BluetoothService._processReceivedPayload() - Process data
   ↓
5. Check if report data → _handleReportData()
   ↓
6. MeshNetworkManager.hasReceivedReport() - Check for duplicate
   ↓
7. If new: MeshNetworkManager.addReceivedReport() - Track UUID
   ↓
8. MeshNetworkManager.shouldRebroadcast() - Check hop count
   ↓
9. If yes: MeshNetworkManager.rebroadcastReport() - Send to others
   ↓
10. Store in _receivedDataList and notify UI
```

### **Sending a Report:**

```
1. UI calls BluetoothService.sendReportData()
   ↓
2. ConnectionManager.startAdvertising() + startDiscovery()
   ↓
3. Wait for connections (adaptive discovery frequency)
   ↓
4. verifyAndCleanConnections() - Remove stale connections (2s timeout)
   ↓
5. PayloadHandler.sendPreSendCheck() - Verify responsive
   ↓
6. Prepare payload with hop count = 0
   ↓
7. PayloadHandler.validatePayloadSize() - Check size
   ↓
8. PayloadHandler.sendBytesPayload() - Send to all devices (parallel)
   ↓
9. ConnectionMetrics.recordAttempt() - Track success/failure
   ↓
10. If success: MeshNetworkManager.addReceivedReport() - Track own UUID
   ↓
11. Return to receiver mode (keep connections)
```

### **Auto-Reconnection Flow:** (NEW)

```
1. Device disconnects unexpectedly
   ↓
2. ConnectionManager._handleDisconnected() triggered
   ↓
3. ReconnectionManager.addToQueue() - Add to reconnection queue
   ↓
4. ConnectionMetrics.recordEvent() - Log disconnection
   ↓
5. ReconnectionManager timer triggers (every 2 seconds)
   ↓
6. attemptReconnections() - Process queue
   ↓
7. Check shouldAttemptReconnection() - Verify backoff timing
   ↓
8. If ready: ConnectionManager.requestConnection()
   ↓
9. On success: ReconnectionManager.removeFromQueue()
   ↓
10. On failure: Increment attempt count, schedule next retry
   ↓
11. If exhausted (5 attempts): Remove from queue
```

### **Adaptive Strategy Flow:** (NEW)

```
1. Connection attempt completes (success or failure)
   ↓
2. ConnectionMetrics.recordAttempt() - Log outcome
   ↓
3. calculateSuccessRate() - Compute rate over last 10 attempts
   ↓
4. If < 50% success:
   └─> updateTimeout() - Increase to 10 seconds
   ↓
5. If > 80% success:
   └─> updateTimeout() - Decrease to 5 seconds
   ↓
6. getRecommendedTimeout() - Return current timeout
   ↓
7. ConnectionManager uses adaptive timeout for next connection
```

### **Health Check Flow:** (Enhanced)

```
1. Timer triggers every 30 seconds
   ↓
2. verifyAndCleanConnections() - Check all connections
   ↓
3. For each connected device:
   ├─> Send health check ping
   ├─> Wait up to 2 seconds for response
   └─> If timeout: Mark as stale
   ↓
4. For each stale connection:
   ├─> ConnectionManager.disconnect()
   ├─> ReconnectionManager.addToQueue()
   └─> ConnectionMetrics.recordEvent()
   ↓
5. Log active vs stale connection counts
   ↓
6. notifyListeners() - Update UI
```

---

## 🎨 Benefits of This Structure

### **1. Modularity**
- Each manager has a single, clear responsibility
- Easy to understand and maintain
- Changes in one area don't affect others

### **2. Testability**
- Each manager can be tested independently
- Mock managers for unit testing
- Clear interfaces between components
- Property-based testing for correctness properties

### **3. Reusability**
- Managers can be reused in other projects
- PermissionManager works for any Bluetooth app
- PayloadHandler works for any payload type
- ReconnectionManager works for any connection-based system

### **4. Maintainability**
- Easy to find where specific logic lives
- Clear separation makes debugging easier
- Adding features doesn't clutter existing code
- Comprehensive logging for troubleshooting

### **5. Scalability**
- Easy to add new managers (e.g., AnalyticsManager)
- Easy to extend existing managers
- Constants in one place make changes easy
- Adaptive strategy handles varying conditions

### **6. Reliability** (NEW)
- Auto-reconnection ensures persistent connections
- Health checks detect and remove dead connections
- Adaptive timeouts optimize for environment
- Error recovery prevents system failures

### **7. Performance** (NEW)
- Connection limit prevents resource exhaustion
- Adaptive discovery reduces battery drain
- Parallel connection processing speeds up mesh formation
- Metrics tracking enables optimization

---

## 🔧 Usage Examples

### **Basic Setup**

```dart
// In main.dart
ChangeNotifierProvider(
  create: (_) => BluetoothService(),
)

// The service automatically:
// - Initializes all managers (including ReconnectionManager, ConnectionMetrics)
// - Starts advertising and discovery
// - Begins health checks every 30 seconds
// - Starts reconnection loop
// - Monitors app lifecycle and Bluetooth state
```

### **Sending a Report**

```dart
final bluetooth = Provider.of<BluetoothService>(context, listen: false);

// Send report with automatic connection management
final success = await bluetooth.sendReportData(
  title: 'Hazard Report',
  description: 'Fallen tree blocking path',
  hazardType: 'Obstacle',
  location: 'Trail marker 5',
  imageBytes: imageData,
);

if (success) {
  print('Report sent to ${bluetooth.connectedDeviceCount} devices');
}
```

### **Monitoring Connection Status**

```dart
Consumer<BluetoothService>(
  builder: (context, bluetooth, child) {
    return Column(
      children: [
        Text('Connected: ${bluetooth.connectedDeviceCount}'),
        Text('Status: ${bluetooth.statusMessage}'),
        Text('Advertising: ${bluetooth.isAdvertising}'),
        Text('Discovering: ${bluetooth.isDiscovering}'),
      ],
    );
  },
)
```

### **Getting Connection Statistics** (NEW)

```dart
final bluetooth = Provider.of<BluetoothService>(context, listen: false);
final stats = bluetooth.getConnectionStatistics();

print('Success Rate: ${stats['successRate']}%');
print('Current Timeout: ${stats['currentTimeout']}ms');
print('Total Attempts: ${stats['totalAttempts']}');
print('Active Connections: ${stats['activeConnections']}');
print('Reconnection Queue: ${stats['reconnectionQueueSize']}');
print('Recent Events: ${stats['recentEvents']}');
```

### **Manual Health Check**

```dart
final bluetooth = Provider.of<BluetoothService>(context, listen: false);

// Manually trigger health check (also runs automatically every 30s)
await bluetooth.verifyAndCleanConnections();

// Check results
print('Active connections: ${bluetooth.connectedDeviceCount}');
```

### **Viewing Received Data**

```dart
ListView.builder(
  itemCount: bluetooth.receivedDataList.length,
  itemBuilder: (context, index) {
    final data = bluetooth.receivedDataList[index];
    return ListTile(
      title: Text(data.reportTitle ?? 'Unknown'),
      subtitle: Text('From: ${data.senderName} at ${data.timestamp}'),
      trailing: Text('Hop: ${data.hopCount}'),
    );
  },
)
```

---

## 📝 Adding New Features

### **Add a new payload type:**
1. Add constant to `BluetoothConstants`
2. Add handling in `BluetoothService._processReceivedPayload()`
3. Add sending method if needed

### **Add connection analytics:**
1. Extend `ConnectionMetrics` with new metrics
2. Add recording calls at key points
3. Expose via `getConnectionStatistics()`

### **Add encryption:**
1. Create `EncryptionManager`
2. Wrap payloads in `PayloadHandler.sendBytesPayload()`
3. Unwrap in `PayloadHandler.decodePayload()`

### **Customize reconnection behavior:**
1. Adjust constants in `BluetoothConstants`:
   - `reconnectionMaxRetries` - Change max attempts
   - `reconnectionIntervalSeconds` - Change retry interval
2. Modify `ReconnectionManager.shouldAttemptReconnection()` for custom backoff

### **Customize adaptive strategy:**
1. Adjust thresholds in `BluetoothConstants`:
   - `lowSuccessThreshold` - When to increase timeout
   - `highSuccessThreshold` - When to decrease timeout
   - `metricsWindowSize` - Success rate calculation window
2. Modify `ConnectionMetrics.updateTimeout()` for custom logic

### **Add custom connection limits:**
1. Change `maxConnections` in `BluetoothConstants`
2. Optionally add logic in `ConnectionManager.canAcceptNewConnection()`

---

## 🐛 Debugging

Enable debug mode to see detailed logs:
```dart
// Run in debug mode
flutter run --debug
```

Look for these log patterns:
- `🔗` - Connection events
- `📨` - Payload callbacks
- `📥` - Received data
- `📤` - Sending data
- `🔄` - Rebroadcast operations
- `🔁` - Reconnection attempts (NEW)
- `📊` - Metrics updates (NEW)
- `⚡` - Health checks (NEW)
- `📡` - Discovery events (NEW)
- `✅` - Success
- `❌` - Errors
- `⚠️` - Warnings

### **Debug Connection Issues**

```dart
// Get detailed statistics
final stats = bluetooth.getConnectionStatistics();
print('Debug Info:');
print('  Success Rate: ${stats['successRate']}%');
print('  Current Timeout: ${stats['currentTimeout']}ms');
print('  Reconnection Queue: ${stats['reconnectionQueueSize']}');
print('  Recent Events: ${stats['recentEvents']}');

// Check recent connection events
for (var event in stats['recentEvents']) {
  print('${event['timestamp']}: ${event['eventType']} - ${event['endpointId']}');
}
```

### **Common Issues and Solutions**

**Issue: Connections not forming**
- Check: `bluetooth.isAdvertising` and `bluetooth.isDiscovering`
- Check: Connection limit not reached (< 8 devices)
- Check: Permissions granted
- Solution: Review logs for discovery events

**Issue: Frequent disconnections**
- Check: Success rate in statistics (should be > 50%)
- Check: Health check timeout (default 2s)
- Solution: Increase timeout if environment is challenging

**Issue: Reconnection not working**
- Check: Reconnection queue size in statistics
- Check: Devices still advertising
- Solution: Verify retry count hasn't been exhausted (max 5)

**Issue: Poor performance**
- Check: Discovery frequency (adaptive based on connections)
- Check: Number of active connections
- Solution: Reduce connection limit or adjust discovery frequency

---

## 📊 Performance Considerations

### **Memory:**
- UUID tracking limited to 100 entries
- Received data limited to 20 entries
- Connection metrics window: last 10 attempts (NEW)
- Event log limited to 50 recent events (NEW)
- Reconnection queue limited to 20 entries (NEW)
- Automatic cleanup prevents memory leaks

### **Battery:**
- Continuous discovery uses battery
- Adaptive discovery frequency reduces drain (NEW):
  - High frequency (5s) when no connections
  - Normal frequency (30s) when connected
- Health checks every 30 seconds (configurable)
- Consider reducing health check frequency for production

### **Network:**
- Pre-send checks add small overhead
- Prevents wasted sends to dead connections
- Hop count prevents infinite loops
- Parallel connection processing speeds up mesh formation (NEW)
- Connection limit (8 devices) prevents resource exhaustion (NEW)

### **CPU:**
- Reconnection timer runs every 2 seconds (NEW)
- Health check timer runs every 30 seconds
- Metrics calculation on each connection attempt (NEW)
- All operations are lightweight and non-blocking

---

## 🔒 Security Considerations

### **Current Implementation:**
- No encryption (payloads sent in plain text)
- No authentication (any device can connect)
- No authorization (any device can send reports)
- Connection limit provides basic DoS protection (NEW)

### **Recommendations for Production:**
1. Add payload encryption (AES-256)
2. Implement device authentication (certificate-based)
3. Add report signing/verification (HMAC)
4. Implement rate limiting per device
5. Add user consent for data sharing
6. Validate all incoming payloads
7. Add connection approval mechanism

### **Built-in Protections:** (NEW)
- Connection limit prevents resource exhaustion
- Hop count prevents infinite message loops
- UUID tracking prevents duplicate processing
- Health checks remove dead connections
- Reconnection backoff prevents connection storms

---

## ⚙️ Configuration Options

All configuration is centralized in `bluetooth_constants.dart`:

### **Connection Management**
```dart
static const int maxConnections = 8;  // Maximum simultaneous connections
static const int healthCheckIntervalSeconds = 30;  // Health check frequency
static const int healthCheckTimeoutSeconds = 2;  // Stale connection timeout
```

### **Reconnection Settings**
```dart
static const int reconnectionMaxRetries = 5;  // Max reconnection attempts
static const int reconnectionIntervalSeconds = 5;  // Time between retries
static const int reconnectionTimerIntervalSeconds = 2;  // Queue check frequency
```

### **Adaptive Strategy**
```dart
static const int metricsWindowSize = 10;  // Success rate calculation window
static const double lowSuccessThreshold = 0.5;  // Increase timeout threshold
static const double highSuccessThreshold = 0.8;  // Decrease timeout threshold
static const int adaptiveTimeoutMin = 5000;  // Minimum timeout (ms)
static const int adaptiveTimeoutMax = 10000;  // Maximum timeout (ms)
```

### **Discovery Settings**
```dart
static const int discoveryHighFrequencySeconds = 5;  // When no connections
static const int discoveryNormalFrequencySeconds = 30;  // When connected
static const int discoveryRestartIntervalSeconds = 30;  // Restart threshold
```

### **Error Recovery**
```dart
static const int fullResetErrorThreshold = 3;  // Errors before full reset
static const int sendRetryCount = 3;  // Send retry attempts
static const int sendRetryDelayMs = 1000;  // Base retry delay
```

### **Range Optimization**
```dart
static const Strategy strategy = Strategy.P2P_CLUSTER;  // Optimized for range
static const int extendedConnectionTimeout = 10000;  // Extended timeout for range
```

---

## 📚 Further Reading

- [Nearby Connections API](https://developers.google.com/nearby/connections/overview)
- [Flutter Provider Pattern](https://pub.dev/packages/provider)
- [Mesh Network Topology](https://en.wikipedia.org/wiki/Mesh_networking)
- [Bluetooth Range Optimization](https://developers.google.com/nearby/connections/strategies)
- [Property-Based Testing](https://en.wikipedia.org/wiki/Property_testing)
