import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/report_model.dart';

class LocalStorageService {
  static Database? _database;
  
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'reports.db');
    
    return await openDatabase(
      path,
      version: 2,
      onCreate: _createTables,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _createTables(Database db, int version) async {
    await db.execute('''
      CREATE TABLE reports (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT NOT NULL,
        imagePath TEXT,
        latitude REAL,
        longitude REAL,
        locationAccuracy REAL,
        locationTimestamp TEXT,
        hazardType TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        status TEXT NOT NULL,
        retryCount INTEGER DEFAULT 0
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('DROP TABLE IF EXISTS tickets');
      await _createTables(db, newVersion);
    }
  }

  Future<void> saveReport(ReportModel report) async {
    final db = await database;
    final json = report.toJson();
    
    final Map<String, dynamic> dbData = {
      'id': json['id'],
      'title': json['title'],
      'description': json['description'],
      'imagePath': json['imagePath'],
      'latitude': json['location']?['latitude'],
      'longitude': json['location']?['longitude'],
      'locationAccuracy': json['location']?['accuracy'],
      'locationTimestamp': json['location']?['timestamp'],
      'hazardType': json['hazardType'],
      'createdAt': json['createdAt'],
      'status': json['status'],
      'retryCount': json['retryCount'],
    };
    
    await db.insert(
      'reports',
      dbData,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<ReportModel>> getPendingReports() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'reports',
      where: 'status != ?',
      whereArgs: [ReportStatus.sent.toString()],
    );

    return _mapsToReports(maps);
  }

  Future<void> updateReport(ReportModel report) async {
    final db = await database;
    final json = report.toJson();
    
    final Map<String, dynamic> dbData = {
      'id': json['id'],
      'title': json['title'],
      'description': json['description'],
      'imagePath': json['imagePath'],
      'latitude': json['location']?['latitude'],
      'longitude': json['location']?['longitude'],
      'locationAccuracy': json['location']?['accuracy'],
      'locationTimestamp': json['location']?['timestamp'],
      'hazardType': json['hazardType'],
      'createdAt': json['createdAt'],
      'status': json['status'],
      'retryCount': json['retryCount'],
    };
    
    await db.update(
      'reports',
      dbData,
      where: 'id = ?',
      whereArgs: [report.id],
    );
  }

  Future<void> deleteReport(String id) async {
    final db = await database;
    await db.delete(
      'reports',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> clearAllReports() async {
    final db = await database;
    await db.delete('reports');
  }

  Future<List<ReportModel>> getAllReports() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('reports');
    return _mapsToReports(maps);
  }

  List<ReportModel> _mapsToReports(List<Map<String, dynamic>> maps) {
    return List.generate(maps.length, (i) {
      final map = maps[i];
      
      LocationData? location;
      if (map['latitude'] != null && map['longitude'] != null) {
        location = LocationData(
          latitude: map['latitude'],
          longitude: map['longitude'],
          accuracy: map['locationAccuracy'],
          timestamp: DateTime.parse(map['locationTimestamp']),
        );
      }
      
      final json = {
        'id': map['id'],
        'title': map['title'],
        'description': map['description'],
        'imagePath': map['imagePath'],
        'location': location?.toJson(),
        'hazardType': map['hazardType'],
        'createdAt': map['createdAt'],
        'status': map['status'],
        'retryCount': map['retryCount'],
      };
      
      return ReportModel.fromJson(json);
    });
  }
}