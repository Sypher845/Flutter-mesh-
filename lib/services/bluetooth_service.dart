import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fbp;
import 'package:permission_handler/permission_handler.dart';
import '../models/report_model.dart';

// Custom enum to avoid conflict with flutter_blue_plus
enum BleConnectionState { 
  disconnected, 
  connecting, 
  connected, 
  scanning, 
  broadcasting 
}

class BluetoothService {
  static final BluetoothService _instance = BluetoothService._internal();
  factory BluetoothService() => _instance;
  BluetoothService._internal();

  BleConnectionState _connectionState = BleConnectionState.disconnected;
  BleConnectionState get connectionState => _connectionState;

  // Scanning
  StreamSubscription<List<fbp.ScanResult>>? _scanSubscription;
  final _scanResultsController = StreamController<List<fbp.ScanResult>>.broadcast();
  Stream<List<fbp.ScanResult>> get scanResults => _scanResultsController.stream;
  bool _isScanning = false;

  // Multiple device connections (mesh network)
  final Map<String, fbp.BluetoothDevice> _connectedDevices = {};
  final Map<String, StreamSubscription<fbp.BluetoothConnectionState>> _connectionSubscriptions = {};
  final Map<String, List<StreamSubscription<List<int>>>> _characteristicSubscriptions = {};
  final Map<String, List<fbp.BluetoothService>> _deviceServices = {};

  // Broadcasting
  Timer? _broadcastTimer;
  bool _isBroadcasting = false;

  // Use lowercase with underscores for constants
  static const String serviceUuid = "4fafc201-1fb5-459e-8fcc-c5c9c331914b";
  static const String characteristicUuid = "beb5483e-36e1-4688-b7f5-ea07361b26a8";

  // MTU and chunking
  static const int defaultMtu = 512;
  static const int chunkSize = 400; // Leave room for headers
  int _currentMtu = defaultMtu;

  // Deduplication
  final Set<String> _processedReportIds = {};
  static const int maxProcessedReports = 1000;

  // Retry configuration
  static const int maxRetryAttempts = 3;
  static const Duration retryDelay = Duration(seconds: 2);
  static const Duration connectionTimeout = Duration(seconds: 15);

  // Callbacks
  Function(ReportModel)? onReportReceived;
  Function(String)? onError;
  Function(BleConnectionState)? onStateChanged;

  // Dispose flag
  bool _isDisposed = false;

  // Initialize Bluetooth and request permissions
  Future<void> initialize() async {
    if (_isDisposed) {
      throw Exception('BluetoothService has been disposed');
    }

    try {
      // Check Bluetooth support
      if (await fbp.FlutterBluePlus.isSupported == false) {
        throw Exception("Bluetooth not supported by this device");
      }

      // Request permissions
      await _requestPermissions();

      // Check if Bluetooth is on
      final adapterState = await fbp.FlutterBluePlus.adapterState.first;
      if (adapterState != fbp.BluetoothAdapterState.on) {
        // On Android, we can request to turn on Bluetooth
        if (Platform.isAndroid) {
          await fbp.FlutterBluePlus.turnOn();
          // Wait for Bluetooth to turn on
          await Future.delayed(const Duration(seconds: 2));
        } else {
          throw Exception('Please enable Bluetooth');
        }
      }

      // Listen to adapter state changes - FIX THIS
      fbp.FlutterBluePlus.adapterState.listen((state) {
        if (state == fbp.BluetoothAdapterState.off && !_isDisposed) {
          _handleBluetoothOff();
        }
      });

      // Start continuous scanning
      await startScanning();

      print('✓ Bluetooth initialized successfully');
    } catch (e) {
      final errorMsg = 'Bluetooth initialization failed: $e';
      print('✗ $errorMsg');
      onError?.call(errorMsg);
      rethrow;
    }
  }

