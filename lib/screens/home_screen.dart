import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/bluetooth/bluetooth_service.dart';
import '../providers/report_provider.dart';
import '../models/report_model.dart';
import 'create_report_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final BluetoothService _bluetoothService = BluetoothService();
  bool _isInitializing = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeBluetooth();
  }

  Future<void> _initializeBluetooth() async {
    try {
      setState(() {
        _isInitializing = true;
        _errorMessage = null;
      });

      // Set up callbacks before any operations
      _setupBluetoothCallbacks();

      // The bluetooth service auto-initializes in receiver mode
      // Just wait a moment for it to be ready
      await Future.delayed(Duration(milliseconds: 500));

      setState(() => _isInitializing = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Bluetooth initialized - Ready to receive reports'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isInitializing = false;
        _errorMessage = e.toString();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✗ Bluetooth error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  void _setupBluetoothCallbacks() {
    // Listen to status messages
    _bluetoothService.addListener(() {
      if (!mounted) return;
      
      final status = _bluetoothService.statusMessage;
      if (status.isNotEmpty) {
        // Status messages are already shown by the service
        // We can add additional UI updates here if needed
      }
    });

    // Listen for received data to extract reports
    _bluetoothService.addListener(() {
      if (!mounted) return;
      
      // Check for new reports in received data
      for (final receivedData in _bluetoothService.receivedDataList) {
        final data = receivedData.data;
        final dataType = data['type'] as String?;
        
        if (dataType == 'report_data' || dataType == 'ticket_data') {
          final reportJson = data['report'] as Map<String, dynamic>? ?? 
                            data['ticket'] as Map<String, dynamic>?;
          
          if (reportJson != null) {
            try {
              // Extract image if present
              final imageBase64 = reportJson['imageBase64'] as String?;
              
              final report = ReportModel.fromJson(reportJson);
              _handleReportReceived(report, imageBase64);
            } catch (e) {
              // Ignore parsing errors
            }
          }
        }
      }
    });
  }

  // Store received images separately (since ReportModel doesn't store base64)
  final Map<String, Uint8List> _reportImages = {};

  void _handleReportReceived(ReportModel report, String? imageBase64) {
    if (!mounted) return;

    final provider = Provider.of<ReportProvider>(context, listen: false);
    final added = provider.addReport(report);

    // Store image if present
    if (imageBase64 != null && imageBase64.isNotEmpty) {
      try {
        _reportImages[report.id] = base64Decode(imageBase64);
      } catch (e) {
        // Ignore image decode errors
      }
    }

    if (added) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('📥 Report received: ${report.title}\n(Hop: ${report.hopCount})${imageBase64 != null ? " 📷" : ""}'),
          backgroundColor: Colors.blue,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }



  Color _getHopColor(int hopCount) {
    // Color gradient based on hop count
    if (hopCount == 0) return Colors.green;
    if (hopCount == 1) return Colors.blue;
    if (hopCount == 2) return Colors.orange;
    if (hopCount >= 3) return Colors.red;
    return Colors.grey;
  }

  @override
  void dispose() {
    _bluetoothService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Initializing Bluetooth...'),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  'Bluetooth Error',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _initializeBluetooth,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('BLE Report Mesh'),
        actions: [
          // Show connection status
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Row(
                children: [
                  Icon(
                    _bluetoothService.connectedDevices.isEmpty 
                        ? Icons.bluetooth_searching 
                        : Icons.bluetooth_connected,
                    size: 20,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${_bluetoothService.connectedDevices.length}',
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _initializeBluetooth,
            tooltip: 'Restart Bluetooth',
          ),
        ],
      ),
      body: Consumer<ReportProvider>(
        builder: (context, provider, child) {
          if (provider.reports.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No reports yet'),
                  SizedBox(height: 8),
                  Text(
                    'Create a report or wait to receive one',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: provider.reports.length,
            itemBuilder: (context, index) {
              final report = provider.reports[index];
              final imageBytes = _reportImages[report.id] ?? 
                                report.imageFile?.readAsBytesSync();
              
              return Card(
                margin: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Image if available
                    if (imageBytes != null)
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                        child: Image.memory(
                          imageBytes,
                          width: double.infinity,
                          height: 200,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              height: 200,
                              color: Colors.grey[300],
                              child: const Center(
                                child: Icon(Icons.broken_image, size: 48, color: Colors.grey),
                              ),
                            );
                          },
                        ),
                      ),
                    
                    // Report details
                    ListTile(
                      title: Row(
                        children: [
                          Expanded(child: Text(report.title, style: const TextStyle(fontWeight: FontWeight.bold))),
                          // Hop count badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _getHopColor(report.hopCount),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Hop: ${report.hopCount}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(report.description),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.location_on, size: 14, color: Colors.grey[600]),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  report.location?.formattedCoordinates ?? "No location",
                                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                ),
                              ),
                              Text(
                                '${report.createdAt.hour}:${report.createdAt.minute.toString().padLeft(2, '0')}',
                                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        ],
                      ),
                      isThreeLine: true,
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateReportScreen()),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}