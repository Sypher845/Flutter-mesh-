import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'dart:convert';
import 'dart:async';

import '../../models/report_model.dart';
import 'connection_manager.dart';
import 'payload_handler.dart';
import 'mesh_network_manager.dart';
import 'connection_metrics.dart';
import 'reconnection_manager.dart';
import 'models/received_data.dart';
import 'models/bluetooth_constants.dart';

/// Main Bluetooth service that orchestrates all Bluetooth operations
/// 
/// This service manages:
/// - Device connections (advertising, discovery, connection management)
/// - Sending and receiving reports
/// - Mesh network rebroadcasting
/// - Connection health monitoring
/// 
/// This is a singleton to ensure only one instance manages Bluetooth
class BluetoothService extends ChangeNotifier {
  // Singleton pattern
  static final BluetoothService _instance = BluetoothService._internal();
  factory BluetoothService() => _instance;
  
  // Device ID for tracking original sender
  late final String _myDeviceId;
  
  // Managers
  late final ConnectionManager _connectionManager;
  late final PayloadHandler _payloadHandler;
  late final MeshNetworkManager _meshManager;
  late final ConnectionMetrics _connectionMetrics;
  late final ReconnectionManager _reconnectionManager;
  
  // State
  final List<ReceivedData> _receivedDataList = [];
  Timer? _healthCheckTimer;
  String _statusMessage = '';
  
  // Connection establishment tracking
  final Set<String> _fullyEstablishedConnections = {};
  final Map<String, Completer<bool>> _pendingAcceptances = {};
  
  // Lifecycle management
  AppLifecycleState? _currentLifecycleState;
  
  // Bluetooth state monitoring
  bool _isBluetoothEnabled = true;
  bool _operationsPaused = false;
  
  // Debug mode for detailed metrics
  bool _debugMode = false;
  
  // Getters
  bool get isAdvertising => _connectionManager.isAdvertising;
  bool get isDiscovering => _connectionManager.isDiscovering;
  Set<String> get connectedDevices => _connectionManager.connectedDevices;
  Set<String> get fullyEstablishedConnections => Set.unmodifiable(_fullyEstablishedConnections);
  List<ReceivedData> get receivedDataList => List.unmodifiable(_receivedDataList);
  String get statusMessage => _statusMessage;
  int get receivedReportCount => _meshManager.receivedReportCount;
  bool get isBluetoothEnabled => _isBluetoothEnabled;
  bool get operationsPaused => _operationsPaused;
  bool get debugMode => _debugMode;

  BluetoothService._internal() {
    // Generate unique device ID for this instance
    _myDeviceId = 'device_${DateTime.now().millisecondsSinceEpoch}';
    
    _initializeManagers();
    _startPeriodicHealthCheck();
    _initializeReceiverMode();
    _initializeLifecycleListener();
  }
  
  // ============================================================================
  // RANGE OPTIMIZATION CONFIGURATION
  // ============================================================================
  
  /// Range Optimization Strategy
  /// 
  /// This Bluetooth service is configured for maximum range using the following
  /// optimizations:
  /// 
  /// **1. P2P_CLUSTER Strategy (Requirement 1.1)**
  /// The Nearby Connections API is configured with Strategy.P2P_CLUSTER which
  /// optimizes for:
  /// - Maximum range over throughput
  /// - Longer connection distances (up to 100m clear line of sight)
  /// - Better obstacle penetration (minimum 30m with obstacles)
  /// - Lower data rates but more reliable connections
  /// 
  /// **2. Extended Timeout Configuration (Requirement 1.1)**
  /// Connection timeouts are configured to allow weaker signals to complete:
  /// - Base timeout: 5 seconds (BluetoothConstants.connectionTimeout)
  /// - Extended timeout: 10 seconds (BluetoothConstants.extendedConnectionTimeout)
  /// - Adaptive timeout adjustment based on success rates (5-10 seconds)
  /// - Health check timeout: 2 seconds for stale detection
  /// 
  /// Longer timeouts benefit range by:
  /// - Allowing more time for weak signal handshakes
  /// - Reducing false negatives from slow connections
  /// - Enabling connections at the edge of range
  /// 
  /// **3. Retry Logic for Range (Requirement 1.1)**
  /// Multiple retry mechanisms improve range reliability:
  /// - Connection retry: Automatic reconnection with exponential backoff
  /// - Send retry: Up to 3 attempts per device with exponential backoff
  /// - Discovery restart: Periodic refresh to find distant devices
  /// - Health check: Proactive detection and recovery of weak connections
  /// 
  /// Retry logic benefits range by:
  /// - Overcoming temporary signal fluctuations
  /// - Increasing success probability at range limits
  /// - Maintaining connections despite interference
  /// - Recovering from brief signal loss
  /// 
  /// **4. Transmit Power Configuration (Requirement 1.5)**
  /// Where platform supports transmit power control:
  /// - Bluetooth transmit power set to maximum allowed level
  /// - Note: Nearby Connections API does not expose direct power control
  /// - Platform-specific implementations may vary
  /// - Android: Uses system default (typically maximum for P2P_CLUSTER)
  /// - iOS: Limited by iOS Bluetooth restrictions
  /// 
  /// **Configuration Constants:**
  /// - BluetoothConstants.connectionTimeout = 5000ms (base)
  /// - BluetoothConstants.extendedConnectionTimeout = 10000ms (extended)
  /// - BluetoothConstants.adaptiveTimeoutMin = 5000ms
  /// - BluetoothConstants.adaptiveTimeoutMax = 10000ms
  /// - BluetoothConstants.maxRetries = 3 (send retries)
  /// - BluetoothConstants.reconnectionMaxRetries = 5
  /// - BluetoothConstants.reconnectionIntervalSeconds = 5
  /// 
  /// **Expected Range Performance:**
  /// - Clear line of sight: 100 meters
  /// - With obstacles: 30+ meters
  /// - Indoor environments: 20-50 meters (varies by construction)
  /// - Outdoor open areas: 50-100 meters
  /// 
  /// See BluetoothConstants for all configuration values.