  // Request all necessary permissions
  Future<void> _requestPermissions() async {
    if (Platform.isAndroid) {
      // Android 12+ requires specific Bluetooth permissions
      final androidInfo = await _getAndroidVersion();
      
      if (androidInfo >= 31) { // Android 12+
        await [
          Permission.bluetoothScan,
          Permission.bluetoothConnect,
          Permission.bluetoothAdvertise,
        ].request();
      } else {
        await [
          Permission.bluetooth,
          Permission.location,
        ].request();
      }
    } else if (Platform.isIOS) {
      await Permission.bluetooth.request();
    }

    // Verify permissions granted
    if (Platform.isAndroid) {
      final bluetoothScan = await Permission.bluetoothScan.status;
      final bluetoothConnect = await Permission.bluetoothConnect.status;
      
      if (!bluetoothScan.isGranted || !bluetoothConnect.isGranted) {
        throw Exception('Bluetooth permissions not granted');
      }
    }
  }

  Future<int> _getAndroidVersion() async {
    if (Platform.isAndroid) {
      // This is a simplified version, use device_info_plus in production
      return 31; // Assume Android 12+ for safety
    }
    return 0;
  }

  // Handle Bluetooth turned off
  void _handleBluetoothOff() {
    print('⚠ Bluetooth turned off');
    _updateState(BleConnectionState.disconnected);
    _disconnectAllDevices();
    stopBroadcasting();
  }

  // Start scanning for nearby devices
  Future<void> startScanning() async {
    if (_isDisposed) return;
    if (_isScanning) return;

    try {
      _isScanning = true;
      _updateState(BleConnectionState.scanning);

      // Cancel any existing scan
      await _scanSubscription?.cancel();
      await fbp.FlutterBluePlus.stopScan();

      // Start new scan with service filter
      await fbp.FlutterBluePlus.startScan(
        withServices: [fbp.Guid(serviceUuid)],
        timeout: Duration.zero, // Continuous scan
        androidUsesFineLocation: true,
      );

      _scanSubscription = fbp.FlutterBluePlus.scanResults.listen(
        (results) {
          if (!_isDisposed && !_scanResultsController.isClosed) {
            _scanResultsController.add(results);
            _autoConnectToDevices(results);
          }
        },
        onError: (error) {
          print('✗ Scan error: $error');
          onError?.call('Scan error: $error');
        },
      );

      print('✓ Scanning started');
    } catch (e) {
      _isScanning = false;
      print('✗ Failed to start scanning: $e');
      onError?.call('Failed to start scanning: $e');
    }
  }

  // Stop scanning
  Future<void> stopScanning() async {
    if (!_isScanning) return;

    try {
      await _scanSubscription?.cancel();
      _scanSubscription = null;
      await fbp.FlutterBluePlus.stopScan();
      _isScanning = false;
      print('✓ Scanning stopped');
    } catch (e) {
      print('✗ Error stopping scan: $e');
    }
  }

  // Auto-connect to discovered devices
  void _autoConnectToDevices(List<fbp.ScanResult> results) {
    for (var result in results) {
      final deviceId = result.device.remoteId.toString();
      
      if (_connectedDevices.containsKey(deviceId)) continue;

      _connectToDevice(result.device);
    }
  }

