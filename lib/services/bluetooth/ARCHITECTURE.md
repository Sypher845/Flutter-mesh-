# Bluetooth Service Architecture Diagram

## 📊 Component Hierarchy

```
┌─────────────────────────────────────────────────────────────┐
│                     BluetoothService                        │
│                   (Main Orchestrator)                       │
│                                                             │
│  • Coordinates all operations                               │
│  • Manages state & notifications                            │
│  • Provides public API                                      │
│  • Handles high-level logic                                 │
│  • Lifecycle management (background/foreground)             │
│  • Bluetooth state monitoring                               │
└─────────────────────────────────────────────────────────────┘
                            │
                            │ manages
                            ▼
        ┌───────────────────┴───────────────────┬──────────────┐
        │                   │                   │              │
        ▼                   ▼                   ▼              ▼
┌──────────────┐   ┌──────────────┐   ┌──────────────┐   ┌──────────────┐
│ Connection   │   │   Payload    │   │ MeshNetwork  │   │ Reconnection │
│   Manager    │   │   Handler    │   │   Manager    │   │   Manager    │
├──────────────┤   ├──────────────┤   ├──────────────┤   ├──────────────┤
│• Advertising │   │• Send bytes  │   │• UUID track  │   │• Queue mgmt  │
│• Discovery   │   │• Decode data │   │• Hop count   │   │• Auto retry  │
│• Connections │   │• Validation  │   │• Rebroadcast │   │• Backoff     │
│• Endpoints   │   │• Retry logic │   │• Cleanup     │   │• Callbacks   │
│• Conn limit  │   │• Health ping │   │              │   │              │
│• Adaptive    │   │              │   │              │   │              │
└──────────────┘   └──────────────┘   └──────────────┘   └──────────────┘
        │                   │                   │                   │
        │                   │                   │                   │
        ▼                   ▼                   ▼                   ▼
┌──────────────┐   ┌──────────────┐   ┌──────────────┐   ┌──────────────┐
│ Connection   │   │  Bluetooth   │   │  Received    │   │ Permission   │
│   Metrics    │   │  Constants   │   │    Data      │   │   Manager    │
├──────────────┤   ├──────────────┤   ├──────────────┤   ├──────────────┤
│• Attempt log │   │• Service ID  │   │• Sender info │   │• BT perms    │
│• Success rate│   │• Timeouts    │   │• Payload     │   │• Location    │
│• Adaptive TO │   │• Limits      │   │• Timestamp   │   │• WiFi nearby │
│• Event log   │   │• Types       │   │              │   │              │
│• Statistics  │   │• Reconnect   │   │              │   │              │
└──────────────┘   │• Metrics     │   └──────────────┘   └──────────────┘
                   └──────────────┘
```

---

## 🆕 New Components (Enhancement)

### **ReconnectionManager** (NEW)
Manages automatic reconnection for lost connections.

**Features:**
- Queue-based reconnection with exponential backoff
- Tracks retry counts (max 5 attempts)
- Periodic reconnection attempts (every 5 seconds)
- Automatic cleanup of exhausted attempts
- Callbacks for reconnection events

**Key Methods:**
- `addToQueue()` - Add disconnected endpoint
- `removeFromQueue()` - Remove on successful reconnection
- `attemptReconnections()` - Process reconnection queue
- `shouldAttemptReconnection()` - Check backoff timing

### **ConnectionMetrics** (NEW)
Tracks connection statistics for adaptive strategy.

**Features:**
- Records connection attempt outcomes
- Calculates success rates over sliding window (last 10 attempts)
- Adaptive timeout adjustment (5s → 10s based on success rate)
- Detailed event logging for debugging
- Statistics API for monitoring

**Key Methods:**
- `recordAttempt()` - Log connection outcome
- `calculateSuccessRate()` - Compute success percentage
- `getRecommendedTimeout()` - Get adaptive timeout value
- `updateTimeout()` - Adjust based on success rate
- `recordEvent()` - Log detailed connection events
- `getStatistics()` - Get metrics summary

