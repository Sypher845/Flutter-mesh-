import 'package:flutter/foundation.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:convert';
import 'dart:async';
import '../models/ticket_model.dart';

class BluetoothService extends ChangeNotifier {
  static const String _serviceId = 'com.yourapp.offlineSync';
  
  bool _isAdvertising = false;
  bool _isDiscovering = false;
  Set<String> _connectedDevices = {};
  
  bool get isAdvertising => _isAdvertising;
  bool get isDiscovering => _isDiscovering;
  Set<String> get connectedDevices => _connectedDevices;
  
  String _statusMessage = '';
  String get statusMessage => _statusMessage;

  Future<bool> _requestPermissions() async {
    print('🔍 BLUETOOTH DEBUG: Starting permission request...');
    
    // Core permissions needed for Bluetooth
    final corePermissions = [
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
      Permission.bluetoothAdvertise,
      Permission.location,
    ];

    print('🔍 BLUETOOTH DEBUG: Requesting core permissions: ${corePermissions.map((p) => p.toString()).join(', ')}');

    // Request core permissions
    Map<Permission, PermissionStatus> statuses = await corePermissions.request();
    
    print('🔍 BLUETOOTH DEBUG: Permission results:');
    statuses.forEach((permission, status) {
      print('  - ${permission.toString()}: ${status.toString()}');
    });
    
    // Check if core permissions are granted
    bool coreGranted = statuses.values.every((status) => 
      status == PermissionStatus.granted || status == PermissionStatus.limited);
    
    if (!coreGranted) {
      print('❌ BLUETOOTH DEBUG: Core Bluetooth permissions not granted: $statuses');
      return false;
    }

    // Try to request additional permissions (these might not be available on all devices)
    try {
      final nearbyStatus = await Permission.nearbyWifiDevices.request();
      print('🔍 BLUETOOTH DEBUG: nearbyWifiDevices permission: $nearbyStatus');
    } catch (e) {
      print('⚠️ BLUETOOTH DEBUG: nearbyWifiDevices permission not available: $e');
    }

    print('✅ BLUETOOTH DEBUG: All required permissions granted');
    return true;
  }

  Future<void> startAdvertising() async {
    print('📡 BLUETOOTH DEBUG: startAdvertising() called');
    
    if (_isAdvertising) {
      print('⚠️ BLUETOOTH DEBUG: Advertising already running, skipping');
      _updateStatus('Advertising is already running');
      return;
    }

    print('🔐 BLUETOOTH DEBUG: Checking permissions for advertising...');
    if (!await _requestPermissions()) {
      print('❌ BLUETOOTH DEBUG: Permissions denied for advertising');
      _updateStatus('❌ Bluetooth permissions denied. Check app settings.');
      await _showPermissionDetails();
      return;
    }

    try {
      print('🚀 BLUETOOTH DEBUG: Starting Nearby().startAdvertising()...');
      print('📡 BLUETOOTH DEBUG: Device name: OfflineSyncDevice');
      print('📡 BLUETOOTH DEBUG: Strategy: P2P_CLUSTER');
      print('📡 BLUETOOTH DEBUG: Service ID: $_serviceId');
      
      await Nearby().startAdvertising(
        'OfflineSyncDevice',
        Strategy.P2P_CLUSTER,
        onConnectionInitiated: _onConnectionInitiated,
        onConnectionResult: _onConnectionResult,
        onDisconnected: _onDisconnected,
        serviceId: _serviceId,
      );
      
      _isAdvertising = true;
      print('✅ BLUETOOTH DEBUG: Advertising started successfully');
      _updateStatus('📡 Started advertising as "OfflineSyncDevice"');
      notifyListeners();
    } catch (e) {
      print('❌ BLUETOOTH DEBUG: Advertising failed with error: $e');
      if (e.toString().contains('STATUS_ALREADY_ADVERTISING') || 
          e.toString().contains('8001')) {
        print('ℹ️ BLUETOOTH DEBUG: Already advertising (system state)');
        _updateStatus('Advertising is already running');
        _isAdvertising = true; // Update state to reflect reality
      } else {
        print('💥 BLUETOOTH DEBUG: Unexpected advertising error: $e');
        _updateStatus('Failed to start advertising: $e');
      }
      notifyListeners();
    }
  }