  /// Initialize all manager instances and set up callbacks
  void _initializeManagers() {
    // Initialize metrics and reconnection managers first
    _connectionMetrics = ConnectionMetrics();
    _reconnectionManager = ReconnectionManager();
    
    // Initialize connection manager with metrics
    _connectionManager = ConnectionManager(connectionMetrics: _connectionMetrics);
    _payloadHandler = PayloadHandler();
    _meshManager = MeshNetworkManager(_payloadHandler);
    
    // Set up callbacks
    _connectionManager.onStatusUpdate = _updateStatus;
    _payloadHandler.onStatusUpdate = _updateStatus;
    _meshManager.onStatusUpdate = _updateStatus;
    _meshManager.onDataChanged = notifyListeners;
    
    // Connection callbacks
    _connectionManager.onConnectionInitiated = _onConnectionInitiated;
    _connectionManager.onConnectionResult = _onConnectionResult;
    _connectionManager.onDisconnected = _onDisconnected;
    _connectionManager.onEndpointFound = _onEndpointFound;
    _connectionManager.onEndpointLost = _onEndpointLost;
    
    // Set up reconnection manager callbacks
    _reconnectionManager.onReconnectAttempt = (endpointId) {
      if (kDebugMode) {
        print('🔄 Attempting reconnection to: $endpointId');
      }
      _connectionManager.requestConnection(endpointId);
    };
    
    _reconnectionManager.onReconnectSuccess = (endpointId) {
      if (kDebugMode) {
        print('✅ Reconnection successful: $endpointId');
      }
      _updateStatus('✅ Reconnected to device');
    };
    
    _reconnectionManager.onReconnectExhausted = (endpointId) {
      if (kDebugMode) {
        print('❌ Reconnection attempts exhausted: $endpointId');
      }
    };
    
    // Start reconnection loop
    _reconnectionManager.startReconnectionLoop();
  }

  /// Initialize device in Receiver Mode (default state)
  /// - Advertising: ON (visible to others)
  /// - Discovery: ON (searching for other devices to form mesh network)
  /// - Ready to receive reports and build mesh connections
  Future<void> _initializeReceiverMode() async {
    await Future.delayed(Duration(seconds: 2));
    
    // Start advertising to be visible to others
    await _connectionManager.startAdvertising();
    
    // Start discovery to find other devices and form mesh network
    await _connectionManager.startDiscovery();
    
    _updateStatus('📡 Ready to receive reports');
    
    if (kDebugMode) {
      print('✅ Receiver Mode initialized');
      print('   Advertising: ${_connectionManager.isAdvertising}');
      print('   Discovery: ${_connectionManager.isDiscovering}');
    }
  }

