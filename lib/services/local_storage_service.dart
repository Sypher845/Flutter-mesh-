import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/report_model.dart';

class LocalStorageService {
  static const String _reportsKey = 'reports';

  Future<List<ReportModel>> getPendingReports() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final reportsJson = prefs.getStringList(_reportsKey) ?? [];
      
      return reportsJson.map((json) {
        final map = jsonDecode(json) as Map<String, dynamic>;
        return ReportModel.fromJson(map);
      }).toList();
    } catch (e) {
      print('Error loading reports: $e');
      return [];
    }
  }

  Future<void> saveReport(ReportModel report) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final reportsJson = prefs.getStringList(_reportsKey) ?? [];
      
      reportsJson.add(jsonEncode(report.toJson()));
      await prefs.setStringList(_reportsKey, reportsJson);
      
      print('✓ Report ${report.id} saved to local storage');
    } catch (e) {
      print('✗ Error saving report: $e');
      rethrow;
    }
  }

  Future<void> updateReport(ReportModel report) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final reportsJson = prefs.getStringList(_reportsKey) ?? [];
      
      // Find and replace the report
      final index = reportsJson.indexWhere((json) {
        final map = jsonDecode(json) as Map<String, dynamic>;
        return map['id'] == report.id;
      });

      if (index != -1) {
        reportsJson[index] = jsonEncode(report.toJson());
        await prefs.setStringList(_reportsKey, reportsJson);
        print('✓ Report ${report.id} updated in local storage');
      }
    } catch (e) {
      print('✗ Error updating report: $e');
      rethrow;
    }
  }

  Future<void> clearAllReports() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_reportsKey);
      print('✓ All reports cleared from local storage');
    } catch (e) {
      print('✗ Error clearing reports: $e');
      rethrow;
    }
  }

  Future<void> deleteReport(String reportId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final reportsJson = prefs.getStringList(_reportsKey) ?? [];
      
      reportsJson.removeWhere((json) {
        final map = jsonDecode(json) as Map<String, dynamic>;
        return map['id'] == reportId;
      });

      await prefs.setStringList(_reportsKey, reportsJson);
      print('✓ Report $reportId deleted from local storage');
    } catch (e) {
      print('✗ Error deleting report: $e');
      rethrow;
    }
  }
}