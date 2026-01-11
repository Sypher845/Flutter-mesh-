# BLE Report Mesh

A Flutter-based mobile application for creating and sharing hazard reports through a decentralized Bluetooth mesh network. Reports automatically propagate to nearby devices without requiring internet connectivity.

## Overview

BLE Report Mesh enables users to create, share, and receive hazard reports (potholes, flooding, accidents, etc.) using Nearby Connections API. The app creates a mesh network where reports automatically propagate from device to device, ensuring wide coverage even in areas with limited connectivity.

## Key Features

### 📱 Report Creation
- **Rich Report Form**: Title, description, and hazard type selection
- **Image Support**: Attach photos with automatic compression (70% quality, max 300KB)
- **Image Preview**: See compressed image with size information before sending
- **GPS Location**: Capture and display precise coordinates (6 decimal precision)
- **Location Details**: View latitude, longitude, and accuracy
- **Visual Feedback**: Card-based UI with color-coded sections

### 🔄 Mesh Network
- **Automatic Discovery**: Devices automatically find and connect to nearby devices
- **Multi-Device Broadcast**: Send reports to all connected devices simultaneously
- **Mesh Rebroadcasting**: Reports automatically relay through the network
- **Hop Count Tracking**: Visual badges show how many hops a report has traveled
- **Duplicate Prevention**: UUID-based deduplication prevents receiving same report twice
- **Max Hops Limit**: Reports stop propagating after 5 hops to prevent network congestion

### 📊 Report Display
- **Image Display**: Full image preview (200px height) in report list
- **Color-Coded Hop Badges**:
  - 🟢 Green (Hop 0) - Original sender
  - 🔵 Blue (Hop 1) - First rebroadcast
  - 🟠 Orange (Hop 2) - Second rebroadcast
  - 🔴 Red (Hop 3+) - Multiple rebroadcasts
- **Location Info**: GPS coordinates displayed for each report
- **Timestamp**: When the report was created
- **Card Layout**: Clean, modern interface

### 🔗 Connectivity
- **Nearby Connections**: Uses Google's Nearby Connections API (WiFi Direct + Bluetooth)
- **Automatic Advertising**: Device is always visible to others
- **Automatic Discovery**: Continuously scans for nearby devices with adaptive frequency
- **Connection Status**: Shows number of connected devices in app bar
- **Range**: ~30-100 meters depending on environment (optimized for maximum range)
- **No Internet Required**: Works completely offline
- **Auto-Reconnection**: Automatically reconnects to lost devices (up to 5 attempts)
- **Connection Limit**: Manages up to 8 simultaneous connections for optimal performance
- **Health Monitoring**: Periodic health checks detect and remove stale connections
- **Adaptive Strategy**: Dynamically adjusts connection timeouts based on success rates

## Architecture

### Technology Stack
- **Framework**: Flutter 3.x
- **Language**: Dart
- **Connectivity**: Nearby Connections API (P2P_CLUSTER strategy)
- **State Management**: Provider pattern
- **Image Processing**: image package for compression
- **Permissions**: permission_handler package

### Project Structure
```
lib/
├── core/
│   └── enums/
│       └── report_enums.dart          # Hazard types, report status
├── models/
│   └── report_model.dart              # Report data model
├── providers/
│   └── report_provider.dart           # Report state management
├── screens/
│   ├── home_screen.dart               # Main screen with report list
│   └── create_report_screen.dart      # Report creation form
├── services/
│   └── bluetooth/
│       ├── bluetooth_service.dart     # Main Bluetooth orchestrator
│       ├── connection_manager.dart    # Connection handling (enhanced)
│       ├── reconnection_manager.dart  # Auto-reconnection (NEW)
│       ├── connection_metrics.dart    # Connection statistics (NEW)
│       ├── payload_handler.dart       # Data encoding/decoding
│       ├── mesh_network_manager.dart  # Mesh rebroadcasting
│       ├── permission_manager.dart    # Permission handling
│       └── models/
│           ├── bluetooth_constants.dart  # Configuration constants
│           ├── received_data.dart        # Received data model
│           ├── reconnection_entry.dart   # Reconnection queue (NEW)
│           ├── connection_attempt.dart   # Connection tracking (NEW)
│           └── connection_event.dart     # Event logging (NEW)
├── widgets/
│   └── status_messages.dart           # UI components
└── main.dart                          # App entry point
```

