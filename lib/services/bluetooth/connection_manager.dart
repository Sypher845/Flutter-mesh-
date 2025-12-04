import 'package:flutter/foundation.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'dart:async';

import 'models/bluetooth_constants.dart';
import 'permission_manager.dart';

/// Manages Bluetooth connections, advertising, and discovery
class ConnectionManager {
  final PermissionManager _permissionManager = PermissionManager();
  
  bool _isAdvertising = false;
  bool _isDiscovering = false;
  final Set<String> _connectedDevices = {};
  
  bool get isAdvertising => _isAdvertising;
  bool get isDiscovering => _isDiscovering;
  Set<String> get connectedDevices => Set.unmodifiable(_connectedDevices);
  
  // Callbacks
  Function(String message)? onStatusUpdate;
  Function(String endpointId, ConnectionInfo info)? onConnectionInitiated;
  Function(String endpointId, Status status)? onConnectionResult;
  Function(String endpointId)? onDisconnected;
  Function(String endpointId, String name, String serviceId)? onEndpointFound;
  Function(String? endpointId)? onEndpointLost;

  /// Start advertising to make device visible to others
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
      await Nearby().startAdvertising(
        BluetoothConstants.deviceName,
        Strategy.P2P_CLUSTER,
        onConnectionInitiated: _handleConnectionInitiated,
        onConnectionResult: _handleConnectionResult,
        onDisconnected: _handleDisconnected,
        serviceId: BluetoothConstants.serviceId,
      );
      
      _isAdvertising = true;
      _updateStatus('📡 Started advertising');
      return true;
    } catch (e) {
      if (e.toString().contains('STATUS_ALREADY_ADVERTISING') || 
          e.toString().contains('8001')) {
        _updateStatus('Advertising is already running');
        _isAdvertising = true;
        return true;
      } else {
        _updateStatus('Failed to start advertising');
        return false;
      }
    }
  }

  /// Start discovery to find nearby devices
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
      await Nearby().startDiscovery(
        BluetoothConstants.deviceName,
        Strategy.P2P_CLUSTER,
        onEndpointFound: _handleEndpointFound,
        onEndpointLost: _handleEndpointLost,
        serviceId: BluetoothConstants.serviceId,
      );
      
      _isDiscovering = true;
      _updateStatus('🔍 Scanning for nearby devices...');
      return true;
    } catch (e) {
      if (e.toString().contains('STATUS_ALREADY_DISCOVERING') || 
          e.toString().contains('8002')) {
        _updateStatus('Discovery is already running');
        _isDiscovering = true;
        return true;
      } else {
        _updateStatus('Failed to start discovery');
        return false;
      }
    }
  }

  /// Stop advertising
  Future<void> stopAdvertising() async {
    if (!_isAdvertising) return;
    
    try {
      await Nearby().stopAdvertising();
      _isAdvertising = false;
      _updateStatus('Stopped advertising');
    } catch (e) {
      if (kDebugMode) {
        print('Error stopping advertising: $e');
      }
    }
  }

  /// Stop discovery
  Future<void> stopDiscovery() async {
    if (!_isDiscovering) return;
    
    try {
      await Nearby().stopDiscovery();
      _isDiscovering = false;
      _updateStatus('Stopped device discovery');
    } catch (e) {
      if (kDebugMode) {
        print('Error stopping discovery: $e');
      }
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
      await Nearby().requestConnection(
        BluetoothConstants.deviceName,
        endpointId,
        onConnectionInitiated: _handleConnectionInitiated,
        onConnectionResult: _handleConnectionResult,
        onDisconnected: _handleDisconnected,
      );
    } catch (e) {
      _updateStatus('❌ Failed to connect to device');
      if (kDebugMode) {
        print('Error requesting connection: $e');
      }
    }
  }

  /// Accept a connection and register payload callback
  Future<void> acceptConnection(
    String endpointId,
    Function(String, Payload) onPayloadReceived,
  ) async {
    try {
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
      
      if (kDebugMode) {
        print('✅ Payload callback registered for: $endpointId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to accept connection: $e');
      }
    }
  }

  /// Disconnect from a specific endpoint
  Future<void> disconnectFromEndpoint(String endpointId) async {
    try {
      await Nearby().disconnectFromEndpoint(endpointId);
      _connectedDevices.remove(endpointId);
      if (kDebugMode) {
        print('✅ Disconnected from: $endpointId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Failed to disconnect from: $endpointId');
      }
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
      
      if (kDebugMode) {
        print('   ✅ Connection successful!');
        print('   Total connected devices: ${_connectedDevices.length}');
      }
    } else {
      _updateStatus('❌ Failed to connect to device');
      _connectedDevices.remove(endpointId);
      
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
    
    if (kDebugMode) {
      print('📱 Found device: $endpointName (ID: $endpointId)');
    }
    
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
