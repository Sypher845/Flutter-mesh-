import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/ticket_model.dart';

class LocalStorageService {
  static Database? _database;
  
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'tickets.db');
    
    return await openDatabase(
      path,
      version: 1,
      onCreate: _createTables,
    );
  }

  Future<void> _createTables(Database db, int version) async {
    await db.execute('''
      CREATE TABLE tickets (
        id TEXT PRIMARY KEY,
        description TEXT NOT NULL,
        imagePath TEXT,
        createdAt TEXT NOT NULL,
        status TEXT NOT NULL,
        retryCount INTEGER DEFAULT 0
      )
    ''');
  }

  Future<void> saveTicket(TicketModel ticket) async {
    final db = await database;
    await db.insert(
      'tickets',
      ticket.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<TicketModel>> getPendingTickets() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'tickets',
      where: 'status != ?',
      whereArgs: [TicketStatus.sent.toString()],
    );

    return List.generate(maps.length, (i) {
      return TicketModel.fromJson(maps[i]);
    });
  }

  Future<void> updateTicket(TicketModel ticket) async {
    final db = await database;
    await db.update(
      'tickets',
      ticket.toJson(),
      where: 'id = ?',
      whereArgs: [ticket.id],
    );
  }

  Future<void> deleteTicket(String id) async {
    final db = await database;
    await db.delete(
      'tickets',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> clearAllTickets() async {
    final db = await database;
    await db.delete('tickets');
  }

  Future<List<TicketModel>> getAllTickets() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('tickets');

    return List.generate(maps.length, (i) {
      return TicketModel.fromJson(maps[i]);
    });
  }
}