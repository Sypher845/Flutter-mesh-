import 'package:flutter/material.dart';

class TestHelper {
  static void showTestDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('🧪 Test Mode'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Testing Instructions:', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 10),
            Text('1. ✅ Check connection status at top'),
            Text('2. 📷 Upload an image (camera/gallery)'),
            Text('3. ✏️ Enter a description'),
            Text('4. 📤 Submit ticket'),
            SizedBox(height: 10),
            Text('With Internet:', style: TextStyle(fontWeight: FontWeight.bold)),
            Text('• Should show "Data sent to backend successfully!"'),
            Text('• Check console for mock backend logs'),
            SizedBox(height: 10),
            Text('Without Internet:', style: TextStyle(fontWeight: FontWeight.bold)),
            Text('• Turn off WiFi/mobile data'),
            Text('• Should show Bluetooth controls'),
            Text('• Try advertising/discovering'),
            Text('• Check console for Bluetooth logs'),
            SizedBox(height: 10),
            Text('Debug Info:', style: TextStyle(fontWeight: FontWeight.bold)),
            Text('• All logs appear in console/terminal'),
            Text('• Status messages show in app'),
            Text('• Pending tickets list shows unsent items'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Got it!'),
          ),
        ],
      ),
    );
  }

  static void printTestInfo() {
    print('=== OFFLINE SYNC APP TEST MODE ===');
    print('📱 App started in test mode');
    print('🔍 Watch console for debug messages');
    print('📡 Backend calls are mocked');
    print('🔵 Bluetooth operations will show debug info');
    print('=====================================');
  }
}