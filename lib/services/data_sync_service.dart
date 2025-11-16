import 'package:flutter/foundation.dart';
import '../models/ticket_model.dart';
import 'local_storage_service.dart';

class DataSyncService extends ChangeNotifier {
  final LocalStorageService _localStorage = LocalStorageService();
  
  List<TicketModel> _pendingTickets = [];
  List<TicketModel> get pendingTickets => _pendingTickets;
  
  String _statusMessage = '';
  String get statusMessage => _statusMessage;
  
  // Mock backend setting - change to false to test error scenarios
  bool _mockBackendSuccess = true;

  DataSyncService() {
    _loadPendingTickets();
  }

  Future<void> _loadPendingTickets() async {
    _pendingTickets = await _localStorage.getPendingTickets();
    notifyListeners();
  }

  Future<void> addTicket(TicketModel ticket) async {
    _pendingTickets.add(ticket);
    await _localStorage.saveTicket(ticket);
    notifyListeners();
  }

  Future<bool> syncToBackend(TicketModel ticket) async {
    try {
      _updateStatus('Sending data to backend...');
      
      // MOCK BACKEND - Simulate network delay and response
      await Future.delayed(Duration(seconds: 2));
      
      // MOCK BACKEND - Simulate success/failure for testing
      if (_mockBackendSuccess) {
        // Success - Mark ticket as sent
        await _markTicketAsSent(ticket);
        _updateStatus('✅ Data sent to backend successfully!');
        print('MOCK BACKEND: Received ticket - ID: ${ticket.id}, Description: ${ticket.description}');
        if (ticket.imagePath != null) {
          print('MOCK BACKEND: Image path: ${ticket.imagePath}');
        }
        return true;
      } else {
        // Failure scenario
        _updateStatus('❌ Failed to send to backend (mock error)');
        return false;
      }
    } catch (e) {
      _updateStatus('Error sending to backend: $e');
      return false;
    }
  }

  Future<void> _markTicketAsSent(TicketModel ticket) async {
    final updatedTicket = ticket.copyWith(status: TicketStatus.sent);
    await _localStorage.updateTicket(updatedTicket);
    
    _pendingTickets.removeWhere((t) => t.id == ticket.id);
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

  Future<void> retryPendingTickets() async {
    for (final ticket in List.from(_pendingTickets)) {
      if (ticket.status == TicketStatus.pending || ticket.status == TicketStatus.failed) {
        await syncToBackend(ticket);
      }
    }
  }
}