### Architecture Pattern

**Singleton Service Pattern**:
- `BluetoothService` is a singleton that manages all Bluetooth operations
- Ensures only one instance handles connections and data flow
- Prevents connection conflicts and state inconsistencies

**Manager Pattern**:
- `ConnectionManager`: Handles advertising, discovery, and connections (enhanced with adaptive frequency and connection limits)
- `ReconnectionManager`: Handles automatic reconnection with exponential backoff (NEW)
- `ConnectionMetrics`: Tracks connection statistics and adaptive timeouts (NEW)
- `PayloadHandler`: Handles data encoding, decoding, and transmission
- `MeshNetworkManager`: Handles rebroadcasting and hop count management
- `PermissionManager`: Handles Android permissions

**Provider Pattern**:
- `ReportProvider`: Manages report list state
- Notifies UI of changes
- Handles report deduplication

## Enhanced Features (v2.0.0)

### 🔄 Auto-Reconnection System
- **Queue-Based Management**: Disconnected devices automatically added to reconnection queue
- **Exponential Backoff**: 5-second intervals between reconnection attempts
- **Retry Limit**: Maximum 5 attempts per device before giving up
- **Automatic Cleanup**: Exhausted attempts automatically removed from queue

### 📊 Connection Metrics & Adaptive Strategy
- **Success Rate Tracking**: Monitors last 10 connection attempts
- **Dynamic Timeout Adjustment**:
  - Success rate < 50% → Increase timeout to 10 seconds
  - Success rate > 80% → Decrease timeout to 5 seconds
- **Event Logging**: Detailed logs of all connection events with timestamps
- **Statistics API**: Access real-time connection statistics

### ⚡ Enhanced Health Monitoring
- **Fast Stale Detection**: 2-second timeout for detecting unresponsive connections
- **Periodic Health Checks**: Automatic verification every 30 seconds
- **Automatic Cleanup**: Stale connections automatically disconnected and queued for reconnection
- **Health Statistics**: Track active vs stale connection counts

### 🎯 Connection Quality Management
- **Connection Limit**: Maximum 8 simultaneous connections for optimal performance
- **Parallel Processing**: Multiple connection requests processed simultaneously
- **Signal Strength Logging**: Track connection quality (when available)
- **Quality Events**: Detailed event tracking for debugging

### 🔍 Adaptive Discovery
- **High Frequency Mode**: 5-second scans when no connections (find devices faster)
- **Normal Frequency Mode**: 30-second scans when connected (save battery)
- **Discovery Restart**: Automatic restart if few devices found
- **Connection Preservation**: Discovery restart maintains existing connections

### 🔧 Lifecycle & Error Management
- **Background/Foreground Handling**: Preserve connections during app state changes
- **Bluetooth State Monitoring**: Automatic pause/resume on Bluetooth disable/enable
- **Graceful Error Handling**: Handle API errors (ALREADY_ADVERTISING, ALREADY_DISCOVERING)
- **Automatic Recovery**: Retry with exponential backoff, full reset on consecutive errors

### 📈 Range Optimization
- **P2P_CLUSTER Strategy**: Optimized for maximum range over throughput
- **Extended Timeouts**: Longer timeouts allow weaker signals to complete
- **Retry Logic**: Multiple attempts increase success at range limits
- **Connection Maintenance**: Keep connections alive to prevent re-establishment overhead

## How It Works

