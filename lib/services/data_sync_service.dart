import 'package:flutter/foundation.dart';
import '../models/ticket_model.dart';
import 'local_storage_service.dart';

class DataSyncService extends ChangeNotifier {
  final LocalStorageService _localStorage = LocalStorageService();
  
  List<TicketModel> _tickets = [];
  List<TicketModel> get tickets => _tickets;
  
  String _statusMessage = '';
  String get statusMessage => _statusMessage;

  DataSyncService() {
    _loadTickets();
  }

  Future<void> _loadTickets() async {
    _tickets = await _localStorage.getPendingTickets();
    notifyListeners();
  }

  Future<void> addTicket(TicketModel ticket) async {
    // Set status to bluetooth hopping since we're only using Bluetooth
    final bluetoothTicket = ticket.copyWith(status: TicketStatus.bluetoothHopping);
    
    _tickets.add(bluetoothTicket);
    await _localStorage.saveTicket(bluetoothTicket);
    
    _updateStatus('📱 Ticket saved locally - ready for Bluetooth hopping');
    notifyListeners();
  }

  Future<void> markTicketAsHopped(TicketModel ticket) async {
    final hoppedTicket = ticket.copyWith(status: TicketStatus.sent);
    await _localStorage.updateTicket(hoppedTicket);
    
    // Update the ticket in our list
    final index = _tickets.indexWhere((t) => t.id == ticket.id);
    if (index != -1) {
      _tickets[index] = hoppedTicket;
    }
    
    _updateStatus('📡 Ticket successfully hopped via Bluetooth');
    notifyListeners();
  }

  Future<void> clearAllTickets() async {
    _tickets.clear();
    await _localStorage.clearAllTickets();
    _updateStatus('🗑️ All tickets cleared');
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