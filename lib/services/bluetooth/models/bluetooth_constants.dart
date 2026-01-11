/// Constants used throughout the Bluetooth service
/// 
/// **Range Optimization Configuration (Requirement 1.1):**
/// 
/// This class defines constants optimized for maximum Bluetooth range using
/// the Nearby Connections API with P2P_CLUSTER strategy.
/// 
/// **Key Range Optimizations:**
/// 
/// 1. **Strategy Selection:**
///    - P2P_CLUSTER is used throughout (see ConnectionManager)
///    - Optimizes for range over throughput
///    - Supports 100m clear line of sight, 30m+ with obstacles
/// 
/// 2. **Timeout Configuration:**
///    - connectionTimeout: 5000ms (base timeout for connections)
///    - extendedConnectionTimeout: 10000ms (for weak signals)
///    - Adaptive timeout adjustment (5-10s) based on success rates
///    - Longer timeouts allow weak signals to complete handshakes
/// 
/// 3. **Retry Logic:**
///    - maxRetries: 3 attempts per send operation
///    - reconnectionMaxRetries: 5 attempts for lost connections
///    - reconnectionIntervalSeconds: 5 seconds between attempts
///    - Exponential backoff for send retries (100ms, 200ms, 400ms)
///    - Retries overcome temporary signal fluctuations at range limits
/// 
/// 4. **Discovery Optimization:**
///    - discoveryHighFrequencySeconds: 5s (when no connections)
///    - discoveryNormalFrequencySeconds: 30s (when connected)
///    - Adaptive frequency helps find distant devices faster
/// 
/// **Expected Range Performance:**
/// - Clear line of sight: 100 meters
/// - With obstacles: 30+ meters
/// - Indoor: 20-50 meters (construction dependent)
/// - Outdoor: 50-100 meters
/// 
/// **Transmit Power (Requirement 1.5):**
/// - Nearby Connections API does not expose direct power control
/// - P2P_CLUSTER strategy uses platform defaults (typically maximum)
/// - Android: System-managed, typically maximum for P2P_CLUSTER
/// - iOS: Limited by iOS Bluetooth restrictions
class BluetoothConstants {
  // Service identification
  static const String serviceId = 'com.yourapp.offlineSync';
  static const String deviceName = 'OfflineSyncDevice';
  
  // Connection settings
  // Requirement 1.1: Retry logic for range reliability
  static const int maxRetries = 3;
  static const int maxSendAttempts = 2;
  // Requirement 1.1: Base timeout allows weak signals to complete
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
  
  // Reconnection settings
  static const int reconnectionMaxRetries = 5;
  static const int reconnectionIntervalSeconds = 5;
  static const int reconnectionTimerIntervalSeconds = 2;
  
  // Adaptive strategy settings
  static const int metricsWindowSize = 10;
  static const double lowSuccessThreshold = 0.5;
  static const double highSuccessThreshold = 0.8;
  static const int adaptiveTimeoutMin = 5000; // milliseconds
  static const int adaptiveTimeoutMax = 10000; // milliseconds
  
  // Connection management settings
  static const int maxConnections = 8;
  static const int discoveryRestartIntervalSeconds = 30;
  static const int fullResetErrorThreshold = 3;
  
  // Range optimization settings
  // Requirement 1.1: Extended timeout for weak signals at range limits
  static const int extendedConnectionTimeout = 10000; // milliseconds
  // Requirement 1.1: Adaptive discovery frequency helps find distant devices
  static const int discoveryHighFrequencySeconds = 5;
  static const int discoveryNormalFrequencySeconds = 30;
  
  // Connection quality logging settings
  static const int signalStrengthThresholdWeak = -80; // dBm
  static const int signalStrengthThresholdModerate = -70; // dBm
  static const int signalStrengthThresholdStrong = -60; // dBm
}
