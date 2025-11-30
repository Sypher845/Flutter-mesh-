import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/data_sync_service.dart';
import '../services/bluetooth_service.dart';

class StatusMessages extends StatelessWidget {
  const StatusMessages({super.key});

  @override
  Widget build(BuildContext context) {
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
}