---

## 🔄 Data Flow: Receiving a Report

```
┌─────────────┐
│   Device A  │ (Sender)
└──────┬──────┘
       │ Sends report via Bluetooth
       │
       ▼
┌─────────────────────────────────────────────────────────┐
│                    Device B (Receiver)                  │
│                                                         │
│  1. ConnectionManager                                   │
│     └─> Receives payload via Nearby Connections        │
│                                                         │
│  2. BluetoothService._onPayloadReceived()              │
│     └─> Triggered by payload callback                  │
│                                                         │
│  3. PayloadHandler.decodePayload()                     │
│     └─> Bytes → JSON                                   │
│                                                         │
│  4. BluetoothService._processReceivedPayload()         │
│     └─> Check payload type                             │
│                                                         │
│  5. BluetoothService._handleReportData()               │
│     └─> Extract report UUID                            │
│                                                         │
│  6. MeshNetworkManager.hasReceivedReport()             │
│     └─> Check for duplicate                            │
│                                                         │
│  7. MeshNetworkManager.addReceivedReport()             │
│     └─> Track UUID                                     │
│                                                         │
│  8. MeshNetworkManager.shouldRebroadcast()             │
│     └─> Check hop count < max                          │
│                                                         │
│  9. MeshNetworkManager.rebroadcastReport()             │
│     └─> Send to other connected devices                │
│                                                         │
│  10. Store in _receivedDataList                        │
│      └─> notifyListeners() → UI updates               │
└─────────────────────────────────────────────────────────┘
       │
       │ Rebroadcast
       ▼
┌─────────────┐
│   Device C  │ (Next hop)
└─────────────┘
```

---

## 📤 Data Flow: Sending a Report

```
┌─────────────────────────────────────────────────────────┐
│                         UI Layer                        │
│                                                         │
│  User creates report → Clicks "Submit"                 │
└─────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────┐
│              BluetoothService.sendReportData()          │
│                                                         │
│  1. ConnectionManager.startAdvertising()               │
│     └─> Make device visible                            │
│                                                         │
│  2. ConnectionManager.startDiscovery()                 │
│     └─> Find nearby devices                            │
│                                                         │
│  3. Wait for connections                               │
│     └─> Loop until devices found                       │
│                                                         │
│  4. verifyAndCleanConnections()                        │
│     └─> Remove dead connections                        │
│                                                         │
│  5. PayloadHandler.sendPreSendCheck()                  │
│     └─> Verify devices are responsive                  │
│                                                         │
│  6. Prepare payload                                    │
│     ├─> Encode image to base64                         │
│     ├─> Create JSON payload                            │
│     ├─> Add hopCount = 0                               │
│     └─> Convert to bytes                               │
│                                                         │
│  7. PayloadHandler.validatePayloadSize()               │
│     └─> Check < 500KB                                  │
│                                                         │
│  8. PayloadHandler.sendBytesPayload()                  │
│     ├─> Send to all devices in parallel               │
│     ├─> Retry up to 3 times per device                │
│     └─> Exponential backoff                            │
│                                                         │
│  9. If success:                                        │
│     └─> MeshNetworkManager.addReceivedReport()        │
│         └─> Track own UUID                             │
│                                                         │
│  10. Return to receiver mode                           │
│      ├─> Keep advertising                              │
│      ├─> Keep discovery                                │
│      └─> Keep connections                              │
└─────────────────────────────────────────────────────────┘
                            │
                            ▼
                    ┌───────────────┐
                    │  Device A, B  │ (Receivers)
                    └───────────────┘
```

---

## 🔗 Connection Lifecycle

