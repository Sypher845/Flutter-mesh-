import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/bluetooth/bluetooth_service.dart';
import 'received_data_item.dart';

class ReceivedDataSection extends StatelessWidget {
  const ReceivedDataSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<BluetoothService>(
      builder: (context, bluetooth, child) {
        final itemCount = bluetooth.receivedDataList.length;

        return Card(
          elevation: 2,
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context, bluetooth, itemCount),
                SizedBox(height: 12),
                
                if (itemCount == 0) 
                  _buildEmptyState()
                else
                  _buildDataList(bluetooth, itemCount),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, BluetoothService bluetooth, int itemCount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Received Data ($itemCount)',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: itemCount > 0 ? Colors.green[700] : Colors.grey[600],
            fontWeight: FontWeight.bold,
          ),
        ),
        if (itemCount > 0)
          TextButton(
            onPressed: bluetooth.clearReceivedData,
            child: Text('Clear All'),
          ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
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
    );
  }

  Widget _buildDataList(BluetoothService bluetooth, int itemCount) {
    return Column(
      children: [
        ...bluetooth.receivedDataList.reversed.take(10).map((receivedData) => 
          ReceivedDataItem(receivedData: receivedData),
        ),
        
        if (itemCount > 10)
          Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              '... and ${itemCount - 10} more items',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ),
      ],
    );
  }
}
