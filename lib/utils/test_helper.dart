import 'package:flutter/material.dart';

class TestHelper {
  static void showTestDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('🧪 Bluetooth Hopping Test Mode'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Testing Instructions:', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 10),
              Text('1. 📷 Upload an image (camera/gallery)'),
              Text('2. ✏️ Enter a description'),
              Text('3. 📤 Create ticket for Bluetooth hopping'),
              Text('4. 📡 Start advertising on this device'),
              Text('5. 🔍 Start discovery on another device'),
              SizedBox(height: 10),
              Text('Bluetooth Testing:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('• Install app on 2+ devices'),
              Text('• Device A: Start Advertising'),
              Text('• Device B: Start Discovery'),
              Text('• Device B should find Device A'),
              Text('• Check console for detailed logs'),
              SizedBox(height: 10),
              Text('Debug Features:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('• "Debug Status" shows current state'),
              Text('• "How to Test" explains process'),
              Text('• "Simulate Device" for emulator testing'),
              Text('• All logs appear in console'),
              SizedBox(height: 10),
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  border: Border.all(color: Colors.orange),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Note: Only finds devices running this same app!',
                  style: TextStyle(color: Colors.orange[800], fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
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
    print('=== BLUETOOTH HOPPING APP TEST MODE ===');
    print('📱 App started in test mode');
    print('🔍 Watch console for debug messages');
    print('📡 No backend - pure Bluetooth hopping');
    print('🔵 Bluetooth operations will show detailed debug info');
    print('🚫 Internet connectivity removed');
    print('==========================================');
  }
}