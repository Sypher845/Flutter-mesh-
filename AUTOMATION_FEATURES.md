# Automation Features

## 1. Automatic Permission Requests on First Launch

### Implementation
- **PermissionService** (`lib/services/permission_service.dart`)
  - Tracks if permissions have been requested using SharedPreferences
  - Requests all required permissions at once
  - Provides helper methods to check individual permission statuses

- **PermissionDialog** (`lib/widgets/permission_dialog.dart`)
  - Beautiful dialog explaining why each permission is needed
  - Shows on first app launch only
  - Lists all permissions with icons and descriptions:
    - 🔵 Bluetooth - Share reports with nearby devices
    - 📍 Location - Capture hazard location and enable Bluetooth
    - 📷 Camera - Take photos of hazards
    - 🖼️ Photos - Select photos from gallery

### Permissions Requested
1. `locationWhenInUse` - Required for Bluetooth and location capture
2. `bluetoothConnect` - Connect to nearby devices
3. `bluetoothScan` - Discover nearby devices
4. `bluetoothAdvertise` - Advertise to nearby devices
5. `camera` - Take photos
6. `photos` - Access photo library

## 2. Automatic Bluetooth Connection

### Auto-Start on App Launch
- Bluetooth service automatically starts advertising and discovery 2 seconds after initialization
- Users don't need to manually click "Start Advertising" or "Find Devices"
- App is always ready to receive reports from nearby devices

### Auto-Connect on Report Submit
When user clicks "Submit Report":

1. **Automatic Activation**
   - If advertising is not running → starts automatically
   - If discovery is not running → starts automatically

2. **Device Search**
   - Waits 3 seconds to find nearby devices
   - Shows status: "🔍 Searching for nearby devices..."

3. **Smart Sending**
   - If devices found → sends report to all connected devices
   - If no devices found → saves locally with message: "📝 Report saved locally - No nearby devices found"
   - Report is always saved locally first for reliability

4. **User Feedback**
   - Success: "✅ Report sent to X device(s)!"
   - No devices: "📝 Report saved locally - Will sync when devices are nearby"
   - Error: "📝 Report saved locally - Will sync when devices are nearby"

### Background Behavior
- **Periodic Health Checks**: Every 30 seconds, verifies connections are still active
- **Auto-Cleanup**: Removes stale/dead connections automatically
- **Connection Verification**: Sends ping messages to verify device connectivity

## 3. Seamless User Experience

### What Users See
1. **First Launch**
   - Permission dialog appears automatically
   - Clear explanation of why each permission is needed
   - Option to grant all or skip

2. **Creating Reports**
   - Fill in: Image → Location → Type → Title → Description
   - Click "Submit Report via Bluetooth"
   - App handles all Bluetooth operations automatically
   - Clear status messages show what's happening

3. **Receiving Reports**
   - App automatically listens for nearby reports
   - Received reports appear in "Received Data" section
   - No manual action needed

### No Manual Bluetooth Management
Users never need to:
- ❌ Click "Start Advertising"
- ❌ Click "Find Devices"
- ❌ Manage connections manually
- ❌ Worry about Bluetooth state

Everything happens automatically! 🎉

## Technical Details

### Bluetooth Service Auto-Initialization
```dart
BluetoothService() {
  _startPeriodicHealthCheck();
  _initializeAutoDiscovery();  // Auto-starts advertising & discovery
}
```

### Smart Report Sending
```dart
Future<void> sendReportData(ReportModel report) async {
  // Ensure advertising and discovery are running
  if (!_isAdvertising) await startAdvertising();
  if (!_isDiscovering) await startDiscovery();
  
  // Wait for connections
  if (_connectedDevices.isEmpty) {
    await Future.delayed(Duration(seconds: 3));
  }
  
  // Send or save locally
  ...
}
```

## Benefits

1. **User-Friendly**: No technical knowledge required
2. **Reliable**: Reports always saved locally first
3. **Automatic**: Bluetooth connections managed automatically
4. **Transparent**: Clear status messages inform users
5. **Efficient**: Background health checks maintain connections
6. **Privacy-Focused**: Permissions explained clearly upfront