### 1. Device Initialization
```
App Starts
    ↓
BluetoothService initializes (Singleton)
    ↓
Initialize Managers:
  - ConnectionManager
  - ReconnectionManager (NEW)
  - ConnectionMetrics (NEW)
  - PayloadHandler
  - MeshNetworkManager
    ↓
Start Advertising (visible to others)
    ↓
Start Discovery (adaptive frequency)
    ↓
Start Health Check Timer (every 30s)
    ↓
Start Reconnection Loop (every 2s)
    ↓
Ready to send/receive reports
```

### 2. Creating and Sending a Report
```
User creates report
    ↓
Report saved locally (ReportProvider)
    ↓
Image compressed (if present)
    ↓
Report encoded to JSON with:
  - originalSenderId (device ID)
  - hopCount: 0
  - maxHops: 5
  - report data (title, description, location, image)
    ↓
Send to ALL connected devices simultaneously
    ↓
Success message shown to user
```

### 3. Receiving and Rebroadcasting
```
Device receives report payload
    ↓
Decode JSON data
    ↓
Check originalSenderId (skip if I'm the sender)
    ↓
Check UUID (skip if already received)
    ↓
Add UUID to tracking set
    ↓
Update hop count in report JSON
    ↓
Decode image (if present)
    ↓
Add to ReportProvider (display in UI)
    ↓
Check if hopCount < maxHops
    ↓
If yes: Rebroadcast to other devices (hop + 1)
If no: Stop (max hops reached)
```

### 4. Mesh Network Example

**Scenario: 3 Devices (A, B, C)**

```
Topology (Star):
    B
    ↑
    A (hub)
    ↓
    C

Flow:
1. Device A creates report
2. A sends to B and C (hop 0)
3. B receives → displays → rebroadcasts to A (hop 1)
4. C receives → displays → rebroadcasts to A (hop 1)
5. A receives from B → skips (originalSenderId matches)
6. A receives from C → skips (originalSenderId matches)

Result: ✅ Both B and C have the report
```

## Configuration

### Bluetooth Constants
Located in `lib/services/bluetooth/models/bluetooth_constants.dart`:

```dart
// Connection
static const String serviceId = 'com.example.ble_report_mesh';
static const String deviceName = 'BLE_Mesh_Device';
static const int maxConnections = 8; // NEW: Connection limit

// Sending
static const int maxSendAttempts = 3;
static const int sendTimeout = 10000; // 10 seconds
static const int maxRetries = 3;

// Payload
static const int maxPayloadSizeBytes = 500 * 1024; // 500 KB
static const int maxImageSizeBytes = 300 * 1024; // 300 KB

// Mesh Network
static const int maxHops = 5;
static const int maxTrackedUUIDs = 1000;

// Timeouts
static const int rebroadcastDelay = 500; // 0.5 seconds
static const int rebroadcastTimeout = 8000; // 8 seconds
static const int healthCheckIntervalSeconds = 30; // NEW: Health check frequency
static const int healthCheckTimeoutSeconds = 2; // NEW: Stale detection timeout

// Reconnection (NEW)
static const int reconnectionMaxRetries = 5; // Max reconnection attempts
static const int reconnectionIntervalSeconds = 5; // Time between retries

// Adaptive Strategy (NEW)
static const int metricsWindowSize = 10; // Success rate window
static const double lowSuccessThreshold = 0.5; // Increase timeout threshold
static const double highSuccessThreshold = 0.8; // Decrease timeout threshold
static const int adaptiveTimeoutMin = 5000; // Minimum timeout (ms)
static const int adaptiveTimeoutMax = 10000; // Maximum timeout (ms)

// Discovery (NEW)
static const int discoveryHighFrequencySeconds = 5; // When no connections
static const int discoveryNormalFrequencySeconds = 30; // When connected
```

## Installation