  // Connect to a device with retry logic
  Future<void> _connectToDevice(fbp.BluetoothDevice device, {int attempt = 1}) async {
    if (_isDisposed) return;

    final deviceId = device.remoteId.toString();
    final deviceName = device.platformName.isNotEmpty ? device.platformName : 'Unknown';

    // Check if already connected
    if (_connectedDevices.containsKey(deviceId)) {
      print('ℹ Device $deviceName already connected');
      return;
    }

    try {
      print('→ Connecting to $deviceName (attempt $attempt/$maxRetryAttempts)...');

      // Set connecting state
      _updateState(BleConnectionState.connecting);

      // Connect with timeout
      await device.connect(
        timeout: connectionTimeout,
        autoConnect: false,
      ).timeout(
        connectionTimeout,
        onTimeout: () {
          throw TimeoutException('Connection timeout');
        },
      );

      // Only update state if connection successful
      _connectedDevices[deviceId] = device;
      _updateState(BleConnectionState.connected);

      print('✓ Connected to $deviceName');

      // Monitor connection state
      final connectionSub = device.connectionState.listen(
        (state) {
          if (state == fbp.BluetoothConnectionState.disconnected) {
            print('⚠ Device $deviceName disconnected');
            _cleanupDevice(deviceId);
            
            // Retry connection after delay
            if (!_isDisposed) {
              Future.delayed(retryDelay, () {
                if (!_isDisposed) _connectToDevice(device);
              });
            }
          }
        },
        onError: (error) {
          print('✗ Connection state error for $deviceName: $error');
        },
      );
      _connectionSubscriptions[deviceId] = connectionSub;

      // Request larger MTU for better throughput
      try {
        _currentMtu = await device.mtu.first;
        if (_currentMtu < 512) {
          _currentMtu = await device.requestMtu(512);
        }
        print('✓ MTU set to $_currentMtu for $deviceName');
      } catch (e) {
        print('⚠ MTU request failed for $deviceName: $e');
      }

      // Discover services and subscribe to characteristics
      await _discoverAndSubscribe(device);

    } on TimeoutException {
      print('✗ Connection timeout for $deviceName');
      await _handleConnectionFailure(device, deviceId, attempt);
    } catch (e) {
      print('✗ Connection error for $deviceName: $e');
      await _handleConnectionFailure(device, deviceId, attempt);
    }
  }

  // Handle connection failure with retry
  Future<void> _handleConnectionFailure(
    fbp.BluetoothDevice device,
    String deviceId,
    int attempt,
  ) async {
    // Cleanup failed connection
    _cleanupDevice(deviceId);

    // Retry if under max attempts
    if (attempt < maxRetryAttempts && !_isDisposed) {
      await Future.delayed(retryDelay);
      await _connectToDevice(device, attempt: attempt + 1);
    } else {
      print('✗ Max retry attempts reached for ${device.platformName}');
      _updateState(BleConnectionState.disconnected);
    }
  }

  // Discover services and subscribe to characteristics
  Future<void> _discoverAndSubscribe(fbp.BluetoothDevice device) async {
    final deviceId = device.remoteId.toString();
    final deviceName = device.platformName.isNotEmpty ? device.platformName : deviceId;

    try {
      print('→ Discovering services for $deviceName...');

      final services = await device.discoverServices().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Service discovery timeout');
        },
      );

      _deviceServices[deviceId] = services;

      bool foundService = false;

      for (var service in services) {
        if (service.uuid.toString().toLowerCase() == serviceUuid.toLowerCase()) {
          foundService = true;
          print('✓ Found target service on $deviceName');

          for (var characteristic in service.characteristics) {
            if (characteristic.uuid.toString().toLowerCase() == characteristicUuid.toLowerCase()) {
              
              // Check if characteristic supports notify
              if (characteristic.properties.notify) {
                await _subscribeToCharacteristic(device, characteristic);
              } else {
                print('⚠ Characteristic does not support notifications on $deviceName');
              }
            }
          }
        }
      }

