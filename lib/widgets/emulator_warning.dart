import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class EmulatorWarning extends StatelessWidget {
  const EmulatorWarning({super.key});

  @override
  Widget build(BuildContext context) {
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
}
