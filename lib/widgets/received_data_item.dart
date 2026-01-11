import 'package:flutter/material.dart';
import 'dart:convert';
import '../services/bluetooth/models/received_data.dart';

class ReceivedDataItem extends StatelessWidget {
  final ReceivedData receivedData;

  const ReceivedDataItem({
    super.key,
    required this.receivedData,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
          _buildHeader(),
          SizedBox(height: 8),
          _buildContent(context),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
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
    );
  }

  Widget _buildContent(BuildContext context) {
    final type = receivedData.data['type'] as String?;
    final report = receivedData.data['report'] as Map<String, dynamic>? ?? receivedData.data['ticket'] as Map<String, dynamic>?;
    
    if (report != null) {
      return _buildReceivedReport(context, receivedData.data);
    }
    
    if (type != null && (type == 'report_data' || type == 'report_metadata' || type.contains('report') ||
        type == 'ticket_data' || type.contains('ticket'))) {
      return _buildReceivedReport(context, receivedData.data);
    }
    
    if (type == 'custom_data' || receivedData.data.containsKey('data')) {
      return _buildReceivedMessage(receivedData.data);
    }
    
    if (receivedData.data.containsKey('message')) {
      return _buildReceivedMessage(receivedData.data);
    }
    
    return _buildGenericData(receivedData.data, type);
  }

  Widget _buildReceivedReport(BuildContext context, Map<String, dynamic> data) {
    final report = data['report'] as Map<String, dynamic>? ?? data['ticket'] as Map<String, dynamic>?;
    
    if (report == null) {
      return Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.red[50],
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text('❌ Invalid report data', style: TextStyle(color: Colors.red[700])),
      );
    }

    final title = report['title'] as String? ?? 'Untitled Report';
    final description = report['description'] as String? ?? 'No description';
    final imageBase64 = report['imageBase64'] as String?;
    final createdAt = report['createdAt'] as String?;
    final reportId = report['id'] as String? ?? 'Unknown ID';
    final hazardType = report['hazardType'] as String?;
    final location = report['location'] as Map<String, dynamic>?;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildReportHeader(imageBase64, hazardType),
        SizedBox(height: 10),
        
        if (imageBase64 != null && imageBase64.isNotEmpty)
          _buildReportImage(context, imageBase64),
        
        _buildReportTitle(title),
        SizedBox(height: 8),
        _buildReportDescription(description),
        
        if (location != null)
          _buildReportLocation(location),
        
        if (createdAt != null || reportId != 'Unknown ID')
          _buildReportMetadata(reportId, createdAt),
      ],
    );
  }

  Widget _buildReportHeader(String? imageBase64, String? hazardType) {
    return Row(
      children: [
        Icon(Icons.report, color: Colors.green, size: 18),
        SizedBox(width: 6),
        Expanded(
          child: Text(
            'Report Received',
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
    );
  }

  Widget _buildReportTitle(String title) {
    return Container(
      padding: EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.title, size: 16, color: Colors.blue[700]),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue[900]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportImage(BuildContext context, String imageBase64) {
    return Column(
      children: [
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
    );
  }

  Widget _buildReportDescription(String description) {
    return Container(
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
    );
  }

  Widget _buildReportLocation(Map<String, dynamic> location) {
    final lat = location['latitude'];
    final lng = location['longitude'];
    
    return Padding(
      padding: EdgeInsets.only(top: 8),
      child: Container(
        padding: EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.green[50],
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.green[200]!),
        ),
        child: Row(
          children: [
            Icon(Icons.location_on, size: 16, color: Colors.green[700]),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Location: ${lat?.toStringAsFixed(6)}, ${lng?.toStringAsFixed(6)}',
                style: TextStyle(fontSize: 12, color: Colors.green[900]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportMetadata(String reportId, String? createdAt) {
    return Padding(
      padding: EdgeInsets.only(top: 8),
      child: Row(
        children: [
          if (reportId != 'Unknown ID') ...[
            Icon(Icons.tag, size: 12, color: Colors.grey[600]),
            SizedBox(width: 4),
            Text(
              'ID: ${reportId.length > 10 ? '${reportId.substring(0, 10)}...' : reportId}',
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

  Widget _buildGenericData(Map<String, dynamic> data, String? type) {
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
              'Content: ${data.toString().length > 100 ? '${data.toString().substring(0, 100)}...' : data.toString()}',
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
          ],
        ],
      ),
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
}
