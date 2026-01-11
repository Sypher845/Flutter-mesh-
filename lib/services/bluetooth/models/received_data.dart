/// Model representing data received from another device
class ReceivedData {
  final String senderId;
  final String senderName;
  final Map<String, dynamic> data;
  final DateTime receivedAt;
  String? receivedImagePath;

  ReceivedData({
    required this.senderId,
    required this.senderName,
    required this.data,
    required this.receivedAt,
    this.receivedImagePath,
  });

  /// Get the type of data received
  String? get dataType => data['type'] as String?;

  /// Get the report data if this is a report
  Map<String, dynamic>? get report => 
      data['report'] as Map<String, dynamic>? ?? 
      data['ticket'] as Map<String, dynamic>?;

  /// Get the report UUID if this is a report
  String? get reportUUID => report?['id'] as String?;

  /// Get the hop count if available
  int get hopCount => data['hopCount'] as int? ?? 0;

  /// Get the timestamp
  String? get timestamp => data['timestamp'] as String?;

  @override
  String toString() {
    return 'ReceivedData(sender: $senderName, type: $dataType, time: $receivedAt)';
  }
}
