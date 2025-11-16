# Bluetooth Testing Guide

## ⚠️ IMPORTANT: Nearby Connections vs Regular Bluetooth

**Your app uses Google's Nearby Connections API, NOT regular Bluetooth discovery!**

- ❌ Will NOT find: Regular Bluetooth devices (headphones, speakers, phones in Bluetooth settings)
- ✅ Will ONLY find: Devices running this SAME app that are actively advertising
- 🔑 Key requirement: Both devices must have this app installed and running

## Current Logging Features

The app now includes comprehensive logging for Bluetooth operations. Here's what to look for:

### 1. Permission Checking
```
🔍 BLUETOOTH DEBUG: Starting permission request...
🔍 BLUETOOTH DEBUG: Requesting core permissions: ...
✅ BLUETOOTH DEBUG: All required permissions granted
```

### 2. Discovery Process
```
🔍 BLUETOOTH DEBUG: startDiscovery() called
🚀 BLUETOOTH DEBUG: Starting Nearby().startDiscovery()...
✅ BLUETOOTH DEBUG: Discovery started successfully
👀 BLUETOOTH DEBUG: Now scanning for devices with service ID: com.yourapp.offlineSync
⏰ BLUETOOTH DEBUG: Discovery still running... Found 0 devices so far
```

### 3. Device Detection
```
🎉 BLUETOOTH DEBUG: ENDPOINT FOUND!
  - Endpoint ID: [device_id]
  - Endpoint Name: [device_name]
  - Service ID: [service_id]
  - Service ID Match: true/false
```

### 4. Connection Process
```
🤝 BLUETOOTH DEBUG: Requesting connection to endpoint: [device_id]
🔗 BLUETOOTH DEBUG: CONNECTION INITIATED!
✅ BLUETOOTH DEBUG: Successfully connected to [device_id]
```

## Testing Scenarios

### Scenario 1: Emulator Testing (Limited)
1. Open the app on emulator
2. Tap "Start Advertising" - should see advertising logs
3. Tap "Find Devices" - should see discovery logs
4. Use "Simulate Device Found" button to test connection flow
5. Check "Debug Status" for current state

**Expected on Emulator:**
- Permissions should be granted
- Discovery should start successfully
- No real devices will be found (emulator limitation)
- Simulation should work for testing UI flow

### Scenario 2: Physical Device Testing
1. Install app on 2+ Android devices
2. On Device A: Tap "Start Advertising"
3. On Device B: Tap "Find Devices"
4. Device B should discover Device A within 10-30 seconds

**Expected Logs on Device B:**
```
🎉 BLUETOOTH DEBUG: ENDPOINT FOUND!
  - Endpoint Name: OfflineSyncDevice
  - Service ID Match: true
🤝 BLUETOOTH DEBUG: Requesting connection...
✅ BLUETOOTH DEBUG: Successfully connected
```

## Troubleshooting

### No Devices Found
**Possible Causes:**
1. No other devices running the same app nearby
2. Bluetooth/Location permissions denied
3. Bluetooth disabled on device
4. Different service IDs between devices

**Solutions:**
1. Ensure both devices have the app installed and advertising
2. Check app permissions in Android Settings
3. Enable Bluetooth and Location services
4. Verify both apps use same service ID

### Permission Issues
**Look for:**
```
❌ BLUETOOTH DEBUG: Core Bluetooth permissions not granted
```

**Solutions:**
1. Tap "Open App Settings" button when it appears
2. Manually grant all Bluetooth and Location permissions
3. Restart the app after granting permissions

### Discovery Starts But Finds Nothing
**Look for:**
```
✅ BLUETOOTH DEBUG: Discovery started successfully
⏰ BLUETOOTH DEBUG: Discovery still running... Found 0 devices so far
```

**This is normal if:**
- No other devices are advertising nearby
- Testing on emulator (expected behavior)
- Other devices are using different service IDs

## Debug Features

### Debug Status Button
- Shows current Bluetooth state
- Displays service ID being used
- Lists connected devices
- Useful for troubleshooting

### Simulate Device Found (Debug Mode Only)
- Only appears in debug builds
- Simulates finding and connecting to a fake device
- Useful for testing UI without real devices
- Tests the complete connection flow

## Key Points

1. **Emulator Limitations**: Bluetooth discovery is very limited on emulators
2. **Physical Devices Required**: For real testing, use actual Android devices
3. **Service ID Matching**: All devices must use the same service ID
4. **Permissions Critical**: All Bluetooth and Location permissions must be granted
5. **Discovery Time**: Can take 10-30 seconds to find nearby devices
6. **Background Apps**: Apps should remain in foreground during testing

## Service ID
Current service ID: `com.yourapp.offlineSync`

All devices must use this exact same service ID to discover each other.