```
┌─────────────────────────────────────────────────────────┐
│                    Device Startup                       │
│                                                         │
│  BluetoothService()                                    │
│  ├─> _initializeManagers()                            │
│  │   ├─> ConnectionManager                            │
│  │   ├─> ReconnectionManager (NEW)                    │
│  │   ├─> ConnectionMetrics (NEW)                      │
│  │   ├─> PayloadHandler                               │
│  │   └─> MeshNetworkManager                           │
│  └─> _initializeReceiverMode()                        │
│      ├─> ConnectionManager.startAdvertising()         │
│      │   └─> Device becomes visible                   │
│      └─> ConnectionManager.startDiscovery()           │
│          └─> Device starts scanning (adaptive freq)   │
└─────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────┐
│                  Device Discovery                       │
│                                                         │
│  ConnectionManager._handleEndpointFound()              │
│  ├─> Check connection limit (max 8)                   │
│  ├─> Log discovery event (ConnectionMetrics)          │
│  └─> If under limit:                                  │
│      └─> ConnectionManager.requestConnection()        │
└─────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────┐
│               Connection Establishment                  │
│                                                         │
│  ConnectionManager._handleConnectionInitiated()        │
│  ├─> Called on BOTH devices                           │
│  ├─> Accept within 2 seconds                          │
│  └─> ConnectionManager.acceptConnection()             │
│      └─> Register payload callback immediately        │
└─────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────┐
│                Connection Confirmed                     │
│                                                         │
│  ConnectionManager._handleConnectionResult()           │
│  ├─> Status.CONNECTED                                 │
│  ├─> Record success (ConnectionMetrics)               │
│  ├─> Send verification ping                           │
│  ├─> Add to _connectedDevices                         │
│  └─> BluetoothService._registerPayloadCallback()      │
│      └─> Register final payload callback              │
└─────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────┐
│                  Connection Active                      │
│                                                         │
│  • Can send/receive data                              │
│  • Health checks every 30s (2s timeout)               │
│  • Automatic cleanup of stale connections             │
│  • Adaptive discovery frequency                       │
│  • Connection quality logging                         │
└─────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────┐
│                   Disconnection                         │
│                                                         │
│  ConnectionManager._handleDisconnected()               │
│  ├─> Remove from _connectedDevices                    │
│  ├─> Add to ReconnectionManager queue (NEW)           │
│  ├─> Record event (ConnectionMetrics)                 │
│  └─> notifyListeners()                                │
└─────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────┐
│              Auto-Reconnection (NEW)                    │
│                                                         │
│  ReconnectionManager.attemptReconnections()            │
│  ├─> Check backoff timing (5s intervals)              │
│  ├─> Attempt reconnection (max 5 retries)             │
│  ├─> On success: remove from queue                    │
│  └─> On exhausted: remove from queue                  │
└─────────────────────────────────────────────────────────┘
```

---

## 🕸️ Mesh Network Topology

```
Initial State:
┌─────────┐
│ Device A│ (Advertising + Discovery)
└─────────┘

┌─────────┐
│ Device B│ (Advertising + Discovery)
└─────────┘

┌─────────┐
│ Device C│ (Advertising + Discovery)
└─────────┘


After Discovery:
┌─────────┐
│ Device A│───────┐
└─────────┘       │
     │            │
     │            │
     ▼            ▼
┌─────────┐   ┌─────────┐
│ Device B│───│ Device C│
└─────────┘   └─────────┘

Full Mesh Network Formed!


Report Flow (with hop count):
┌─────────┐
│ Device A│ Sends report (hop=0)
└─────────┘
     │
     │ Send
     ▼
┌─────────┐
│ Device B│ Receives (hop=0)
└─────────┘ Rebroadcasts (hop=1)
     │
     │ Rebroadcast
     ▼
┌─────────┐
│ Device C│ Receives (hop=1)
└─────────┘ Rebroadcasts (hop=2)
     │
     │ Rebroadcast
     ▼
┌─────────┐
│ Device A│ Receives (hop=2)
└─────────┘ Already has UUID → Ignores
```

---

## 🔐 Security Layers (Future)

