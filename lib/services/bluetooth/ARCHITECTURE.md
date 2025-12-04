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
└─────────────────────────────────────────────────────────────┘
                            │
                            │ manages
                            ▼
        ┌───────────────────┴───────────────────┐
        │                   │                   │
        ▼                   ▼                   ▼
┌──────────────┐   ┌──────────────┐   ┌──────────────┐
│ Connection   │   │   Payload    │   │ MeshNetwork  │
│   Manager    │   │   Handler    │   │   Manager    │
├──────────────┤   ├──────────────┤   ├──────────────┤
│• Advertising │   │• Send bytes  │   │• UUID track  │
│• Discovery   │   │• Decode data │   │• Hop count   │
│• Connections │   │• Validation  │   │• Rebroadcast │
│• Endpoints   │   │• Retry logic │   │• Cleanup     │
└──────────────┘   └──────────────┘   └──────────────┘
        │                   │                   │
        │                   │                   │
        ▼                   ▼                   ▼
┌──────────────┐   ┌──────────────┐   ┌──────────────┐
│ Permission   │   │  Bluetooth   │   │  Received    │
│   Manager    │   │  Constants   │   │    Data      │
├──────────────┤   ├──────────────┤   ├──────────────┤
│• BT perms    │   │• Service ID  │   │• Sender info │
│• Location    │   │• Timeouts    │   │• Payload     │
│• WiFi nearby │   │• Limits      │   │• Timestamp   │
└──────────────┘   │• Types       │   └──────────────┘
                   └──────────────┘
```

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
│  └─> _initializeReceiverMode()                        │
│      ├─> ConnectionManager.startAdvertising()         │
│      │   └─> Device becomes visible                   │
│      └─> ConnectionManager.startDiscovery()           │
│          └─> Device starts scanning                   │
└─────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────┐
│                  Device Discovery                       │
│                                                         │
│  ConnectionManager._handleEndpointFound()              │
│  └─> Found nearby device                              │
│      └─> ConnectionManager.requestConnection()        │
└─────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────┐
│               Connection Establishment                  │
│                                                         │
│  ConnectionManager._handleConnectionInitiated()        │
│  ├─> Called on BOTH devices                           │
│  └─> ConnectionManager.acceptConnection()             │
│      └─> Register temporary payload callback          │
└─────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────┐
│                Connection Confirmed                     │
│                                                         │
│  ConnectionManager._handleConnectionResult()           │
│  ├─> Status.CONNECTED                                 │
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
│  • Health checks every 30s                            │
│  • Automatic cleanup of dead connections              │
└─────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────┐
│                   Disconnection                         │
│                                                         │
│  ConnectionManager._handleDisconnected()               │
│  ├─> Remove from _connectedDevices                    │
│  └─> notifyListeners()                                │
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

This architecture provides a solid foundation for a scalable, maintainable Bluetooth mesh network implementation.
