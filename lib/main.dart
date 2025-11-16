import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/home_screen.dart';
import 'services/connectivity_service.dart';
import 'services/data_sync_service.dart';
import 'services/bluetooth_service.dart';
import 'utils/test_helper.dart';

void main() {
  // Print test info to console
  TestHelper.printTestInfo();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ConnectivityService()),
        ChangeNotifierProvider(create: (_) => DataSyncService()),
        ChangeNotifierProvider(create: (_) => BluetoothService()),
      ],
      child: MaterialApp(
        title: 'Offline Sync App',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          useMaterial3: true,
        ),
        home: HomeScreen(),
      ),
    );
  }
}