import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PermissionService {
  // Private constructor
  PermissionService._();

  static const String _permissionsRequestedKey = 'permissions_requested';
  
  // Cache for SharedPreferences instance
  static SharedPreferences? _prefsCache;

  static Future<SharedPreferences> get _prefs async {
    _prefsCache ??= await SharedPreferences.getInstance();
    return _prefsCache!;
  }

  static Future<bool> hasRequestedPermissions() async {
    final prefs = await _prefs;
    return prefs.getBool(_permissionsRequestedKey) ?? false;
  }

  static Future<void> markPermissionsRequested() async {
    final prefs = await _prefs;
    await prefs.setBool(_permissionsRequestedKey, true);
  }

  static Future<PermissionStatus> requestAllPermissions() async {
    const permissions = <Permission>[
      Permission.locationWhenInUse,
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
      Permission.bluetoothAdvertise,
      Permission.camera,
      Permission.photos,
    ];

    final statuses = await permissions.request();
    
    // Check if all critical permissions are granted
    final allGranted = statuses.values.every(
      (status) => status.isGranted || status.isLimited
    );
    
    await markPermissionsRequested();
    
    return allGranted ? PermissionStatus.granted : PermissionStatus.denied;
  }

  static Future<bool> checkBluetoothPermissions() async {
    final results = await Future.wait([
      Permission.bluetoothConnect.status,
      Permission.bluetoothScan.status,
      Permission.bluetoothAdvertise.status,
    ]);
    
    return results.every((status) => status.isGranted);
  }

  static Future<bool> checkLocationPermissions() async {
    final status = await Permission.locationWhenInUse.status;
    return status.isGranted || status.isLimited;
  }

  static Future<bool> checkCameraPermissions() async {
    final status = await Permission.camera.status;
    return status.isGranted;
  }

  static Future<bool> checkPhotosPermissions() async {
    final status = await Permission.photos.status;
    return status.isGranted || status.isLimited;
  }
}
