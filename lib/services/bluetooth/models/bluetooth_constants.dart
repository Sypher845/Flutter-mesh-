/// Constants used throughout the Bluetooth service
class BluetoothConstants {
  // Service identification
  static const String serviceId = 'com.yourapp.offlineSync';
  static const String deviceName = 'OfflineSyncDevice';
  
  // Connection settings
  static const int maxRetries = 3;
  static const int maxSendAttempts = 2;
  static const int connectionTimeout = 5000; // milliseconds
  static const int sendTimeout = 30000; // milliseconds
  
  // Mesh network settings
  static const int maxHops = 5;
  static const int maxTrackedUUIDs = 100;
  static const int maxReceivedDataItems = 20;
  static const int uuidCleanupCount = 20;
  
  // Payload size limits
  static const int maxImageSizeBytes = 200 * 1024; // 200KB
  static const int maxEncodedImageSizeBytes = 250 * 1024; // 250KB
  static const int maxPayloadSizeBytes = 500 * 1024; // 500KB
  
  // Timing
  static const int healthCheckIntervalSeconds = 30;
  static const int connectionVerificationTimeout = 2000; // milliseconds
  static const int preSendCheckTimeout = 500; // milliseconds
  static const int rebroadcastDelay = 100; // milliseconds
  static const int rebroadcastTimeout = 10000; // milliseconds
  
  // Payload types
  static const String payloadTypePing = 'ping';
  static const String payloadTypeAck = 'ack';
  static const String payloadTypeConnectionVerify = 'connection_verify';
  static const String payloadTypePreSendCheck = 'pre_send_check';
  static const String payloadTypeReportData = 'report_data';
  static const String payloadTypeCustomData = 'custom_data';
}
