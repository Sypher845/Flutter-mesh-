import 'package:flutter/foundation.dart';
import '../models/report_model.dart';
import 'local_storage_service.dart';

class DataSyncService extends ChangeNotifier {
  final LocalStorageService _localStorage = LocalStorageService();
  
  List<ReportModel> _reports = [];
  List<ReportModel> get reports => _reports;
  
  String _statusMessage = '';
  String get statusMessage => _statusMessage;

  DataSyncService() {
    _loadReports();
  }

  Future<void> _loadReports() async {
    _reports = await _localStorage.getPendingReports();
    notifyListeners();
  }

  Future<void> addReport(ReportModel report) async {
    final bluetoothReport = report.copyWith(status: ReportStatus.bluetoothHopping);
    
    _reports.add(bluetoothReport);
    await _localStorage.saveReport(bluetoothReport);
    
    _updateStatus('📱 Report saved locally - ready for Bluetooth hopping');
    notifyListeners();
  }

  Future<void> markReportAsHopped(ReportModel report) async {
    final hoppedReport = report.copyWith(status: ReportStatus.sent);
    await _localStorage.updateReport(hoppedReport);
    
    final index = _reports.indexWhere((r) => r.id == report.id);
    if (index != -1) {
      _reports[index] = hoppedReport;
    }
    
    _updateStatus('📡 Report successfully hopped via Bluetooth');
    notifyListeners();
  }

  Future<void> clearAllReports() async {
    _reports.clear();
    await _localStorage.clearAllReports();
    _updateStatus('🗑️ All reports cleared');
    notifyListeners();
  }

  void _updateStatus(String message) {
    _statusMessage = message;
    notifyListeners();
    
    // Clear status after 3 seconds
    Future.delayed(Duration(seconds: 3), () {
      if (_statusMessage == message) {
        _statusMessage = '';
        notifyListeners();
      }
    });
  }
}