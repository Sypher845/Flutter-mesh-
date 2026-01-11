/// Application-wide constants
class AppConstants {
  // Private constructor to prevent instantiation
  AppConstants._();

  // App Information
  static const String appName = 'Hazard Reporter';
  static const String appVersion = '1.0.0';

  // Bluetooth Configuration
  static const String bluetoothServiceId = 'com.yourapp.offlineSync';
  static const String bluetoothDeviceName = 'OfflineSyncDevice';
  
  // Image Configuration
  static const int maxImageDimension = 800;
  static const int imageJpegQuality = 85;
  static const int maxImageSizeKB = 200;
  static const int maxEncodedImageSizeKB = 250;
  
  // Network Configuration
  static const int maxRetryAttempts = 3;
  static const int rebroadcastDelayMs = 100;
  static const int sendTimeoutSeconds = 30;
  static const int rebroadcastTimeoutSeconds = 10;
  static const int connectionWaitSeconds = 5;
  
  // Data Limits
  static const int maxReceivedDataItems = 20;
  static const int maxTrackedUUIDs = 100;
  static const int uuidCleanupCount = 20;
  
  // Health Check
  static const int healthCheckIntervalSeconds = 30;
  static const int connectionVerifyTimeoutSeconds = 2;
  
  // UI Configuration
  static const int statusMessageDurationSeconds = 3;
  static const int errorMessageDurationSeconds = 5;
}