```
┌─────────────────────────────────────────────────────────┐
│                    Application Layer                    │
│  • Report validation                                    │
│  • User authentication                                  │
│  • Rate limiting                                        │
└─────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────┐
│                   Encryption Layer                      │
│  • Payload encryption (AES-256)                        │
│  • Key exchange (Diffie-Hellman)                       │
│  • Message signing (HMAC)                              │
└─────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────┐
│                  Bluetooth Layer                        │
│  • Nearby Connections API                              │
│  • Device discovery                                     │
│  • Connection management                                │
└─────────────────────────────────────────────────────────┘
```

---

## 📊 State Management

```
┌─────────────────────────────────────────────────────────┐
│              BluetoothService (ChangeNotifier)          │
│                                                         │
│  State:                                                │
│  ├─ _isAdvertising: bool                              │
│  ├─ _isDiscovering: bool                              │
│  ├─ _connectedDevices: Set<String>                    │
│  ├─ _receivedDataList: List<ReceivedData>             │
│  ├─ _receivedReportUUIDs: Set<String>                 │
│  └─ _statusMessage: String                            │
│                                                         │
│  Getters (for UI):                                     │
│  ├─ isAdvertising                                      │
│  ├─ isDiscovering                                      │
│  ├─ connectedDevices                                   │
│  ├─ receivedDataList                                   │
│  ├─ statusMessage                                      │
│  └─ receivedReportCount                               │
│                                                         │
│  notifyListeners() called when:                       │
│  ├─ Connection state changes                          │
│  ├─ New data received                                 │
│  ├─ Status message updates                            │
│  └─ Device list changes                               │
└─────────────────────────────────────────────────────────┘
                            │
                            │ notifies
                            ▼
┌─────────────────────────────────────────────────────────┐
│                      UI Widgets                         │
│                                                         │
│  Consumer<BluetoothService>(                           │
│    builder: (context, bluetooth, child) {              │
│      return Text(bluetooth.statusMessage);             │
│    }                                                   │
│  )                                                     │
└─────────────────────────────────────────────────────────┘
```

---

## 🔧 Enhanced Features

### **1. Range Optimization**
- P2P_CLUSTER strategy for maximum range
- Extended connection timeouts (5-10 seconds)
- Retry logic for weak signals
- Platform-specific transmit power configuration

### **2. Auto-Reconnection System**
- Queue-based reconnection management
- Exponential backoff (5 second intervals)
- Maximum 5 retry attempts per endpoint
- Automatic cleanup of exhausted attempts

### **3. Adaptive Connection Strategy**
- Success rate tracking (sliding window of 10 attempts)
- Dynamic timeout adjustment:
  - < 50% success → increase to 10s
  - > 80% success → decrease to 5s
- Discovery restart on low device count
- Adaptive discovery frequency based on connections

### **4. Enhanced Health Monitoring**
- Faster stale detection (2 second timeout)
- Periodic health checks (every 30 seconds)
- Automatic disconnection of stale connections
- Stale connections added to reconnection queue

### **5. Connection Quality Management**
- Connection limit enforcement (max 8 devices)
- Parallel connection processing
- Signal strength logging (when available)
- Connection quality event tracking

### **6. Lifecycle Management**
- Background/foreground transition handling
- Connection preservation during app state changes
- Bluetooth state monitoring
- Automatic pause/resume on Bluetooth disable/enable

### **7. Error Recovery**
- Graceful handling of API errors (ALREADY_ADVERTISING, ALREADY_DISCOVERING)
- Automatic retry with exponential backoff
- Full reset on consecutive errors (3+ errors)
- Comprehensive error logging

### **8. Comprehensive Metrics**
- Connection attempt tracking
- Success rate calculation
- Event logging with timestamps
- Debug mode for detailed metrics
- Statistics API for monitoring

---

## 🎯 Key Design Patterns

