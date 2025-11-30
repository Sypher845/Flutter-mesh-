import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/report_model.dart';
import '../services/data_sync_service.dart';

class ReportsList extends StatelessWidget {
  const ReportsList({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<DataSyncService>(
      builder: (context, dataSync, child) {
        if (dataSync.reports.isEmpty) return SizedBox.shrink();

        return Card(
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Reports (${dataSync.reports.length})', 
                         style: Theme.of(context).textTheme.titleMedium),
                    TextButton(
                      onPressed: dataSync.clearAllReports,
                      child: Text('Clear All'),
                    ),
                  ],
                ),
                SizedBox(height: 10),
                ...dataSync.reports.map((report) => 
                  ListTile(
                    leading: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(report.hazardType.icon, style: TextStyle(fontSize: 24)),
                        SizedBox(width: 4),
                        Icon(_getStatusIcon(report.status)),
                      ],
                    ),
                    title: Text(report.title),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(report.hazardType.displayName),
                        Text('Created: ${report.createdAt.toString().substring(0, 16)}'),
                      ],
                    ),
                    trailing: Text(_getStatusText(report.status)),
                    isThreeLine: true,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  IconData _getStatusIcon(ReportStatus status) {
    switch (status) {
      case ReportStatus.pending:
        return Icons.pending;
      case ReportStatus.syncing:
        return Icons.sync;
      case ReportStatus.sent:
        return Icons.check_circle;
      case ReportStatus.failed:
        return Icons.error;
      case ReportStatus.bluetoothHopping:
        return Icons.bluetooth;
    }
  }

  String _getStatusText(ReportStatus status) {
    switch (status) {
      case ReportStatus.pending:
        return 'Pending';
      case ReportStatus.syncing:
        return 'Syncing...';
      case ReportStatus.sent:
        return 'Sent';
      case ReportStatus.failed:
        return 'Failed';
      case ReportStatus.bluetoothHopping:
        return 'Hopping...';
    }
  }
}
