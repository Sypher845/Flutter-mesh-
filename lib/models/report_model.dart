import 'dart:io';
import '../core/enums/report_enums.dart';

/// Model representing a hazard report
///
/// Contains all information about a reported hazard including:
/// - Basic info (title, description)
/// - Location data (GPS coordinates)
/// - Image (optional)
/// - Hazard type classification
/// - Status tracking
class ReportModel {
  /// Unique identifier (UUID v4)
  final String id;
  
  /// Short title of the report
  final String title;
  
  /// Detailed description of the hazard
  final String description;
  
  /// Image file (in-memory, not persisted)
  final File? imageFile;
  
  /// Path to saved image file
  final String? imagePath;
  
  /// GPS location where hazard was reported
  final LocationData? location;
  
  /// Type of hazard (pothole, flooding, etc.)
  final HazardType hazardType;
  
  /// When the report was created
  final DateTime createdAt;
  
  /// Current status of the report
  final ReportStatus status;
  
  /// Number of retry attempts for sending
  final int retryCount;

  /// Number of hops the report has gone through
  final int hopCount;

  const ReportModel({
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
    this.hopCount = 0,
  });

  /// Convert report to JSON for storage/transmission
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
      'hopCount': hopCount,
    };
  }

  /// Create report from JSON
  factory ReportModel.fromJson(Map<String, dynamic> json) {
    return ReportModel(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      description: json['description'] as String,
      imagePath: json['imagePath'] as String?,
      location: json['location'] != null 
          ? LocationData.fromJson(json['location'] as Map<String, dynamic>) 
          : null,
      hazardType: _parseHazardType(json['hazardType'] as String?),
      createdAt: DateTime.parse(json['createdAt'] as String),
      status: _parseReportStatus(json['status'] as String?),
      retryCount: json['retryCount'] as int? ?? 0,
      hopCount: json['hopCount'] as int? ?? 0,
    );
  }

  /// Parse hazard type from string
  static HazardType _parseHazardType(String? value) {
    if (value == null) return HazardType.other;
    return HazardType.values.firstWhere(
      (e) => e.toString() == value,
      orElse: () => HazardType.other,
    );
  }

  /// Parse report status from string
  static ReportStatus _parseReportStatus(String? value) {
    if (value == null) return ReportStatus.pending;
    return ReportStatus.values.firstWhere(
      (e) => e.toString() == value,
      orElse: () => ReportStatus.pending,
    );
  }

  /// Create a copy with modified fields
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
    int? hopCount,
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
      hopCount: hopCount ?? this.hopCount,
    );
  }
}

/// Model representing location data
class LocationData {
  final double latitude;
  final double longitude;
  final double? accuracy;
  final DateTime timestamp;

  const LocationData({
    required this.latitude,
    required this.longitude,
    this.accuracy,
    required this.timestamp,
  });

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  /// Create from JSON
  factory LocationData.fromJson(Map<String, dynamic> json) {
    return LocationData(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      accuracy: (json['accuracy'] as num?)?.toDouble(),
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }

  /// Get formatted coordinates string
  String get formattedCoordinates {
    return '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';
  }

  @override
  String toString() => formattedCoordinates;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LocationData &&
          runtimeType == other.runtimeType &&
          latitude == other.latitude &&
          longitude == other.longitude;

  @override
  int get hashCode => latitude.hashCode ^ longitude.hashCode;
}


