import 'dart:io';

class ReportModel {
  final String id;
  final String title;
  final String description;
  final File? imageFile;
  final String? imagePath;
  final LocationData? location;
  final HazardType hazardType;
  final DateTime createdAt;
  final ReportStatus status;
  final int retryCount;

  ReportModel({
    required this.id,
    required this.title,
    required this.description,
    this.imageFile,
    this.imagePath,
    this.location,
    required this.hazardType,
    required this.createdAt,
    this.status = ReportStatus.pending,
    this.retryCount = 0,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'imagePath': imagePath,
      'location': location?.toJson(),
      'hazardType': hazardType.toString(),
      'createdAt': createdAt.toIso8601String(),
      'status': status.toString(),
      'retryCount': retryCount,
    };
  }

  factory ReportModel.fromJson(Map<String, dynamic> json) {
    return ReportModel(
      id: json['id'],
      title: json['title'] ?? '',
      description: json['description'],
      imagePath: json['imagePath'],
      location: json['location'] != null ? LocationData.fromJson(json['location']) : null,
      hazardType: HazardType.values.firstWhere(
        (e) => e.toString() == json['hazardType'],
        orElse: () => HazardType.other,
      ),
      createdAt: DateTime.parse(json['createdAt']),
      status: ReportStatus.values.firstWhere(
        (e) => e.toString() == json['status'],
        orElse: () => ReportStatus.pending,
      ),
      retryCount: json['retryCount'] ?? 0,
    );
  }

  ReportModel copyWith({
    String? id,
    String? title,
    String? description,
    File? imageFile,
    String? imagePath,
    LocationData? location,
    HazardType? hazardType,
    DateTime? createdAt,
    ReportStatus? status,
    int? retryCount,
  }) {
    return ReportModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      imageFile: imageFile ?? this.imageFile,
      imagePath: imagePath ?? this.imagePath,
      location: location ?? this.location,
      hazardType: hazardType ?? this.hazardType,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      retryCount: retryCount ?? this.retryCount,
    );
  }
}

class LocationData {
  final double latitude;
  final double longitude;
  final double? accuracy;
  final DateTime timestamp;

  LocationData({
    required this.latitude,
    required this.longitude,
    this.accuracy,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory LocationData.fromJson(Map<String, dynamic> json) {
    return LocationData(
      latitude: json['latitude'],
      longitude: json['longitude'],
      accuracy: json['accuracy'],
      timestamp: DateTime.parse(json['timestamp']),
    );
  }

  String get formattedCoordinates {
    return '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';
  }
}

enum HazardType {
  pothole,
  brokenLight,
  flooding,
  debris,
  signDamage,
  roadDamage,
  other,
}

extension HazardTypeExtension on HazardType {
  String get displayName {
    switch (this) {
      case HazardType.pothole:
        return 'Pothole';
      case HazardType.brokenLight:
        return 'Broken Street Light';
      case HazardType.flooding:
        return 'Flooding';
      case HazardType.debris:
        return 'Debris on Road';
      case HazardType.signDamage:
        return 'Sign Damage';
      case HazardType.roadDamage:
        return 'Road Damage';
      case HazardType.other:
        return 'Other';
    }
  }

  String get icon {
    switch (this) {
      case HazardType.pothole:
        return '🕳️';
      case HazardType.brokenLight:
        return '💡';
      case HazardType.flooding:
        return '🌊';
      case HazardType.debris:
        return '🚧';
      case HazardType.signDamage:
        return '🚸';
      case HazardType.roadDamage:
        return '🛣️';
      case HazardType.other:
        return '⚠️';
    }
  }
}

enum ReportStatus {
  pending,
  syncing,
  sent,
  failed,
  bluetoothHopping,
}
