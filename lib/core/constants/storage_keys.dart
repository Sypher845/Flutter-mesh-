/// Storage keys for SharedPreferences and Database
class StorageKeys {
  // Private constructor
  StorageKeys._();

  // SharedPreferences Keys
  static const String permissionsRequested = 'permissions_requested';
  
  // Database Tables
  static const String reportsTable = 'reports';
  
  // Database Columns
  static const String columnId = 'id';
  static const String columnTitle = 'title';
  static const String columnDescription = 'description';
  static const String columnImagePath = 'imagePath';
  static const String columnLatitude = 'latitude';
  static const String columnLongitude = 'longitude';
  static const String columnLocationAccuracy = 'locationAccuracy';
  static const String columnLocationTimestamp = 'locationTimestamp';
  static const String columnHazardType = 'hazardType';
  static const String columnCreatedAt = 'createdAt';
  static const String columnStatus = 'status';
  static const String columnRetryCount = 'retryCount';
}
