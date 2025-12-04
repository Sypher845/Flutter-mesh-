import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'dart:async';

import 'models/bluetooth_constants.dart';
import 'payload_handler.dart';

/// Manages mesh network operations including rebroadcasting and UUID tracking
class MeshNetworkManager {
  final PayloadHandler _payloadHandler;
  final Set<String> _receivedReportUUIDs = {};
  
  // Callbacks
  Function(String message)? onStatusUpdate;
  Function()? onDataChanged;

  MeshNetworkManager(this._payloadHandler);

  /// Get the number of tracked report UUIDs
  int get receivedReportCount => _receivedReportUUIDs.length;

  /// Check if a report UUID has already been received
  bool hasReceivedReport(String uuid) {
    return _receivedReportUUIDs.contains(uuid);
  }

  /// Add a report UUID to the tracking set
  void addReceivedReport(String uuid) {
    _receivedReportUUIDs.add(uuid);
    _cleanupOldUUIDs();
  }

  /// Clear all received report UUIDs
  void clearReceivedUUIDs() {
    _receivedReportUUIDs.clear();
    onDataChanged?.call();
  }

  /// Validate hop count and check if report should be rebroadcasted
  bool shouldRebroadcast(Map<String, dynamic> reportData) {
    final hopCount = reportData['hopCount'] as int? ?? 0;
    final maxHops = reportData['maxHops'] as int? ?? BluetoothConstants.maxHops;
    
    if (hopCount >= maxHops) {
      if (kDebugMode) {
        print('⏭️  Report reached max hops ($hopCount/$maxHops), not rebroadcasting');
      }
      return false;
    }
    
    return true;
  }

  /// Rebroadcast a report to other connected devices
  Future<void> rebroadcastReport(
    Map<String, dynamic> reportData,
    String sourceEndpointId,
    Set<String> connectedDevices,
  ) async {
    // Run rebroadcast asynchronously without blocking
    Future.microtask(() async {
      try {
        // Small delay to ensure we don't rebroadcast before fully processing
        await Future.delayed(
          Duration(milliseconds: BluetoothConstants.rebroadcastDelay)
        );
        
        // Get current connected devices (snapshot)
        final currentDevices = Set<String>.from(connectedDevices);
        
        // Get all connected devices except the one we received from
        final devicesToRebroadcast = currentDevices
            .where((id) => id != sourceEndpointId)
            .toList();
        
        if (devicesToRebroadcast.isEmpty) {
          if (kDebugMode) {
            print('🔄 No devices to rebroadcast to (total connected: ${currentDevices.length})');
          }
          return;
        }
        
        // Increment hop count before rebroadcasting
        final modifiedReportData = Map<String, dynamic>.from(reportData);
        final currentHopCount = modifiedReportData['hopCount'] as int? ?? 0;
        modifiedReportData['hopCount'] = currentHopCount + 1;
        
        if (kDebugMode) {
          print('');
          print('🔄 ═══════════════════════════════════════════════════');
          print('🔄 MESH REBROADCAST INITIATED');
          print('🔄 ═══════════════════════════════════════════════════');
          print('   Report UUID: ${reportData['report']?['id'] ?? 'Unknown'}');
          print('   Source endpoint: $sourceEndpointId');
          print('   Target devices: ${devicesToRebroadcast.length}');
          print('   Device IDs: $devicesToRebroadcast');
          print('   Hop count: $currentHopCount → ${currentHopCount + 1}');
          print('   Max hops: ${reportData['maxHops'] ?? 5}');
          print('🔄 ═══════════════════════════════════════════════════');
        }
        
        // Prepare the payload once with incremented hop count
        final jsonString = jsonEncode(modifiedReportData);
        final bytes = Uint8List.fromList(utf8.encode(jsonString));
        
        int successCount = 0;
        int failCount = 0;
        final sendFutures = <Future>[];
        
        // Send to all devices with retry logic
        for (final deviceId in devicesToRebroadcast) {
          // Verify device is still connected before sending
          if (!connectedDevices.contains(deviceId)) {
            if (kDebugMode) {
              print('   ⏭️  Skipping disconnected device: $deviceId');
            }
            continue;
          }
          
          // Send with retry
          sendFutures.add(
            _payloadHandler.sendWithRetry(deviceId, bytes, maxRetries: 2).then((_) {
              successCount++;
              if (kDebugMode) {
                print('   ✅ Rebroadcast success to: $deviceId');
              }
            }).catchError((e) {
              failCount++;
              if (kDebugMode) {
                print('   ❌ Rebroadcast failed to: $deviceId - Error: $e');
              }
            })
          );
        }
        
        // Wait for all sends to complete (with timeout)
        try {
          await Future.wait(sendFutures).timeout(
            Duration(milliseconds: BluetoothConstants.rebroadcastTimeout),
            onTimeout: () {
              if (kDebugMode) {
                print('⚠️  Rebroadcast timeout - some sends may not have completed');
              }
              return <dynamic>[];
            },
          );
        } catch (e) {
          if (kDebugMode) {
            print('⚠️  Rebroadcast error during wait: $e');
          }
        }
        
        if (kDebugMode) {
          print('');
          print('🔄 ═══════════════════════════════════════════════════');
          print('🔄 MESH REBROADCAST COMPLETE');
          print('🔄 ═══════════════════════════════════════════════════');
          print('   Success: $successCount/${devicesToRebroadcast.length}');
          print('   Failed: $failCount/${devicesToRebroadcast.length}');
          print('   New hop count: ${modifiedReportData['hopCount']}');
          print('🔄 ═══════════════════════════════════════════════════');
          print('');
        }
        
        if (successCount > 0) {
          _updateStatus('🔄 Rebroadcasted report to $successCount device(s) (hop ${modifiedReportData['hopCount']})');
        } else if (failCount > 0) {
          if (kDebugMode) {
            print('⚠️  Rebroadcast failed to all $failCount devices');
          }
        }
      } catch (e) {
        if (kDebugMode) {
          print('❌ Rebroadcast error: $e');
        }
      }
    });
  }

  /// Clean up old UUIDs to prevent memory growth
  void _cleanupOldUUIDs() {
    if (_receivedReportUUIDs.length > BluetoothConstants.maxTrackedUUIDs) {
      final oldestUUIDs = _receivedReportUUIDs
          .take(BluetoothConstants.uuidCleanupCount)
          .toList();
      _receivedReportUUIDs.removeAll(oldestUUIDs);
      
      if (kDebugMode) {
        print('🧹 Cleaned up ${oldestUUIDs.length} old UUIDs');
      }
    }
  }

  void _updateStatus(String message) {
    onStatusUpdate?.call(message);
  }
}