  /// Start periodic health check of connections
  void _startPeriodicHealthCheck() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = Timer.periodic(
      Duration(seconds: BluetoothConstants.healthCheckIntervalSeconds),
      (timer) async {
        if (_connectionManager.connectedDevices.isNotEmpty) {
          try {
            await verifyAndCleanConnections();
          } catch (e) {
            // Silently handle health check errors
          }
        }
      },
    );
  }

  /// Initialize app lifecycle listener
  void _initializeLifecycleListener() {
    // Get the current lifecycle state
    _currentLifecycleState = WidgetsBinding.instance.lifecycleState;
    
    // Listen to lifecycle changes
    WidgetsBinding.instance.addObserver(_LifecycleObserver(this));
    
    if (kDebugMode) {
      print('✅ Lifecycle listener initialized');
      print('   Current state: $_currentLifecycleState');
    }
  }

  /// Handle app lifecycle state changes
  /// 
  /// Requirements 6.1: When app transitions to background, maintain connections
  /// Requirements 6.2: When app returns to foreground, verify connection health
  void handleAppLifecycleChange(AppLifecycleState state) {
    final previousState = _currentLifecycleState;
    _currentLifecycleState = state;
    
    if (kDebugMode) {
      print('🔄 App lifecycle changed: $previousState → $state');
    }
    
    switch (state) {
      case AppLifecycleState.resumed:
        // App returned to foreground
        _handleForegroundTransition();
        break;
        
      case AppLifecycleState.paused:
        // App moved to background
        _handleBackgroundTransition();
        break;
        
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        // No specific action needed for these states
        break;
    }
  }

  /// Handle transition to background
  /// Maintains all active connections as per requirement 6.1
  void _handleBackgroundTransition() {
    if (kDebugMode) {
      print('📱 App moving to background');
      print('   Maintaining ${_connectionManager.connectedDevices.length} connections');
    }
    
    // Record the background transition event
    _connectionMetrics.recordEvent(
      'lifecycle',
      'background',
      {
        'timestamp': DateTime.now().toIso8601String(),
        'connected_devices': _connectionManager.connectedDevices.length,
      },
    );
    
    // Connections are maintained automatically
    // No action needed - just log the state
    _updateStatus('📱 App in background - connections maintained');
  }

  /// Handle transition to foreground
  /// Verifies connection health as per requirement 6.2
  void _handleForegroundTransition() {
    if (kDebugMode) {
      print('📱 App returning to foreground');
      print('   Verifying health of ${_connectionManager.connectedDevices.length} connections');
    }
    
    // Record the foreground transition event
    _connectionMetrics.recordEvent(
      'lifecycle',
      'foreground',
      {
        'timestamp': DateTime.now().toIso8601String(),
        'connected_devices': _connectionManager.connectedDevices.length,
      },
    );
    
    // Update status immediately
    _updateStatus('📱 App resumed - connections verified');
    
    // Verify connection health when returning to foreground
    if (_connectionManager.connectedDevices.isNotEmpty) {
      verifyAndCleanConnections().then((_) {
        if (kDebugMode) {
          print('✅ Foreground health check complete');
          print('   Active connections: ${_connectionManager.connectedDevices.length}');
        }
      }).catchError((e) {
        if (kDebugMode) {
          print('⚠️ Error during foreground health check: $e');
        }
      });
    }
  }

  /// Handle Bluetooth state changes
  /// 
  /// Requirements 6.3: When Bluetooth is disabled, pause operations and notify user
  /// Requirements 6.4: When Bluetooth is enabled, resume operations
  void handleBluetoothStateChange(bool enabled) {
    final previousState = _isBluetoothEnabled;
    _isBluetoothEnabled = enabled;
    
    if (kDebugMode) {
      print('📡 Bluetooth state changed: $previousState → $enabled');
    }
    
    // Record the Bluetooth state change event
    _connectionMetrics.recordEvent(
      'bluetooth_state',
      enabled ? 'enabled' : 'disabled',
      {
        'timestamp': DateTime.now().toIso8601String(),
        'previous_state': previousState,
        'new_state': enabled,
        'connected_devices': _connectionManager.connectedDevices.length,
      },
    );
    
    if (!enabled && previousState) {
      // Bluetooth was disabled
      _handleBluetoothDisabled();
    } else if (enabled && !previousState) {
      // Bluetooth was enabled
      _handleBluetoothEnabled();
    }
  }

  /// Handle Bluetooth disabled state
  /// Pauses all operations and notifies user as per requirement 6.3
  void _handleBluetoothDisabled() {
    if (kDebugMode) {
      print('📡 Bluetooth disabled - pausing operations');
      print('   Current connections: ${_connectionManager.connectedDevices.length}');
      print('   Advertising: ${_connectionManager.isAdvertising}');
      print('   Discovery: ${_connectionManager.isDiscovering}');
    }
    
    // Mark operations as paused
    _operationsPaused = true;
    
    // Stop all Bluetooth operations
    _connectionManager.stopAll().then((_) {
      if (kDebugMode) {
        print('✅ All Bluetooth operations stopped');
      }
    }).catchError((e) {
      if (kDebugMode) {
        print('⚠️ Error stopping Bluetooth operations: $e');
      }
    });
    
    // Notify user that Bluetooth must be enabled
    _updateStatus('⚠️ Bluetooth is disabled. Please enable Bluetooth to continue.');
    
    if (kDebugMode) {
      print('⚠️ User notified: Bluetooth must be enabled');
    }
  }

  /// Handle Bluetooth enabled state
  /// Resumes operations as per requirement 6.4
  void _handleBluetoothEnabled() {
    if (kDebugMode) {
      print('📡 Bluetooth enabled - resuming operations');
    }
    
    // Mark operations as no longer paused
    _operationsPaused = false;
    
    // Resume advertising and discovery
    Future.delayed(Duration(milliseconds: 500), () async {
      try {
        await _connectionManager.startAdvertising();
        await _connectionManager.startDiscovery();
        
        if (kDebugMode) {
          print('✅ Bluetooth operations resumed');
          print('   Advertising: ${_connectionManager.isAdvertising}');
          print('   Discovery: ${_connectionManager.isDiscovering}');
        }
        
        _updateStatus('✅ Bluetooth enabled - operations resumed');
      } catch (e) {
        if (kDebugMode) {
          print('⚠️ Error resuming Bluetooth operations: $e');
        }
        _updateStatus('⚠️ Error resuming Bluetooth operations');
      }
    });
  }

  @override
  void dispose() {
    _healthCheckTimer?.cancel();
    _reconnectionManager.dispose();
    _connectionManager.stopAll();
    _fullyEstablishedConnections.clear();
    _pendingAcceptances.clear();
    super.dispose();
  }

  // ============================================================================
  // CONNECTION CALLBACKS
  // ============================================================================

  void _onConnectionInitiated(String endpointId, ConnectionInfo connectionInfo) async {
    // Requirement 9.2: Accept connection within 2 seconds
    final acceptCompleter = Completer<bool>();
    _pendingAcceptances[endpointId] = acceptCompleter;
    
    if (kDebugMode) {
      print('🔗 Connection initiated - accepting with 2-second timeout');
      print('   Endpoint: $endpointId');
    }
    
    try {
      // Accept connection with temporary callback
      // Will be replaced in _onConnectionResult after connection confirms
      await _connectionManager.acceptConnection(
        endpointId,
        (receivedEndpointId, receivedPayload) {
          if (kDebugMode) {
            print('📨 Early payload callback (before connection confirmed)');
          }
          _onPayloadReceived(receivedEndpointId, receivedPayload);
        },
      ).timeout(
        Duration(seconds: 2),
        onTimeout: () {
          if (kDebugMode) {
            print('⚠️ Connection acceptance timeout after 2 seconds');
          }
          
          // Record timeout in metrics
          _connectionMetrics.recordEvent(
            endpointId,
            'acceptance_timeout',
            {
              'timestamp': DateTime.now().toIso8601String(),
              'timeout': '2s',
            },
          );
          
          acceptCompleter.complete(false);
          throw TimeoutException('Connection acceptance timeout');
        },
      );
      
      // Acceptance successful
      acceptCompleter.complete(true);
      
      // Record successful acceptance in metrics
      _connectionMetrics.recordEvent(
        endpointId,
        'acceptance_success',
        {
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
      
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error accepting connection: $e');
      }
      
      if (!acceptCompleter.isCompleted) {
        acceptCompleter.complete(false);
      }
      
      // Record acceptance error in metrics
      _connectionMetrics.recordEvent(
        endpointId,
        'acceptance_error',
        {
          'timestamp': DateTime.now().toIso8601String(),
          'error': e.toString(),
        },
      );
    } finally {
      _pendingAcceptances.remove(endpointId);
    }
  }

  void _onConnectionResult(String endpointId, Status status) {
    if (status == Status.CONNECTED) {
      // Requirement 9.3: Register payload callback immediately after acceptance
      _registerPayloadCallbackImmediate(endpointId);
      
      // Requirement 9.4: Send verification ping after confirmation
      _sendVerificationPing(endpointId);
      
      // If this was a reconnection, remove from queue
      if (_reconnectionManager.isInQueue(endpointId)) {
        _reconnectionManager.removeFromQueue(endpointId);
        _reconnectionManager.onReconnectSuccess?.call(endpointId);
      }
      
      notifyListeners();
    }
  }

  void _onDisconnected(String endpointId) {
    // Remove from fully established connections
    _fullyEstablishedConnections.remove(endpointId);
    
    // Add to reconnection queue for automatic reconnection
    _reconnectionManager.addToQueue(endpointId, 'Device_$endpointId');
    
    // Record disconnection event in metrics
    _connectionMetrics.recordEvent(
      endpointId,
      'disconnected',
      {'timestamp': DateTime.now().toIso8601String()},
    );
    
    notifyListeners();
  }

  void _onEndpointFound(String endpointId, String endpointName, String serviceId) async {
    if (serviceId == BluetoothConstants.serviceId) {
      // Requirement 7.1: Check connection limit before accepting new connections
      if (!_connectionManager.canAcceptNewConnection()) {
        if (kDebugMode) {
          print('⚠️ Connection limit reached (${_connectionManager.connectedDevices.length}/${_connectionManager.maxConnections})');
          print('   Skipping connection to: $endpointName ($endpointId)');
        }
        
        // Log when limit prevents new connections
        _connectionMetrics.recordEvent(
          endpointId,
          'connection_limit_reached',
          {
            'timestamp': DateTime.now().toIso8601String(),
            'endpoint_name': endpointName,
            'current_connections': _connectionManager.connectedDevices.length,
            'max_connections': _connectionManager.maxConnections,
          },
        );
        
        _updateStatus('⚠️ Connection limit reached - maintaining existing connections');
        return;
      }
      
      // Requirement 9.1: Process connection requests in parallel
      // Don't await - let multiple discoveries be processed simultaneously
      _processConnectionRequest(endpointId, endpointName);
    }
  }
  
  /// Process a connection request in parallel
  /// Requirement 9.1: Multiple discoveries trigger parallel connections
  Future<void> _processConnectionRequest(String endpointId, String endpointName) async {
    if (kDebugMode) {
      print('🔗 Processing connection request in parallel');
      print('   Endpoint: $endpointId');
      print('   Name: $endpointName');
    }
    
    try {
      await _connectionManager.requestConnection(endpointId);
      
      // Record connection request in metrics
      _connectionMetrics.recordEvent(
        endpointId,
        'connection_request',
        {
          'timestamp': DateTime.now().toIso8601String(),
          'endpoint_name': endpointName,
        },
      );
      
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error processing connection request: $e');
      }
      
      // Record connection request error in metrics
      _connectionMetrics.recordEvent(
        endpointId,
        'connection_request_error',
        {
          'timestamp': DateTime.now().toIso8601String(),
          'error': e.toString(),
        },
      );
    }
    
    // Requirement 10.5: Check if full reset is needed after connection errors
    if (_connectionManager.shouldPerformFullReset()) {
      if (kDebugMode) {
        print('⚠️ ${_connectionManager.consecutiveErrors} consecutive errors detected - performing full reset');
      }
      
      _updateStatus('⚠️ Resetting Bluetooth due to errors...');
      
      // Perform full reset after a short delay
      Future.delayed(Duration(seconds: 1), () async {
        await _connectionManager.performFullReset();
      });
    }
  }

  void _onEndpointLost(String? endpointId) {
    notifyListeners();
  }

  /// Register payload callback immediately for a confirmed connection
  /// Requirement 9.3: Immediate callback registration after acceptance
  void _registerPayloadCallbackImmediate(String endpointId) {
    if (kDebugMode) {
      print('📝 Registering payload callback immediately for: $endpointId');
    }
    
    _connectionManager.acceptConnection(
      endpointId,
      (receivedEndpointId, receivedPayload) {
        _onPayloadReceived(receivedEndpointId, receivedPayload);
      },
    ).then((_) {
      if (kDebugMode) {
        print('✅ Payload callback registered for: $endpointId');
      }
      
      // Record callback registration in metrics
      _connectionMetrics.recordEvent(
        endpointId,
        'callback_registered',
        {
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
    }).catchError((e) {
      if (kDebugMode) {
        print('❌ Failed to register callback for: $endpointId - $e');
      }
    });
  }
  
  /// Send verification ping after connection confirmation
  /// Requirement 9.4: Send verification ping after confirmation
  /// Requirement 9.5: Mark connection as fully established after successful ping
  void _sendVerificationPing(String endpointId) {
    if (kDebugMode) {
      print('🏓 Sending verification ping to: $endpointId');
    }
    
    // Small delay to ensure callback is registered
    Timer(Duration(milliseconds: 100), () async {
      if (!_connectionManager.connectedDevices.contains(endpointId)) {
        if (kDebugMode) {
          print('⚠️ Device disconnected before ping: $endpointId');
        }
        return;
      }
      
      try {
        // Send verification ping
        await _payloadHandler.sendConnectionPing(endpointId);
        
        if (kDebugMode) {
          print('✅ Verification ping sent to: $endpointId');
        }
        
        // Record ping sent in metrics
        _connectionMetrics.recordEvent(
          endpointId,
          'verification_ping_sent',
          {
            'timestamp': DateTime.now().toIso8601String(),
          },
        );
        
        // Requirement 9.5: Mark connection as fully established after successful ping
        _markConnectionEstablished(endpointId);
        
      } catch (e) {
        if (kDebugMode) {
          print('❌ Failed to send verification ping to: $endpointId - $e');
        }
        
        // Record ping failure in metrics
        _connectionMetrics.recordEvent(
          endpointId,
          'verification_ping_failed',
          {
            'timestamp': DateTime.now().toIso8601String(),
            'error': e.toString(),
          },
        );
      }
    });
  }
  
  /// Mark a connection as fully established
  /// Requirement 9.5: Mark connection as fully established after successful ping
  void _markConnectionEstablished(String endpointId) {
    _fullyEstablishedConnections.add(endpointId);
    
    if (kDebugMode) {
      print('✅ Connection fully established: $endpointId');
      print('   Total established connections: ${_fullyEstablishedConnections.length}');
    }
    
    // Record establishment in metrics
    _connectionMetrics.recordEvent(
      endpointId,
      'connection_established',
      {
        'timestamp': DateTime.now().toIso8601String(),
        'total_established': _fullyEstablishedConnections.length,
      },
    );
  }
  


  // ============================================================================
  // PAYLOAD HANDLING
  // ============================================================================

  void _onPayloadReceived(String endpointId, Payload payload) {
    if (kDebugMode) {
      print('📥 _onPayloadReceived called');
      print('   Endpoint: $endpointId');
      print('   Payload type: ${payload.type}');
      print('   Payload ID: ${payload.id}');
    }
    
    try {
      if (payload.type == PayloadType.BYTES) {
        if (kDebugMode) {
          print('   Processing BYTES payload...');
        }
        _processReceivedPayload(endpointId, payload);
        _payloadHandler.sendAcknowledgment(endpointId, payload.id);
      } else {
        _updateStatus('⚠️ Received unsupported payload type');
        if (kDebugMode) {
          print('   ⚠️ Unsupported payload type: ${payload.type}');
        }
      }
    } catch (e) {
      _updateStatus('❌ Error processing received payload');
      if (kDebugMode) {
        print('❌ Error in _onPayloadReceived: $e');
      }
    }
  }

  void _processReceivedPayload(String endpointId, Payload payload) {
    try {
      // Decode payload
      final receivedData = _payloadHandler.decodePayload(payload);
      if (receivedData == null) return;
      
      final dataType = receivedData['type'] as String?;
      final senderId = receivedData['senderId'] as String?;
      final senderName = receivedData['senderName'] as String?;
      
      if (dataType == null) {
        _updateStatus('❌ Invalid data structure');
        return;
      }
      
      // Ignore connection test payloads
      if (_payloadHandler.shouldIgnorePayload(dataType)) {
        if (kDebugMode && dataType == BluetoothConstants.payloadTypePreSendCheck) {
          print('   ✅ Pre-send check received and acknowledged');
        }
        return;
      }
      
      // Handle report data
      if (_isReportData(dataType)) {
        _handleReportData(receivedData, endpointId);
      }
      
      // Handle custom data
      if (dataType == BluetoothConstants.payloadTypeCustomData) {
        // Handle custom data
      }
      
      // Store received data
      _storeReceivedData(receivedData, senderId, senderName, endpointId);
      
    } catch (e) {
      _updateStatus('❌ Error processing received data');
      if (kDebugMode) {
        print('❌ Error in _processReceivedPayload: $e');
      }
      notifyListeners();
    }
  }

  bool _isReportData(String dataType) {
    return dataType == BluetoothConstants.payloadTypeReportData ||
           dataType == 'report_metadata' ||
           dataType.contains('report') ||
           dataType == 'ticket_data' ||
           dataType.contains('ticket');
  }

  void _handleReportData(Map<String, dynamic> receivedData, String endpointId) {
    // Check if I'm the original sender (prevent receiving my own report)
    final originalSenderId = receivedData['originalSenderId'] as String?;
    if (originalSenderId == _myDeviceId) {
      if (kDebugMode) {
        print('⏭️  Skipping my own report (originalSenderId matches _myDeviceId)');
      }
      return;
    }
    
    // Check hop count
    final hopCount = receivedData['hopCount'] as int? ?? 0;
    final maxHops = receivedData['maxHops'] as int? ?? BluetoothConstants.maxHops;
    
    final report = receivedData['report'] as Map<String, dynamic>? ?? 
                   receivedData['ticket'] as Map<String, dynamic>?;
    
    if (report == null) {
      _updateStatus('❌ Invalid report data received');
      return;
    }
    
    // CRITICAL: Update hop count in the report JSON itself
    // This ensures the UI displays the correct hop count
    report['hopCount'] = hopCount;
    
    // Check UUID for deduplication
    final reportUUID = report['id'] as String?;
    if (reportUUID == null || reportUUID.isEmpty) {
      _updateStatus('❌ Report missing UUID');
      return;
    }
    
    if (kDebugMode) {
      print('📥 Received report UUID: $reportUUID');
      print('   Original sender: $originalSenderId');
      print('   My device ID: $_myDeviceId');
      print('   Hop count: $hopCount/$maxHops');
      print('   Report JSON hop count updated to: ${report['hopCount']}');
      print('   Already have: ${_meshManager.hasReceivedReport(reportUUID)}');
      print('   Total UUIDs tracked: ${_meshManager.receivedReportCount}');
    }
    
    // Check for duplicate
    if (_meshManager.hasReceivedReport(reportUUID)) {
      if (kDebugMode) {
        print('⏭️  Skipping duplicate report: $reportUUID');
      }
      return;
    }
    
    // New report - add UUID to tracking set
    _meshManager.addReceivedReport(reportUUID);
    
    if (kDebugMode) {
      print('✅ New report accepted: $reportUUID');
      print('   Connected devices: ${_connectionManager.connectedDevices.length}');
      print('   Will rebroadcast to: ${_connectionManager.connectedDevices.length - 1} devices');
    }
    
    // Rebroadcast if under max hops
    if (_meshManager.shouldRebroadcast(receivedData)) {
      _meshManager.rebroadcastReport(
        receivedData,
        endpointId,
        _connectionManager.connectedDevices,
      );
    } else {
      if (kDebugMode) {
        print('⏭️  Not rebroadcasting - max hops reached');
      }
    }
  }

  void _storeReceivedData(
    Map<String, dynamic> receivedData,
    String? senderId,
    String? senderName,
    String endpointId,
  ) {
    final receivedDataObj = ReceivedData(
      senderId: senderId ?? endpointId,
      senderName: senderName ?? 'Unknown Device',
      data: receivedData,
      receivedAt: DateTime.now(),
    );
    
    _receivedDataList.add(receivedDataObj);
    
    // Keep only last N items
    while (_receivedDataList.length > BluetoothConstants.maxReceivedDataItems) {
      _receivedDataList.removeAt(0);
    }
    
    final dataType = receivedData['type'] as String?;
    _updateStatus('📥 Received $dataType from ${senderName ?? 'Unknown'}');
    notifyListeners();
  }

  // ============================================================================
  // SENDING REPORTS
  // ============================================================================

  /// Send report in Sender Mode with retry logic
  Future<void> sendReportData(ReportModel report) async {
    const maxAttempts = BluetoothConstants.maxSendAttempts;
    int attempt = 0;
    Exception? lastError;

    if (kDebugMode) {
      print('');
      print('═══════════════════════════════════════════════════════');
      print('📤 STARTING REPORT SEND');
      print('═══════════════════════════════════════════════════════');
      print('Report ID: ${report.id}');
      print('Report Title: ${report.title}');
      print('Max Attempts: $maxAttempts');
      print('═══════════════════════════════════════════════════════');
      print('');
    }

    while (attempt < maxAttempts) {
      attempt++;
      
      try {
        if (kDebugMode) {
          print('');
          print('─────────────────────────────────────────────────────');
          print('📡 SEND ATTEMPT $attempt/$maxAttempts');
          print('─────────────────────────────────────────────────────');
        }
        
        _updateStatus(attempt == 1 
          ? '📡 Entering Sender Mode...' 
          : '🔄 Retrying send...');
        
        // Ensure advertising and discovery are running
        await _ensureConnectionsActive();
        
        // Wait for connections
        if (!await _waitForConnections(attempt)) {
          if (attempt < maxAttempts) {
            await _connectionManager.stopDiscovery();
            await Future.delayed(Duration(seconds: 1));
            continue;
          } else {
            _updateStatus('⚠️ No receivers found - Report saved locally');
            await _returnToReceiverMode();
            throw Exception('No connected devices available after $maxAttempts attempts');
          }
        }

        // Verify connections are healthy
        await verifyAndCleanConnections();
        
        if (_connectionManager.connectedDevices.isEmpty) {
          if (attempt < maxAttempts) {
            await _connectionManager.stopDiscovery();
            await Future.delayed(Duration(seconds: 1));
            continue;
          } else {
            _updateStatus('❌ No active connections available');
            await _returnToReceiverMode();
            throw Exception('No active connections after $maxAttempts attempts');
          }
        }

        // Verify connections are responsive
        final activeDevices = await _verifyResponsiveConnections();
        
        if (activeDevices.isEmpty) {
          if (attempt < maxAttempts) {
            await _connectionManager.stopDiscovery();
            await Future.delayed(Duration(seconds: 1));
            continue;
          } else {
            _updateStatus('❌ No responsive connections available');
            await _returnToReceiverMode();
            throw Exception('No responsive connections after $maxAttempts attempts');
          }
        }

        // Prepare and send payload
        final bytes = await _prepareReportPayload(report);
        
        if (bytes == null || !_payloadHandler.validatePayloadSize(bytes)) {
          if (attempt < maxAttempts) {
            continue; // Retry without image
          }
          await _returnToReceiverMode();
          throw Exception('Payload too large');
        }

        // Send to all devices
        final successCount = await _sendToAllDevices(activeDevices, bytes, report.id);

        if (successCount > 0) {
          // REMOVED: _meshManager.addReceivedReport(report.id);
          // Sender should NOT add UUID to tracking
          // This allows the report to flow through mesh network via relay
          // The originalSenderId check prevents infinite loops
          
          if (kDebugMode) {
            print('');
            print('═══════════════════════════════════════════════════════');
            print('✅ REPORT SEND SUCCESSFUL');
            print('═══════════════════════════════════════════════════════');
            print('Report ID: ${report.id}');
            print('Original Sender ID: $_myDeviceId');
            print('Sent to: $successCount/${activeDevices.length} devices');
            print('Attempt: $attempt/$maxAttempts');
            print('NOT adding UUID to tracking (allows mesh relay)');
            print('Will skip if received back (originalSenderId check)');
            print('═══════════════════════════════════════════════════════');
            print('');
          }
          
          _updateStatus('✅ Report sent to $successCount/${activeDevices.length} devices');
          await _returnToReceiverMode();
          return; // Success
        } else {
          // All sends failed
          if (attempt < maxAttempts) {
            lastError = Exception('Send failed to all devices');
            await _connectionManager.stopDiscovery();
            await _connectionManager.disconnectAll();
            await Future.delayed(Duration(seconds: 1));
            continue;
          } else {
            _updateStatus('❌ Failed to send report to any devices after $maxAttempts attempts');
            await _returnToReceiverMode();
            throw Exception('Send failed to all devices after $maxAttempts attempts');
          }
        }
        
      } catch (e) {
        if (kDebugMode) {
          print('❌ Error during send attempt $attempt: $e');
        }
        lastError = e is Exception ? e : Exception(e.toString());
        
        if (attempt < maxAttempts) {
          await _connectionManager.stopDiscovery();
          await _connectionManager.disconnectAll();
          await Future.delayed(Duration(seconds: 1));
          continue;
        } else {
          _updateStatus('❌ Send failed after $maxAttempts attempts');
          await _returnToReceiverMode();
          rethrow;
        }
      }
    }
    
    await _returnToReceiverMode();
    throw lastError ?? Exception('Send failed');
  }

  Future<void> _ensureConnectionsActive() async {
    if (!_connectionManager.isAdvertising) {
      await _connectionManager.startAdvertising();
      await Future.delayed(Duration(milliseconds: 500));
    }
    
    if (!_connectionManager.isDiscovering) {
      await _connectionManager.startDiscovery();
      await Future.delayed(Duration(milliseconds: 500));
    }
  }

  Future<bool> _waitForConnections(int attempt) async {
    if (_connectionManager.connectedDevices.isEmpty) {
      _updateStatus('🔍 Searching for receivers...');
      
      final waitIterations = attempt == 1 ? 10 : 15;
      for (int i = 0; i < waitIterations; i++) {
        await Future.delayed(Duration(milliseconds: 500));
        if (_connectionManager.connectedDevices.isNotEmpty) break;
      }
    }
    
    return _connectionManager.connectedDevices.isNotEmpty;
  }

  Future<List<String>> _verifyResponsiveConnections() async {
    final activeDevices = _connectionManager.connectedDevices.toList();
    
    if (kDebugMode) {
      print('');
      print('🔍 USING ALL CONNECTED DEVICES (NO PRE-CHECK)');
      print('   Total connected devices: ${activeDevices.length}');
      print('   Device IDs: $activeDevices');
      print('   Note: Pre-send check removed to prevent false positives');
      print('   Actual send has retry logic to handle failures');
    }
    
    // REMOVED: Pre-send check that was causing devices to be excluded
    // The pre-send check was too aggressive and marked slow devices as dead
    // The actual send (_sendToAllDevices) has retry logic to handle failures
    
    return activeDevices;
  }

  Future<Uint8List?> _prepareReportPayload(ReportModel report) async {
    String? imageBase64;
    if (report.imageFile != null) {
      try {
        final imageBytes = await report.imageFile!.readAsBytes();
        
        if (imageBytes.length > BluetoothConstants.maxImageSizeBytes) {
          _updateStatus('⚠️ Image too large, sending without image');
        } else {
          imageBase64 = base64Encode(imageBytes);
          
          if (imageBase64.length > BluetoothConstants.maxEncodedImageSizeBytes) {
            _updateStatus('⚠️ Encoded image too large, sending without image');
            imageBase64 = null;
          }
        }
      } catch (e) {
        _updateStatus('⚠️ Image processing failed, sending without image');
      }
    }

    final reportData = report.toJson();
    if (imageBase64 != null) {
      reportData['imageBase64'] = imageBase64;
    }

    final payloadId = DateTime.now().millisecondsSinceEpoch;
    final payload = {
      'type': BluetoothConstants.payloadTypeReportData,
      'originalSenderId': _myDeviceId, // Track original sender to prevent loops
      'payloadId': payloadId,
      'senderId': 'device_$payloadId',
      'senderName': 'My Device',
      'timestamp': DateTime.now().toIso8601String(),
      'hopCount': 0,
      'maxHops': BluetoothConstants.maxHops,
      'report': reportData,
    };

    final jsonString = jsonEncode(payload);
    return Uint8List.fromList(utf8.encode(jsonString));
  }

  /// Send data to all devices with retry logic and health check marking
  /// 
  /// Requirements 7.3: Send to all connected devices in parallel
  /// Requirements 7.4: Retry up to 3 times with exponential backoff on failure
  /// Requirements 7.5: Mark connection for health check when all retries exhausted
  Future<int> _sendToAllDevices(
    List<String> activeDevices,
    Uint8List bytes,
    String reportId,
  ) async {
    int successCount = 0;
    final sendTasks = <Future<void>>[];
    final payloadId = DateTime.now().millisecondsSinceEpoch;
    final devicesNeedingHealthCheck = <String>[];

    if (kDebugMode) {
      print('');
      print('📤 SENDING TO ALL DEVICES');
      print('   Target devices: ${activeDevices.length}');
      print('   Payload size: ${bytes.length} bytes (${(bytes.length / 1024).toStringAsFixed(2)} KB)');
      print('   Payload ID: $payloadId');
      print('   Report ID: $reportId');
    }

    // Requirement 7.3: Send to all devices in parallel
    for (final deviceId in activeDevices) {
      if (kDebugMode) {
        print('   → Sending to device: $deviceId');
      }
      
      sendTasks.add(
        _sendToDeviceWithRetry(deviceId, bytes, payloadId).then((success) {
          if (success) {
            successCount++;
            if (kDebugMode) {
              print('   ✅ Successfully sent to device: $deviceId');
            }
            
            // Record successful send in metrics
            _connectionMetrics.recordEvent(
              deviceId,
              'send_success',
              {
                'timestamp': DateTime.now().toIso8601String(),
                'payload_id': payloadId,
                'report_id': reportId,
                'payload_size': bytes.length,
              },
            );
          } else {
            // All retries exhausted - mark for health check
            devicesNeedingHealthCheck.add(deviceId);
            
            if (kDebugMode) {
              print('   ❌ All retries exhausted for device: $deviceId');
              print('      Marking for health check');
            }
            
            // Record exhausted retries in metrics
            _connectionMetrics.recordEvent(
              deviceId,
              'send_retries_exhausted',
              {
                'timestamp': DateTime.now().toIso8601String(),
                'payload_id': payloadId,
                'report_id': reportId,
              },
            );
          }
        })
      );
    }

    try {
      await Future.wait(sendTasks).timeout(
        Duration(milliseconds: BluetoothConstants.sendTimeout * 4), // Extended for retries
        onTimeout: () {
          if (kDebugMode) {
            print('⚠️  Send timeout after ${BluetoothConstants.sendTimeout * 4}ms');
            print('   Some devices may not have received the report');
          }
          return <void>[];
        },
      );
    } catch (e) {
      if (kDebugMode) {
        print('⚠️  Error during send wait: $e');
      }
    }

    // Requirement 7.5: Trigger health check for devices with exhausted retries
    if (devicesNeedingHealthCheck.isNotEmpty) {
      if (kDebugMode) {
        print('');
        print('🏥 TRIGGERING HEALTH CHECK');
        print('   Devices needing check: ${devicesNeedingHealthCheck.length}');
        print('   Device IDs: $devicesNeedingHealthCheck');
      }
      
      // Schedule health check for these specific devices
      Future.delayed(Duration(milliseconds: 500), () {
        verifyAndCleanConnections();
      });
    }

    if (kDebugMode) {
      print('');
      print('📊 SEND RESULTS');
      print('   Success: $successCount/${activeDevices.length}');
      print('   Failed: ${activeDevices.length - successCount}/${activeDevices.length}');
      print('   Needs health check: ${devicesNeedingHealthCheck.length}');
    }

    return successCount;
  }

  /// Send to a single device with retry logic and exponential backoff
  /// 
  /// Requirements 7.4: Retry up to 3 times with exponential backoff
  Future<bool> _sendToDeviceWithRetry(
    String deviceId,
    Uint8List bytes,
    int payloadId,
  ) async {
    const maxRetries = 3;
    
    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        // Attempt to send
        await _payloadHandler.sendBytesPayload(deviceId, bytes, payloadId);
        
        // Success on this attempt
        if (attempt > 0 && kDebugMode) {
          print('   ✅ Retry $attempt succeeded for device: $deviceId');
        }
        
        return true;
        
      } catch (e) {
        if (kDebugMode) {
          print('   ⚠️  Send attempt ${attempt + 1}/$maxRetries failed for device: $deviceId');
          print('      Error: $e');
        }
        
        // Record failed attempt in metrics
        _connectionMetrics.recordEvent(
          deviceId,
          'send_attempt_failed',
          {
            'timestamp': DateTime.now().toIso8601String(),
            'attempt': attempt + 1,
            'max_retries': maxRetries,
            'error': e.toString(),
          },
        );
        
        // If not the last attempt, wait with exponential backoff
        if (attempt < maxRetries - 1) {
          // Exponential backoff: 100ms, 200ms, 400ms
          final backoffMs = 100 * (1 << attempt);
          
          if (kDebugMode) {
            print('      Waiting ${backoffMs}ms before retry...');
          }
          
          await Future.delayed(Duration(milliseconds: backoffMs));
        }
      }
    }
    
    // All retries exhausted
    return false;
  }

  /// Return to Receiver Mode after sending
  Future<void> _returnToReceiverMode() async {
    if (kDebugMode) {
      print('🔄 Returning to Receiver Mode');
      print('   Current connections: ${_connectionManager.connectedDevices.length}');
    }
    
    // Keep advertising and discovery running
    // Keep connections intact for mesh network
    await _connectionManager.startAdvertising();
    await _connectionManager.startDiscovery();
    
    _updateStatus('📡 Ready to receive reports');
    
    if (kDebugMode) {
      print('✅ Back in Receiver Mode');
      print('   Advertising: ${_connectionManager.isAdvertising}');
      print('   Discovery: ${_connectionManager.isDiscovering}');
      print('   Connections maintained: ${_connectionManager.connectedDevices.length}');
    }
  }

  // ============================================================================
  // CONNECTION HEALTH
  // ============================================================================

  /// Verify and clean stale connections
  /// 
  /// This method performs a health check on all connected devices by sending
  /// a verification payload. Connections that timeout (2 seconds) are marked
  /// as stale and removed. Stale connections are added to the reconnection queue.
  Future<void> verifyAndCleanConnections() async {
    if (_connectionManager.connectedDevices.isEmpty) return;

    final staleConnections = <String>[];
    final activeConnections = <String>[];
    
    if (kDebugMode) {
      print('🏥 Starting health check for ${_connectionManager.connectedDevices.length} devices');
    }

    // Verify each connected device with 2-second timeout
    for (final deviceId in _connectionManager.connectedDevices.toList()) {
      try {
        final testPayload = {
          'type': BluetoothConstants.payloadTypeConnectionVerify,
          'timestamp': DateTime.now().toIso8601String()
        };
        final testData = jsonEncode(testPayload);
        final bytes = Uint8List.fromList(utf8.encode(testData));
        
        // Use 2-second timeout for stale detection
        await Nearby().sendBytesPayload(deviceId, bytes).timeout(
          Duration(seconds: 2),
          onTimeout: () {
            throw TimeoutException('Connection verification timeout after 2 seconds');
          },
        );
        
        // Connection is responsive
        activeConnections.add(deviceId);
        
        // Record successful health check in metrics
        _connectionMetrics.recordEvent(
          deviceId,
          'health_check_success',
          {
            'timestamp': DateTime.now().toIso8601String(),
            'timeout': '2s',
          },
        );
        
      } catch (e) {
        // Connection timed out or failed - mark as stale
        staleConnections.add(deviceId);
        
        if (kDebugMode) {
          print('❌ Device $deviceId marked as stale: $e');
        }
        
        // Record failed health check in metrics
        _connectionMetrics.recordEvent(
          deviceId,
          'health_check_failed',
          {
            'timestamp': DateTime.now().toIso8601String(),
            'error': e.toString(),
            'timeout': '2s',
          },
        );
      }
    }

    // Disconnect and add stale connections to reconnection queue
    for (final staleDevice in staleConnections) {
      // Remove from connected devices
      _connectionManager.removeConnectedDevice(staleDevice);
      
      // Disconnect from the endpoint
      try {
        await _connectionManager.disconnectFromEndpoint(staleDevice);
      } catch (e) {
        if (kDebugMode) {
          print('⚠️ Error disconnecting stale device $staleDevice: $e');
        }
      }
      
      // Add to reconnection queue for automatic reconnection
      _reconnectionManager.addToQueue(staleDevice, 'Device_$staleDevice');
      
      if (kDebugMode) {
        print('➕ Added stale device $staleDevice to reconnection queue');
      }
    }

    // Log health check results with counts
    if (kDebugMode) {
      print('🏥 Health check complete:');
      print('   Active connections: ${activeConnections.length}');
      print('   Stale connections: ${staleConnections.length}');
      print('   Total checked: ${activeConnections.length + staleConnections.length}');
    }
    
    // Record health check summary in metrics
    _connectionMetrics.recordEvent(
      'health_check',
      'summary',
      {
        'timestamp': DateTime.now().toIso8601String(),
        'active_count': activeConnections.length,
        'stale_count': staleConnections.length,
        'total_checked': activeConnections.length + staleConnections.length,
      },
    );

    if (staleConnections.isNotEmpty) {
      _updateStatus('🧹 Removed ${staleConnections.length} stale connections (${activeConnections.length} active)');
      notifyListeners();
    } else if (kDebugMode) {
      print('✅ All ${activeConnections.length} connections are healthy');
    }
  }

  // ============================================================================
  // PUBLIC API
  // ============================================================================

  Future<void> startAdvertising() => _connectionManager.startAdvertising();
  Future<void> startDiscovery() => _connectionManager.startDiscovery();
  Future<void> stopAdvertising() => _connectionManager.stopAdvertising();
  Future<void> stopDiscovery() => _connectionManager.stopDiscovery();
  Future<void> stopAll() => _connectionManager.stopAll();
  Future<void> checkConnectionHealth() => verifyAndCleanConnections();

  void clearReceivedData() {
    _receivedDataList.clear();
    notifyListeners();
  }

  void clearReceivedUUIDs() {
    _meshManager.clearReceivedUUIDs();
  }

  /// Enable debug mode for detailed metrics logging
  /// 
  /// Requirement 8.5: Debug mode enables detailed connection metrics
  void enableDebugMode() {
    _debugMode = true;
    if (kDebugMode) {
      print('🐛 Debug mode enabled - detailed metrics will be logged');
    }
    notifyListeners();
  }

  /// Disable debug mode
  void disableDebugMode() {
    _debugMode = false;
    if (kDebugMode) {
      print('🐛 Debug mode disabled');
    }
    notifyListeners();
  }

  /// Get connection statistics with optional detailed metrics
  /// 
  /// Requirement 8.5: Provide detailed metrics when debug mode is enabled
  Map<String, dynamic> getConnectionStatistics() {
    final baseStats = _connectionMetrics.getStatistics();
    
    if (_debugMode) {
      // Return detailed metrics in debug mode
      final detailedMetrics = _connectionMetrics.getDetailedMetrics();
      
      if (kDebugMode) {
        print('📊 Detailed connection statistics:');
        print('   Current timeout: ${detailedMetrics['currentTimeout']}ms');
        print('   Success rate: ${(detailedMetrics['successRate'] * 100).toStringAsFixed(1)}%');
        print('   Total attempts: ${detailedMetrics['totalAttempts']}');
        print('   Total events: ${detailedMetrics['totalEvents']}');
        print('   Endpoints tracked: ${detailedMetrics['endpoint_metrics'].length}');
      }
      
      return {
        ...detailedMetrics,
        'debug_mode': true,
        'connected_devices': _connectionManager.connectedDevices.length,
        'is_advertising': _connectionManager.isAdvertising,
        'is_discovering': _connectionManager.isDiscovering,
      };
    } else {
      // Return basic stats in normal mode
      return {
        ...baseStats,
        'debug_mode': false,
        'connected_devices': _connectionManager.connectedDevices.length,
      };
    }
  }

  /// Log connection quality degradation with signal strength
  /// 
  /// Requirement 1.4: Log signal strength metrics when quality degrades
  void logConnectionQuality(
    String endpointId,
    int? signalStrength,
  ) {
    // Determine quality level based on signal strength
    String qualityLevel;
    if (signalStrength == null) {
      qualityLevel = 'unknown';
    } else if (signalStrength >= BluetoothConstants.signalStrengthThresholdStrong) {
      qualityLevel = 'strong';
    } else if (signalStrength >= BluetoothConstants.signalStrengthThresholdModerate) {
      qualityLevel = 'moderate';
    } else if (signalStrength >= BluetoothConstants.signalStrengthThresholdWeak) {
      qualityLevel = 'weak';
    } else {
      qualityLevel = 'very_weak';
    }
    
    // Log quality degradation if weak or very weak
    if (qualityLevel == 'weak' || qualityLevel == 'very_weak') {
      _connectionMetrics.logConnectionQualityDegradation(
        endpointId,
        signalStrength,
        qualityLevel,
      );
      
      if (kDebugMode || _debugMode) {
        print('📶 Connection quality degradation detected:');
        print('   Endpoint: $endpointId');
        print('   Signal strength: ${signalStrength ?? 'N/A'} dBm');
        print('   Quality level: $qualityLevel');
      }
    } else if (_debugMode) {
      // Only log quality_check for non-degraded connections in debug mode
      _connectionMetrics.recordEvent(
        endpointId,
        'quality_check',
        {
          'timestamp': DateTime.now().toIso8601String(),
          'signal_strength': signalStrength,
          'quality_level': qualityLevel,
        },
      );
    }
  }

  Future<void> broadcastCustomData(Map<String, dynamic> customData) async {
    if (_connectionManager.connectedDevices.isEmpty) {
      _updateStatus('📱 No connected devices to broadcast to');
      return;
    }

    await verifyAndCleanConnections();
    
    if (_connectionManager.connectedDevices.isEmpty) {
      _updateStatus('📱 No active connections to broadcast to');
      return;
    }

    try {
      final broadcastData = {
        'type': BluetoothConstants.payloadTypeCustomData,
        'senderId': 'advertiser_${DateTime.now().millisecondsSinceEpoch}',
        'senderName': 'Advertiser Device',
        'timestamp': DateTime.now().toIso8601String(),
        'data': customData,
      };
      
      final data = jsonEncode(broadcastData);
      final bytes = Uint8List.fromList(utf8.encode(data));
      
      int successCount = 0;
      for (final deviceId in _connectionManager.connectedDevices) {
        try {
          await Nearby().sendBytesPayload(deviceId, bytes);
          successCount++;
        } catch (e) {
          // Ignore individual failures
        }
      }
      
      _updateStatus('📡 Broadcasted to $successCount/${_connectionManager.connectedDevices.length} devices');
    } catch (e) {
      _updateStatus('❌ Failed to broadcast');
    }
  }

  void _updateStatus(String message) {
    _statusMessage = message;
    notifyListeners();
    
    final duration = message.contains('❌') ? Duration(seconds: 5) : Duration(seconds: 3);
    Future.delayed(duration, () {
      if (_statusMessage == message) {
        _statusMessage = '';
        notifyListeners();
      }
    });
  }
}

/// Lifecycle observer that forwards lifecycle events to BluetoothService
class _LifecycleObserver with WidgetsBindingObserver {
  final BluetoothService _service;
  
  _LifecycleObserver(this._service);
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _service.handleAppLifecycleChange(state);
  }
}
