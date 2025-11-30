import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/bluetooth_service.dart';

class BluetoothControls extends StatelessWidget {
  const BluetoothControls({super.key});

  @override
  Widget build(BuildContext context) {
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
                _buildStatusContainer(bluetooth),
                if (bluetooth.connectedDevices.isNotEmpty) ...[
                  SizedBox(height: 10),
                  Text('Connected devices: ${bluetooth.connectedDevices.length}'),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusContainer(BluetoothService bluetooth) {
    return Container(
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
    );
  }
}
