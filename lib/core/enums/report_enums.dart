/// Enum for different types of hazards
enum HazardType {
  pothole,
  flooding,
  debris,
  roadDamage,
  other,
}

/// Enum for report status
enum ReportStatus {
  pending,
  syncing,
  sent,
  failed,
  bluetoothHopping,
}

/// Extension for HazardType display properties
extension HazardTypeExtension on HazardType {
  String get displayName {
    switch (this) {
      case HazardType.pothole:
        return 'Pothole';
      case HazardType.flooding:
        return 'Flooding';
      case HazardType.debris:
        return 'Debris on Road';
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
      case HazardType.flooding:
        return '🌊';
      case HazardType.debris:
        return '🚧';
      case HazardType.roadDamage:
        return '🛣️';
      case HazardType.other:
        return '⚠️';
    }
  }
}
