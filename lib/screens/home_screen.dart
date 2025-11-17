import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'dart:convert';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

import '../models/ticket_model.dart';
import '../services/data_sync_service.dart';
import '../services/bluetooth_service.dart';
import '../utils/test_helper.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _descriptionController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  File? _selectedImage;

  @override
  void initState() {
    super.initState();
    // Add listener to rebuild when text changes
    _descriptionController.addListener(() {
      setState(() {
        // Trigger rebuild when text changes
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Bluetooth Hopping App'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: Icon(Icons.help_outline),
            onPressed: () => TestHelper.showTestDialog(context),
            tooltip: 'Test Instructions',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildImageSection(),
            SizedBox(height: 20),
            _buildDescriptionSection(),
            SizedBox(height: 20),
            _buildSubmitButton(),
            SizedBox(height: 10),
            // Debug buttons for testing
            if (kDebugMode) ...[
              ElevatedButton(
                onPressed: () {
                  print('🧪 DEBUG: Test button pressed');
                  if (_descriptionController.text.trim().isEmpty) {
                    _descriptionController.text = 'Test ticket description';
                  }
                  _submitTicket();
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: Text('Test Submit (Debug)', style: TextStyle(color: Colors.white)),
              ),
              SizedBox(height: 5),
              ElevatedButton(
                onPressed: () {
                  final bluetooth = Provider.of<BluetoothService>(context, listen: false);
                  print('🧪 DEBUG: Force broadcast test');
                  print('🧪 DEBUG: Connected devices: ${bluetooth.connectedDevices.length}');
                  if (bluetooth.connectedDevices.isNotEmpty) {
                    bluetooth.broadcastCustomData({
                      'message': 'Test broadcast from debug button',
                      'timestamp': DateTime.now().toIso8601String(),
                    });
                  } else {
                    print('🧪 DEBUG: No devices to broadcast to');
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
                child: Text('Force Broadcast Test', style: TextStyle(color: Colors.white)),
              ),
              SizedBox(height: 5),
              ElevatedButton(
                onPressed: () {
                  final bluetooth = Provider.of<BluetoothService>(context, listen: false);
                  bluetooth.testPayloadReception();
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                child: Text('Test Payload Reception', style: TextStyle(color: Colors.white)),
              ),
              SizedBox(height: 5),
              ElevatedButton(
                onPressed: () {
                  final bluetooth = Provider.of<BluetoothService>(context, listen: false);
                  bluetooth.addTestTicket();
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo),
                child: Text('Add Test Ticket', style: TextStyle(color: Colors.white)),
              ),
              SizedBox(height: 5),
              ElevatedButton(
                onPressed: () {
                  final bluetooth = Provider.of<BluetoothService>(context, listen: false);
                  bluetooth.addTestTicketWithImage();
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                child: Text('Add Test Ticket + Image', style: TextStyle(color: Colors.white)),
              ),
              SizedBox(height: 5),
              ElevatedButton(
                onPressed: () {
                  final bluetooth = Provider.of<BluetoothService>(context, listen: false);
                  print('🧪 DEBUG: Current state check');
                  print('  - Advertising: ${bluetooth.isAdvertising}');
                  print('  - Discovering: ${bluetooth.isDiscovering}');
                  print('  - Connected: ${bluetooth.connectedDevices.length}');
                  print('  - Received: ${bluetooth.receivedDataList.length}');
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Check console for debug info'),
                      backgroundColor: Colors.purple,
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
                child: Text('Debug State Check', style: TextStyle(color: Colors.white)),
              ),
              SizedBox(height: 5),
              ElevatedButton(
                onPressed: () async {
                  final bluetooth = Provider.of<BluetoothService>(context, listen: false);
                  print('🧪 DEBUG: Testing connection health');
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Testing connection health...'),
                      backgroundColor: Colors.blue,
                    ),
                  );
                  
                  await bluetooth.checkConnectionHealth();
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Health check complete - ${bluetooth.connectedDevices.length} healthy connections'),
                      backgroundColor: Colors.green,
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.cyan),
                child: Text('Test Connection Health', style: TextStyle(color: Colors.white)),
              ),
              SizedBox(height: 5),
              ElevatedButton(
                onPressed: () {
                  final bluetooth = Provider.of<BluetoothService>(context, listen: false);
                  print('🧪 DEBUG: Testing complete reception pipeline');
                  
                  bluetooth.testCompleteReceptionPipeline();
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Pipeline test complete - check received data section'),
                      backgroundColor: Colors.purple,
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple),
                child: Text('Test Reception Pipeline', style: TextStyle(color: Colors.white)),
              ),
            ],
            SizedBox(height: 20),
            _buildStatusMessages(),
            SizedBox(height: 20),
            _buildEmulatorWarning(),
            SizedBox(height: 20),
            _buildBluetoothControls(),
            SizedBox(height: 20),
            _buildReceivedData(),
            SizedBox(height: 20),
            _buildTicketsList(),
          ],
        ),
      ),
    );
  }



  Widget _buildImageSection() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Upload Image', style: Theme.of(context).textTheme.titleMedium),
            SizedBox(height: 10),
            if (_selectedImage != null) ...[
              Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(_selectedImage!, fit: BoxFit.cover),
                ),
              ),
              SizedBox(height: 8),
              FutureBuilder<int>(
                future: _selectedImage!.length(),
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    final sizeKB = snapshot.data! / 1024;
                    final color = sizeKB > 200 ? Colors.red : (sizeKB > 100 ? Colors.orange : Colors.green);
                    final icon = sizeKB > 200 ? Icons.warning : Icons.check_circle;
                    return Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: color.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(icon, size: 14, color: color),
                          SizedBox(width: 4),
                          Text(
                            'Size: ${sizeKB.toStringAsFixed(1)} KB${sizeKB > 200 ? ' (Too large!)' : sizeKB > 100 ? ' (May fail)' : ' (Good)'}',
                            style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    );
                  }
                  return SizedBox.shrink();
                },
              ),
              SizedBox(height: 10),
            ],
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _pickImage(ImageSource.camera),
                    icon: Icon(Icons.camera_alt),
                    label: Text('Camera'),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _pickImage(ImageSource.gallery),
                    icon: Icon(Icons.photo_library),
                    label: Text('Gallery'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDescriptionSection() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Description', style: Theme.of(context).textTheme.titleMedium),
            SizedBox(height: 10),
            TextField(
              controller: _descriptionController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Enter ticket description...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return Consumer2<DataSyncService, BluetoothService>(
      builder: (context, dataSync, bluetooth, child) {
        final canSubmit = _canSubmit();
        print('🔍 DEBUG: Building submit button, canSubmit = $canSubmit');
        
        return ElevatedButton(
          onPressed: canSubmit ? () {
            print('🎫 DEBUG: Submit button pressed');
            _submitTicket();
          } : null,
          style: ElevatedButton.styleFrom(
            padding: EdgeInsets.symmetric(vertical: 16),
            backgroundColor: canSubmit ? Theme.of(context).primaryColor : Colors.grey,
            foregroundColor: Colors.white,
          ),
          child: Text(
            'Create Ticket for Bluetooth Hopping',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        );
      },
    );
  }

  Widget _buildStatusMessages() {
    return Consumer2<DataSyncService, BluetoothService>(
      builder: (context, dataSync, bluetooth, child) {
        final messages = [
          if (dataSync.statusMessage.isNotEmpty) dataSync.statusMessage,
          if (bluetooth.statusMessage.isNotEmpty) bluetooth.statusMessage,
        ];

        if (messages.isEmpty) return SizedBox.shrink();

        return Card(
          color: Colors.blue[50],
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: messages.map((message) => 
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(Icons.info, color: Colors.blue, size: 20),
                      SizedBox(width: 8),
                      Expanded(child: Text(message)),
                    ],
                  ),
                ),
              ).toList(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBluetoothControls() {
    return Consumer<BluetoothService>(
      builder: (context, bluetooth, child) {

        return Card(
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Bluetooth Hopping Controls', style: Theme.of(context).textTheme.titleMedium),
                SizedBox(height: 10),
                Text('Use Bluetooth to hop data to nearby devices running this app.'),
            SizedBox(height: 8),
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                border: Border.all(color: Colors.orange),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Note: Only finds devices running this same app that are advertising',
                style: TextStyle(fontSize: 12, color: Colors.orange[800]),
              ),
            ),
                SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: bluetooth.isAdvertising 
                          ? bluetooth.stopAdvertising 
                          : bluetooth.startAdvertising,
                        child: Text(bluetooth.isAdvertising ? 'Stop Advertising' : 'Start Advertising'),
                      ),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: bluetooth.isDiscovering 
                          ? bluetooth.stopDiscovery 
                          : bluetooth.startDiscovery,
                        child: Text(bluetooth.isDiscovering ? 'Stop Discovery' : 'Find Devices'),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: () async {
                    await bluetooth.checkBluetoothStatus();
                  },
                  icon: Icon(Icons.bug_report),
                  label: Text('Debug Status'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
                ),
                SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: () => _showTestingInstructions(context),
                  icon: Icon(Icons.help),
                  label: Text('How to Test'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                ),
                if (kDebugMode) ...[
                  SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: () {
                      // Simulate finding a device for testing
                      final bluetooth = Provider.of<BluetoothService>(context, listen: false);
                      bluetooth.simulateDeviceFound();
                    },
                    icon: Icon(Icons.android),
                    label: Text('Simulate Device Found (Debug)'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                  ),
                ],
                // Add broadcast button for advertisers
                if (bluetooth.isAdvertising && bluetooth.connectedDevices.isNotEmpty) ...[
                  SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: () => _showBroadcastDialog(context),
                    icon: Icon(Icons.broadcast_on_personal),
                    label: Text('Broadcast Message (${bluetooth.connectedDevices.length} devices)'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  ),
                ],
                SizedBox(height: 10),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: bluetooth.connectedDevices.isNotEmpty ? Colors.green[50] : Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: bluetooth.connectedDevices.isNotEmpty ? Colors.green[300]! : Colors.grey[300]!,
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(
                            bluetooth.isDiscovering ? Icons.search : Icons.search_off,
                            color: bluetooth.isDiscovering ? Colors.blue : Colors.grey,
                            size: 16,
                          ),
                          SizedBox(width: 4),
                          Text('Discovery: ${bluetooth.isDiscovering ? "Active" : "Inactive"}'),
                          SizedBox(width: 16),
                          Icon(
                            bluetooth.isAdvertising ? Icons.broadcast_on_personal : Icons.portable_wifi_off,
                            color: bluetooth.isAdvertising ? Colors.green : Colors.grey,
                            size: 16,
                          ),
                          SizedBox(width: 4),
                          Text('Advertising: ${bluetooth.isAdvertising ? "Active" : "Inactive"}'),
                        ],
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            bluetooth.connectedDevices.isNotEmpty ? Icons.devices : Icons.devices_other,
                            color: bluetooth.connectedDevices.isNotEmpty ? Colors.green : Colors.grey,
                            size: 16,
                          ),
                          SizedBox(width: 4),
                          Expanded(
                            child: Text('Connected: ${bluetooth.connectedDevices.length} devices'),
                          ),
                          if (bluetooth.connectedDevices.isNotEmpty) ...[
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.green[100],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check_circle, color: Colors.green[700], size: 14),
                                  SizedBox(width: 4),
                                  Text(
                                    'Ready to Send',
                                    style: TextStyle(
                                      color: Colors.green[700],
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                if (bluetooth.connectedDevices.isNotEmpty) ...[
                  SizedBox(height: 10),
                  Text('Connected devices: ${bluetooth.connectedDevices.length}'),
                ],
                if (bluetooth.statusMessage.contains('❌') && bluetooth.statusMessage.contains('permissions')) ...[
                  SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: () async {
                      await openAppSettings();
                    },
                    icon: Icon(Icons.settings),
                    label: Text('Open App Settings'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTicketsList() {
    return Consumer<DataSyncService>(
      builder: (context, dataSync, child) {
        if (dataSync.tickets.isEmpty) return SizedBox.shrink();

        return Card(
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Tickets (${dataSync.tickets.length})', 
                         style: Theme.of(context).textTheme.titleMedium),
                    TextButton(
                      onPressed: dataSync.clearAllTickets,
                      child: Text('Clear All'),
                    ),
                  ],
                ),
                SizedBox(height: 10),
                ...dataSync.tickets.map((ticket) => 
                  ListTile(
                    leading: Icon(_getStatusIcon(ticket.status)),
                    title: Text(ticket.description),
                    subtitle: Text('Created: ${ticket.createdAt.toString().substring(0, 16)}'),
                    trailing: Text(_getStatusText(ticket.status)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1024,  // Limit width to reduce size
        maxHeight: 1024, // Limit height to reduce size
        imageQuality: 85, // Reduce quality slightly (85 is good balance)
      );
      
      if (image != null) {
        print('🖼️ IMAGE DEBUG: Original image path: ${image.path}');
        
        // Get file size
        final originalFile = File(image.path);
        final originalSize = await originalFile.length();
        print('🖼️ IMAGE DEBUG: Original size: ${(originalSize / 1024).toStringAsFixed(2)} KB');
        
        // Further compress the image if needed
        final compressedFile = await _compressImage(originalFile);
        
        if (compressedFile != null) {
          final compressedSize = await compressedFile.length();
          print('🖼️ IMAGE DEBUG: Compressed size: ${(compressedSize / 1024).toStringAsFixed(2)} KB');
          print('🖼️ IMAGE DEBUG: Compression ratio: ${((1 - compressedSize / originalSize) * 100).toStringAsFixed(1)}%');
          
          setState(() {
            _selectedImage = compressedFile;
          });
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Image compressed: ${(compressedSize / 1024).toStringAsFixed(1)} KB'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
          }
        } else {
          // Fallback to original if compression fails
          setState(() {
            _selectedImage = originalFile;
          });
        }
      }
    } catch (e) {
      print('❌ IMAGE ERROR: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }

  // Compress image to reduce size for Bluetooth transmission
  Future<File?> _compressImage(File imageFile) async {
    try {
      print('🖼️ COMPRESSION: Starting image compression...');
      
      // Read the image file
      final imageBytes = await imageFile.readAsBytes();
      
      // Decode the image
      img.Image? image = img.decodeImage(imageBytes);
      
      if (image == null) {
        print('❌ COMPRESSION: Failed to decode image');
        return null;
      }
      
      print('🖼️ COMPRESSION: Original dimensions: ${image.width}x${image.height}');
      
      // Resize if image is too large (max 800x800 for Bluetooth)
      if (image.width > 800 || image.height > 800) {
        image = img.copyResize(
          image,
          width: image.width > image.height ? 800 : null,
          height: image.height > image.width ? 800 : null,
        );
        print('🖼️ COMPRESSION: Resized to: ${image.width}x${image.height}');
      }
      
      // Compress as JPEG with quality 85
      final compressedBytes = img.encodeJpg(image, quality: 85);
      print('🖼️ COMPRESSION: Compressed to ${(compressedBytes.length / 1024).toStringAsFixed(2)} KB');
      
      // Save compressed image to temp file
      final tempDir = await getTemporaryDirectory();
      final fileName = 'compressed_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final compressedFile = File(path.join(tempDir.path, fileName));
      await compressedFile.writeAsBytes(compressedBytes);
      
      print('✅ COMPRESSION: Image compressed successfully');
      return compressedFile;
      
    } catch (e) {
      print('❌ COMPRESSION ERROR: $e');
      return null;
    }
  }

  bool _canSubmit() {
    final canSubmit = _descriptionController.text.trim().isNotEmpty;
    print('🔍 DEBUG: _canSubmit() = $canSubmit, text = "${_descriptionController.text}"');
    return canSubmit;
  }

  Future<void> _submitTicket() async {
    print('🎫 SUBMIT: Starting ticket submission...');
    
    final description = _descriptionController.text.trim();
    if (description.isEmpty) {
      print('❌ SUBMIT: Empty description');
      _showMessage('❌ Please enter a description', Colors.red);
      return;
    }

    // Create ticket
    final ticket = TicketModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      description: description,
      imageFile: _selectedImage,
      imagePath: _selectedImage?.path,
      createdAt: DateTime.now(),
    );

    print('🎫 SUBMIT: Created ticket ID: ${ticket.id}');
    print('🎫 SUBMIT: Has image: ${ticket.imageFile != null}');

    final dataSync = Provider.of<DataSyncService>(context, listen: false);
    final bluetooth = Provider.of<BluetoothService>(context, listen: false);

    // Save locally first
    try {
      await dataSync.addTicket(ticket);
      print('🎫 SUBMIT: Saved locally');
    } catch (e) {
      print('❌ SUBMIT: Local save failed: $e');
      _showMessage('❌ Failed to save ticket', Colors.red);
      return;
    }

    // Check for connected devices and verify connections
    final deviceCount = bluetooth.connectedDevices.length;
    print('🎫 SUBMIT: Connected devices: $deviceCount');
    
    if (deviceCount == 0) {
      print('🎫 SUBMIT: No devices connected, local only');
      _showMessage('📝 Ticket saved locally (no connected devices)', Colors.orange);
      _clearForm();
      return;
    }

    // Check connection health before sending
    print('🎫 SUBMIT: Checking connection health...');
    _showMessage('🔍 Verifying connections...', Colors.blue);
    
    try {
      await bluetooth.checkConnectionHealth();
      final healthyDeviceCount = bluetooth.connectedDevices.length;
      
      if (healthyDeviceCount == 0) {
        print('🎫 SUBMIT: No healthy connections found');
        _showMessage('❌ No active connections found', Colors.red);
        return;
      }
      
      if (healthyDeviceCount != deviceCount) {
        print('🎫 SUBMIT: Some connections were stale, now have $healthyDeviceCount healthy connections');
      }

      // Attempt to send
      print('🎫 SUBMIT: Attempting to send to $healthyDeviceCount devices...');
      _showMessage('📡 Sending to $healthyDeviceCount devices...', Colors.blue);

      await bluetooth.sendTicketData(ticket);
      print('🎫 SUBMIT: Send successful');
      _showMessage('✅ Ticket sent successfully!', Colors.green);
      
    } catch (e) {
      print('❌ SUBMIT: Send failed: $e');
      _showMessage('❌ Send failed: ${e.toString()}', Colors.red);
    }

    _clearForm();
  }

  void _showMessage(String message, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  void _clearForm() {
    _descriptionController.clear();
    setState(() {
      _selectedImage = null;
    });
    print('🎫 SUBMIT: Form cleared');
  }

  IconData _getStatusIcon(TicketStatus status) {
    switch (status) {
      case TicketStatus.pending:
        return Icons.pending;
      case TicketStatus.syncing:
        return Icons.sync;
      case TicketStatus.sent:
        return Icons.check_circle;
      case TicketStatus.failed:
        return Icons.error;
      case TicketStatus.bluetoothHopping:
        return Icons.bluetooth;
    }
  }

  String _getStatusText(TicketStatus status) {
    switch (status) {
      case TicketStatus.pending:
        return 'Pending';
      case TicketStatus.syncing:
        return 'Syncing...';
      case TicketStatus.sent:
        return 'Sent';
      case TicketStatus.failed:
        return 'Failed';
      case TicketStatus.bluetoothHopping:
        return 'Hopping...';
    }
  }

  Widget _buildEmulatorWarning() {
    // Simple check for emulator (not 100% accurate but good enough for development)
    if (!kDebugMode) return SizedBox.shrink();
    
    return Card(
      color: Colors.orange[100],
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Emulator Detected',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Bluetooth/NFC features are limited on emulators. Use physical devices for full testing.',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showTestingInstructions(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('How to Test Bluetooth Discovery'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Nearby Connections only finds devices running this SAME app:', 
                   style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 10),
              Text('1. Install this app on a second device'),
              Text('2. On Device A: Tap "Start Advertising"'),
              Text('3. On Device B: Tap "Find Devices"'),
              Text('4. Device B should find Device A within 30 seconds'),
              SizedBox(height: 10),
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  border: Border.all(color: Colors.red),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Will NOT find:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                    Text('• Regular Bluetooth devices (headphones, speakers)', style: TextStyle(color: Colors.red)),
                    Text('• Devices without this app', style: TextStyle(color: Colors.red)),
                    Text('• Devices not advertising', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
              SizedBox(height: 10),
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  border: Border.all(color: Colors.green),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Will find:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                    Text('• Devices running this exact app', style: TextStyle(color: Colors.green)),
                    Text('• Devices actively advertising', style: TextStyle(color: Colors.green)),
                    Text('• Same service ID: com.yourapp.offlineSync', style: TextStyle(color: Colors.green, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Got it!'),
          ),
        ],
      ),
    );
  }

  Widget _buildReceivedData() {
    return Consumer<BluetoothService>(
      builder: (context, bluetooth, child) {
        final itemCount = bluetooth.receivedDataList.length;
        print('🖥️ UI: Building received data section, items: $itemCount');
        
        return Card(
          elevation: 2,
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Received Data ($itemCount)',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: itemCount > 0 ? Colors.green[700] : Colors.grey[600],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Row(
                      children: [
                        if (kDebugMode)
                          TextButton(
                            onPressed: () {
                              print('🔄 UI: Manual refresh');
                              setState(() {});
                            },
                            child: Text('Refresh'),
                          ),
                        if (itemCount > 0)
                          TextButton(
                            onPressed: () {
                              bluetooth.clearReceivedData();
                            },
                            child: Text('Clear All'),
                          ),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: 12),
                
                // Content
                if (itemCount == 0) ...[
                  // Empty state
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.inbox_outlined, size: 48, color: Colors.grey[400]),
                        SizedBox(height: 8),
                        Text(
                          'No data received yet',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[600],
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Connect to other devices to receive tickets',
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  // Data items
                  ...bluetooth.receivedDataList.reversed.take(10).map((receivedData) => 
                    Container(
                      margin: EdgeInsets.only(bottom: 12),
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        border: Border.all(color: Colors.green[200]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header
                          Row(
                            children: [
                              Icon(Icons.download_done, color: Colors.green[600], size: 18),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'From: ${receivedData.senderName}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green[800],
                                  ),
                                ),
                              ),
                              Text(
                                '${receivedData.receivedAt.hour.toString().padLeft(2, '0')}:${receivedData.receivedAt.minute.toString().padLeft(2, '0')}',
                                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                              ),
                            ],
                          ),
                          SizedBox(height: 8),
                          // Content
                          _buildReceivedDataContent(receivedData.data),
                        ],
                      ),
                    ),
                  ),
                  
                  // Show more indicator
                  if (itemCount > 10)
                    Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        '... and ${itemCount - 10} more items',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildReceivedDataContent(Map<String, dynamic> data) {
    final type = data['type'] as String?;
    
    print('🖥️ UI DEBUG: Building content for data type: $type');
    print('🖥️ UI DEBUG: Data keys: ${data.keys.toList()}');
    
    // CRITICAL FIX: More flexible data type matching
    // First check if it has ticket data regardless of type
    final ticket = data['ticket'] as Map<String, dynamic>?;
    if (ticket != null) {
      print('✅ UI DEBUG: Found ticket data, displaying');
      return _buildReceivedTicket(data);
    }
    
    // Check for ticket-related types (flexible matching)
    if (type != null && (type == 'ticket_data' || type == 'ticket_metadata' || type.contains('ticket'))) {
      print('✅ UI DEBUG: Ticket-related type detected: $type');
      return _buildReceivedTicket(data);
    }
    
    // Check for custom data/message
    if (type == 'custom_data' || data.containsKey('data')) {
      return _buildReceivedMessage(data);
    }
    
    // Fallback: try to display as generic message
    if (data.containsKey('message')) {
      return _buildReceivedMessage(data);
    }
    
    // Last resort: show raw data in a friendly way
    print('⚠️ UI DEBUG: Unknown format, showing raw data');
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        border: Border.all(color: Colors.blue[200]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue[700], size: 18),
              SizedBox(width: 6),
              Text(
                'Received Data',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue[700]),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            'Type: ${type ?? 'unknown'}',
            style: TextStyle(fontSize: 12, color: Colors.grey[700]),
          ),
          if (data.isNotEmpty) ...[
            SizedBox(height: 4),
            Text(
              'Content: ${data.toString().length > 100 ? data.toString().substring(0, 100) + '...' : data.toString()}',
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReceivedTicket(Map<String, dynamic> data) {
    print('🖥️ UI DEBUG: Building received ticket display');
    final ticket = data['ticket'] as Map<String, dynamic>?;
    
    if (ticket == null) {
      print('❌ UI DEBUG: Ticket data is null');
      return Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.red[50],
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text('❌ Invalid ticket data', style: TextStyle(color: Colors.red[700])),
      );
    }

    final description = ticket['description'] as String? ?? 'No description';
    final imageBase64 = ticket['imageBase64'] as String?;
    final createdAt = ticket['createdAt'] as String?;
    final ticketId = ticket['id'] as String? ?? 'Unknown ID';

    print('🖥️ UI DEBUG: Ticket details - ID: $ticketId, Has image: ${imageBase64 != null}, Description length: ${description.length}');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.receipt_long, color: Colors.green, size: 18),
            SizedBox(width: 6),
            Expanded(
              child: Text(
                'Ticket Received',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green[700], fontSize: 16),
              ),
            ),
            if (imageBase64 != null)
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.image, size: 12, color: Colors.blue[700]),
                    SizedBox(width: 2),
                    Text(
                      'Image',
                      style: TextStyle(fontSize: 10, color: Colors.blue[700]),
                    ),
                  ],
                ),
              ),
          ],
        ),
        SizedBox(height: 10),
        
        // Image display
        if (imageBase64 != null && imageBase64.isNotEmpty) ...[
          GestureDetector(
            onTap: () => _showFullImageFromBase64(context, imageBase64),
            child: Container(
              height: 150,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(
                  base64Decode(imageBase64),
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    print('❌ UI DEBUG: Error displaying image: $error');
                    return Container(
                      color: Colors.grey[200],
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.broken_image, color: Colors.grey[600], size: 32),
                            SizedBox(height: 4),
                            Text(
                              'Image Error',
                              style: TextStyle(color: Colors.grey[600], fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          SizedBox(height: 6),
          Text(
            '👆 Tap image to view full size',
            style: TextStyle(color: Colors.blue[600], fontSize: 11, fontStyle: FontStyle.italic),
          ),
          SizedBox(height: 10),
        ],
        
        // Description
        Container(
          padding: EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Description:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[700]),
              ),
              SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(fontSize: 14, color: Colors.grey[800]),
              ),
            ],
          ),
        ),
        
        // Metadata
        if (createdAt != null || ticketId != 'Unknown ID') ...[
          SizedBox(height: 8),
          Row(
            children: [
              if (ticketId != 'Unknown ID') ...[
                Icon(Icons.tag, size: 12, color: Colors.grey[600]),
                SizedBox(width: 4),
                Text(
                  'ID: ${ticketId.length > 10 ? ticketId.substring(0, 10) + '...' : ticketId}',
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
                if (createdAt != null) ...[
                  SizedBox(width: 12),
                  Text('•', style: TextStyle(color: Colors.grey[400])),
                  SizedBox(width: 12),
                ],
              ],
              if (createdAt != null) ...[
                Icon(Icons.schedule, size: 12, color: Colors.grey[600]),
                SizedBox(width: 4),
                Text(
                  'Created: ${DateTime.tryParse(createdAt)?.toString().substring(0, 16) ?? createdAt}',
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildReceivedMessage(Map<String, dynamic> data) {
    final customData = data['data'] as Map<String, dynamic>?;
    final message = customData?['message'] as String? ?? 'No message';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.message, color: Colors.orange, size: 16),
            SizedBox(width: 4),
            Text(
              'Message Received',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange[700]),
            ),
          ],
        ),
        SizedBox(height: 8),
        Text(
          message,
          style: TextStyle(fontSize: 14),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }



  void _showFullImageFromBase64(BuildContext context, String imageBase64) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                child: Image.memory(
                  base64Decode(imageBase64),
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      padding: EdgeInsets.all(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.broken_image, color: Colors.white, size: 64),
                          SizedBox(height: 16),
                          Text(
                            'Failed to load image',
                            style: TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: Icon(Icons.close, color: Colors.white, size: 30),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black54,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }





  void _showBroadcastDialog(BuildContext context) {
    final TextEditingController messageController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Broadcast Message'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Send a message to all connected devices:'),
            SizedBox(height: 10),
            TextField(
              controller: messageController,
              decoration: InputDecoration(
                hintText: 'Enter your message...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final message = messageController.text.trim();
              if (message.isNotEmpty) {
                final bluetooth = Provider.of<BluetoothService>(context, listen: false);
                bluetooth.broadcastCustomData({'message': message});
                Navigator.of(context).pop();
              }
            },
            child: Text('Broadcast'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }
}