import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:remocall_flutter/models/notification_model.dart';
import 'package:remocall_flutter/models/transaction_model.dart';

class DatabaseService {
  static Database? _database;
  static const String _dbName = 'remocall.db';
  static const int _dbVersion = 3;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);

    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Create notifications table
    await db.execute('''
      CREATE TABLE notifications(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        package_name TEXT NOT NULL,
        sender TEXT NOT NULL,
        message TEXT NOT NULL,
        parsed_data TEXT,
        received_at TEXT NOT NULL,
        is_sent INTEGER DEFAULT 0,
        sent_at TEXT,
        error_message TEXT,
        is_server_sent INTEGER DEFAULT 0,
        server_sent_at TEXT
      )
    ''');

    // Create transactions table
    await db.execute('''
      CREATE TABLE transactions(
        id TEXT PRIMARY KEY,
        type TEXT NOT NULL,
        amount REAL NOT NULL,
        description TEXT NOT NULL,
        sender TEXT,
        receiver TEXT,
        category TEXT NOT NULL,
        created_at TEXT NOT NULL,
        status TEXT DEFAULT 'completed',
        account TEXT,
        balance REAL,
        is_synced INTEGER DEFAULT 0,
        raw_message TEXT
      )
    ''');

    // Create indexes
    await db.execute('CREATE INDEX idx_notifications_sent ON notifications(is_sent)');
    await db.execute('CREATE INDEX idx_transactions_synced ON transactions(is_synced)');
  }

  Future<void> initialize() async {
    await database;
  }

  // Notification methods
  Future<int> insertNotification(NotificationModel notification) async {
    final db = await database;
    return await db.insert('notifications', notification.toJson());
  }

  Future<List<NotificationModel>> getNotifications() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'notifications',
      orderBy: 'received_at DESC',
    );
    return List.generate(maps.length, (i) => NotificationModel.fromJson(maps[i]));
  }

  Future<List<NotificationModel>> getUnsentNotifications() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'notifications',
      where: 'is_sent = ?',
      whereArgs: [0],
      orderBy: 'received_at ASC',
    );
    return List.generate(maps.length, (i) => NotificationModel.fromJson(maps[i]));
  }

  Future<void> markNotificationAsSent(int id) async {
    final db = await database;
    await db.update(
      'notifications',
      {
        'is_sent': 1,
        'sent_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }
  
  Future<void> markNotificationAsServerSent(int id) async {
    final db = await database;
    await db.update(
      'notifications',
      {
        'is_server_sent': 1,
        'server_sent_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }
  
  Future<List<NotificationModel>> getUnsentToServerNotifications() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'notifications',
      where: 'is_server_sent = ? AND parsed_data IS NOT NULL',
      whereArgs: [0],
      orderBy: 'received_at ASC',
    );
    return List.generate(maps.length, (i) => NotificationModel.fromJson(maps[i]));
  }

  Future<void> deleteNotification(int id) async {
    final db = await database;
    await db.delete(
      'notifications',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Transaction methods
  Future<int> insertTransaction(TransactionModel transaction) async {
    final db = await database;
    return await db.insert('transactions', transaction.toJson());
  }

  Future<List<TransactionModel>> getTransactions() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      orderBy: 'created_at DESC',
      limit: 100,
    );
    return List.generate(maps.length, (i) => TransactionModel.fromJson(maps[i]));
  }

  Future<void> deleteOldData(DateTime before) async {
    final db = await database;
    final beforeStr = before.toIso8601String();
    
    await db.delete(
      'notifications',
      where: 'received_at < ?',
      whereArgs: [beforeStr],
    );
    
    await db.delete(
      'transactions',
      where: 'created_at < ?',
      whereArgs: [beforeStr],
    );
  }
  
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add new columns for server sent status
      await db.execute('ALTER TABLE notifications ADD COLUMN is_server_sent INTEGER DEFAULT 0');
      await db.execute('ALTER TABLE notifications ADD COLUMN server_sent_at TEXT');
    }
  }
}