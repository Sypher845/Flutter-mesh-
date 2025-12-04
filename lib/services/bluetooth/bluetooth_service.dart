import 'package:flutter/foundation.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'dart:convert';
import 'dart:async';

import '../../models/report_model.dart';
import 'connection_manager.dart';
import 'payload_handler.dart';
import 'mesh_network_manager.dart';
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
  
  // State
  final List<ReceivedData> _receivedDataList = [];
  Timer? _healthCheckTimer;
  String _statusMessage = '';
  
  // Getters
  bool get isAdvertising => _connectionManager.isAdvertising;
  bool get isDiscovering => _connectionManager.isDiscovering;
  Set<String> get connectedDevices => _connectionManager.connectedDevices;
  List<ReceivedData> get receivedDataList => List.unmodifiable(_receivedDataList);
  String get statusMessage => _statusMessage;
  int get receivedReportCount => _meshManager.receivedReportCount;

  BluetoothService._internal() {
    // Generate unique device ID for this instance
    _myDeviceId = 'device_${DateTime.now().millisecondsSinceEpoch}';
    
    _initializeManagers();
    _startPeriodicHealthCheck();
    _initializeReceiverMode();
  }

  /// Initialize all manager instances and set up callbacks
  void _initializeManagers() {
    _connectionManager = ConnectionManager();
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

  @override
  void dispose() {
    _healthCheckTimer?.cancel();
    _connectionManager.stopAll();
    super.dispose();
  }

  // ============================================================================
  // CONNECTION CALLBACKS
  // ============================================================================

  void _onConnectionInitiated(String endpointId, ConnectionInfo connectionInfo) async {
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
    );
  }

  void _onConnectionResult(String endpointId, Status status) {
    if (status == Status.CONNECTED) {
      // Register payload callback after connection is confirmed
      _registerPayloadCallback(endpointId);
      notifyListeners();
    }
  }

  void _onDisconnected(String endpointId) {
    notifyListeners();
  }

  void _onEndpointFound(String endpointId, String endpointName, String serviceId) {
    if (serviceId == BluetoothConstants.serviceId) {
      _connectionManager.requestConnection(endpointId);
    }
  }

  void _onEndpointLost(String? endpointId) {
    notifyListeners();
  }

  /// Register payload callback for a confirmed connection
  void _registerPayloadCallback(String endpointId) {
    _connectionManager.acceptConnection(
      endpointId,
      (receivedEndpointId, receivedPayload) {
        _onPayloadReceived(receivedEndpointId, receivedPayload);
      },
    ).then((_) {
      // Send ping to verify connection works
      Timer(Duration(milliseconds: 500), () {
        if (_connectionManager.connectedDevices.contains(endpointId)) {
          _payloadHandler.sendConnectionPing(endpointId);
        }
      });
    });
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

  Future<int> _sendToAllDevices(
    List<String> activeDevices,
    Uint8List bytes,
    String reportId,
  ) async {
    int successCount = 0;
    final sendTasks = <Future<void>>[];
    final payloadId = DateTime.now().millisecondsSinceEpoch;

    if (kDebugMode) {
      print('');
      print('📤 SENDING TO ALL DEVICES');
      print('   Target devices: ${activeDevices.length}');
      print('   Payload size: ${bytes.length} bytes (${(bytes.length / 1024).toStringAsFixed(2)} KB)');
      print('   Payload ID: $payloadId');
      print('   Report ID: $reportId');
    }

    for (final deviceId in activeDevices) {
      if (kDebugMode) {
        print('   → Sending to device: $deviceId');
      }
      
      sendTasks.add(
        _payloadHandler.sendBytesPayload(deviceId, bytes, payloadId).then((_) {
          successCount++;
          if (kDebugMode) {
            print('   ✅ Successfully sent to device: $deviceId');
          }
        }).catchError((e) {
          if (kDebugMode) {
            print('   ❌ Failed to send to device: $deviceId');
            print('      Error: $e');
          }
        })
      );
    }

    try {
      await Future.wait(sendTasks).timeout(
        Duration(milliseconds: BluetoothConstants.sendTimeout),
        onTimeout: () {
          if (kDebugMode) {
            print('⚠️  Send timeout after ${BluetoothConstants.sendTimeout}ms');
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

    if (kDebugMode) {
      print('');
      print('📊 SEND RESULTS');
      print('   Success: $successCount/${activeDevices.length}');
      print('   Failed: ${activeDevices.length - successCount}/${activeDevices.length}');
    }

    return successCount;
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
  Future<void> verifyAndCleanConnections() async {
    if (_connectionManager.connectedDevices.isEmpty) return;

    final staleConnections = <String>[];

    for (final deviceId in _connectionManager.connectedDevices.toList()) {
      try {
        final testPayload = {
          'type': BluetoothConstants.payloadTypeConnectionVerify,
          'timestamp': DateTime.now().toIso8601String()
        };
        final testData = jsonEncode(testPayload);
        final bytes = Uint8List.fromList(utf8.encode(testData));
        
        await Nearby().sendBytesPayload(deviceId, bytes).timeout(
          Duration(milliseconds: BluetoothConstants.connectionVerificationTimeout),
          onTimeout: () {
            throw TimeoutException('Connection verification timeout');
          },
        );
      } catch (e) {
        staleConnections.add(deviceId);
      }
    }

    for (final staleDevice in staleConnections) {
      _connectionManager.removeConnectedDevice(staleDevice);
    }

    if (staleConnections.isNotEmpty) {
      _updateStatus('🧹 Removed ${staleConnections.length} dead connections');
      notifyListeners();
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