### **1. Facade Pattern**
`BluetoothService` acts as a facade, providing a simple interface to complex subsystems.

### **2. Strategy Pattern**
Different managers implement different strategies (connection, payload, mesh).

### **3. Observer Pattern**
`ChangeNotifier` notifies UI of state changes.

### **4. Singleton Pattern**
Managers are created once and reused throughout the service lifecycle.

### **5. Dependency Injection**
Managers are injected into `BluetoothService` constructor.

---

## 📈 Performance Characteristics

### **Time Complexity:**
- Connection lookup: O(1) - using Set
- UUID lookup: O(1) - using Set
- Rebroadcast: O(n) - where n = connected devices

### **Space Complexity:**
- UUID tracking: O(100) - limited to 100 entries
- Received data: O(20) - limited to 20 entries
- Connections: O(n) - where n = connected devices

### **Network Complexity:**
- Discovery: O(n) - scans all nearby devices
- Send: O(n) - sends to all connected devices
- Rebroadcast: O(n²) - in worst case mesh network

---

## ⚙️ Configuration Options

### **Connection Management**
```dart
// In bluetooth_constants.dart
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
static const int metricsWindowSize = 10;  // Success rate window
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

---

## 📖 Usage Examples

### **Basic Initialization**
```dart
// In main.dart
ChangeNotifierProvider(
  create: (_) => BluetoothService(),
)

// The service automatically:
// - Initializes all managers
// - Starts advertising and discovery
// - Begins health checks
// - Starts reconnection loop
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

### **Getting Connection Statistics**
```dart
final bluetooth = Provider.of<BluetoothService>(context, listen: false);
final stats = bluetooth.getConnectionStatistics();

print('Success Rate: ${stats['successRate']}%');
print('Current Timeout: ${stats['currentTimeout']}ms');
print('Total Attempts: ${stats['totalAttempts']}');
print('Active Connections: ${stats['activeConnections']}');
print('Reconnection Queue: ${stats['reconnectionQueueSize']}');
```

### **Manual Health Check**
```dart
final bluetooth = Provider.of<BluetoothService>(context, listen: false);

// Manually trigger health check
await bluetooth.verifyAndCleanConnections();

// Check results
print('Active: ${bluetooth.connectedDeviceCount}');
```

### **Handling Lifecycle Events**
```dart
// Automatic handling - no code needed!
// The service automatically:
// - Preserves connections when app goes to background
// - Verifies health when app returns to foreground
// - Pauses operations when Bluetooth is disabled
// - Resumes operations when Bluetooth is enabled
```

### **Debug Mode**
```dart
// Enable detailed logging in debug builds
// Logs include:
// - Signal strength (when available)
// - Connection quality metrics
// - Detailed event timeline
// - Success/failure reasons

// Check logs for patterns like:
// 🔗 Connection events
// 📊 Metrics updates
// 🔄 Reconnection attempts
// ⚡ Health checks
// 📡 Discovery events
```

---

## 🔍 Troubleshooting

### **Connections Not Forming**
1. Check permissions are granted
2. Verify Bluetooth is enabled
3. Check devices are within range (< 100m clear, < 30m with obstacles)
4. Review connection limit (max 8 devices)
5. Check logs for error patterns

### **Frequent Disconnections**
1. Check signal strength in logs
2. Verify devices aren't moving out of range
3. Review health check timeout (may need adjustment)
4. Check for interference (WiFi, other Bluetooth devices)

### **Reconnection Not Working**
1. Verify ReconnectionManager is initialized
2. Check reconnection queue size in statistics
3. Review retry count (max 5 attempts)
4. Ensure devices are still advertising

### **Poor Performance**
1. Reduce discovery frequency if battery is concern
2. Adjust health check interval
3. Consider connection limit reduction
4. Review metrics for success rate patterns

---

This architecture provides a solid foundation for a scalable, maintainable Bluetooth mesh network implementation with enhanced reliability, range, and automatic recovery capabilities.
