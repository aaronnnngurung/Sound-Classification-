import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  // Singleton pattern — only one instance of the database exists at a time
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    // If database already open, return it
    if (_database != null) return _database!;
    // Otherwise open/create it
    _database = await _initDB('soundclass.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    // Get the path where Flutter stores app databases
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  // Called once when the database is first created
  // This is where we define your table structure
  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE detection_history (
        id              INTEGER PRIMARY KEY AUTOINCREMENT,
        sound_class     TEXT    NOT NULL,
        display_label   TEXT    NOT NULL,
        confidence      REAL    NOT NULL,
        timestamp       TEXT    NOT NULL,
        is_false_positive INTEGER NOT NULL DEFAULT 0,
        user_id         TEXT
      )
    ''');

    // AUTOINCREMENT means SQLite assigns the id automatically
    // REAL is SQLite's type for decimal numbers (like 0.92)
    // INTEGER for booleans (0 = false, 1 = true) — SQLite has no boolean type
    // TEXT for dates stored as ISO string: "2026-07-04T14:30:00"
  }

  // INSERT a new detection
  Future<int> insertDetection({
    required String soundClass,
    required String displayLabel,
    required double confidence,
    required String userId,
  }) async {
    final db = await database;
    return await db.insert(
      'detection_history',
      {
        'sound_class': soundClass,
        'display_label': displayLabel,
        'confidence': confidence,
        'timestamp': DateTime.now().toIso8601String(),
        'is_false_positive': 0,
        'user_id': userId,
      },
      // If a row with the same id somehow exists, replace it
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // GET all detections for a user
  Future<List<Map<String, dynamic>>> getAllDetections(String userId) async {
    final db = await database;
    return await db.query(
      'detection_history',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'timestamp DESC', // newest first
    );
  }

  //  GET detections filtered by sound class
  Future<List<Map<String, dynamic>>> getDetectionsByClass(
    String userId,
    String soundClass,
  ) async {
    final db = await database;
    return await db.query(
      'detection_history',
      where: 'user_id = ? AND sound_class = ?',
      whereArgs: [userId, soundClass],
      orderBy: 'timestamp DESC',
    );
  }

  //  UPDATE false positive flag
  Future<void> updateFalsePositive(int id, bool isFalsePositive) async {
    final db = await database;
    await db.update(
      'detection_history',
      {'is_false_positive': isFalsePositive ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  //  Delete a single entry
  Future<void> deleteDetection(int id) async {
    final db = await database;
    await db.delete('detection_history', where: 'id = ?', whereArgs: [id]);
  }

  //  Delte all entries for a user
  Future<void> clearAllDetections(String userId) async {
    final db = await database;
    await db.delete(
      'detection_history',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
  }

  // Close the database
  Future<void> close() async {
    final db = await database;
    db.close();
  }
}
