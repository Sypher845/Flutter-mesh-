import 'package:flutter/foundation.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'dart:async';

import 'models/bluetooth_constants.dart';
import 'permission_manager.dart';
import 'connection_metrics.dart';

/// Manages Bluetooth connections, advertising, and discovery
class ConnectionManager {
  final PermissionManager _permissionManager = PermissionManager();
  final ConnectionMetrics? _connectionMetrics;
  
  bool _isAdvertising = false;
  bool _isDiscovering = false;
  final Set<String> _connectedDevices = {};
  
  // New fields for enhanced features
  int maxConnections = BluetoothConstants.maxConnections;
  DateTime? lastDiscoveryRestart;
  int consecutiveErrors = 0;
  
  bool get isAdvertising => _isAdvertising;
  bool get isDiscovering => _isDiscovering;
  Set<String> get connectedDevices => Set.unmodifiable(_connectedDevices);
  
  ConnectionManager({ConnectionMetrics? connectionMetrics})
      : _connectionMetrics = connectionMetrics;
  
  // Callbacks
  Function(String message)? onStatusUpdate;
  Function(String endpointId, ConnectionInfo info)? onConnectionInitiated;
  Function(String endpointId, Status status)? onConnectionResult;
  Function(String endpointId)? onDisconnected;
  Function(String endpointId, String name, String serviceId)? onEndpointFound;
  Function(String? endpointId)? onEndpointLost;

