import 'package:permission_handler/permission_handler.dart';

/// Manages Bluetooth and location permissions
class PermissionManager {
  /// Request all necessary permissions for Bluetooth operations
  /// Returns true if all required permissions are granted
  Future<bool> requestPermissions() async {
    bool locationGranted = await _requestLocationPermissions();
    bool bluetoothGranted = await _requestBluetoothPermissions();
    
    if (!bluetoothGranted || !locationGranted) {
      return false;
    }

    // Optional permission
    await _requestNearbyWifiPermission();

    return true;
  }

  /// Request location permissions (required for Bluetooth scanning)
  Future<bool> _requestLocationPermissions() async {
    bool locationGranted = false;
    
    // Try locationWhenInUse first
    try {
      final locationStatus = await Permission.locationWhenInUse.request();
      locationGranted = locationStatus == PermissionStatus.granted || 
                       locationStatus == PermissionStatus.limited;
    } catch (e) {
      // Continue to next attempt
    }
    
    // Try general location permission
    if (!locationGranted) {
      try {
        final locationStatus = await Permission.location.request();
        locationGranted = locationStatus == PermissionStatus.granted || 
                         locationStatus == PermissionStatus.limited;
      } catch (e) {
        // Continue to next attempt
      }
    }
    
    // Try locationAlways as last resort
    if (!locationGranted) {
      try {
        final fineLocationStatus = await Permission.locationAlways.request();
        locationGranted = fineLocationStatus == PermissionStatus.granted || 
                         fineLocationStatus == PermissionStatus.limited;
      } catch (e) {
        // Final attempt failed
      }
    }
    
    return locationGranted;
  }

  /// Request Bluetooth permissions
  Future<bool> _requestBluetoothPermissions() async {
    final bluetoothPermissions = [
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
      Permission.bluetoothAdvertise,
    ];

    Map<Permission, PermissionStatus> bluetoothStatuses = 
        await bluetoothPermissions.request();
    
    bool bluetoothGranted = bluetoothStatuses.values.every((status) => 
      status == PermissionStatus.granted || status == PermissionStatus.limited);
    
    return bluetoothGranted;
  }

  /// Request nearby WiFi devices permission (optional)
  Future<void> _requestNearbyWifiPermission() async {
    try {
      await Permission.nearbyWifiDevices.request();
    } catch (e) {
      // Optional permission, ignore errors
    }
  }
}
