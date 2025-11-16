import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import '../models/ticket_model.dart';
import '../services/connectivity_service.dart';
import '../services/data_sync_service.dart';
import '../services/bluetooth_service.dart';
import '../utils/test_helper.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _descriptionController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  File? _selectedImage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Offline Sync App'),
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
            _buildConnectionStatus(),
            SizedBox(height: 20),
            _buildImageSection(),
            SizedBox(height: 20),
            _buildDescriptionSection(),
            SizedBox(height: 20),
            _buildSubmitButton(),
            SizedBox(height: 20),
            _buildStatusMessages(),
            SizedBox(height: 20),
            _buildEmulatorWarning(),
            SizedBox(height: 20),
            _buildBluetoothControls(),
            SizedBox(height: 20),
            _buildPendingTickets(),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionStatus() {
    return Consumer<ConnectivityService>(
      builder: (context, connectivity, child) {
        return Card(
          color: connectivity.isConnected ? Colors.green[100] : Colors.red[100],
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: Row(
              children: [
                Icon(
                  connectivity.isConnected ? Icons.wifi : Icons.wifi_off,
                  color: connectivity.isConnected ? Colors.green : Colors.red,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    connectivity.isConnected ? 'Connected to Internet' : 'No Internet Connection',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: connectivity.isConnected ? Colors.green[800] : Colors.red[800],
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => connectivity.setInternetEnabled(!connectivity.isConnected),
                  child: Text(
                    connectivity.isConnected ? 'Disable' : 'Enable',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
    return Consumer2<ConnectivityService, DataSyncService>(
      builder: (context, connectivity, dataSync, child) {
        return ElevatedButton(
          onPressed: _canSubmit() ? _submitTicket : null,
          style: ElevatedButton.styleFrom(
            padding: EdgeInsets.symmetric(vertical: 16),
            backgroundColor: Theme.of(context).primaryColor,
            foregroundColor: Colors.white,
          ),
          child: Text(
            'Submit Ticket',
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
    return Consumer2<ConnectivityService, BluetoothService>(
      builder: (context, connectivity, bluetooth, child) {
        if (connectivity.isConnected) return SizedBox.shrink();

        return Card(
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Bluetooth Hopping', style: Theme.of(context).textTheme.titleMedium),
                SizedBox(height: 10),
                Text('No internet connection. Use Bluetooth to hop data to nearby devices.'),
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
                SizedBox(height: 10),
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

  Widget _buildPendingTickets() {
    return Consumer<DataSyncService>(
      builder: (context, dataSync, child) {
        if (dataSync.pendingTickets.isEmpty) return SizedBox.shrink();

        return Card(
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Pending Tickets (${dataSync.pendingTickets.length})', 
                         style: Theme.of(context).textTheme.titleMedium),
                    Consumer<ConnectivityService>(
                      builder: (context, connectivity, child) {
                        if (!connectivity.isConnected) return SizedBox.shrink();
                        return TextButton(
                          onPressed: dataSync.retryPendingTickets,
                          child: Text('Retry All'),
                        );
                      },
                    ),
                  ],
                ),
                SizedBox(height: 10),
                ...dataSync.pendingTickets.map((ticket) => 
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
      final XFile? image = await _picker.pickImage(source: source);
      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
    }
  }

  bool _canSubmit() {
    return _descriptionController.text.trim().isNotEmpty;
  }

  Future<void> _submitTicket() async {
    final description = _descriptionController.text.trim();
    if (description.isEmpty) return;

    final ticket = TicketModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      description: description,
      imageFile: _selectedImage,
      imagePath: _selectedImage?.path,
      createdAt: DateTime.now(),
    );

    final connectivity = Provider.of<ConnectivityService>(context, listen: false);
    final dataSync = Provider.of<DataSyncService>(context, listen: false);
    final bluetooth = Provider.of<BluetoothService>(context, listen: false);

    await dataSync.addTicket(ticket);

    if (connectivity.isConnected) {
      // Try to send directly to backend
      await dataSync.syncToBackend(ticket);
    } else {
      // Use Bluetooth hopping
      await bluetooth.sendTicketData(ticket);
    }

    // Clear form
    _descriptionController.clear();
    setState(() {
      _selectedImage = null;
    });
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

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }
}