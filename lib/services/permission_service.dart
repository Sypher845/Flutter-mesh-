import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PermissionService {
  static const String _permissionsRequestedKey = 'permissions_requested';

  static Future<bool> hasRequestedPermissions() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_permissionsRequestedKey) ?? false;
  }

  static Future<void> markPermissionsRequested() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_permissionsRequestedKey, true);
  }

  static Future<PermissionStatus> requestAllPermissions() async {
    final permissions = <Permission>[
      Permission.locationWhenInUse,
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
      Permission.bluetoothAdvertise,
      Permission.camera,
      Permission.photos,
    ];

    Map<Permission, PermissionStatus> statuses = await permissions.request();
    
    // Check if all critical permissions are granted
    bool allGranted = statuses.values.every((status) => 
      status == PermissionStatus.granted || status == PermissionStatus.limited);
    
    await markPermissionsRequested();
    
    return allGranted ? PermissionStatus.granted : PermissionStatus.denied;
  }

  static Future<bool> checkBluetoothPermissions() async {
    final bluetoothConnect = await Permission.bluetoothConnect.status;
    final bluetoothScan = await Permission.bluetoothScan.status;
    final bluetoothAdvertise = await Permission.bluetoothAdvertise.status;
    
    return bluetoothConnect.isGranted && 
           bluetoothScan.isGranted && 
           bluetoothAdvertise.isGranted;
  }

  static Future<bool> checkLocationPermissions() async {
    final location = await Permission.locationWhenInUse.status;
    return location.isGranted || location.isLimited;
  }

  static Future<bool> checkCameraPermissions() async {
    final camera = await Permission.camera.status;
    return camera.isGranted;
  }

  static Future<bool> checkPhotosPermissions() async {
    final photos = await Permission.photos.status;
    return photos.isGranted || photos.isLimited;
  }
}
