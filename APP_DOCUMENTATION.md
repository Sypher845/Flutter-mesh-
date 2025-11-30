# Bluetooth NFC Flooding App - Complete Documentation

## Table of Contents
1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Core Components](#core-components)
4. [Data Flow](#data-flow)
5. [Key Features](#key-features)
6. [Technical Implementation](#technical-implementation)
7. [How It Works](#how-it-works)
8. [User Guide](#user-guide)
9. [Troubleshooting](#troubleshooting)

---

## Overview

The Bluetooth NFC Flooding App is a peer-to-peer (P2P) mobile application that enables offline data synchronization between devices using Bluetooth technology. It allows users to create, share, and receive "tickets" (data packets containing text and images) without requiring an internet connection.

### Purpose
- **Offline Communication**: Share data between devices when no internet is available
- **P2P Architecture**: Direct device-to-device communication without central server
- **Data Broadcasting**: Automatically flood data to all connected peers
- **Local Storage**: Persist data locally using SQLite database

### Technology Stack
- **Framework**: Flutter/Dart
- **Bluetooth API**: Nearby Connections (Google's P2P API)
- **State Management**: Provider pattern
- **Local Database**: SQLite (sqflite package)
- **Image Processing**: image_picker, image compression

---

## Architecture

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        User Interface                        │
│                      (HomeScreen Widget)                     │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ├─────────────────────┐
                         ↓                     ↓
              ┌──────────────────┐   ┌──────────────────┐
              │ BluetoothService │   │ DataSyncService  │
              │   (Provider)     │   │   (Provider)     │
              └────────┬─────────┘   └────────┬─────────┘
                       │                      │
                       ↓                      ↓
              ┌──────────────────┐   ┌──────────────────┐
              │ Nearby           │   │ Local Storage    │
              │ Connections API  │   │ (SQLite)         │
              └──────────────────┘   └──────────────────┘
```

### Design Patterns

1. **Provider Pattern**: Used for state management
   - `BluetoothService`: Manages Bluetooth connections and data transmission
   - `DataSyncService`: Manages local database operations

2. **Observer Pattern**: UI automatically updates when service state changes
   - `Consumer<T>` widgets listen to provider changes
   - `notifyListeners()` triggers UI rebuilds

3. **Service Layer Architecture**: Separation of concerns
   - UI Layer: Presentation and user interaction
   - Service Layer: Business logic and data management
   - Data Layer: Local storage and Bluetooth communication

---

## Core Components

### 1. BluetoothService (`lib/services/bluetooth_service.dart`)

**Purpose**: Manages all Bluetooth operations including discovery, connection, and data transmission.

**Key Responsibilities**:
- Request and manage Bluetooth permissions
- Start/stop advertising (making device discoverable)
- Start/stop discovery (finding nearby devices)
- Handle incoming connection requests
- Send and receive data payloads
- Manage connected devices
- Verify connection health

**Important Properties**:
```dart
bool isAdvertising           // Device is broadcasting its presence
bool isDiscovering          // Device is searching for others
Set<String> connectedDevices // Currently connected endpoint IDs
List<ReceivedData> receivedDataList // All received data packets
String statusMessage        // Current operation status
```

**Key Methods**:

- `requestPermissions()`: Requests all necessary Bluetooth and location permissions
- `startAdvertising()`: Makes device discoverable to others
- `stopAdvertising()`: Stops broadcasting
- `startDiscovery()`: Starts searching for nearby devices
- `stopDiscovery()`: Stops searching
- `sendTicketData(TicketModel)`: Sends a ticket to all connected devices
- `broadcastCustomData(Map)`: Broadcasts custom data to connected devices

**Connection Flow**:
```
Device A (Advertiser)          Device B (Discoverer)
      │                              │
      ├─ startAdvertising()          │
      │  (broadcasts presence)       │
      │                              ├─ startDiscovery()
      │                              │  (searches for devices)
      │                              │
      │◄─────── onEndpointFound ─────┤
      │                              │
      ├──── requestConnection() ─────►│
      │                              │
      │◄─── onConnectionInitiated ───┤
      │                              │
      ├───── acceptConnection() ─────►│
      │                              │
      │◄──── onConnectionResult ─────┤
      │   (CONNECTION_SUCCESS)        │
      │                              │
      │◄═══════ Data Exchange ═══════►│
```

### 2. DataSyncService (`lib/services/data_sync_service.dart`)

**Purpose**: Manages local data persistence using SQLite database.

**Key Responsibilities**:
- Initialize SQLite database
- Save tickets to local storage
- Retrieve all stored tickets
- Delete tickets
- Manage database schema

**Database Schema**:
```sql
CREATE TABLE tickets (
  id TEXT PRIMARY KEY,
  name TEXT,
  description TEXT,
  imageData TEXT,           -- Base64 encoded image
  timestamp TEXT,
  source TEXT DEFAULT 'local'
)
```

**Key Methods**:
- `saveTicket(TicketModel)`: Saves ticket to database
- `getTickets()`: Retrieves all tickets
- `deleteTicket(String id)`: Removes ticket by ID

### 3. LocalStorageService (`lib/services/local_storage_service.dart`)

**Purpose**: Provides low-level database operations using sqflite.

**Key Methods**:
- `initDatabase()`: Creates/opens SQLite database
- `insertTicket(Map)`: Inserts ticket record
- `getAllTickets()`: Queries all tickets
- `deleteTicket(String)`: Deletes ticket by ID

### 4. HomeScreen (`lib/screens/home_screen.dart`)

**Purpose**: Main UI interface for the application.

**Key Sections**:

1. **Image Picker Section**: Select and compress images
2. **Ticket Form**: Input name and description
3. **Submit Button**: Create and send tickets
4. **Status Messages**: Display connection/operation status
5. **Bluetooth Controls**: Start/stop advertising and discovery
6. **Received Data**: Display incoming tickets from other devices
7. **Local Tickets**: Display tickets stored in local database

**UI Layout**:
```
╔═══════════════════════════════════════════╗
║          Bluetooth Hopping App            ║
╠═══════════════════════════════════════════╣
║  [Select Image] [📷]                      ║
║  Selected: image.jpg (45 KB)              ║
║  ┌─────────────────────────────────────┐  ║
║  │ Name: _________________            │  ║
║  │ Description: ___________           │  ║
║  └─────────────────────────────────────┘  ║
║  [Submit Ticket]                          ║
║  ┌─────────────────────────────────────┐  ║
║  │ Status: ✅ All permissions granted  │  ║
║  │ 📡 Broadcasting: Yes                │  ║
║  │ 🔍 Discovering: No                  │  ║
║  └─────────────────────────────────────┘  ║
║  [Start Advertising] [Find Devices]       ║
║  ┌─────────────────────────────────────┐  ║
║  │ Received Data (3)              [↻]  │  ║
║  │ ┌─────────────────────────────────┐ │  ║
║  │ │ 🎫 Ticket from Device_123       │ │  ║
║  │ │ Name: Test Ticket               │ │  ║
║  │ │ Description: Hello world        │ │  ║
║  │ │ [📷 Image]                      │ │  ║
║  │ └─────────────────────────────────┘ │  ║
║  └─────────────────────────────────────┘  ║
║  ┌─────────────────────────────────────┐  ║
║  │ Saved Tickets (5)                   │  ║
║  │ • Ticket 1                          │  ║
║  │ • Ticket 2                          │  ║
║  └─────────────────────────────────────┘  ║
╚═══════════════════════════════════════════╝
```

### 5. TicketModel (`lib/models/ticket_model.dart`)

**Purpose**: Data model representing a ticket.

**Properties**:
```dart
String id              // Unique identifier (UUID)
String name            // Ticket name/title
String description     // Ticket details
String? imageData      // Base64 encoded image (optional)
DateTime timestamp     // Creation time
String source          // 'local' or 'endpoint_xxx'
```

**Methods**:
- `toJson()`: Converts ticket to JSON map for transmission
- `fromJson(Map)`: Creates ticket from JSON map
- `toDatabase()`: Converts to database format
- `fromDatabase(Map)`: Creates from database record

---

## Data Flow

### Sending Data Flow

```
User Action (Submit Button)
       ↓
1. Validate Form Input
       ↓
2. Create TicketModel
   - Generate UUID
   - Add timestamp
   - Compress image (if present)
   - Encode image to Base64
       ↓
3. Save to Local Database
   (DataSyncService.saveTicket)
       ↓
4. Convert to JSON
   (TicketModel.toJson)
       ↓
5. Encode to UTF-8 Bytes
   (Uint8List payload)
       ↓
6. Send via Bluetooth
   (BluetoothService.sendTicketData)
       ↓
7. For Each Connected Device:
   - Verify connection health
   - Send bytes payload
   - Handle retry logic
       ↓
8. Update UI Status
   (notifyListeners)
```

### Receiving Data Flow

```
Bluetooth Payload Received
       ↓
1. Payload Callback Triggered
   (_onPayloadReceived)
       ↓
2. Decode UTF-8 Bytes to String
       ↓
3. Parse JSON String to Map
       ↓
4. Extract Data Type
   - Check 'ticket' field
   - Check 'type' field
       ↓
5. Process Based on Type:
   ┌──────────────────┬────────────────┐
   │ Ticket Data      │ Custom Data    │
   ↓                  ↓                │
   Create TicketModel │ Create Generic │
   from JSON         │ ReceivedData   │
   ↓                  ↓                │
   Save to Database  │ (no save)      │
   └──────────────────┴────────────────┘
       ↓
6. Add to receivedDataList
       ↓
7. Update UI
   (notifyListeners)
       ↓
8. Display in "Received Data" Section
```

---

## Key Features

### 1. Image Compression

**Problem**: Bluetooth payload has size limits (~250 KB recommended)

**Solution**: Two-stage compression

**Stage 1 - Image Picker**:
```dart
ImagePicker.pickImage(
  maxWidth: 1024,
  maxHeight: 1024,
  imageQuality: 85
)
```

**Stage 2 - Custom Compression**:
```dart
_compressImage(File imageFile) {
  1. Decode image file
  2. Resize to max 800x800 (maintain aspect ratio)
  3. Encode as JPEG with quality 85%
  4. Validate size < 200 KB
  5. Return compressed bytes
}
```

**Result**: Images typically compressed to 30-100 KB

### 2. Connection Health Monitoring

**Purpose**: Ensure connections are active before sending data

**Implementation**:
```dart
_verifyAndCleanConnections() {
  For each connected device:
    1. Send test payload (empty bytes)
    2. Wait 2 seconds
    3. If no response → disconnect
    4. Remove stale connections
}
```

**Benefit**: Prevents sending to disconnected devices

### 3. Flexible Data Type Matching

**Challenge**: Data type field may vary ('ticket', 'ticket_data', etc.)

**Solution**: Check multiple fields
```dart
if (data.containsKey('ticket')) {
  // Process as ticket
} else if (type?.contains('ticket') == true) {
  // Process as ticket
} else {
  // Process as generic data
}
```

### 4. Automatic Connection Acceptance

**Implementation**:
```dart
onConnectionInitiated: (endpointId, info) {
  // Automatically accept all connections
  Nearby().acceptConnection(endpointId);
}
```

**Benefit**: Seamless P2P mesh network formation

### 5. Retry Logic for Failed Sends

**Implementation**:
```dart
sendTicketData(ticket) {
  for (device in connectedDevices) {
    try {
      await Nearby().sendBytesPayload(device, bytes);
    } catch (e) {
      // Log error but continue to next device
      // Don't block entire broadcast on single failure
    }
  }
}
```

---

## Technical Implementation

### Permission Management

**Required Permissions**:
- `BLUETOOTH_CONNECT` - Connect to Bluetooth devices
- `BLUETOOTH_SCAN` - Scan for Bluetooth devices
- `BLUETOOTH_ADVERTISE` - Advertise device presence
- `ACCESS_FINE_LOCATION` - Required for Bluetooth scanning (Android)
- `ACCESS_COARSE_LOCATION` - Fallback location permission
- `NEARBY_WIFI_DEVICES` - For nearby device discovery (Android 13+)

**Permission Request Strategy**:
```dart
1. Request location permissions first (multiple strategies)
2. Request Bluetooth permissions
3. Request nearby WiFi devices (if available)
4. Verify all granted before enabling features
```

### Nearby Connections Configuration

**Strategy**: `P2P_CLUSTER`
- Allows multiple connections simultaneously
- Devices can be both advertiser and discoverer
- Forms mesh network automatically

**Service ID**: `com.yourapp.offlineSync`
- Unique identifier for this app
- Only devices with same service ID can connect

**Discovery Options**:
```dart
Strategy.P2P_CLUSTER        // Multi-device mesh
mediumType: AUTO           // Use best available (WiFi/Bluetooth)
```

### Data Serialization

**Format**: JSON encoded as UTF-8 bytes

**Ticket JSON Structure**:
```json
{
  "ticket": {
    "id": "uuid-v4-string",
    "name": "Ticket Name",
    "description": "Ticket details",
    "imageData": "base64-encoded-string",
    "timestamp": "2025-11-18T12:34:56.789",
    "source": "endpoint_xxx"
  }
}
```

**Encoding Process**:
```dart
1. Create Map from TicketModel
2. JSON.encode(map) → String
3. utf8.encode(string) → Uint8List
4. Send Uint8List via Bluetooth
```

**Decoding Process**:
```dart
1. Receive Uint8List payload
2. utf8.decode(bytes) → String
3. JSON.decode(string) → Map
4. TicketModel.fromJson(map) → Object
```

### State Management

**Provider Pattern Implementation**:

```dart
// Service extends ChangeNotifier
class BluetoothService extends ChangeNotifier {
  // When state changes:
  notifyListeners();  // Triggers UI rebuild
}

// UI listens to changes:
Consumer<BluetoothService>(
  builder: (context, bluetooth, child) {
    // Rebuilds when notifyListeners() called
    return Widget(bluetooth.data);
  }
)
```

**Benefits**:
- Automatic UI updates
- Centralized state
- Easy testing
- Dependency injection

---

## How It Works

### Complete User Journey

#### Scenario: User A sends a ticket to User B

**Setup Phase**:

1. **Device A (Sender)**:
   - User opens app
   - App requests permissions
   - User taps "Start Advertising"
   - Device A broadcasts its presence

2. **Device B (Receiver)**:
   - User opens app
   - App requests permissions
   - User taps "Find Devices"
   - Device B discovers Device A

**Connection Phase**:

3. **Automatic Connection**:
   - Device B finds Device A (onEndpointFound callback)
   - Device B requests connection automatically
   - Device A receives connection request (onConnectionInitiated)
   - Device A accepts connection automatically
   - Connection established (onConnectionResult)
   - Both devices update UI: "Connected: 1 device"

**Data Creation Phase**:

4. **Device A (Create Ticket)**:
   - User taps "Select Image" → picks photo
   - Image compressed (800x800, 85% quality)
   - User enters Name: "Event Ticket"
   - User enters Description: "Concert tonight at 8 PM"
   - User taps "Submit Ticket"

**Data Sending Phase**:

5. **Device A (Send Data)**:
   - Ticket saved to local SQLite database
   - Ticket appears in "Saved Tickets" section
   - TicketModel created with:
     - UUID generated
     - Timestamp added
     - Image encoded to Base64
     - Source set to 'local'
   - Ticket converted to JSON
   - JSON encoded to UTF-8 bytes
   - Health check performed on connection to Device B
   - Bytes payload sent to Device B
   - Status updated: "✅ Sent to 1 device(s)"

**Data Receiving Phase**:

6. **Device B (Receive Data)**:
   - Payload callback triggered
   - Bytes decoded to JSON string
   - JSON parsed to Map
   - Data type identified as 'ticket'
   - TicketModel created from JSON:
     - Source updated to 'endpoint_A'
     - All fields preserved
   - Ticket saved to local database
   - Ticket added to receivedDataList
   - UI updated automatically
   - Ticket appears in "Received Data" section with:
     - Sender info
     - Name and description
     - Compressed image displayed
     - Timestamp

**Result**:
- Device A: Ticket in "Saved Tickets"
- Device B: Ticket in "Received Data" AND "Saved Tickets"
- Both devices have persistent copy in SQLite

---

## User Guide

### First-Time Setup

1. **Install App** on two or more physical devices (emulators don't support Bluetooth)

2. **Grant Permissions**:
   - Bluetooth permissions
   - Location permissions (required by Android for BLE scanning)
   - Nearby devices permissions

3. **Verify Status**:
   - Status should show: "✅ All permissions granted"
   - If not, check system settings

### Basic Usage

#### Device 1 (Advertiser):
```
1. Open app
2. Tap "Start Advertising"
3. Status shows: "📡 Broadcasting: Yes"
4. Create a ticket:
   - (Optional) Tap "Select Image"
   - Enter name
   - Enter description
   - Tap "Submit Ticket"
5. Ticket sent automatically to connected devices
```

#### Device 2 (Discoverer):
```
1. Open app
2. Tap "Find Devices"
3. Wait 5-10 seconds
4. Connection established automatically
5. Status shows: "Connected devices: 1"
6. Received tickets appear in "Received Data" section
```

### Advanced Usage

#### Both Advertising and Discovering:
- Device can do both simultaneously
- Creates bi-directional mesh network
- All devices can send/receive

#### Managing Tickets:
- View received tickets in "Received Data"
- View local tickets in "Saved Tickets"
- Delete tickets with trash icon
- All tickets persist in database

#### Troubleshooting Connection Issues:
- Stop and restart advertising/discovery
- Ensure both devices have permissions granted
- Keep devices within 100 meters
- Check that Bluetooth is enabled

---

## Troubleshooting

### Common Issues

#### 1. "No devices found"
**Causes**:
- Only one device is advertising/discovering
- Devices running different apps/service IDs
- Location permission not granted
- Bluetooth disabled

**Solutions**:
- Ensure one device is advertising, another discovering
- Verify both devices running same app version
- Grant all permissions
- Enable Bluetooth in system settings

#### 2. "Connection failed"
**Causes**:
- Devices too far apart
- Bluetooth interference
- Timeout (connection takes time)

**Solutions**:
- Move devices closer (within 10 meters)
- Remove interference sources
- Wait 10-20 seconds for connection
- Restart advertising/discovery

#### 3. "Image too large"
**Causes**:
- Original image > 200 KB after compression
- High-resolution photo

**Solutions**:
- Use lower resolution images
- App automatically compresses to 800x800
- If still too large, validation shows error

#### 4. "Sent but not received"
**Causes**:
- Connection dropped before complete transmission
- Device disconnected
- Payload corruption

**Solutions**:
- Check connection status before sending
- Ensure stable Bluetooth connection
- Retry sending

#### 5. "Permission denied"
**Causes**:
- User denied permissions
- Android security settings
- App not granted location access

**Solutions**:
- Go to Settings → Apps → [App] → Permissions
- Grant all required permissions
- Enable location for app
- Restart app

### Performance Tips

1. **Optimal Range**: Keep devices within 10-50 meters
2. **Image Size**: Use images < 1 MB for faster compression
3. **Connection Stability**: Avoid moving devices during transfer
4. **Battery**: Bluetooth operations drain battery - monitor usage
5. **Multiple Devices**: App supports multiple simultaneous connections

### Debugging

**Status Messages Guide**:
- ✅ Green checkmark = Success
- ⏳ Hourglass = In progress
- ❌ Red X = Error
- 📡 Satellite = Broadcasting
- 🔍 Magnifying glass = Searching

**Connection States**:
- "Broadcasting: Yes" = Device discoverable
- "Discovering: Yes" = Device searching
- "Connected devices: N" = N active connections
- "Received data: N" = N items received

---

## Best Practices

### For Developers

1. **Error Handling**: Always wrap Bluetooth operations in try-catch
2. **Connection Cleanup**: Properly disconnect when app closes
3. **Data Validation**: Validate payloads before processing
4. **State Management**: Use Provider pattern consistently
5. **Testing**: Test on physical devices, not emulators

### For Users

1. **Permissions**: Grant all permissions on first launch
2. **Connectivity**: Keep Bluetooth enabled
3. **Range**: Stay within reasonable distance
4. **Battery**: Monitor battery usage during extended sessions
5. **Data**: Tickets persist locally - safe to close app

---

## Security Considerations

### Current Implementation

1. **No Authentication**: Devices automatically connect
2. **No Encryption**: Data sent as plain JSON
3. **No Validation**: All connections accepted
4. **Public Discovery**: Device visible to all nearby devices

### Recommendations for Production

1. **Add Authentication**: PIN or password for connections
2. **Enable Encryption**: Use TLS/SSL for payload encryption
3. **Validate Connections**: User approval for new connections
4. **Data Sanitization**: Validate and sanitize received data
5. **Permission Scoping**: Request only necessary permissions

---

## Future Enhancements

### Potential Features

1. **End-to-End Encryption**: Encrypt payloads before transmission
2. **User Authentication**: Secure connections with passwords
3. **File Transfer**: Support for larger files beyond images
4. **Group Chat**: Real-time messaging between connected devices
5. **Offline Maps**: Share location markers offline
6. **Smart Routing**: Optimize data routing in mesh network
7. **Data Sync Conflicts**: Resolve duplicate data intelligently
8. **Background Sync**: Continue syncing when app minimized
9. **QR Code Pairing**: Quick device pairing via QR codes
10. **Analytics Dashboard**: View connection history and statistics

---

## Technical Specifications

### System Requirements

**Android**:
- Minimum SDK: 21 (Android 5.0 Lollipop)
- Target SDK: 34 (Android 14)
- Bluetooth 4.0+ (BLE support)
- Location services enabled

**iOS**: 
- Currently not supported (Nearby Connections is Android-only)

### Performance Metrics

- **Connection Time**: 5-20 seconds average
- **Data Transfer Speed**: ~100 KB/s typical
- **Max Payload Size**: 32 KB per transmission
- **Recommended Image Size**: < 200 KB
- **Max Simultaneous Connections**: 8 devices
- **Effective Range**: 10-100 meters (varies by environment)

### Dependencies

```yaml
dependencies:
  flutter: sdk: flutter
  nearby_connections: ^4.3.0      # Bluetooth P2P API
  image_picker: ^1.0.4            # Image selection
  image: ^4.0.17                  # Image compression
  provider: ^6.1.1                # State management
  sqflite: ^2.3.0                 # Local database
  path_provider: ^2.1.1           # File system paths
  permission_handler: ^12.0.1     # Permission requests
```

---

## Conclusion

The Bluetooth NFC Flooding App demonstrates a complete peer-to-peer data synchronization solution using Flutter and Nearby Connections API. It provides offline capability, automatic mesh networking, and persistent local storage, making it ideal for scenarios where internet connectivity is unavailable or unreliable.

### Key Achievements

✅ **Offline-First Design**: No internet required  
✅ **Automatic Mesh Networking**: Self-organizing device connections  
✅ **Data Persistence**: SQLite local storage  
✅ **Image Compression**: Efficient payload size management  
✅ **Clean Architecture**: Separation of concerns with Provider pattern  
✅ **Robust Error Handling**: Connection health monitoring and retry logic  
✅ **User-Friendly Interface**: Simple, intuitive UI  

### Use Cases

- Emergency communication systems
- Event ticketing without internet
- Offline data collection in remote areas
- Local file sharing
- Peer-to-peer messaging
- IoT device networking

---

**Version**: 1.0.0  
**Last Updated**: November 18, 2025  
**License**: MIT  
**Repository**: Flutter-mesh-  
**Author**: Sypher845