  /// Start advertising to make device visible to others
  /// 
  /// **Range Optimization (Requirement 1.1):**
  /// Uses Strategy.P2P_CLUSTER for maximum range:
  /// - Optimizes for distance over throughput
  /// - Supports up to 100m clear line of sight
  /// - Minimum 30m with obstacles
  /// - Better signal penetration than P2P_STAR or P2P_POINT_TO_POINT
  Future<bool> startAdvertising() async {
    if (_isAdvertising) {
      _updateStatus('Advertising is already running');
      return true;
    }

    if (!await _permissionManager.requestPermissions()) {
      _updateStatus('❌ Bluetooth permissions denied. Check app settings.');
      return false;
    }

    try {
      if (kDebugMode) {
        print('📡 Starting advertising...');
        print('   Strategy: P2P_CLUSTER (optimized for range)');
      }
      
      // Requirement 1.1: Use P2P_CLUSTER strategy for maximum range
      await Nearby().startAdvertising(
        BluetoothConstants.deviceName,
        Strategy.P2P_CLUSTER,
        onConnectionInitiated: _handleConnectionInitiated,
        onConnectionResult: _handleConnectionResult,
        onDisconnected: _handleDisconnected,
        serviceId: BluetoothConstants.serviceId,
      );
      
      _isAdvertising = true;
      resetErrorCount();
      _updateStatus('📡 Started advertising');
      
      // Requirement 6.5 & 8.2: Log successful operation
      _connectionMetrics?.recordEvent(
        'advertising',
        'start_success',
        {
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
      
      if (kDebugMode) {
        print('✅ Advertising started successfully');
      }
      
      return true;
    } catch (e) {
      // Requirement 6.5 & 8.2: Log the error with details
      if (kDebugMode) {
        print('❌ Error starting advertising: $e');
        print('   Error type: ${e.runtimeType}');
      }
      
      // Requirement 10.1: Handle STATUS_ALREADY_ADVERTISING as success
      if (e.toString().contains('STATUS_ALREADY_ADVERTISING') || 
          e.toString().contains('8001')) {
        if (kDebugMode) {
          print('ℹ️ STATUS_ALREADY_ADVERTISING - treating as success');
          print('   Recovery action: Treating as success');
        }
        _updateStatus('Advertising is already running');
        _isAdvertising = true;
        resetErrorCount();
        
        // Requirement 6.5: Log recovery success
        _connectionMetrics?.recordEvent(
          'advertising',
          'already_running_recovery',
          {
            'timestamp': DateTime.now().toIso8601String(),
            'error': e.toString(),
            'recovery_action': 'treated_as_success',
          },
        );
        
        return true;
      } else {
        // Requirement 10.3: Handle unexpected errors with retry logic
        if (kDebugMode) {
          print('❌ Unexpected error starting advertising: $e');
          print('   Consecutive errors: $consecutiveErrors');
          print('   Recovery action: Increment error count, retry recommended');
        }
        _updateStatus('Failed to start advertising');
        incrementErrorCount();
        
        // Requirement 6.5 & 8.2: Record error in metrics with full details
        _connectionMetrics?.recordEvent(
          'advertising',
          'start_error',
          {
            'timestamp': DateTime.now().toIso8601String(),
            'error': e.toString(),
            'error_type': e.runtimeType.toString(),
            'consecutive_errors': consecutiveErrors,
            'recovery_action': 'increment_error_count',
          },
        );
        
        return false;
      }
    }
  }

  /// Start discovery to find nearby devices
  /// 
  /// **Range Optimization (Requirement 1.1):**
  /// Uses Strategy.P2P_CLUSTER for maximum range:
  /// - Scans for devices at extended distances
  /// - Better detection of weak signals
  /// - Optimized for mesh network formation
  Future<bool> startDiscovery() async {
    if (_isDiscovering) {
      _updateStatus('Discovery is already running');
      return true;
    }

    if (!await _permissionManager.requestPermissions()) {
      _updateStatus('❌ Bluetooth permissions denied. Check app settings.');
      return false;
    }

    try {
      if (kDebugMode) {
        print('🔍 Starting discovery...');
        print('   Strategy: P2P_CLUSTER (optimized for range)');
      }
      
      // Requirement 1.1: Use P2P_CLUSTER strategy for maximum range
      await Nearby().startDiscovery(
        BluetoothConstants.deviceName,
        Strategy.P2P_CLUSTER,
        onEndpointFound: _handleEndpointFound,
        onEndpointLost: _handleEndpointLost,
        serviceId: BluetoothConstants.serviceId,
      );
      
      _isDiscovering = true;
      resetErrorCount();
      _updateStatus('🔍 Scanning for nearby devices...');
      
      // Requirement 6.5 & 8.2: Log successful operation
      _connectionMetrics?.recordEvent(
        'discovery',
        'start_success',
        {
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
      
      if (kDebugMode) {
        print('✅ Discovery started successfully');
      }
      
      return true;
    } catch (e) {
      // Requirement 6.5 & 8.2: Log the error with details
      if (kDebugMode) {
        print('❌ Error starting discovery: $e');
        print('   Error type: ${e.runtimeType}');
      }
      
      // Requirement 10.2: Handle STATUS_ALREADY_DISCOVERING as success
      if (e.toString().contains('STATUS_ALREADY_DISCOVERING') || 
          e.toString().contains('8002')) {
        if (kDebugMode) {
          print('ℹ️ STATUS_ALREADY_DISCOVERING - treating as success');
          print('   Recovery action: Treating as success');
        }
        _updateStatus('Discovery is already running');
        _isDiscovering = true;
        resetErrorCount();
        
        // Requirement 6.5: Log recovery success
        _connectionMetrics?.recordEvent(
          'discovery',
          'already_running_recovery',
          {
            'timestamp': DateTime.now().toIso8601String(),
            'error': e.toString(),
            'recovery_action': 'treated_as_success',
          },
        );
        
        return true;
      } else {
        // Requirement 10.3: Handle unexpected errors with retry logic
        if (kDebugMode) {
          print('❌ Unexpected error starting discovery: $e');
          print('   Consecutive errors: $consecutiveErrors');
          print('   Recovery action: Increment error count, retry recommended');
        }
        _updateStatus('Failed to start discovery');
        incrementErrorCount();
        
        // Requirement 6.5 & 8.2: Record error in metrics with full details
        _connectionMetrics?.recordEvent(
          'discovery',
          'start_error',
          {
            'timestamp': DateTime.now().toIso8601String(),
            'error': e.toString(),
            'error_type': e.runtimeType.toString(),
            'consecutive_errors': consecutiveErrors,
            'recovery_action': 'increment_error_count',
          },
        );
        
        return false;
      }
    }
  }

  /// Stop advertising
  Future<void> stopAdvertising() async {
    if (!_isAdvertising) return;
    
    try {
      if (kDebugMode) {
        print('🛑 Stopping advertising...');
      }
      
      await Nearby().stopAdvertising();
      _isAdvertising = false;
      _updateStatus('Stopped advertising');
      
      // Requirement 6.5 & 8.2: Log successful operation
      _connectionMetrics?.recordEvent(
        'advertising',
        'stop_success',
        {
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
      
      if (kDebugMode) {
        print('✅ Advertising stopped successfully');
      }
    } catch (e) {
      // Requirement 10.4 & 6.5 & 8.2: Handle stop operation errors with logging
      if (kDebugMode) {
        print('❌ Error stopping advertising: $e');
        print('   Error type: ${e.runtimeType}');
        print('   Recovery action: Update internal state');
      }
      
      // Update internal state even if stop fails
      _isAdvertising = false;
      
      // Requirement 6.5 & 8.2: Record error in metrics with recovery action
      _connectionMetrics?.recordEvent(
        'advertising',
        'stop_error',
        {
          'timestamp': DateTime.now().toIso8601String(),
          'error': e.toString(),
          'error_type': e.runtimeType.toString(),
          'recovery_action': 'updated_internal_state',
        },
      );
    }
  }

  /// Stop discovery
  Future<void> stopDiscovery() async {
    if (!_isDiscovering) return;
    
    try {
      if (kDebugMode) {
        print('🛑 Stopping discovery...');
      }
      
      await Nearby().stopDiscovery();
      _isDiscovering = false;
      _updateStatus('Stopped device discovery');
      
      // Requirement 6.5 & 8.2: Log successful operation
      _connectionMetrics?.recordEvent(
        'discovery',
        'stop_success',
        {
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
      
      if (kDebugMode) {
        print('✅ Discovery stopped successfully');
      }
    } catch (e) {
      // Requirement 10.4 & 6.5 & 8.2: Handle stop operation errors with logging
      if (kDebugMode) {
        print('❌ Error stopping discovery: $e');
        print('   Error type: ${e.runtimeType}');
        print('   Recovery action: Update internal state');
      }
      
      // Update internal state even if stop fails
      _isDiscovering = false;
      
      // Requirement 6.5 & 8.2: Record error in metrics with recovery action
      _connectionMetrics?.recordEvent(
        'discovery',
        'stop_error',
        {
          'timestamp': DateTime.now().toIso8601String(),
          'error': e.toString(),
          'error_type': e.runtimeType.toString(),
          'recovery_action': 'updated_internal_state',
        },
      );
    }
  }

  /// Stop all Bluetooth operations
  Future<void> stopAll() async {
    try {
      await Nearby().stopAdvertising();
      await Nearby().stopDiscovery();
      await Nearby().stopAllEndpoints();
      
      _isAdvertising = false;
      _isDiscovering = false;
      _connectedDevices.clear();
      _updateStatus('Stopped all Bluetooth operations');
    } catch (e) {
      if (kDebugMode) {
        print('Error stopping all: $e');
      }
    }
  }

  /// Request connection to a discovered endpoint
  Future<void> requestConnection(String endpointId) async {
    try {
      if (kDebugMode) {
        print('🔗 Requesting connection to: $endpointId');
      }
      
      await Nearby().requestConnection(
        BluetoothConstants.deviceName,
        endpointId,
        onConnectionInitiated: _handleConnectionInitiated,
        onConnectionResult: _handleConnectionResult,
        onDisconnected: _handleDisconnected,
      );
      resetErrorCount();
      
      // Requirement 6.5 & 8.2: Log successful connection request
      _connectionMetrics?.recordEvent(
        endpointId,
        'connection_request_success',
        {
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
      
      if (kDebugMode) {
        print('✅ Connection request sent successfully to: $endpointId');
      }
    } catch (e) {
      // Requirement 10.3 & 6.5 & 8.2: Handle unexpected errors with retry logic and logging
      _updateStatus('❌ Failed to connect to device');
      if (kDebugMode) {
        print('❌ Error requesting connection to $endpointId: $e');
        print('   Error type: ${e.runtimeType}');
        print('   Consecutive errors: $consecutiveErrors');
        print('   Recovery action: Increment error count, retry recommended');
      }
      
      incrementErrorCount();
      
      // Requirement 6.5 & 8.2: Record error in metrics with full details
      _connectionMetrics?.recordEvent(
        endpointId,
        'connection_request_error',
        {
          'timestamp': DateTime.now().toIso8601String(),
          'error': e.toString(),
          'error_type': e.runtimeType.toString(),
          'consecutive_errors': consecutiveErrors,
          'recovery_action': 'increment_error_count',
        },
      );
      
      // Requirement 10.5: Check if full reset is needed
      if (shouldPerformFullReset()) {
        if (kDebugMode) {
          print('⚠️ Consecutive error threshold reached - full reset needed');
        }
        
        // Log that full reset is recommended
        _connectionMetrics?.recordEvent(
          'system',
          'full_reset_recommended',
          {
            'timestamp': DateTime.now().toIso8601String(),
            'consecutive_errors': consecutiveErrors,
            'threshold': BluetoothConstants.fullResetErrorThreshold,
          },
        );
        
        // Note: Full reset will be triggered by the caller (BluetoothService)
      }
    }
  }

  /// Accept a connection and register payload callback
  Future<void> acceptConnection(
    String endpointId,
    Function(String, Payload) onPayloadReceived,
  ) async {
    try {
      if (kDebugMode) {
        print('✅ Accepting connection from: $endpointId');
      }
      
      await Nearby().acceptConnection(
        endpointId,
        onPayLoadRecieved: (String receivedEndpointId, Payload receivedPayload) {
          if (kDebugMode) {
            print('📨 Payload callback triggered!');
            print('   From endpoint: $receivedEndpointId');
            print('   Payload type: ${receivedPayload.type}');
            print('   Payload ID: ${receivedPayload.id}');
          }
          onPayloadReceived(receivedEndpointId, receivedPayload);
        },
      );
      
      // Requirement 6.5 & 8.2: Log successful connection acceptance
      _connectionMetrics?.recordEvent(
        endpointId,
        'connection_accept_success',
        {
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
      
      if (kDebugMode) {
        print('✅ Payload callback registered for: $endpointId');
      }
    } catch (e) {
      // Requirement 6.5 & 8.2: Log connection acceptance errors
      if (kDebugMode) {
        print('❌ Failed to accept connection: $e');
        print('   Error type: ${e.runtimeType}');
        print('   Endpoint: $endpointId');
      }
      
      _connectionMetrics?.recordEvent(
        endpointId,
        'connection_accept_error',
        {
          'timestamp': DateTime.now().toIso8601String(),
          'error': e.toString(),
          'error_type': e.runtimeType.toString(),
        },
      );
    }
  }

  /// Disconnect from a specific endpoint
  Future<void> disconnectFromEndpoint(String endpointId) async {
    try {
      if (kDebugMode) {
        print('🔌 Disconnecting from: $endpointId');
      }
      
      await Nearby().disconnectFromEndpoint(endpointId);
      _connectedDevices.remove(endpointId);
      
      // Requirement 6.5 & 8.2: Log successful disconnection
      _connectionMetrics?.recordEvent(
        endpointId,
        'disconnect_success',
        {
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
      
      if (kDebugMode) {
        print('✅ Disconnected from: $endpointId');
      }
    } catch (e) {
      // Requirement 6.5 & 8.2: Log disconnection errors
      if (kDebugMode) {
        print('⚠️ Failed to disconnect from: $endpointId');
        print('   Error: $e');
        print('   Error type: ${e.runtimeType}');
        print('   Recovery action: Remove from connected devices anyway');
      }
      
      // Remove from connected devices even if disconnect fails
      _connectedDevices.remove(endpointId);
      
      _connectionMetrics?.recordEvent(
        endpointId,
        'disconnect_error',
        {
          'timestamp': DateTime.now().toIso8601String(),
          'error': e.toString(),
          'error_type': e.runtimeType.toString(),
          'recovery_action': 'removed_from_connected_devices',
        },
      );
    }
  }

  /// Disconnect from all connected devices
  Future<void> disconnectAll() async {
    if (_connectedDevices.isEmpty) return;
    
    if (kDebugMode) {
      print('🔌 Disconnecting from ${_connectedDevices.length} devices');
    }
    
    final devicesToDisconnect = _connectedDevices.toList();
    
    for (final deviceId in devicesToDisconnect) {
      await disconnectFromEndpoint(deviceId);
    }
    
    _connectedDevices.clear();
  }

  /// Add a device to connected devices list
  void addConnectedDevice(String endpointId) {
    _connectedDevices.add(endpointId);
  }

  /// Remove a device from connected devices list
  void removeConnectedDevice(String endpointId) {
    _connectedDevices.remove(endpointId);
  }

  /// Check if a new connection can be accepted based on connection limit
  bool canAcceptNewConnection() {
    return _connectedDevices.length < maxConnections;
  }

  /// Increment the consecutive error counter
  void incrementErrorCount() {
    consecutiveErrors++;
  }

  /// Reset the consecutive error counter
  void resetErrorCount() {
    consecutiveErrors = 0;
  }

  /// Check if a full reset should be performed based on error count
  bool shouldPerformFullReset() {
    return consecutiveErrors >= BluetoothConstants.fullResetErrorThreshold;
  }

  /// Restart discovery to refresh scan while maintaining connections
  /// 
  /// Requirement 6.5 & 8.2: Log all errors and recovery attempts during restart
  Future<void> restartDiscovery() async {
    if (kDebugMode) {
      print('🔄 Restarting discovery to refresh scan');
      print('   Connected devices: ${_connectedDevices.length}');
    }
    
    // Requirement 6.5 & 8.2: Log the restart attempt
    _connectionMetrics?.recordEvent(
      'discovery',
      'restart_started',
      {
        'timestamp': DateTime.now().toIso8601String(),
        'connected_devices': _connectedDevices.length,
      },
    );

    // Stop discovery
    try {
      if (kDebugMode) {
        print('   Stopping discovery...');
      }
      await Nearby().stopDiscovery();
      _isDiscovering = false;
      
      if (kDebugMode) {
        print('   ✅ Discovery stopped');
      }
    } catch (e) {
      // Requirement 6.5 & 8.2: Log stop errors during restart
      if (kDebugMode) {
        print('⚠️ Error stopping discovery during restart: $e');
        print('   Error type: ${e.runtimeType}');
        print('   Recovery action: Increment error count');
      }
      incrementErrorCount();
      
      _connectionMetrics?.recordEvent(
        'discovery',
        'restart_stop_error',
        {
          'timestamp': DateTime.now().toIso8601String(),
          'error': e.toString(),
          'error_type': e.runtimeType.toString(),
          'consecutive_errors': consecutiveErrors,
        },
      );
    }

    // Small delay to ensure clean state
    await Future.delayed(const Duration(milliseconds: 500));

    // Start discovery again
    if (kDebugMode) {
      print('   Restarting discovery...');
    }
    
    final success = await startDiscovery();
    
    if (success) {
      lastDiscoveryRestart = DateTime.now();
      resetErrorCount();
      _updateStatus('🔄 Discovery restarted');
      
      // Requirement 6.5: Log successful recovery
      if (kDebugMode) {
        print('✅ Discovery restart completed successfully');
        print('   Connected devices maintained: ${_connectedDevices.length}');
      }
      
      _connectionMetrics?.recordEvent(
        'discovery',
        'restart_success',
        {
          'timestamp': DateTime.now().toIso8601String(),
          'connected_devices': _connectedDevices.length,
          'recovery_action': 'reset_error_count',
        },
      );
    } else {
      incrementErrorCount();
      _updateStatus('⚠️ Failed to restart discovery');
      
      // Requirement 6.5 & 8.2: Log restart failure
      if (kDebugMode) {
        print('❌ Discovery restart failed');
        print('   Consecutive errors: $consecutiveErrors');
      }
      
      _connectionMetrics?.recordEvent(
        'discovery',
        'restart_failed',
        {
          'timestamp': DateTime.now().toIso8601String(),
          'consecutive_errors': consecutiveErrors,
          'recovery_action': 'increment_error_count',
        },
      );
    }
  }

  /// Perform a full reset of advertising and discovery
  /// 
  /// Requirement 6.5 & 8.2: Log all errors and recovery attempts during reset
  Future<void> performFullReset() async {
    if (kDebugMode) {
      print('🔄 Performing full reset of Bluetooth operations');
      print('   Consecutive errors: $consecutiveErrors');
      print('   Connected devices: ${_connectedDevices.length}');
    }

    _updateStatus('🔄 Resetting Bluetooth operations...');
    
    // Requirement 6.5 & 8.2: Log the reset attempt
    _connectionMetrics?.recordEvent(
      'system',
      'full_reset_started',
      {
        'timestamp': DateTime.now().toIso8601String(),
        'consecutive_errors': consecutiveErrors,
        'connected_devices': _connectedDevices.length,
      },
    );

    // Stop all operations
    try {
      if (kDebugMode) {
        print('   Stopping advertising...');
      }
      await Nearby().stopAdvertising();
      _isAdvertising = false;
      
      if (kDebugMode) {
        print('   ✅ Advertising stopped');
      }
    } catch (e) {
      // Requirement 6.5 & 8.2: Log stop errors during reset
      if (kDebugMode) {
        print('⚠️ Error stopping advertising during reset: $e');
        print('   Error type: ${e.runtimeType}');
      }
      
      _connectionMetrics?.recordEvent(
        'system',
        'reset_stop_advertising_error',
        {
          'timestamp': DateTime.now().toIso8601String(),
          'error': e.toString(),
          'error_type': e.runtimeType.toString(),
        },
      );
    }

    try {
      if (kDebugMode) {
        print('   Stopping discovery...');
      }
      await Nearby().stopDiscovery();
      _isDiscovering = false;
      
      if (kDebugMode) {
        print('   ✅ Discovery stopped');
      }
    } catch (e) {
      // Requirement 6.5 & 8.2: Log stop errors during reset
      if (kDebugMode) {
        print('⚠️ Error stopping discovery during reset: $e');
        print('   Error type: ${e.runtimeType}');
      }
      
      _connectionMetrics?.recordEvent(
        'system',
        'reset_stop_discovery_error',
        {
          'timestamp': DateTime.now().toIso8601String(),
          'error': e.toString(),
          'error_type': e.runtimeType.toString(),
        },
      );
    }

    // Small delay to ensure clean state
    if (kDebugMode) {
      print('   Waiting 1 second for clean state...');
    }
    await Future.delayed(const Duration(milliseconds: 1000));

    // Restart operations
    if (kDebugMode) {
      print('   Restarting operations...');
    }
    
    final advertisingSuccess = await startAdvertising();
    final discoverySuccess = await startDiscovery();

    if (advertisingSuccess && discoverySuccess) {
      consecutiveErrors = 0;
      _updateStatus('✅ Bluetooth operations reset successfully');
      
      // Requirement 6.5: Log successful recovery
      if (kDebugMode) {
        print('✅ Full reset completed successfully');
        print('   Advertising: $advertisingSuccess');
        print('   Discovery: $discoverySuccess');
        print('   Consecutive errors reset to: $consecutiveErrors');
      }
      
      _connectionMetrics?.recordEvent(
        'system',
        'full_reset_success',
        {
          'timestamp': DateTime.now().toIso8601String(),
          'advertising_success': advertisingSuccess,
          'discovery_success': discoverySuccess,
          'recovery_action': 'reset_error_count',
        },
      );
    } else {
      _updateStatus('⚠️ Partial reset - some operations failed');
      
      // Requirement 6.5 & 8.2: Log partial recovery
      if (kDebugMode) {
        print('⚠️ Full reset partially failed');
        print('   Advertising: $advertisingSuccess');
        print('   Discovery: $discoverySuccess');
      }
      
      _connectionMetrics?.recordEvent(
        'system',
        'full_reset_partial',
        {
          'timestamp': DateTime.now().toIso8601String(),
          'advertising_success': advertisingSuccess,
          'discovery_success': discoverySuccess,
          'recovery_action': 'partial_recovery',
        },
      );
    }
  }

  // Internal callback handlers
  void _handleConnectionInitiated(String endpointId, ConnectionInfo connectionInfo) {
    if (kDebugMode) {
      print('🔗 _onConnectionInitiated called for endpoint: $endpointId');
      print('   Device name: ${connectionInfo.endpointName}');
      print('   Is incoming: ${connectionInfo.isIncomingConnection}');
    }
    
    _updateStatus('🔗 Connection initiated with ${connectionInfo.endpointName}');
    onConnectionInitiated?.call(endpointId, connectionInfo);
  }

  void _handleConnectionResult(String endpointId, Status status) {
    if (kDebugMode) {
      print('🔗 _onConnectionResult called');
      print('   Endpoint: $endpointId');
      print('   Status: $status');
    }
    
    if (status == Status.CONNECTED) {
      _connectedDevices.add(endpointId);
      _updateStatus('✅ Connected to device');
      
      // Record successful connection attempt
      _connectionMetrics?.recordAttempt(endpointId, true);
      _connectionMetrics?.updateTimeout();
      resetErrorCount();
      
      if (kDebugMode) {
        print('   ✅ Connection successful!');
        print('   Total connected devices: ${_connectedDevices.length}');
      }
    } else {
      _updateStatus('❌ Failed to connect to device');
      _connectedDevices.remove(endpointId);
      
      // Record failed connection attempt
      _connectionMetrics?.recordAttempt(endpointId, false, error: 'Status: $status');
      _connectionMetrics?.updateTimeout();
      incrementErrorCount();
      
      if (kDebugMode) {
        print('   ❌ Connection failed with status: $status');
      }
    }
    
    onConnectionResult?.call(endpointId, status);
  }

  void _handleDisconnected(String endpointId) {
    _connectedDevices.remove(endpointId);
    _updateStatus('💔 Disconnected from device');
    
    if (kDebugMode) {
      print('💔 Disconnected from: $endpointId');
    }
    
    onDisconnected?.call(endpointId);
  }

  void _handleEndpointFound(String endpointId, String endpointName, String serviceId) {
    _updateStatus('📱 Found device: $endpointName');
    
    // Requirement 8.4: Log endpoint name and service ID when discovery finds a device
    if (kDebugMode) {
      print('📱 Found device: $endpointName (ID: $endpointId)');
      print('   Service ID: $serviceId');
    }
    
    // Log discovery event with endpoint details
    _connectionMetrics?.recordEvent(
      endpointId,
      'discovered',
      {
        'timestamp': DateTime.now().toIso8601String(),
        'endpoint_name': endpointName,
        'service_id': serviceId,
      },
    );
    
    // Validate service ID and log result
    final isValidServiceId = serviceId == BluetoothConstants.serviceId;
    if (kDebugMode) {
      if (isValidServiceId) {
        print('   ✅ Service ID matches - will attempt connection');
      } else {
        print('   ⚠️ Service ID mismatch - expected: ${BluetoothConstants.serviceId}, got: $serviceId');
      }
    }
    
    // Log service ID validation result
    _connectionMetrics?.recordEvent(
      endpointId,
      'service_id_validation',
      {
        'timestamp': DateTime.now().toIso8601String(),
        'service_id': serviceId,
        'expected_service_id': BluetoothConstants.serviceId,
        'is_valid': isValidServiceId,
      },
    );
    
    onEndpointFound?.call(endpointId, endpointName, serviceId);
  }

  void _handleEndpointLost(String? endpointId) {
    if (endpointId != null && _connectedDevices.contains(endpointId)) {
      _connectedDevices.remove(endpointId);
    }
    _updateStatus('📤 Lost device: $endpointId');
    
    if (kDebugMode) {
      print('📤 Lost device: $endpointId');
    }
    
    onEndpointLost?.call(endpointId);
  }

  void _updateStatus(String message) {
    onStatusUpdate?.call(message);
  }
}