  Future<void> startDiscovery() async {
    print('🔍 BLUETOOTH DEBUG: startDiscovery() called');
    
    if (_isDiscovering) {
      print('⚠️ BLUETOOTH DEBUG: Discovery already running, skipping');
      _updateStatus('Discovery is already running');
      return;
    }

    print('🔐 BLUETOOTH DEBUG: Checking permissions for discovery...');
    if (!await _requestPermissions()) {
      print('❌ BLUETOOTH DEBUG: Permissions denied for discovery');
      _updateStatus('❌ Bluetooth permissions denied. Check app settings.');
      await _showPermissionDetails();
      return;
    }

    try {
      print('🚀 BLUETOOTH DEBUG: Starting Nearby().startDiscovery()...');
      print('🔍 BLUETOOTH DEBUG: Device name: OfflineSyncDevice');
      print('🔍 BLUETOOTH DEBUG: Strategy: P2P_CLUSTER');
      print('🔍 BLUETOOTH DEBUG: Service ID: $_serviceId');
      print('🔍 BLUETOOTH DEBUG: Callbacks registered: onEndpointFound, onEndpointLost');
      
      await Nearby().startDiscovery(
        'OfflineSyncDevice',
        Strategy.P2P_CLUSTER,
        onEndpointFound: _onEndpointFound,
        onEndpointLost: _onEndpointLost,
        serviceId: _serviceId,
      );
      
      _isDiscovering = true;
      print('✅ BLUETOOTH DEBUG: Discovery started successfully');
      print('👀 BLUETOOTH DEBUG: Now scanning for devices with service ID: $_serviceId');
      _updateStatus('🔍 Scanning for nearby devices...');
      notifyListeners();
      
      // Add a timer to log discovery status and provide helpful messages
      Timer.periodic(Duration(seconds: 15), (timer) {
        if (!_isDiscovering) {
          timer.cancel();
          return;
        }
        print('⏰ BLUETOOTH DEBUG: Discovery still running... Found ${_connectedDevices.length} devices so far');
        
        if (_connectedDevices.isEmpty) {
          print('💡 BLUETOOTH DEBUG: No devices found yet. Make sure another device is running this app and advertising!');
          _updateStatus('🔍 Still searching... Make sure other devices are advertising');
        }
      });
      
    } catch (e) {
      print('❌ BLUETOOTH DEBUG: Discovery failed with error: $e');
      if (e.toString().contains('STATUS_ALREADY_DISCOVERING') || 
          e.toString().contains('8002')) {
        print('ℹ️ BLUETOOTH DEBUG: Already discovering (system state)');
        _updateStatus('Discovery is already running');
        _isDiscovering = true; // Update state to reflect reality
      } else {
        print('💥 BLUETOOTH DEBUG: Unexpected discovery error: $e');
        _updateStatus('Failed to start discovery: $e');
      }
      notifyListeners();
    }
  }

  void _onEndpointFound(String endpointId, String endpointName, String serviceId) {
    print('🎉 BLUETOOTH DEBUG: ENDPOINT FOUND!');
    print('  - Endpoint ID: $endpointId');
    print('  - Endpoint Name: $endpointName');
    print('  - Service ID: $serviceId');
    print('  - Expected Service ID: $_serviceId');
    print('  - Service ID Match: ${serviceId == _serviceId}');
    
    _updateStatus('📱 Found device: $endpointName');
    
    if (serviceId == _serviceId) {
      print('✅ BLUETOOTH DEBUG: Service ID matches, requesting connection...');
      _requestConnection(endpointId);
    } else {
      print('⚠️ BLUETOOTH DEBUG: Service ID mismatch, ignoring device');
    }
  }

  void _onEndpointLost(String? endpointId) {
    print('📤 BLUETOOTH DEBUG: ENDPOINT LOST!');
    print('  - Endpoint ID: $endpointId');
    _updateStatus('📤 Lost device: $endpointId');
  }

