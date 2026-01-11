import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/permission_service.dart';

class PermissionDialog extends StatelessWidget {
  const PermissionDialog({super.key});

  static Future<void> showIfNeeded(BuildContext context) async {
    final hasRequested = await PermissionService.hasRequestedPermissions();
    
    if (!hasRequested && context.mounted) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => PermissionDialog(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.security, color: Theme.of(context).primaryColor),
          SizedBox(width: 12),
          Text('Permissions Required'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This app needs the following permissions to work properly:',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            SizedBox(height: 16),
            _buildPermissionItem(
              Icons.bluetooth,
              'Bluetooth',
              'To share reports with nearby devices',
            ),
            SizedBox(height: 12),
            _buildPermissionItem(
              Icons.location_on,
              'Location',
              'To capture hazard location and enable Bluetooth',
            ),
            SizedBox(height: 12),
            _buildPermissionItem(
              Icons.camera_alt,
              'Camera',
              'To take photos of hazards',
            ),
            SizedBox(height: 12),
            _buildPermissionItem(
              Icons.photo_library,
              'Photos',
              'To select photos from gallery',
            ),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'You can change these permissions later in your device settings.',
                      style: TextStyle(fontSize: 12, color: Colors.blue[900]),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () async {
            await PermissionService.markPermissionsRequested();
            if (context.mounted) {
              Navigator.of(context).pop();
            }
          },
          child: Text('Not Now'),
        ),
        ElevatedButton(
          onPressed: () async {
            final status = await PermissionService.requestAllPermissions();
            
            if (context.mounted) {
              Navigator.of(context).pop();
              
              if (status == PermissionStatus.granted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('✅ All permissions granted!'),
                    backgroundColor: Colors.green,
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('⚠️ Some permissions were denied. App functionality may be limited.'),
                    backgroundColor: Colors.orange,
                    duration: Duration(seconds: 4),
                  ),
                );
              }
            }
          },
          child: Text('Grant Permissions'),
        ),
      ],
    );
  }

  Widget _buildPermissionItem(IconData icon, String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 24, color: Colors.grey[700]),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              SizedBox(height: 2),
              Text(
                description,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
