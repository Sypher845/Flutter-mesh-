# Bluetooth Service Architecture

This directory contains a modular, well-structured implementation of the Bluetooth mesh network service.

## 📁 Structure

```
bluetooth/
├── bluetooth_service.dart          # Main orchestrator service
├── connection_manager.dart         # Connection handling (advertising, discovery, connections)
├── payload_handler.dart            # Payload sending/receiving logic
├── mesh_network_manager.dart       # Mesh network & rebroadcast logic
├── permission_manager.dart         # Permission handling
└── models/
    ├── bluetooth_constants.dart    # All constants in one place
    └── received_data.dart          # ReceivedData model
```

## 🎯 Separation of Concerns

### **BluetoothService** (Main Orchestrator)
**Responsibility:** Coordinates all Bluetooth operations
- Initializes and manages all sub-managers
- Handles high-level operations (send report, receive data)
- Manages state and notifies listeners
- Provides public API for UI

**Key Methods:**
- `sendReportData()` - Send a report to nearby devices
- `verifyAndCleanConnections()` - Health check connections
- `clearReceivedData()` - Clear received data list

---

### **ConnectionManager**
**Responsibility:** Manages all connection-related operations
- Advertising (making device visible)
- Discovery (finding nearby devices)
- Connection establishment and teardown
- Connection state tracking

**Key Methods:**
- `startAdvertising()` - Make device visible
- `startDiscovery()` - Find nearby devices
- `requestConnection()` - Connect to a device
- `acceptConnection()` - Accept incoming connection
- `disconnectAll()` - Disconnect from all devices

**Callbacks:**
- `onConnectionInitiated` - When connection starts
- `onConnectionResult` - When connection succeeds/fails
- `onDisconnected` - When device disconnects
- `onEndpointFound` - When device is discovered
- `onEndpointLost` - When device is lost

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

#### **ReceivedData**
Model for received data:
- Sender information
- Payload data
- Timestamp
- Helper methods (dataType, reportUUID, hopCount)

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
3. Wait for connections
   ↓
4. verifyAndCleanConnections() - Remove dead connections
   ↓
5. PayloadHandler.sendPreSendCheck() - Verify responsive
   ↓
6. Prepare payload with hop count = 0
   ↓
7. PayloadHandler.validatePayloadSize() - Check size
   ↓
8. PayloadHandler.sendBytesPayload() - Send to all devices
   ↓
9. If success: MeshNetworkManager.addReceivedReport() - Track own UUID
   ↓
10. Return to receiver mode (keep connections)
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

### **3. Reusability**
- Managers can be reused in other projects
- PermissionManager works for any Bluetooth app
- PayloadHandler works for any payload type

### **4. Maintainability**
- Easy to find where specific logic lives
- Clear separation makes debugging easier
- Adding features doesn't clutter existing code

### **5. Scalability**
- Easy to add new managers (e.g., AnalyticsManager)
- Easy to extend existing managers
- Constants in one place make changes easy

---

## 🔧 Usage Example

```dart
// In main.dart
ChangeNotifierProvider(
  create: (_) => BluetoothService(),
)

// In a widget
final bluetooth = Provider.of<BluetoothService>(context);

// Send a report
await bluetooth.sendReportData(report);

// Check status
Text(bluetooth.statusMessage);

// View received data
ListView.builder(
  itemCount: bluetooth.receivedDataList.length,
  itemBuilder: (context, index) {
    final data = bluetooth.receivedDataList[index];
    return Text('From: ${data.senderName}');
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
1. Create `AnalyticsManager`
2. Add to `BluetoothService._initializeManagers()`
3. Call analytics methods at key points

### **Add encryption:**
1. Create `EncryptionManager`
2. Wrap payloads in `PayloadHandler.sendBytesPayload()`
3. Unwrap in `PayloadHandler.decodePayload()`

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
- `✅` - Success
- `❌` - Errors
- `⚠️` - Warnings

---

## 📊 Performance Considerations

### **Memory:**
- UUID tracking limited to 100 entries
- Received data limited to 20 entries
- Automatic cleanup prevents memory leaks

### **Battery:**
- Continuous discovery uses battery
- Consider periodic discovery for production
- Health checks every 30 seconds (configurable)

### **Network:**
- Pre-send checks add small overhead
- Prevents wasted sends to dead connections
- Hop count prevents infinite loops

---

## 🔒 Security Considerations

### **Current Implementation:**
- No encryption (payloads sent in plain text)
- No authentication (any device can connect)
- No authorization (any device can send reports)

### **Recommendations for Production:**
1. Add payload encryption
2. Implement device authentication
3. Add report signing/verification
4. Implement rate limiting
5. Add user consent for data sharing

---

## 📚 Further Reading

- [Nearby Connections API](https://developers.google.com/nearby/connections/overview)
- [Flutter Provider Pattern](https://pub.dev/packages/provider)
- [Mesh Network Topology](https://en.wikipedia.org/wiki/Mesh_networking)