  Future<void> _requestConnection(String endpointId) async {
    print('🤝 BLUETOOTH DEBUG: Requesting connection to endpoint: $endpointId');
    try {
      await Nearby().requestConnection(
        'OfflineSyncDevice',
        endpointId,
        onConnectionInitiated: _onConnectionInitiated,
        onConnectionResult: _onConnectionResult,
        onDisconnected: _onDisconnected,
      );
      print('✅ BLUETOOTH DEBUG: Connection request sent successfully');
    } catch (e) {
      print('❌ BLUETOOTH DEBUG: Failed to request connection: $e');
      _updateStatus('❌ Failed to connect to device');
    }
  }

  void _onConnectionInitiated(String endpointId, ConnectionInfo connectionInfo) {
    print('🔗 BLUETOOTH DEBUG: CONNECTION INITIATED!');
    print('  - Endpoint ID: $endpointId');
    print('  - Connection Info: ${connectionInfo.toString()}');
    print('  - Auth Token: ${connectionInfo.authenticationToken}');
    print('  - Endpoint Name: ${connectionInfo.endpointName}');
    print('  - Is Incoming: ${connectionInfo.isIncomingConnection}');
    
    _updateStatus('🔗 Connection initiated with ${connectionInfo.endpointName}');
    
    // Auto-accept all connections for simplicity
    print('✅ BLUETOOTH DEBUG: Auto-accepting connection...');
    Nearby().acceptConnection(
      endpointId,
      onPayLoadRecieved: _onPayloadReceived,
    );
  }

  void _onConnectionResult(String endpointId, Status status) {
    print('🔗 BLUETOOTH DEBUG: CONNECTION RESULT!');
    print('  - Endpoint ID: $endpointId');
    print('  - Status: ${status.toString()}');
    
    if (status == Status.CONNECTED) {
      _connectedDevices.add(endpointId);
      print('✅ BLUETOOTH DEBUG: Successfully connected to $endpointId');
      print('📊 BLUETOOTH DEBUG: Total connected devices: ${_connectedDevices.length}');
      _updateStatus('✅ Connected to device: $endpointId');
      notifyListeners();
    } else {
      print('❌ BLUETOOTH DEBUG: Connection failed to $endpointId with status: $status');
      _updateStatus('❌ Failed to connect to device: $endpointId');
    }
  }

  void _onDisconnected(String endpointId) {
    print('💔 BLUETOOTH DEBUG: DISCONNECTED!');
    print('  - Endpoint ID: $endpointId');
    
    _connectedDevices.remove(endpointId);
    print('📊 BLUETOOTH DEBUG: Remaining connected devices: ${_connectedDevices.length}');
    _updateStatus('💔 Disconnected from device: $endpointId');
    notifyListeners();
  }

  void _onPayloadReceived(String endpointId, Payload payload) {
    if (payload.type == PayloadType.BYTES) {
      try {
        final data = String.fromCharCodes(payload.bytes!);
        final ticketData = jsonDecode(data);
        
        // Handle received ticket data
        _handleReceivedTicket(ticketData);
        _updateStatus('Received data from device: $endpointId');
      } catch (e) {
        print('Error processing received payload: $e');
      }
    }
  }

  Future<void> sendTicketData(TicketModel ticket) async {
    if (_connectedDevices.isEmpty) {
      _updateStatus('📱 No connected devices to send data');
      print('BLUETOOTH DEBUG: No connected devices available');
      return;
    }

    try {
      final ticketJson = ticket.toJson();
      final data = jsonEncode(ticketJson);
      final bytes = Uint8List.fromList(data.codeUnits);
      
      print('BLUETOOTH DEBUG: Sending ticket data to ${_connectedDevices.length} devices');
      print('BLUETOOTH DEBUG: Data size: ${bytes.length} bytes');
      
      for (final deviceId in _connectedDevices) {
        await Nearby().sendBytesPayload(deviceId, bytes);
        print('BLUETOOTH DEBUG: Sent to device: $deviceId');
      }
      
      _updateStatus('📡 Data sent via Bluetooth hopping to ${_connectedDevices.length} devices');
    } catch (e) {
      _updateStatus('❌ Failed to send data via Bluetooth: $e');
      print('BLUETOOTH ERROR: $e');
    }
  }

  void _handleReceivedTicket(Map<String, dynamic> ticketData) {
    // This would typically forward the data to backend if internet is available
    // or continue the hopping process
    print('BLUETOOTH DEBUG: Received ticket data: $ticketData');
    _updateStatus('📥 Received data from another device!');
    
    // In a real implementation, you would:
    // 1. Check if this device has internet
    // 2. If yes, send to backend
    // 3. If no, continue hopping to other devices
  }

