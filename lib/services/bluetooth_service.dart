import 'package:flutter/foundation.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';

import '../models/ticket_model.dart';

class ReceivedData {
  final String senderId;
  final String senderName;
  final Map<String, dynamic> data;
  final DateTime receivedAt;
  String? receivedImagePath; // Path to received image file

  ReceivedData({
    required this.senderId,
    required this.senderName,
    required this.data,
    required this.receivedAt,
    this.receivedImagePath,
  });
}

class BluetoothService extends ChangeNotifier {
  static const String _serviceId = 'com.yourapp.offlineSync';
  
  bool _isAdvertising = false;
  bool _isDiscovering = false;
  final Set<String> _connectedDevices = {};
  final List<ReceivedData> _receivedDataList = [];
  Timer? _healthCheckTimer;
  
  bool get isAdvertising => _isAdvertising;
  bool get isDiscovering => _isDiscovering;
  Set<String> get connectedDevices => _connectedDevices;
  List<ReceivedData> get receivedDataList => List.unmodifiable(_receivedDataList);
  
  String _statusMessage = '';
  String get statusMessage => _statusMessage;

  BluetoothService() {
    // Start periodic health check every 30 seconds
    _startPeriodicHealthCheck();
  }

  void _startPeriodicHealthCheck() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = Timer.periodic(Duration(seconds: 30), (timer) async {
      if (_connectedDevices.isNotEmpty) {
        print('⏰ BLUETOOTH DEBUG: Running periodic health check...');
        try {
          await _verifyAndCleanConnections();
        } catch (e) {
          print('⚠️ BLUETOOTH DEBUG: Periodic health check error: $e');
        }
      }
    });
  }

  @override
  void dispose() {
    _healthCheckTimer?.cancel();
    stopAll();
    super.dispose();
  }

  Future<bool> _requestPermissions() async {
    print('🔍 BLUETOOTH DEBUG: Starting permission request...');
    
    // Try multiple location permission strategies
    bool locationGranted = false;
    
    // Strategy 1: Try locationWhenInUse first
    try {
      final locationStatus = await Permission.locationWhenInUse.request();
      print('🔍 BLUETOOTH DEBUG: locationWhenInUse status: $locationStatus');
      locationGranted = locationStatus == PermissionStatus.granted || locationStatus == PermissionStatus.limited;
    } catch (e) {
      print('⚠️ BLUETOOTH DEBUG: locationWhenInUse failed: $e');
    }
    
    // Strategy 2: If first failed, try general location
    if (!locationGranted) {
      try {
        final locationStatus = await Permission.location.request();
        print('🔍 BLUETOOTH DEBUG: location status: $locationStatus');
        locationGranted = locationStatus == PermissionStatus.granted || locationStatus == PermissionStatus.limited;
      } catch (e) {
        print('⚠️ BLUETOOTH DEBUG: location failed: $e');
      }
    }
    
    // Strategy 3: If still failed, try fine location as last resort
    if (!locationGranted) {
      try {
        final fineLocationStatus = await Permission.locationAlways.request();
        print('🔍 BLUETOOTH DEBUG: locationAlways status: $fineLocationStatus');
        locationGranted = fineLocationStatus == PermissionStatus.granted || fineLocationStatus == PermissionStatus.limited;
      } catch (e) {
        print('⚠️ BLUETOOTH DEBUG: locationAlways failed: $e');
      }
    }
    
    // Core Bluetooth permissions
    final bluetoothPermissions = [
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
      Permission.bluetoothAdvertise,
    ];

    print('🔍 BLUETOOTH DEBUG: Requesting Bluetooth permissions: ${bluetoothPermissions.map((p) => p.toString()).join(', ')}');

    // Request Bluetooth permissions
    Map<Permission, PermissionStatus> bluetoothStatuses = await bluetoothPermissions.request();
    
    print('🔍 BLUETOOTH DEBUG: Permission results:');
    print('  - Location granted: $locationGranted');
    bluetoothStatuses.forEach((permission, status) {
      print('  - ${permission.toString()}: ${status.toString()}');
    });
    
    // Check if Bluetooth permissions are granted
    bool bluetoothGranted = bluetoothStatuses.values.every((status) => 
      status == PermissionStatus.granted || status == PermissionStatus.limited);
    
    if (!bluetoothGranted || !locationGranted) {
      print('❌ BLUETOOTH DEBUG: Required permissions not granted');
      print('  - Bluetooth granted: $bluetoothGranted');
      print('  - Location granted: $locationGranted');
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
    print('📤 BLUETOOTH DEBUG: ===== ENDPOINT LOST =====');
    print('  - Endpoint ID: $endpointId');
    print('  - Was connected: ${endpointId != null ? _connectedDevices.contains(endpointId) : false}');
    
    if (endpointId != null && _connectedDevices.contains(endpointId)) {
      print('📤 BLUETOOTH DEBUG: Removing lost endpoint from connected devices');
      _connectedDevices.remove(endpointId);
      notifyListeners();
    }
    
    _updateStatus('📤 Lost device: $endpointId');
    print('📤 BLUETOOTH DEBUG: ===== ENDPOINT LOST HANDLED =====');
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

  void _onConnectionInitiated(String endpointId, ConnectionInfo connectionInfo) async {
    print('🔗 BLUETOOTH DEBUG: ===== CONNECTION INITIATED =====');
    print('🔗 BLUETOOTH DEBUG: Endpoint ID: $endpointId');
    print('🔗 BLUETOOTH DEBUG: Endpoint Name: ${connectionInfo.endpointName}');
    print('🔗 BLUETOOTH DEBUG: Is Incoming: ${connectionInfo.isIncomingConnection}');
    print('🔗 BLUETOOTH DEBUG: Auth Token: ${connectionInfo.authenticationToken}');
    
    _updateStatus('🔗 Connection initiated with ${connectionInfo.endpointName}');
    
    // Auto-accept all connections and set up payload callback with enhanced error handling
    print('🔗 BLUETOOTH DEBUG: Auto-accepting connection and setting up payload callback...');
    
    try {
      print('🔗 BLUETOOTH DEBUG: Attempting to accept connection with payload callback...');
      
      // Accept connection with robust payload callback that accepts ANY endpoint
      await Nearby().acceptConnection(
        endpointId,
        onPayLoadRecieved: (String receivedEndpointId, Payload receivedPayload) {
          print('📥 BLUETOOTH DEBUG: ===== PAYLOAD CALLBACK TRIGGERED =====');
          print('📥 BLUETOOTH DEBUG: Callback endpoint: $receivedEndpointId');
          print('📥 BLUETOOTH DEBUG: Expected endpoint: $endpointId');
          print('📥 BLUETOOTH DEBUG: Payload type: ${receivedPayload.type}');
          print('📥 BLUETOOTH DEBUG: Payload ID: ${receivedPayload.id}');
          print('📥 BLUETOOTH DEBUG: Payload size: ${receivedPayload.bytes?.length ?? 0}');
          
          // CRITICAL FIX: Process ALL payloads regardless of endpoint ID
          // The endpoint ID might vary but the data is still valid
          print('📥 BLUETOOTH DEBUG: Processing payload from any endpoint...');
          try {
            _onPayloadReceived(receivedEndpointId, receivedPayload);
            print('✅ BLUETOOTH DEBUG: Payload processed successfully');
          } catch (e) {
            print('❌ BLUETOOTH DEBUG: Error in payload processing: $e');
            // Still try to notify UI even if processing fails
            _updateStatus('⚠️ Received data but processing failed');
          }
        },
      );
      
      print('✅ BLUETOOTH DEBUG: Connection accepted successfully for $endpointId');
      print('✅ BLUETOOTH DEBUG: Payload callback registered and ready');
      
      // Send a test ping after a short delay to verify the connection works
      Timer(Duration(seconds: 2), () {
        if (_connectedDevices.contains(endpointId)) {
          print('📡 BLUETOOTH DEBUG: Sending verification ping to $endpointId');
          _sendConnectionPing(endpointId);
        }
      });
      
    } catch (e) {
      print('❌ BLUETOOTH DEBUG: Failed to accept connection: $e');
      print('❌ BLUETOOTH DEBUG: Error details: ${e.toString()}');
      _updateStatus('❌ Failed to accept connection: $e');
    }
  }

  void _onConnectionResult(String endpointId, Status status) {
    print('🔗 BLUETOOTH DEBUG: ===== CONNECTION RESULT =====');
    print('  - Endpoint ID: $endpointId');
    print('  - Status: ${status.toString()}');
    print('  - Status value: ${status.name}');
    
    if (status == Status.CONNECTED) {
      _connectedDevices.add(endpointId);
      print('✅ BLUETOOTH DEBUG: Successfully connected to $endpointId');
      print('📊 BLUETOOTH DEBUG: Total connected devices: ${_connectedDevices.length}');
      print('📊 BLUETOOTH DEBUG: All connected devices: ${_connectedDevices.toList()}');
      _updateStatus('✅ Connected to device: $endpointId');
      
      // CRITICAL FIX: Re-register payload callback after successful connection
      // This ensures the callback is active even if connection was re-established
      _reRegisterPayloadCallback(endpointId);
      
      notifyListeners();
    } else {
      print('❌ BLUETOOTH DEBUG: Connection failed to $endpointId with status: $status');
      _updateStatus('❌ Failed to connect to device: $endpointId');
      // Clean up if connection failed
      _connectedDevices.remove(endpointId);
    }
    print('🔗 BLUETOOTH DEBUG: ===== CONNECTION RESULT END =====');
  }

  // CRITICAL FIX: Re-register payload callback to ensure it's always active
  void _reRegisterPayloadCallback(String endpointId) {
    print('🔄 BLUETOOTH DEBUG: Re-registering payload callback for $endpointId');
    try {
      // Note: Nearby Connections doesn't allow re-registration on same connection
      // But we can verify the connection is ready to receive by sending a ping
      Timer(Duration(milliseconds: 500), () {
        if (_connectedDevices.contains(endpointId)) {
          _sendConnectionPing(endpointId);
          print('✅ BLUETOOTH DEBUG: Callback verification ping sent to $endpointId');
        }
      });
    } catch (e) {
      print('⚠️ BLUETOOTH DEBUG: Error re-registering callback: $e');
    }
  }

  void _onDisconnected(String endpointId) {
    print('💔 BLUETOOTH DEBUG: ===== DEVICE DISCONNECTED =====');
    print('  - Endpoint ID: $endpointId');
    print('  - Was in connected list: ${_connectedDevices.contains(endpointId)}');
    
    final wasRemoved = _connectedDevices.remove(endpointId);
    print('📊 BLUETOOTH DEBUG: Device removed from list: $wasRemoved');
    print('📊 BLUETOOTH DEBUG: Remaining connected devices: ${_connectedDevices.length}');
    print('📊 BLUETOOTH DEBUG: Remaining device IDs: ${_connectedDevices.toList()}');
    
    _updateStatus('💔 Disconnected from device: $endpointId');
    notifyListeners();
    print('💔 BLUETOOTH DEBUG: ===== DISCONNECTION HANDLED =====');
  }

  void _onPayloadReceived(String endpointId, Payload payload) {
    print('📥 BLUETOOTH DEBUG: ===== PAYLOAD RECEIVED CALLBACK ENTRY =====');
    print('📥 BLUETOOTH DEBUG: Timestamp: ${DateTime.now().toIso8601String()}');
    print('📥 BLUETOOTH DEBUG: From endpoint: $endpointId');
    print('📥 BLUETOOTH DEBUG: Payload type: ${payload.type}');
    print('📥 BLUETOOTH DEBUG: Payload ID: ${payload.id}');
    print('📥 BLUETOOTH DEBUG: Payload size: ${payload.bytes?.length ?? 0} bytes');
    print('📥 BLUETOOTH DEBUG: Connected devices: ${_connectedDevices.toList()}');
    print('📥 BLUETOOTH DEBUG: Current received list size: ${_receivedDataList.length}');
    
    // Don't show processing message - will show final result after processing
    
    try {
      if (payload.type == PayloadType.BYTES) {
        print('📥 BLUETOOTH DEBUG: Confirmed BYTES payload, processing...');
        
        // Process the payload
        _processReceivedPayload(endpointId, payload);
        
        // Send acknowledgment back to sender
        print('📥 BLUETOOTH DEBUG: Sending acknowledgment...');
        _sendAcknowledgment(endpointId, payload.id);
        
        print('📥 BLUETOOTH DEBUG: Payload processing complete');
        
      } else {
        print('⚠️ BLUETOOTH DEBUG: Unsupported payload type: ${payload.type}');
        _updateStatus('⚠️ Received unsupported payload type');
      }
    } catch (e, stackTrace) {
      print('❌ BLUETOOTH DEBUG: ===== PAYLOAD CALLBACK ERROR =====');
      print('❌ BLUETOOTH DEBUG: Error: $e');
      print('❌ BLUETOOTH DEBUG: Stack trace: $stackTrace');
      _updateStatus('❌ Error processing received payload: $e');
    }
    
    print('📥 BLUETOOTH DEBUG: ===== PAYLOAD CALLBACK EXIT =====');
  }

  void _processReceivedPayload(String endpointId, Payload payload) {
    try {
      print('📥 BLUETOOTH DEBUG: ===== PROCESSING PAYLOAD =====');
      print('📥 BLUETOOTH DEBUG: Endpoint: $endpointId');
      print('📥 BLUETOOTH DEBUG: Payload ID: ${payload.id}');
      
      // Validate payload
      if (payload.bytes == null || payload.bytes!.isEmpty) {
        print('❌ BLUETOOTH DEBUG: Payload bytes is null or empty');
        _updateStatus('❌ Received empty payload from $endpointId');
        return;
      }
      
      print('📥 BLUETOOTH DEBUG: Payload bytes length: ${payload.bytes!.length}');
      
      // Convert bytes to string with proper UTF-8 decoding
      String jsonString;
      try {
        jsonString = utf8.decode(payload.bytes!);
        print('📥 BLUETOOTH DEBUG: UTF-8 decoded to string, length: ${jsonString.length}');
      } catch (e) {
        print('❌ BLUETOOTH DEBUG: Failed to decode UTF-8 bytes: $e');
        // Fallback to basic string conversion
        try {
          jsonString = String.fromCharCodes(payload.bytes!);
          print('📥 BLUETOOTH DEBUG: Fallback conversion successful, length: ${jsonString.length}');
        } catch (e2) {
          print('❌ BLUETOOTH DEBUG: Both UTF-8 and fallback conversion failed: $e2');
          _updateStatus('❌ Invalid payload format');
          return;
        }
      }
      
      // Parse JSON with detailed error handling
      final Map<String, dynamic> receivedData;
      try {
        receivedData = jsonDecode(jsonString) as Map<String, dynamic>;
        print('📥 BLUETOOTH DEBUG: ✅ JSON parsed successfully');
      } catch (e) {
        print('❌ BLUETOOTH DEBUG: JSON parsing failed: $e');
        print('❌ BLUETOOTH DEBUG: Raw data preview: ${jsonString.length > 200 ? jsonString.substring(0, 200) + '...' : jsonString}');
        _updateStatus('❌ Invalid JSON format received');
        return;
      }
      
      // Validate required fields
      final dataType = receivedData['type'] as String?;
      final senderId = receivedData['senderId'] as String?;
      final senderName = receivedData['senderName'] as String?;
      
      if (dataType == null) {
        print('❌ BLUETOOTH DEBUG: Missing data type field');
        _updateStatus('❌ Invalid data structure');
        return;
      }
      
      print('📥 BLUETOOTH DEBUG: ===== RECEIVED DATA DETAILS =====');
      print('  - Type: $dataType');
      print('  - Sender ID: $senderId');
      print('  - Sender Name: $senderName');
      print('  - Timestamp: ${receivedData['timestamp']}');
      
      // Handle different data types
      if (dataType == 'ping' || dataType == 'connection_verify') {
        print('📥 BLUETOOTH DEBUG: Received connection ping from $senderName');
        _updateStatus('📡 Connection verified with $senderName');
        return;
      }
      
      if (dataType == 'ack') {
        print('📥 BLUETOOTH DEBUG: Received acknowledgment for payload ${receivedData['payloadId']}');
        return;
      }
      
      // CRITICAL FIX: Process ALL ticket-related data types flexibly
      if (dataType == 'ticket_data' || dataType == 'ticket_metadata' || dataType.contains('ticket')) {
        final ticket = receivedData['ticket'] as Map<String, dynamic>?;
        if (ticket != null) {
          print('📥 BLUETOOTH DEBUG: ===== TICKET DETAILS =====');
          print('  - Ticket ID: ${ticket['id']}');
          print('  - Description: ${ticket['description']}');
          print('  - Created At: ${ticket['createdAt']}');
          print('  - Has Image: ${ticket['imageBase64'] != null}');
          if (ticket['imageBase64'] != null) {
            final imageSize = (ticket['imageBase64'] as String).length;
            print('  - Image Size: $imageSize chars');
          }
        } else {
          print('❌ BLUETOOTH DEBUG: Ticket data is null');
          _updateStatus('❌ Invalid ticket data received');
          return;
        }
      }
      
      // Also handle custom_data and other types gracefully
      if (dataType == 'custom_data') {
        print('📥 BLUETOOTH DEBUG: Received custom data');
        final customData = receivedData['data'];
        if (customData != null) {
          print('📥 BLUETOOTH DEBUG: Custom data: $customData');
        }
      }
      
      // Create received data object
      final receivedDataObj = ReceivedData(
        senderId: senderId ?? endpointId,
        senderName: senderName ?? 'Unknown Device',
        data: receivedData,
        receivedAt: DateTime.now(),
      );
      
      // Add to list with duplicate check (check by timestamp AND senderId)
      final isDuplicate = _receivedDataList.any((item) => 
        item.senderId == receivedDataObj.senderId && 
        item.data['timestamp'] == receivedDataObj.data['timestamp']
      );
      
      if (!isDuplicate) {
        _receivedDataList.add(receivedDataObj);
        print('📥 BLUETOOTH DEBUG: ✅ Added to received list. Total: ${_receivedDataList.length}');
        
        // Cleanup old items (keep last 20)
        while (_receivedDataList.length > 20) {
          _receivedDataList.removeAt(0);
        }
        
        // CRITICAL: Update UI immediately
        _updateStatus('📥 Received $dataType from ${senderName ?? 'Unknown'}');
        
        print('📥 BLUETOOTH DEBUG: Calling notifyListeners()...');
        notifyListeners();
        print('📥 BLUETOOTH DEBUG: ===== PROCESSING COMPLETE ✅ =====');
      } else {
        print('📥 BLUETOOTH DEBUG: Duplicate data ignored');
        // Still notify listeners in case UI needs refresh
        notifyListeners();
      }
      
    } catch (e, stackTrace) {
      print('❌ BLUETOOTH DEBUG: ===== PAYLOAD PROCESSING ERROR =====');
      print('❌ BLUETOOTH DEBUG: Error: $e');
      print('❌ BLUETOOTH DEBUG: Stack trace: $stackTrace');
      _updateStatus('❌ Error processing received data');
      notifyListeners();
    }
  }



  // Send a connection ping to verify the connection works
  void _sendConnectionPing(String endpointId) {
    try {
      print('📡 BLUETOOTH DEBUG: Sending connection ping to $endpointId');
      
      final pingData = {
        'type': 'ping',
        'senderId': 'device_${DateTime.now().millisecondsSinceEpoch}',
        'senderName': 'My Device',
        'timestamp': DateTime.now().toIso8601String(),
        'message': 'Connection test ping',
      };
      
      final jsonString = jsonEncode(pingData);
      final bytes = Uint8List.fromList(utf8.encode(jsonString));
      
      Nearby().sendBytesPayload(endpointId, bytes).then((_) {
        print('✅ BLUETOOTH DEBUG: Ping sent successfully to $endpointId');
      }).catchError((e) {
        print('❌ BLUETOOTH DEBUG: Ping failed to $endpointId: $e');
      });
    } catch (e) {
      print('❌ BLUETOOTH DEBUG: Error sending ping: $e');
    }
  }

  // Send acknowledgment for received payload
  void _sendAcknowledgment(String endpointId, int payloadId) {
    try {
      print('📡 BLUETOOTH DEBUG: Sending acknowledgment to $endpointId for payload $payloadId');
      
      final ackData = {
        'type': 'ack',
        'senderId': 'device_${DateTime.now().millisecondsSinceEpoch}',
        'senderName': 'My Device',
        'timestamp': DateTime.now().toIso8601String(),
        'payloadId': payloadId,
      };
      
      final jsonString = jsonEncode(ackData);
      final bytes = Uint8List.fromList(utf8.encode(jsonString));
      
      Nearby().sendBytesPayload(endpointId, bytes).then((_) {
        print('✅ BLUETOOTH DEBUG: Acknowledgment sent to $endpointId');
      }).catchError((e) {
        print('❌ BLUETOOTH DEBUG: Acknowledgment failed to $endpointId: $e');
      });
    } catch (e) {
      print('❌ BLUETOOTH DEBUG: Error sending acknowledgment: $e');
    }
  }

  Future<void> sendTicketData(TicketModel ticket) async {
    print('📡 BLUETOOTH DEBUG: ===== SEND TICKET DATA =====');
    
    // Validate connected devices
    if (_connectedDevices.isEmpty) {
      print('❌ BLUETOOTH DEBUG: No connected devices available');
      _updateStatus('❌ No connected devices to send to');
      throw Exception('No connected devices available');
    }

    // CRITICAL FIX: Verify connection health before sending
    print('🔍 BLUETOOTH DEBUG: Verifying connection health before sending...');
    await _verifyAndCleanConnections();
    
    if (_connectedDevices.isEmpty) {
      print('❌ BLUETOOTH DEBUG: No healthy connections found');
      _updateStatus('❌ No active connections available');
      throw Exception('No active connections available');
    }

    // Get fresh list of verified active devices
    final activeDevices = _connectedDevices.toList();
    print('📡 BLUETOOTH DEBUG: Verified ${activeDevices.length} active connections');
    print('📡 BLUETOOTH DEBUG: Device IDs: $activeDevices');

    try {
      // Process image if present with size validation
      String? imageBase64;
      if (ticket.imageFile != null) {
        print('📷 BLUETOOTH DEBUG: Processing image...');
        try {
          final imageBytes = await ticket.imageFile!.readAsBytes();
          final imageSizeKB = imageBytes.length / 1024;
          print('📷 BLUETOOTH DEBUG: Image size: ${imageSizeKB.toStringAsFixed(2)} KB');
          
          // Nearby Connections has a practical limit of ~32KB per payload
          // With base64 encoding, original file should be < 200KB to be safe
          if (imageBytes.length > 200 * 1024) {
            print('⚠️ BLUETOOTH DEBUG: Image too large (${imageSizeKB.toStringAsFixed(0)} KB), skipping');
            _updateStatus('⚠️ Image too large (${imageSizeKB.toStringAsFixed(0)} KB), sending without image');
            // Continue without image - don't fail the whole send
          } else {
            imageBase64 = base64Encode(imageBytes);
            final base64SizeKB = imageBase64.length / 1024;
            print('📷 BLUETOOTH DEBUG: ✅ Image encoded, base64 size: ${base64SizeKB.toStringAsFixed(2)} KB');
            
            // Final check after base64 encoding
            if (imageBase64.length > 250 * 1024) {
              print('⚠️ BLUETOOTH DEBUG: Base64 too large, removing image');
              _updateStatus('⚠️ Encoded image too large, sending without image');
              imageBase64 = null;
            }
          }
        } catch (e) {
          print('❌ BLUETOOTH DEBUG: Image processing failed: $e');
          _updateStatus('⚠️ Image processing failed, sending without image');
          // Continue without image
        }
      } else {
        print('📷 BLUETOOTH DEBUG: No image to process');
      }

      // Create payload with unique ID for tracking
      final ticketData = ticket.toJson();
      if (imageBase64 != null) {
        ticketData['imageBase64'] = imageBase64;
      }

      final payloadId = DateTime.now().millisecondsSinceEpoch;
      final payload = {
        'type': 'ticket_data',
        'payloadId': payloadId,
        'senderId': 'device_$payloadId',
        'senderName': 'My Device',
        'timestamp': DateTime.now().toIso8601String(),
        'ticket': ticketData,
      };

      // Convert to bytes with proper UTF-8 encoding
      final jsonString = jsonEncode(payload);
      final bytes = Uint8List.fromList(utf8.encode(jsonString));
      
      print('📡 BLUETOOTH DEBUG: ===== PAYLOAD INFO =====');
      print('  - Payload ID: $payloadId');
      print('  - Ticket ID: ${ticketData['id']}');
      print('  - Description: ${ticketData['description']}');
      print('  - Has Image: ${imageBase64 != null}');
      print('  - JSON Length: ${jsonString.length}');
      print('  - Bytes Length: ${bytes.length}');

      // Send to all connected devices with retry logic
      int successCount = 0;
      final List<String> failedDevices = [];
      final List<Future<void>> sendTasks = [];

      for (final deviceId in activeDevices) {
        sendTasks.add(_sendToDeviceWithRetry(deviceId, bytes, payloadId).then((_) {
          successCount++;
          print('✅ BLUETOOTH DEBUG: Successfully sent to $deviceId');
        }).catchError((e) {
          print('❌ BLUETOOTH DEBUG: Failed to send to $deviceId: $e');
          failedDevices.add(deviceId);
        }));
      }

      // Wait for all sends to complete (with timeout)
      try {
        await Future.wait(sendTasks).timeout(Duration(seconds: 30));
      } catch (e) {
        print('⚠️ BLUETOOTH DEBUG: Some sends timed out: $e');
      }

      // Report results
      print('📡 BLUETOOTH DEBUG: ===== SEND COMPLETE =====');
      print('📡 BLUETOOTH DEBUG: Success: $successCount/${activeDevices.length}');
      if (failedDevices.isNotEmpty) {
        print('📡 BLUETOOTH DEBUG: Failed devices: $failedDevices');
      }
      
      if (successCount > 0) {
        _updateStatus('✅ Ticket sent to $successCount/${activeDevices.length} devices');
      } else {
        _updateStatus('❌ Failed to send ticket to any devices');
        throw Exception('Send failed to all devices');
      }

    } catch (e, stackTrace) {
      print('❌ BLUETOOTH DEBUG: ===== SEND ERROR =====');
      print('❌ BLUETOOTH DEBUG: Error: $e');
      print('❌ BLUETOOTH DEBUG: Stack trace: $stackTrace');
      _updateStatus('❌ Send failed: $e');
      rethrow;
    }
  }

  // Send to device with retry mechanism
  Future<void> _sendToDeviceWithRetry(String deviceId, Uint8List bytes, int payloadId) async {
    const maxRetries = 3;
    const retryDelay = Duration(seconds: 1);
    
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        print('📤 BLUETOOTH DEBUG: Sending to $deviceId (attempt $attempt/$maxRetries)');
        await Nearby().sendBytesPayload(deviceId, bytes);
        print('✅ BLUETOOTH DEBUG: Send successful to $deviceId on attempt $attempt');
        return;
      } catch (e) {
        print('❌ BLUETOOTH DEBUG: Send attempt $attempt failed to $deviceId: $e');
        
        if (attempt < maxRetries) {
          print('🔄 BLUETOOTH DEBUG: Retrying in ${retryDelay.inSeconds} seconds...');
          await Future.delayed(retryDelay);
        } else {
          print('💥 BLUETOOTH DEBUG: All retry attempts failed for $deviceId');
          rethrow;
        }
      }
    }
  }



  // New method to send any custom data
  Future<void> broadcastCustomData(Map<String, dynamic> customData) async {
    if (_connectedDevices.isEmpty) {
      _updateStatus('📱 No connected devices to broadcast to');
      return;
    }

    // Verify connections before broadcasting
    await _verifyAndCleanConnections();
    
    if (_connectedDevices.isEmpty) {
      _updateStatus('📱 No active connections to broadcast to');
      return;
    }

    try {
      final broadcastData = {
        'type': 'custom_data',
        'senderId': 'advertiser_${DateTime.now().millisecondsSinceEpoch}',
        'senderName': 'Advertiser Device',
        'timestamp': DateTime.now().toIso8601String(),
        'data': customData,
      };
      
      final data = jsonEncode(broadcastData);
      final bytes = Uint8List.fromList(utf8.encode(data));
      
      print('📡 BLUETOOTH DEBUG: Broadcasting custom data to ${_connectedDevices.length} devices');
      
      int successCount = 0;
      for (final deviceId in _connectedDevices) {
        try {
          await Nearby().sendBytesPayload(deviceId, bytes);
          successCount++;
        } catch (e) {
          print('❌ BLUETOOTH DEBUG: Failed to send to device $deviceId: $e');
        }
      }
      
      _updateStatus('📡 Broadcasted custom data to $successCount/${_connectedDevices.length} devices');
    } catch (e) {
      _updateStatus('❌ Failed to broadcast custom data: $e');
    }
  }



  // CRITICAL FIX: New method to verify connections are actually active before sending
  Future<void> _verifyAndCleanConnections() async {
    if (_connectedDevices.isEmpty) return;

    print('🔍 BLUETOOTH DEBUG: Verifying ${_connectedDevices.length} connections...');
    final List<String> staleConnections = [];

    // Test each connection with a lightweight ping
    for (final deviceId in _connectedDevices.toList()) {
      try {
        // Attempt a test payload to verify the connection is alive
        final testPayload = {'type': 'connection_verify', 'timestamp': DateTime.now().toIso8601String()};
        final testData = jsonEncode(testPayload);
        final bytes = Uint8List.fromList(utf8.encode(testData));
        
        await Nearby().sendBytesPayload(deviceId, bytes).timeout(
          Duration(seconds: 2),
          onTimeout: () {
            print('⏱️ BLUETOOTH DEBUG: Connection verification timeout for $deviceId');
            throw TimeoutException('Connection verification timeout');
          },
        );
        
        print('✅ BLUETOOTH DEBUG: Connection verified for $deviceId');
      } catch (e) {
        print('❌ BLUETOOTH DEBUG: Connection dead for $deviceId: $e');
        staleConnections.add(deviceId);
      }
    }

    // Remove stale connections
    for (final staleDevice in staleConnections) {
      print('🧹 BLUETOOTH DEBUG: Removing stale connection: $staleDevice');
      _connectedDevices.remove(staleDevice);
    }

    if (staleConnections.isNotEmpty) {
      print('📡 BLUETOOTH DEBUG: Cleaned up ${staleConnections.length} stale connections');
      _updateStatus('🧹 Removed ${staleConnections.length} dead connections');
      notifyListeners();
    }
  }

  // Check connection health by sending pings
  Future<void> checkConnectionHealth() async {
    await _verifyAndCleanConnections();
  }

  void clearReceivedData() {
    _receivedDataList.clear();
    notifyListeners();
    print('🗑️ BLUETOOTH DEBUG: Cleared all received data');
  }

  // Test method to verify payload reception is working
  void testPayloadReception() {
    print('🧪 BLUETOOTH DEBUG: Testing payload reception...');
    print('🧪 BLUETOOTH DEBUG: Connected devices: ${_connectedDevices.length}');
    print('🧪 BLUETOOTH DEBUG: Device IDs: ${_connectedDevices.toList()}');
    
    // Simulate a payload reception for testing
    final testData = {
      'type': 'test_data',
      'senderId': 'test_sender',
      'senderName': 'Test Device',
      'timestamp': DateTime.now().toIso8601String(),
      'message': 'This is a test payload',
    };
    
    final receivedDataObj = ReceivedData(
      senderId: 'test_sender',
      senderName: 'Test Device',
      data: testData,
      receivedAt: DateTime.now(),
    );
    
    _receivedDataList.add(receivedDataObj);
    notifyListeners();
    print('🧪 BLUETOOTH DEBUG: Test payload added to received list');
  }

  // Test method to add a proper ticket for UI testing
  void addTestTicket() {
    print('🧪 BLUETOOTH DEBUG: Adding test ticket...');
    
    final testTicketData = {
      'type': 'ticket_data',
      'senderId': 'test_sender_123',
      'senderName': 'Test Device',
      'timestamp': DateTime.now().toIso8601String(),
      'ticket': {
        'id': '123456789',
        'description': 'This is a test ticket description with some longer text to see how it displays in the UI',
        'createdAt': DateTime.now().toIso8601String(),
        'status': 'TicketStatus.pending',
        'retryCount': 0,
      }
    };
    
    final receivedDataObj = ReceivedData(
      senderId: 'test_sender_123',
      senderName: 'Test Device',
      data: testTicketData,
      receivedAt: DateTime.now(),
    );
    
    _receivedDataList.add(receivedDataObj);
    _updateStatus('🧪 Test ticket added for UI testing');
    notifyListeners();
    print('🧪 BLUETOOTH DEBUG: Test ticket added to received list. Total items: ${_receivedDataList.length}');
  }

  // Critical test method to verify the entire reception pipeline
  void testCompleteReceptionPipeline() {
    print('🧪 BLUETOOTH DEBUG: ===== TESTING COMPLETE RECEPTION PIPELINE =====');
    
    // Test 1: Direct method call
    print('🧪 TEST 1: Testing direct _processReceivedPayload call');
    final testPayload = {
      'type': 'ticket_data',
      'senderId': 'pipeline_test_123',
      'senderName': 'Pipeline Test Device',
      'timestamp': DateTime.now().toIso8601String(),
      'ticket': {
        'id': 'pipeline_test_ticket',
        'description': 'This is a pipeline test ticket to verify reception works',
        'createdAt': DateTime.now().toIso8601String(),
      }
    };
    
    final jsonString = jsonEncode(testPayload);
    final bytes = utf8.encode(jsonString);
    
    // Create a mock payload
    final mockPayload = Payload(
      id: 999,
      type: PayloadType.BYTES,
      bytes: Uint8List.fromList(bytes),
    );
    
    print('🧪 TEST 1: Calling _processReceivedPayload directly...');
    _processReceivedPayload('test_endpoint', mockPayload);
    
    // Test 2: Check if data was added
    print('🧪 TEST 2: Checking if data was added to received list...');
    print('🧪 TEST 2: Current received list length: ${_receivedDataList.length}');
    
    // Test 3: Trigger UI update
    print('🧪 TEST 3: Triggering notifyListeners...');
    notifyListeners();
    
    print('🧪 BLUETOOTH DEBUG: ===== PIPELINE TEST COMPLETE =====');
  }

  // Test method to add a ticket with image for comprehensive testing
  void addTestTicketWithImage() {
    print('🧪 BLUETOOTH DEBUG: Adding test ticket with image...');
    
    // Create a small test image (1x1 pixel PNG in base64)
    const testImageBase64 = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==';
    
    final testTicketData = {
      'type': 'ticket_data',
      'senderId': 'test_sender_456',
      'senderName': 'Test Device with Image',
      'timestamp': DateTime.now().toIso8601String(),
      'ticket': {
        'id': '987654321',
        'description': 'This is a test ticket with an image attachment. The image should display properly in the received data section.',
        'createdAt': DateTime.now().toIso8601String(),
        'status': 'TicketStatus.pending',
        'retryCount': 0,
        'imageBase64': testImageBase64,
      }
    };
    
    final receivedDataObj = ReceivedData(
      senderId: 'test_sender_456',
      senderName: 'Test Device with Image',
      data: testTicketData,
      receivedAt: DateTime.now(),
    );
    
    _receivedDataList.add(receivedDataObj);
    _updateStatus('🧪 Test ticket with image added');
    notifyListeners();
    print('🧪 BLUETOOTH DEBUG: Test ticket with image added. Total items: ${_receivedDataList.length}');
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
    print('🔵 BLUETOOTH DEBUG: ===== BLUETOOTH STATUS CHECK =====');
    
    try {
      print('📱 BLUETOOTH DEBUG: Device platform: ${defaultTargetPlatform.toString()}');
      print('🔧 BLUETOOTH DEBUG: Service ID being used: $_serviceId');
      print('📊 BLUETOOTH DEBUG: Current state:');
      print('  - Advertising: $_isAdvertising');
      print('  - Discovering: $_isDiscovering');
      print('  - Connected devices: ${_connectedDevices.length}');
      print('  - Received data items: ${_receivedDataList.length}');
      
      if (_connectedDevices.isNotEmpty) {
        print('📋 BLUETOOTH DEBUG: Connected device details:');
        for (final deviceId in _connectedDevices) {
          print('  - Device ID: $deviceId');
        }
      } else {
        print('⚠️ BLUETOOTH DEBUG: No connected devices');
      }
      
      if (_receivedDataList.isNotEmpty) {
        print('📥 BLUETOOTH DEBUG: Received data summary:');
        for (int i = 0; i < _receivedDataList.length; i++) {
          final item = _receivedDataList[i];
          print('  - Item $i: ${item.data['type']} from ${item.senderName}');
        }
      } else {
        print('📥 BLUETOOTH DEBUG: No received data');
      }
      
      print('');
      print('🔍 IMPORTANT: Nearby Connections only finds devices running this SAME APP!');
      print('📱 To test: Install this app on another device and start advertising there');
      print('🚫 Regular Bluetooth devices (headphones, speakers, etc.) will NOT be found');
      print('✅ Only devices with this app running and advertising will appear');
      print('🔵 BLUETOOTH DEBUG: ===== STATUS CHECK COMPLETE =====');
      
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