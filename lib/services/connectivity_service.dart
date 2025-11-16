import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';

class ConnectivityService extends ChangeNotifier {
  final Connectivity _connectivity = Connectivity();
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;
  
  bool _isConnected = false;
  bool _userDisabledInternet = false; // Track if user manually disabled internet
  Timer? _connectivityDebounceTimer;
  
  bool get isConnected => _isConnected && !_userDisabledInternet;

  ConnectivityService() {
    _initConnectivity();
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(_updateConnectionStatus);
  }

  Future<void> _initConnectivity() async {
    try {
      final result = await _connectivity.checkConnectivity();
      _updateConnectionStatus(result);
    } catch (e) {
      print('Could not check connectivity status: $e');
    }
  }

  void _updateConnectionStatus(List<ConnectivityResult> results) {
    final wasConnected = _isConnected;
    final newConnectionState = !results.contains(ConnectivityResult.none);
    
    // Debounce rapid connectivity changes (common when Bluetooth starts)
    _connectivityDebounceTimer?.cancel();
    _connectivityDebounceTimer = Timer(Duration(milliseconds: 500), () {
      _isConnected = newConnectionState;
      
      if (wasConnected != _isConnected) {
        // If internet suddenly connects while user had it disabled, it might be system-triggered
        if (_isConnected && _userDisabledInternet) {
          print('System-triggered connectivity detected, keeping user preference');
          return;
        }
        
        notifyListeners();
        print('Connectivity changed: ${_isConnected ? 'Connected' : 'Disconnected'}');
      }
    });
  }
  
  // Method to manually control internet usage
  void setInternetEnabled(bool enabled) {
    _userDisabledInternet = !enabled;
    notifyListeners();
    print('User ${enabled ? 'enabled' : 'disabled'} internet usage');
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    _connectivityDebounceTimer?.cancel();
    super.dispose();
  }
}