  Future<void> stopDiscovery() async {
    if (!_isDiscovering) return;
    
    try {
      await Nearby().stopDiscovery();
      _isDiscovering = false;
      _updateStatus('Stopped device discovery');
      notifyListeners();
    } catch (e) {
      print('Error stopping discovery: $e');
    }
  }

  Future<void> stopAdvertising() async {
    if (!_isAdvertising) return;
    
    try {
      await Nearby().stopAdvertising();
      _isAdvertising = false;
      _updateStatus('Stopped advertising');
      notifyListeners();
    } catch (e) {
      print('Error stopping advertising: $e');
    }
  }

  Future<void> stopAll() async {
    try {
      await Nearby().stopAdvertising();
      await Nearby().stopDiscovery();
      await Nearby().stopAllEndpoints();
      
      _isAdvertising = false;
      _isDiscovering = false;
      _connectedDevices.clear();
      _updateStatus('Stopped all Bluetooth operations');
      notifyListeners();
    } catch (e) {
      print('Error stopping Bluetooth operations: $e');
    }
  }

  Future<void> _showPermissionDetails() async {
    final permissions = [
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
      Permission.bluetoothAdvertise,
      Permission.location,
    ];

    print('=== PERMISSION STATUS ===');
    for (final permission in permissions) {
      final status = await permission.status;
      print('${permission.toString()}: ${status.toString()}');
    }
    print('========================');
  }

  Future<void> checkBluetoothStatus() async {
    print('🔵 BLUETOOTH DEBUG: Checking Bluetooth system status...');
    
    try {
      // This is a simple check - in a real app you might want to use a Bluetooth plugin
      print('📱 BLUETOOTH DEBUG: Device platform: ${defaultTargetPlatform.toString()}');
      print('🔧 BLUETOOTH DEBUG: Service ID being used: $_serviceId');
      print('📊 BLUETOOTH DEBUG: Current state - Advertising: $_isAdvertising, Discovering: $_isDiscovering');
      print('🔗 BLUETOOTH DEBUG: Connected devices: ${_connectedDevices.length}');
      
      if (_connectedDevices.isNotEmpty) {
        print('📋 BLUETOOTH DEBUG: Connected device IDs:');
        for (final deviceId in _connectedDevices) {
          print('  - $deviceId');
        }
      }
      
      print('');
      print('🔍 IMPORTANT: Nearby Connections only finds devices running this SAME APP!');
      print('📱 To test: Install this app on another device and start advertising there');
      print('🚫 Regular Bluetooth devices (headphones, speakers, etc.) will NOT be found');
      print('✅ Only devices with this app running and advertising will appear');
      print('');
      
    } catch (e) {
      print('❌ BLUETOOTH DEBUG: Error checking Bluetooth status: $e');
    }
  }

  // Debug method to simulate device discovery (for testing on emulator)
  void simulateDeviceFound() {
    if (!kDebugMode) return;
    
    print('🧪 BLUETOOTH DEBUG: SIMULATING DEVICE FOUND (Debug Mode)');
    final fakeEndpointId = 'FAKE_DEVICE_${DateTime.now().millisecondsSinceEpoch}';
    final fakeEndpointName = 'TestDevice_${DateTime.now().second}';
    
    // Simulate finding a device
    _onEndpointFound(fakeEndpointId, fakeEndpointName, _serviceId);
    
    // Simulate successful connection after 2 seconds
    Timer(Duration(seconds: 2), () {
      print('🧪 BLUETOOTH DEBUG: SIMULATING CONNECTION SUCCESS');
      _onConnectionResult(fakeEndpointId, Status.CONNECTED);
      
      _updateStatus('🧪 Simulated device connected for testing');
    });
  }

  void _updateStatus(String message) {
    _statusMessage = message;
    notifyListeners();
    
    // Clear status after 5 seconds for error messages, 3 for others
    final duration = message.contains('❌') ? Duration(seconds: 5) : Duration(seconds: 3);
    Future.delayed(duration, () {
      if (_statusMessage == message) {
        _statusMessage = '';
        notifyListeners();
      }
    });
  }
}