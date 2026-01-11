import 'package:flutter/foundation.dart';
import '../models/report_model.dart';

class ReportProvider with ChangeNotifier {
  final List<ReportModel> _reports = [];
  final Set<String> _reportIds = {};
  
  List<ReportModel> get reports => List.unmodifiable(_reports);
  int get reportCount => _reports.length;

  bool addReport(ReportModel report) {
    if (_reportIds.contains(report.id)) {
      debugPrint('⚠ Duplicate report ${report.id} - not added');
      return false;
    }

    _reports.add(report);
    _reportIds.add(report.id);
    notifyListeners();
    
    debugPrint('✓ Report ${report.id} added (total: ${_reports.length})');
    return true;
  }

  bool hasReport(String reportId) {
    return _reportIds.contains(reportId);
  }

  ReportModel? getReportById(String reportId) {
    try {
      return _reports.firstWhere((report) => report.id == reportId);
    } catch (e) {
      return null;
    }
  }

  void removeReport(String reportId) {
    final index = _reports.indexWhere((report) => report.id == reportId);
    if (index != -1) {
      _reports.removeAt(index);
      _reportIds.remove(reportId);
      notifyListeners();
      debugPrint('✓ Report $reportId removed');
    }
  }

  void clearAll() {
    _reports.clear();
    _reportIds.clear();
    notifyListeners();
    debugPrint('✓ All reports cleared');
  }

  List<ReportModel> getReportsByHopCount(int hopCount) {
    return _reports.where((report) => report.hopCount == hopCount).toList();
  }

  List<ReportModel> getSortedReports({bool newestFirst = true}) {
    final sorted = List<ReportModel>.from(_reports);
    sorted.sort((a, b) => newestFirst
        ? b.createdAt.compareTo(a.createdAt)
        : a.createdAt.compareTo(b.createdAt));
    return sorted;
  }
}