### Prerequisites
- Flutter SDK 3.0 or higher
- Android SDK (API 21+)
- Real Android devices (Nearby Connections doesn't work on emulators)

### Setup
1. Clone the repository:
   ```bash
   git clone <repository-url>
   cd ble_report_mesh
   ```

2. Install dependencies:
   ```bash
   flutter pub get
   ```

3. Check for issues:
   ```bash
   flutter analyze
   ```

4. Build APK:
   ```bash
   flutter build apk --split-per-abi
   ```

5. Install on devices:
   ```bash
   adb install build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
   ```

## Permissions

### Android Permissions Required
- `BLUETOOTH_SCAN` (Android 12+)
- `BLUETOOTH_CONNECT` (Android 12+)
- `BLUETOOTH_ADVERTISE` (Android 12+)
- `ACCESS_FINE_LOCATION` (Android 11 and below)
- `BLUETOOTH` (Android 11 and below)

Permissions are automatically requested on app start.

## Usage

### Creating a Report
1. Tap the **+** button (floating action button)
2. Enter report title and description
3. Select hazard type from dropdown
4. (Optional) Tap "Pick Image from Gallery" to add a photo
   - Image will be compressed automatically
   - Size will be displayed
5. (Optional) Tap "Capture Current Location" to add GPS coordinates
   - Coordinates will be displayed with accuracy
6. Tap "Submit Report"
7. Report will be saved locally and sent to nearby devices

### Viewing Reports
- Reports appear in the home screen list
- Each report shows:
  - Image (if present)
  - Title and description
  - Hop count badge (color-coded)
  - Location coordinates
  - Timestamp
- Scroll through the list to see all reports

### Connection Status
- Top-right corner shows Bluetooth icon and connection count
- 📶 with number = connected devices
- 🔍 = searching for devices

## Testing

### Basic Test (2 Devices)
1. Install app on Device A and Device B
2. Open app on both devices
3. Wait for connection (check count in app bar)
4. Create report on Device A
5. Verify report appears on Device B within 2-3 seconds

### Mesh Network Test (3+ Devices)
1. Install app on Devices A, B, and C
2. Open app on all devices
3. Wait for connections
4. Create report on Device A
5. Verify report appears on B and C
6. Check hop count badges (should be 0 on all)

### Logs
View detailed logs using:
```bash
adb logcat | grep -E "📤|📥|🔄|✅|❌"
```

## Troubleshooting

### Devices Not Connecting
- Ensure Bluetooth is enabled on all devices
- Check permissions are granted
- Restart app on all devices
- Ensure devices are within 100m of each other
- **NEW**: Check connection limit (max 8 devices)
- **NEW**: Review connection statistics for success rate

### Report Not Sending
- Check connection count in app bar (should be > 0)
- Check logs for error messages
- Verify image size is < 300KB
- Try restarting Bluetooth
- **NEW**: Check if health check marked connections as stale

### Report Not Appearing
- Check if duplicate (same UUID)
- Check logs for "Skipping duplicate" messages
- Verify receiving device is connected

### Frequent Disconnections (NEW)
- Check connection success rate in statistics (should be > 50%)
- Review signal strength in logs
- Verify devices aren't moving out of range
- Consider increasing health check timeout if environment is challenging

### Reconnection Not Working (NEW)
- Check reconnection queue size in statistics
- Verify retry count hasn't been exhausted (max 5 attempts)
- Ensure devices are still advertising
- Check logs for reconnection attempt messages

### Poor Performance (NEW)
- Review discovery frequency (should be adaptive)
- Check number of active connections
- Consider reducing connection limit
- Review metrics for patterns

### Getting Connection Statistics (NEW)
```dart
final bluetooth = Provider.of<BluetoothService>(context, listen: false);
final stats = bluetooth.getConnectionStatistics();
print('Success Rate: ${stats['successRate']}%');
print('Current Timeout: ${stats['currentTimeout']}ms');
print('Reconnection Queue: ${stats['reconnectionQueueSize']}');
```

## Known Limitations

1. **Platform**: Android only (iOS uses different APIs)
2. **Emulator**: Nearby Connections doesn't work on emulators
3. **Range**: ~30-100m depending on environment
4. **Topology**: P2P_CLUSTER creates star topology, not full mesh
5. **Image Size**: Max 300KB recommended
6. **Max Hops**: Limited to 5 hops
7. **Persistence**: Images stored in memory only (not persisted)

## Future Enhancements

### Short Term
- [ ] Real GPS integration (currently uses mock data)
- [ ] Image persistence to local storage
- [ ] Offline send queue for failed transmissions
- [ ] Report status indicators (sending, sent, failed)
- [ ] Connection quality UI indicators

### Medium Term
- [ ] Multiple images per report
- [ ] Camera capture (in addition to gallery)
- [ ] Image editing (crop, rotate)
- [ ] Map view with report locations
- [ ] Address lookup (reverse geocoding)
- [ ] Signal strength-based connection prioritization
- [ ] Predictive reconnection (before complete signal loss)

### Long Term
- [ ] iOS support
- [ ] Report categories and filtering
- [ ] Search functionality
- [ ] Analytics dashboard
- [ ] Cloud sync (optional)
- [ ] User accounts
- [ ] Mesh topology optimization
- [ ] Intelligent connection pruning (replace weak with strong)

## Performance

### Benchmarks
- **Connection Time**: < 10 seconds
- **Send Time (no image)**: < 5 seconds
- **Send Time (with image)**: < 10 seconds
- **Receive Latency**: < 3 seconds
- **Rebroadcast Delay**: < 2 seconds

### Optimization
- Image compression reduces payload size by ~70%
- UUID tracking prevents duplicate processing
- Singleton pattern prevents connection conflicts
- Retry logic ensures reliable transmission

## Contributing

Contributions are welcome! Please follow these guidelines:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test on real devices
5. Submit a pull request

## License

[Add your license here]

## Credits

- **Nearby Connections**: Google's Nearby Connections API
- **Flutter**: Google's UI framework
- **Image Package**: Dart image processing library

## Support

For issues, questions, or suggestions:
- Open an issue on GitHub
- Check logs for detailed error messages
- Ensure you're testing on real Android devices

## Version History

### v2.0.0 (Current) - Bluetooth Enhancement
- ✅ **Auto-Reconnection System**: Automatic reconnection with exponential backoff (max 5 attempts)
- ✅ **Connection Metrics**: Track connection statistics and success rates
- ✅ **Adaptive Strategy**: Dynamic timeout adjustment based on success rates (5s-10s)
- ✅ **Enhanced Health Monitoring**: Faster stale detection (2s timeout) with periodic checks (30s)
- ✅ **Connection Limit**: Enforce maximum 8 simultaneous connections
- ✅ **Adaptive Discovery**: High frequency (5s) when no connections, normal (30s) when connected
- ✅ **Lifecycle Management**: Handle background/foreground transitions and Bluetooth state changes
- ✅ **Error Recovery**: Graceful handling of API errors with automatic retry and full reset
- ✅ **Range Optimization**: Optimized for maximum range (up to 100m clear line of sight)
- ✅ **Comprehensive Testing**: Property-based tests for all correctness properties
- ✅ **Enhanced Documentation**: Updated ARCHITECTURE.md and README.md with new features

### v1.0.3
- ✅ Fixed broadcast to multiple devices
- ✅ Fixed mesh rebroadcasting
- ✅ Added device ID tracking
- ✅ Removed aggressive pre-send check
- ✅ Enhanced logging

### v1.0.2
- ✅ Added image display in report list
- ✅ Fixed hop count tracking
- ✅ Added color-coded hop badges
- ✅ Enhanced create report screen
- ✅ Added image preview and size display
- ✅ Added detailed location display

### v1.0.1
- ✅ Fixed report sending issue
- ✅ Implemented singleton pattern
- ✅ Added comprehensive logging

### v1.0.0
- Initial release
- Basic report creation and sharing
- Bluetooth mesh network
- Image support
- Location support

---

**Built with ❤️ using Flutter**
