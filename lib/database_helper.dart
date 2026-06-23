import 'dart:async';
import 'dart:io' show Directory;
import 'package:path/path.dart' show join;
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart' show getApplicationDocumentsDirectory;

enum DBAction {
  create,
  update,
  delete
}

class DatabaseHelper {
  static const String _databaseName = "open-time-tracker.db";
  static const int _databaseVersion = 2;

  static const String tableCache = 'tCache';
  static const String tableChanges = 'tChanges';
  static const String columnRequest = 'fRequest';
  static const String columnDate = 'fDate';
  static const String columnData = 'fData';

  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database = null;

  Future<Database> get database async {
    if (_database != null) {
    }else {
      _database = await _initDatabase();
    }
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final Directory documentsDirectory = await getApplicationDocumentsDirectory();
    final String path = join(documentsDirectory.path, _databaseName);

    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Create tables here
    await _createTables(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Handle database upgrades here
    if (oldVersion < newVersion) {
      // Add migration logic
    }
  }

  // SQL code to create the database table
  Future<void> _createTables(Database db) async {
    await db.execute('''
          CREATE TABLE $tableCache (
            $columnRequest TEXT NOT NULL PRIMARY KEY,
            $columnData TEXT
          )
          ''');
    await db.execute('''
          CREATE TABLE $tableChanges (
            $columnDate TEXT NOT NULL PRIMARY KEY,
            $columnRequest TEXT NOT NULL,
            $columnData TEXT
          )
          ''');
    // Create indexes for better performance
    await db.execute('CREATE INDEX idx_requests ON $tableCache ($columnRequest)');
    await db.execute('CREATE INDEX idx_dates ON $tableChanges ($columnDate)');
  }

  int get getVersion {
    return _databaseVersion;
  }
}
