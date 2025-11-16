import 'dart:io';

class TicketModel {
  final String id;
  final String description;
  final File? imageFile;
  final String? imagePath;
  final DateTime createdAt;
  final TicketStatus status;
  final int retryCount;

  TicketModel({
    required this.id,
    required this.description,
    this.imageFile,
    this.imagePath,
    required this.createdAt,
    this.status = TicketStatus.pending,
    this.retryCount = 0,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'description': description,
      'imagePath': imagePath,
      'createdAt': createdAt.toIso8601String(),
      'status': status.toString(),
      'retryCount': retryCount,
    };
  }

  factory TicketModel.fromJson(Map<String, dynamic> json) {
    return TicketModel(
      id: json['id'],
      description: json['description'],
      imagePath: json['imagePath'],
      createdAt: DateTime.parse(json['createdAt']),
      status: TicketStatus.values.firstWhere(
        (e) => e.toString() == json['status'],
        orElse: () => TicketStatus.pending,
      ),
      retryCount: json['retryCount'] ?? 0,
    );
  }

  TicketModel copyWith({
    String? id,
    String? description,
    File? imageFile,
    String? imagePath,
    DateTime? createdAt,
    TicketStatus? status,
    int? retryCount,
  }) {
    return TicketModel(
      id: id ?? this.id,
      description: description ?? this.description,
      imageFile: imageFile ?? this.imageFile,
      imagePath: imagePath ?? this.imagePath,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      retryCount: retryCount ?? this.retryCount,
    );
  }
}

enum TicketStatus {
  pending,
  syncing,
  sent,
  failed,
  bluetoothHopping,
}