      if (!foundService) {
        print('⚠ Target service not found on $deviceName');
      }

    } on TimeoutException {
      print('✗ Service discovery timeout for $deviceName');
      _cleanupDevice(deviceId);
    } catch (e) {
      print('✗ Service discovery error for $deviceName: $e');
      _cleanupDevice(deviceId);
    }
  }

  // Subscribe to a characteristic for notifications
  Future<void> _subscribeToCharacteristic(
    fbp.BluetoothDevice device,
    fbp.BluetoothCharacteristic characteristic,
  ) async {
    final deviceId = device.remoteId.toString();
    final deviceName = device.platformName.isNotEmpty ? device.platformName : deviceId;

    try {
      // Enable notifications
      await characteristic.setNotifyValue(true);

      // Subscribe to value updates
      final sub = characteristic.lastValueStream.listen(
        (value) {
          if (!_isDisposed) {
            _handleReceivedData(deviceId, deviceName, value);
          }
        },
        onError: (error) {
          print('✗ Characteristic error for $deviceName: $error');
        },
        cancelOnError: false,
      );

      // Store subscription
      _characteristicSubscriptions.putIfAbsent(deviceId, () => []).add(sub);

      print('✓ Subscribed to characteristic on $deviceName');
    } catch (e) {
      print('✗ Failed to subscribe to characteristic on $deviceName: $e');
    }
  }

  // Handle received data from a device
  void _handleReceivedData(String deviceId, String deviceName, List<int> data) {
    if (data.isEmpty) return;

    try {
      final jsonString = utf8.decode(data);
      final reportData = jsonDecode(jsonString);
      final report = ReportModel.fromJson(reportData);

      // Check for duplicates
      if (_processedReportIds.contains(report.id)) {
        print('ℹ Duplicate report ${report.id} from $deviceName - ignored');
        return;
      }

      // Check hop count limit
      if (report.hopCount >= 5) {
        print('ℹ Report ${report.id} from $deviceName reached max hops - ignored');
        return;
      }

      // Mark as processed
      _processedReportIds.add(report.id);
      _cleanupOldReports();

      print('✓ Report ${report.id} received from $deviceName (hop: ${report.hopCount})');

      // Notify callback
      onReportReceived?.call(report);

      // Re-broadcast with incremented hop count
      _rebroadcastReport(report);

    } catch (e) {
      print('✗ Error processing data from $deviceName: $e');
      onError?.call('Error processing data: $e');
    }
  }

  // Re-broadcast received report
  Future<void> _rebroadcastReport(ReportModel report) async {
    if (_isDisposed || _isBroadcasting) return;

    try {
      final rebroadcastReport = report.copyWith(
        hopCount: report.hopCount + 1,
      );

      await broadcastReport(
        rebroadcastReport,
        duration: const Duration(seconds: 10),
      );

      print('✓ Re-broadcasting report ${report.id} (hop: ${rebroadcastReport.hopCount})');
    } catch (e) {
      print('✗ Re-broadcast error: $e');
    }
  }

  // Broadcast a report to nearby devices
  Future<void> broadcastReport(
    ReportModel report, {
    Duration duration = const Duration(seconds: 10),
  }) async {
    if (_isDisposed) return;

    try {
      // Stop any existing broadcast
      await stopBroadcasting();

      _isBroadcasting = true;
      _updateState(BleConnectionState.broadcasting);

      // Send to all connected devices
      await _sendReportToConnectedDevices(report);

      // Auto-stop after duration
      _broadcastTimer = Timer(duration, () {
        if (!_isDisposed) stopBroadcasting();
      });

      print('✓ Broadcasting report ${report.id} for ${duration.inSeconds}s');
    } catch (e) {
      print('✗ Broadcast error: $e');
      _isBroadcasting = false;
      onError?.call('Broadcast error: $e');
      rethrow;
    }
  }

  // Send report to all connected devices
  Future<void> _sendReportToConnectedDevices(ReportModel report) async {
    final reportJson = jsonEncode(report.toJson());
    final reportBytes = utf8.encode(reportJson);

    print('→ Sending report to ${_connectedDevices.length} connected devices (${reportBytes.length} bytes)');

    for (var entry in _connectedDevices.entries) {
      try {
        await _sendDataToDevice(entry.value, reportBytes);
      } catch (e) {
        print('✗ Failed to send to ${entry.value.platformName}: $e');
      }
    }
  }

  // Send data to a specific device
  Future<void> _sendDataToDevice(fbp.BluetoothDevice device, List<int> data) async {
    final deviceId = device.remoteId.toString();
    final services = _deviceServices[deviceId];

    if (services == null) {
      throw Exception('No services discovered for device');
    }

    for (var service in services) {
      if (service.uuid.toString().toLowerCase() == serviceUuid.toLowerCase()) {
        for (var characteristic in service.characteristics) {
          if (characteristic.uuid.toString().toLowerCase() == characteristicUuid.toLowerCase()) {
            
            if (characteristic.properties.write || characteristic.properties.writeWithoutResponse) {
              // Send data in chunks if needed
              if (data.length > chunkSize) {
                await _sendDataInChunks(characteristic, data);
              } else {
                await characteristic.write(data, withoutResponse: characteristic.properties.writeWithoutResponse);
              }
              
              print('✓ Data sent to ${device.platformName}');
              return;
            }
          }
        }
      }
    }

    throw Exception('No writable characteristic found');
  }

  // Send data in chunks for large payloads
  Future<void> _sendDataInChunks(fbp.BluetoothCharacteristic characteristic, List<int> data) async {
    final chunks = <List<int>>[];
    for (var i = 0; i < data.length; i += chunkSize) {
      final end = (i + chunkSize < data.length) ? i + chunkSize : data.length;
      chunks.add(data.sublist(i, end));
    }

    print('→ Sending ${chunks.length} chunks...');

    for (var i = 0; i < chunks.length; i++) {
      await characteristic.write(
        chunks[i],
        withoutResponse: characteristic.properties.writeWithoutResponse,
      );
      
      // Small delay between chunks
      if (i < chunks.length - 1) {
        await Future.delayed(const Duration(milliseconds: 50));
      }
    }

    print('✓ All chunks sent');
  }

  // Stop broadcasting
  Future<void> stopBroadcasting() async {
    _broadcastTimer?.cancel();
    _broadcastTimer = null;
    _isBroadcasting = false;

    if (_connectionState == BleConnectionState.broadcasting) {
      _updateState(BleConnectionState.connected);
    }

    print('✓ Broadcasting stopped');
  }

  // Cleanup a specific device
  void _cleanupDevice(String deviceId) {
    try {
      // Cancel connection subscription
      _connectionSubscriptions[deviceId]?.cancel();
      _connectionSubscriptions.remove(deviceId);

      // Cancel all characteristic subscriptions
      _characteristicSubscriptions[deviceId]?.forEach((sub) => sub.cancel());
      _characteristicSubscriptions.remove(deviceId);

      // Remove services
      _deviceServices.remove(deviceId);

      // Disconnect device
      final device = _connectedDevices.remove(deviceId);
      device?.disconnect().catchError((e) {
        print('⚠ Error disconnecting device $deviceId: $e');
      });

      print('✓ Device $deviceId cleaned up');
    } catch (e) {
      print('✗ Error cleaning up device $deviceId: $e');
    }
  }

  // Disconnect all devices
  void _disconnectAllDevices() {
    final deviceIds = _connectedDevices.keys.toList();
    for (var deviceId in deviceIds) {
      _cleanupDevice(deviceId);
    }
    print('✓ All devices disconnected');
  }

  // Cleanup old processed reports to prevent memory bloat
  void _cleanupOldReports() {
    if (_processedReportIds.length > maxProcessedReports) {
      final removeCount = _processedReportIds.length - (maxProcessedReports ~/ 2);
      final toRemove = _processedReportIds.take(removeCount).toList();
      _processedReportIds.removeAll(toRemove);
      print('ℹ Cleaned up $removeCount old report IDs');
    }
  }

  // Update state and notify listeners
  void _updateState(BleConnectionState newState) {
    if (_connectionState != newState) {
      _connectionState = newState;
      onStateChanged?.call(newState);
    }
  }

  // Check if a report has been processed
  bool isReportProcessed(String reportId) {
    return _processedReportIds.contains(reportId);
  }

  // Get number of connected devices
  int get connectedDeviceCount => _connectedDevices.length;

  // Check if currently broadcasting
  bool get isBroadcasting => _isBroadcasting;

  // Dispose and cleanup all resources
  Future<void> dispose() async {
    if (_isDisposed) return;

    _isDisposed = true;
    print('→ Disposing BluetoothService...');

    try {
      // Stop scanning
      await stopScanning();

      // Stop broadcasting
      await stopBroadcasting();

      // Disconnect all devices
      _disconnectAllDevices();

      // Close stream controller
      if (!_scanResultsController.isClosed) {
        await _scanResultsController.close();
      }

      // Clear caches
      _processedReportIds.clear();
      _deviceServices.clear();

      print('✓ BluetoothService disposed successfully');
    } catch (e) {
      print('✗ Error during disposal: $e');
    }
  }
}
