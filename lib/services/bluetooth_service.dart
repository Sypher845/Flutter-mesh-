import 'package:flutter/foundation.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:convert';
import 'dart:async';

import '../models/report_model.dart';

class ReceivedData {
  final String senderId;
  final String senderName;
  final Map<String, dynamic> data;
  final DateTime receivedAt;
  String? receivedImagePath;

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
    _startPeriodicHealthCheck();
    _initializeAutoDiscovery();
  }

  Future<void> _initializeAutoDiscovery() async {
    // Auto-start discovery when service is created
    await Future.delayed(Duration(seconds: 2));
    if (!_isDiscovering && !_isAdvertising) {
      await startAdvertising();
      await startDiscovery();
    }
  }

  void _startPeriodicHealthCheck() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = Timer.periodic(Duration(seconds: 30), (timer) async {
      if (_connectedDevices.isNotEmpty) {
        try {
          await _verifyAndCleanConnections();
        } catch (e) {
          // Silently handle health check errors
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
    bool locationGranted = false;
    
    try {
      final locationStatus = await Permission.locationWhenInUse.request();
      locationGranted = locationStatus == PermissionStatus.granted || locationStatus == PermissionStatus.limited;
    } catch (e) {
      // Continue
    }
    
    if (!locationGranted) {
      try {
        final locationStatus = await Permission.location.request();
        locationGranted = locationStatus == PermissionStatus.granted || locationStatus == PermissionStatus.limited;
      } catch (e) {
        // Continue
      }
    }
    
    if (!locationGranted) {
      try {
        final fineLocationStatus = await Permission.locationAlways.request();
        locationGranted = fineLocationStatus == PermissionStatus.granted || fineLocationStatus == PermissionStatus.limited;
      } catch (e) {
        // Continue
      }
    }
    
    final bluetoothPermissions = [
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
      Permission.bluetoothAdvertise,
    ];

    Map<Permission, PermissionStatus> bluetoothStatuses = await bluetoothPermissions.request();
    
    bool bluetoothGranted = bluetoothStatuses.values.every((status) => 
      status == PermissionStatus.granted || status == PermissionStatus.limited);
    
    if (!bluetoothGranted || !locationGranted) {
      return false;
    }

    try {
      await Permission.nearbyWifiDevices.request();
    } catch (e) {
      // Optional permission
    }

    return true;
  }

  Future<void> startAdvertising() async {
    if (_isAdvertising) {
      _updateStatus('Advertising is already running');
      return;
    }

    if (!await _requestPermissions()) {
      _updateStatus('❌ Bluetooth permissions denied. Check app settings.');
      return;
    }

    try {
      await Nearby().startAdvertising(
        'OfflineSyncDevice',
        Strategy.P2P_CLUSTER,
        onConnectionInitiated: _onConnectionInitiated,
        onConnectionResult: _onConnectionResult,
        onDisconnected: _onDisconnected,
        serviceId: _serviceId,
      );
      
      _isAdvertising = true;
      _updateStatus('📡 Started advertising');
      notifyListeners();
    } catch (e) {
      if (e.toString().contains('STATUS_ALREADY_ADVERTISING') || 
          e.toString().contains('8001')) {
        _updateStatus('Advertising is already running');
        _isAdvertising = true;
      } else {
        _updateStatus('Failed to start advertising');
      }
      notifyListeners();
    }
  }

  Future<void> startDiscovery() async {
    if (_isDiscovering) {
      _updateStatus('Discovery is already running');
      return;
    }

    if (!await _requestPermissions()) {
      _updateStatus('❌ Bluetooth permissions denied. Check app settings.');
      return;
    }

    try {
      await Nearby().startDiscovery(
        'OfflineSyncDevice',
        Strategy.P2P_CLUSTER,
        onEndpointFound: _onEndpointFound,
        onEndpointLost: _onEndpointLost,
        serviceId: _serviceId,
      );
      
      _isDiscovering = true;
      _updateStatus('🔍 Scanning for nearby devices...');
      notifyListeners();
    } catch (e) {
      if (e.toString().contains('STATUS_ALREADY_DISCOVERING') || 
          e.toString().contains('8002')) {
        _updateStatus('Discovery is already running');
        _isDiscovering = true;
      } else {
        _updateStatus('Failed to start discovery');
      }
      notifyListeners();
    }
  }

  void _onEndpointFound(String endpointId, String endpointName, String serviceId) {
    _updateStatus('📱 Found device: $endpointName');
    
    if (serviceId == _serviceId) {
      _requestConnection(endpointId);
    }
  }

  void _onEndpointLost(String? endpointId) {
    if (endpointId != null && _connectedDevices.contains(endpointId)) {
      _connectedDevices.remove(endpointId);
      notifyListeners();
    }
    _updateStatus('📤 Lost device: $endpointId');
  }

  Future<void> _requestConnection(String endpointId) async {
    try {
      await Nearby().requestConnection(
        'OfflineSyncDevice',
        endpointId,
        onConnectionInitiated: _onConnectionInitiated,
        onConnectionResult: _onConnectionResult,
        onDisconnected: _onDisconnected,
      );
    } catch (e) {
      _updateStatus('❌ Failed to connect to device');
    }
  }

  void _onConnectionInitiated(String endpointId, ConnectionInfo connectionInfo) async {
    _updateStatus('🔗 Connection initiated with ${connectionInfo.endpointName}');
    
    try {
      await Nearby().acceptConnection(
        endpointId,
        onPayLoadRecieved: (String receivedEndpointId, Payload receivedPayload) {
          try {
            _onPayloadReceived(receivedEndpointId, receivedPayload);
          } catch (e) {
            _updateStatus('⚠️ Received data but processing failed');
          }
        },
      );
      
      Timer(Duration(seconds: 2), () {
        if (_connectedDevices.contains(endpointId)) {
          _sendConnectionPing(endpointId);
        }
      });
    } catch (e) {
      _updateStatus('❌ Failed to accept connection');
    }
  }

  void _onConnectionResult(String endpointId, Status status) {
    if (status == Status.CONNECTED) {
      _connectedDevices.add(endpointId);
      _updateStatus('✅ Connected to device');
      _reRegisterPayloadCallback(endpointId);
      notifyListeners();
    } else {
      _updateStatus('❌ Failed to connect to device');
      _connectedDevices.remove(endpointId);
    }
  }

  void _reRegisterPayloadCallback(String endpointId) {
    try {
      Timer(Duration(milliseconds: 500), () {
        if (_connectedDevices.contains(endpointId)) {
          _sendConnectionPing(endpointId);
        }
      });
    } catch (e) {
      // Ignore
    }
  }

  void _onDisconnected(String endpointId) {
    _connectedDevices.remove(endpointId);
    _updateStatus('💔 Disconnected from device');
    notifyListeners();
  }

  void _onPayloadReceived(String endpointId, Payload payload) {
    try {
      if (payload.type == PayloadType.BYTES) {
        _processReceivedPayload(endpointId, payload);
        _sendAcknowledgment(endpointId, payload.id);
      } else {
        _updateStatus('⚠️ Received unsupported payload type');
      }
    } catch (e) {
      _updateStatus('❌ Error processing received payload');
    }
  }

  void _processReceivedPayload(String endpointId, Payload payload) {
    try {
      if (payload.bytes == null || payload.bytes!.isEmpty) {
        _updateStatus('❌ Received empty payload');
        return;
      }
      
      String jsonString;
      try {
        jsonString = utf8.decode(payload.bytes!);
      } catch (e) {
        try {
          jsonString = String.fromCharCodes(payload.bytes!);
        } catch (e2) {
          _updateStatus('❌ Invalid payload format');
          return;
        }
      }
      
      final Map<String, dynamic> receivedData;
      try {
        receivedData = jsonDecode(jsonString) as Map<String, dynamic>;
      } catch (e) {
        _updateStatus('❌ Invalid JSON format received');
        return;
      }
      
      final dataType = receivedData['type'] as String?;
      final senderId = receivedData['senderId'] as String?;
      final senderName = receivedData['senderName'] as String?;
      
      if (dataType == null) {
        _updateStatus('❌ Invalid data structure');
        return;
      }
      
      if (dataType == 'ping' || dataType == 'connection_verify') {
        _updateStatus('📡 Connection verified');
        return;
      }
      
      if (dataType == 'ack') {
        return;
      }
      
      if (dataType == 'report_data' || dataType == 'report_metadata' || dataType.contains('report') || 
          dataType == 'ticket_data' || dataType.contains('ticket')) {
        final report = receivedData['report'] as Map<String, dynamic>? ?? receivedData['ticket'] as Map<String, dynamic>?;
        if (report == null) {
          _updateStatus('❌ Invalid report data received');
          return;
        }
      }
      
      if (dataType == 'custom_data') {
        // Handle custom data
      }
      
      final receivedDataObj = ReceivedData(
        senderId: senderId ?? endpointId,
        senderName: senderName ?? 'Unknown Device',
        data: receivedData,
        receivedAt: DateTime.now(),
      );
      
      final isDuplicate = _receivedDataList.any((item) => 
        item.senderId == receivedDataObj.senderId && 
        item.data['timestamp'] == receivedDataObj.data['timestamp']
      );
      
      if (!isDuplicate) {
        _receivedDataList.add(receivedDataObj);
        
        while (_receivedDataList.length > 20) {
          _receivedDataList.removeAt(0);
        }
        
        _updateStatus('📥 Received $dataType from ${senderName ?? 'Unknown'}');
        notifyListeners();
      } else {
        notifyListeners();
      }
    } catch (e) {
      _updateStatus('❌ Error processing received data');
      notifyListeners();
    }
  }

  void _sendConnectionPing(String endpointId) {
    try {
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
        // Success
      }).catchError((e) {
        // Ignore errors
      });
    } catch (e) {
      // Ignore errors
    }
  }

  void _sendAcknowledgment(String endpointId, int payloadId) {
    try {
      final ackData = {
        'type': 'ack',
        'senderId': 'device_${DateTime.now().millisecondsSinceEpoch}',
        'senderName': 'My Device',
        'timestamp': DateTime.now().toIso8601String(),
        'payloadId': payloadId,
      };
      
      final jsonString = jsonEncode(ackData);
      final bytes = Uint8List.fromList(utf8.encode(jsonString));
      
      Nearby().sendBytesPayload(endpointId, bytes).catchError((e) {
        // Ignore
      });
    } catch (e) {
      // Ignore
    }
  }

  Future<void> sendReportData(ReportModel report) async {
    // Ensure advertising and discovery are running
    if (!_isAdvertising) {
      await startAdvertising();
    }
    if (!_isDiscovering) {
      await startDiscovery();
    }

    // Wait a bit for connections to establish
    if (_connectedDevices.isEmpty) {
      _updateStatus('🔍 Searching for nearby devices...');
      await Future.delayed(Duration(seconds: 3));
    }

    if (_connectedDevices.isEmpty) {
      _updateStatus('⚠️ No devices found nearby - Report saved locally');
      throw Exception('No connected devices available');
    }

    await _verifyAndCleanConnections();
    
    if (_connectedDevices.isEmpty) {
      _updateStatus('❌ No active connections available');
      throw Exception('No active connections available');
    }

    final activeDevices = _connectedDevices.toList();

    try {
      String? imageBase64;
      if (report.imageFile != null) {
        try {
          final imageBytes = await report.imageFile!.readAsBytes();
          
          if (imageBytes.length > 200 * 1024) {
            _updateStatus('⚠️ Image too large, sending without image');
          } else {
            imageBase64 = base64Encode(imageBytes);
            
            if (imageBase64.length > 250 * 1024) {
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
        'type': 'report_data',
        'payloadId': payloadId,
        'senderId': 'device_$payloadId',
        'senderName': 'My Device',
        'timestamp': DateTime.now().toIso8601String(),
        'report': reportData,
      };

      final jsonString = jsonEncode(payload);
      final bytes = Uint8List.fromList(utf8.encode(jsonString));

      int successCount = 0;
      final List<String> failedDevices = [];
      final List<Future<void>> sendTasks = [];

      for (final deviceId in activeDevices) {
        sendTasks.add(_sendToDeviceWithRetry(deviceId, bytes, payloadId).then((_) {
          successCount++;
        }).catchError((e) {
          failedDevices.add(deviceId);
        }));
      }

      try {
        await Future.wait(sendTasks).timeout(Duration(seconds: 30));
      } catch (e) {
        // Some sends timed out
      }

      if (successCount > 0) {
        _updateStatus('✅ Report sent to $successCount/${activeDevices.length} devices');
      } else {
        _updateStatus('❌ Failed to send report to any devices');
        throw Exception('Send failed to all devices');
      }
    } catch (e) {
      _updateStatus('❌ Send failed');
      rethrow;
    }
  }

  Future<void> _sendToDeviceWithRetry(String deviceId, Uint8List bytes, int payloadId) async {
    const maxRetries = 3;
    const retryDelay = Duration(seconds: 1);
    
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        await Nearby().sendBytesPayload(deviceId, bytes);
        return;
      } catch (e) {
        if (attempt < maxRetries) {
          await Future.delayed(retryDelay);
        } else {
          rethrow;
        }
      }
    }
  }

  Future<void> broadcastCustomData(Map<String, dynamic> customData) async {
    if (_connectedDevices.isEmpty) {
      _updateStatus('📱 No connected devices to broadcast to');
      return;
    }

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
      
      int successCount = 0;
      for (final deviceId in _connectedDevices) {
        try {
          await Nearby().sendBytesPayload(deviceId, bytes);
          successCount++;
        } catch (e) {
          // Ignore individual failures
        }
      }
      
      _updateStatus('📡 Broadcasted to $successCount/${_connectedDevices.length} devices');
    } catch (e) {
      _updateStatus('❌ Failed to broadcast');
    }
  }

  Future<void> _verifyAndCleanConnections() async {
    if (_connectedDevices.isEmpty) return;

    final List<String> staleConnections = [];

    for (final deviceId in _connectedDevices.toList()) {
      try {
        final testPayload = {'type': 'connection_verify', 'timestamp': DateTime.now().toIso8601String()};
        final testData = jsonEncode(testPayload);
        final bytes = Uint8List.fromList(utf8.encode(testData));
        
        await Nearby().sendBytesPayload(deviceId, bytes).timeout(
          Duration(seconds: 2),
          onTimeout: () {
            throw TimeoutException('Connection verification timeout');
          },
        );
      } catch (e) {
        staleConnections.add(deviceId);
      }
    }

    for (final staleDevice in staleConnections) {
      _connectedDevices.remove(staleDevice);
    }

    if (staleConnections.isNotEmpty) {
      _updateStatus('🧹 Removed ${staleConnections.length} dead connections');
      notifyListeners();
    }
  }

  Future<void> checkConnectionHealth() async {
    await _verifyAndCleanConnections();
  }

  void clearReceivedData() {
    _receivedDataList.clear();
    notifyListeners();
  }

  Future<void> stopDiscovery() async {
    if (!_isDiscovering) return;
    
    try {
      await Nearby().stopDiscovery();
      _isDiscovering = false;
      _updateStatus('Stopped device discovery');
      notifyListeners();
    } catch (e) {
      // Ignore
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
      // Ignore
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
      // Ignore
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
