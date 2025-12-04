import 'package:flutter/foundation.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'dart:convert';
import 'dart:async';

import 'models/bluetooth_constants.dart';

/// Handles sending and receiving payloads
class PayloadHandler {
  // Callbacks
  Function(String message)? onStatusUpdate;

  /// Send bytes payload to a device with retry logic
  Future<void> sendBytesPayload(
    String deviceId,
    Uint8List bytes,
    int payloadId, {
    int maxRetries = BluetoothConstants.maxRetries,
  }) async {
    if (kDebugMode) {
      print('📤 _sendToDeviceWithRetry starting for: $deviceId');
      print('   Payload size: ${bytes.length} bytes');
      print('   Payload ID: $payloadId');
    }
    
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        if (kDebugMode) {
          print('   Attempt $attempt: Calling sendBytesPayload...');
        }
        
        await Nearby().sendBytesPayload(deviceId, bytes);
        
        if (kDebugMode) {
          print('   ✅ Send succeeded on attempt $attempt for: $deviceId');
        }
        return; // Success
      } catch (e) {
        if (kDebugMode) {
          print('   ❌ Send attempt $attempt failed: $e');
        }
        
        if (attempt < maxRetries) {
          // Exponential backoff: 100ms, 200ms, 400ms
          final delayMs = 100 * (1 << (attempt - 1));
          await Future.delayed(Duration(milliseconds: delayMs));
          
          if (kDebugMode) {
            print('   🔄 Retrying after ${delayMs}ms...');
          }
        } else {
          if (kDebugMode) {
            print('   ❌ All retries exhausted for: $deviceId');
          }
          rethrow; // Final attempt failed
        }
      }
    }
  }

  /// Send a simple retry payload (for rebroadcast)
  Future<void> sendWithRetry(
    String deviceId,
    Uint8List bytes, {
    int maxRetries = 2,
  }) async {
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        await Nearby().sendBytesPayload(deviceId, bytes);
        return; // Success
      } catch (e) {
        if (attempt < maxRetries) {
          // Wait before retry with exponential backoff
          await Future.delayed(Duration(milliseconds: 50 * attempt));
        } else {
          rethrow; // Final attempt failed
        }
      }
    }
  }

  /// Send a connection ping to verify connection
  Future<void> sendConnectionPing(String endpointId) async {
    try {
      final pingData = {
        'type': BluetoothConstants.payloadTypePing,
        'senderId': 'device_${DateTime.now().millisecondsSinceEpoch}',
        'senderName': 'My Device',
        'timestamp': DateTime.now().toIso8601String(),
        'message': 'Connection test ping',
      };
      
      final jsonString = jsonEncode(pingData);
      final bytes = Uint8List.fromList(utf8.encode(jsonString));
      
      await Nearby().sendBytesPayload(endpointId, bytes);
    } catch (e) {
      // Ignore ping errors
      if (kDebugMode) {
        print('⚠️ Ping failed: $e');
      }
    }
  }

  /// Send acknowledgment for received payload
  Future<void> sendAcknowledgment(String endpointId, int payloadId) async {
    try {
      final ackData = {
        'type': BluetoothConstants.payloadTypeAck,
        'senderId': 'device_${DateTime.now().millisecondsSinceEpoch}',
        'senderName': 'My Device',
        'timestamp': DateTime.now().toIso8601String(),
        'payloadId': payloadId,
      };
      
      final jsonString = jsonEncode(ackData);
      final bytes = Uint8List.fromList(utf8.encode(jsonString));
      
      await Nearby().sendBytesPayload(endpointId, bytes);
    } catch (e) {
      // Ignore ack errors
      if (kDebugMode) {
        print('⚠️ ACK failed: $e');
      }
    }
  }

  /// Send a pre-send check to verify connection is responsive
  Future<void> sendPreSendCheck(String deviceId) async {
    final testPayload = {
      'type': BluetoothConstants.payloadTypePreSendCheck,
      'timestamp': DateTime.now().toIso8601String()
    };
    final testData = jsonEncode(testPayload);
    final testBytes = Uint8List.fromList(utf8.encode(testData));
    
    await Nearby().sendBytesPayload(deviceId, testBytes).timeout(
      Duration(milliseconds: BluetoothConstants.preSendCheckTimeout),
      onTimeout: () {
        throw TimeoutException('Pre-send check timeout');
      },
    );
  }

  /// Decode payload bytes to JSON
  Map<String, dynamic>? decodePayload(Payload payload) {
    try {
      if (payload.bytes == null || payload.bytes!.isEmpty) {
        _updateStatus('❌ Received empty payload');
        return null;
      }
      
      String jsonString;
      try {
        jsonString = utf8.decode(payload.bytes!);
      } catch (e) {
        try {
          jsonString = String.fromCharCodes(payload.bytes!);
        } catch (e2) {
          _updateStatus('❌ Invalid payload format');
          return null;
        }
      }
      
      final Map<String, dynamic> receivedData;
      try {
        receivedData = jsonDecode(jsonString) as Map<String, dynamic>;
      } catch (e) {
        _updateStatus('❌ Invalid JSON format received');
        return null;
      }
      
      return receivedData;
    } catch (e) {
      _updateStatus('❌ Error decoding payload');
      return null;
    }
  }

  /// Validate payload size
  bool validatePayloadSize(Uint8List bytes) {
    if (bytes.length > BluetoothConstants.maxPayloadSizeBytes) {
      _updateStatus(
        '❌ Payload too large (${(bytes.length / 1024).toStringAsFixed(1)} KB)'
      );
      if (kDebugMode) {
        print('❌ Payload exceeds size limit: ${bytes.length} bytes');
      }
      return false;
    }
    
    if (kDebugMode) {
      print('📦 Payload size: ${(bytes.length / 1024).toStringAsFixed(1)} KB');
    }
    
    return true;
  }

  /// Check if payload type should be ignored
  bool shouldIgnorePayload(String? dataType) {
    return dataType == BluetoothConstants.payloadTypePing ||
           dataType == BluetoothConstants.payloadTypeConnectionVerify ||
           dataType == BluetoothConstants.payloadTypePreSendCheck ||
           dataType == BluetoothConstants.payloadTypeAck;
  }

  void _updateStatus(String message) {
    onStatusUpdate?.call(message);
  }
}
