import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/expense.dart';
import '../models/user.dart';

class DatabaseHelper {
  DatabaseHelper._internal();

  static final DatabaseHelper instance = DatabaseHelper._internal();

  static const _databaseName = 'prm393_expense_manager.db';
  static const _databaseVersion = 4;

  static const userTable = 'users';
  static const expenseTable = 'expenses';

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDatabase();
    return _db!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _databaseName);

    return openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $userTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT UNIQUE NOT NULL,
        email TEXT NOT NULL,
        password TEXT NOT NULL,
        createdAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE $expenseTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        amount REAL NOT NULL,
        category TEXT NOT NULL,
        note TEXT,
        date TEXT NOT NULL,
        userId INTEGER NOT NULL,
        FOREIGN KEY (userId) REFERENCES $userTable (id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS $expenseTable (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          title TEXT NOT NULL,
          amount REAL NOT NULL,
          category TEXT NOT NULL,
          note TEXT,
          date TEXT NOT NULL,
          userId INTEGER NOT NULL,
          FOREIGN KEY (userId) REFERENCES $userTable (id) ON DELETE CASCADE
        )
      ''');
    }

    if (oldVersion < 4) {
      await db.execute('DROP TABLE IF EXISTS artworks');
      await db.execute('DROP TABLE IF EXISTS favorites');
    }
  }

  Future<bool> isUsernameTaken(String username) async {
    final db = await database;
    final result = await db.query(
      userTable,
      columns: ['id'],
      where: 'username = ?',
      whereArgs: [username],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  Future<int> registerUser(UserModel user) async {
    final db = await database;
    return db.insert(userTable, user.toMap());
  }

  Future<UserModel?> login(String username, String password) async {
    final db = await database;
    final result = await db.query(
      userTable,
      where: 'username = ? AND password = ?',
      whereArgs: [username, password],
      limit: 1,
    );

    if (result.isEmpty) return null;
    return UserModel.fromMap(result.first);
  }

  Future<UserModel?> getUserById(int userId) async {
    final db = await database;
    final result = await db.query(
      userTable,
      where: 'id = ?',
      whereArgs: [userId],
      limit: 1,
    );

    if (result.isEmpty) return null;
    return UserModel.fromMap(result.first);
  }

  Future<int> insertExpense(Expense expense) async {
    final db = await database;
    return db.insert(expenseTable, expense.toMap());
  }

  Future<List<Expense>> getExpensesByUser(int userId) async {
    final db = await database;
    final result = await db.query(
      expenseTable,
      where: 'userId = ?',
      whereArgs: [userId],
      orderBy: 'date DESC, id DESC',
    );
    return result.map(Expense.fromMap).toList();
  }

  Future<double> getTotalExpenseByUser(int userId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT SUM(amount) AS total FROM $expenseTable WHERE userId = ?',
      [userId],
    );

    final total = result.first['total'];
    if (total == null) return 0;
    return (total as num).toDouble();
  }

  Future<bool> updateUserPassword(int userId, String newPassword) async {
    final db = await database;
    final result = await db.update(
      userTable,
      {'password': newPassword},
      where: 'id = ?',
      whereArgs: [userId],
    );
    return result > 0;
  }

  Future<int> deleteExpense(int expenseId) async {
    final db = await database;
    return db.delete(expenseTable, where: 'id = ?', whereArgs: [expenseId]);
  }

  Future<int> deleteUser(int userId) async {
    final db = await database;
    return db.delete(userTable, where: 'id = ?', whereArgs: [userId]);
  }
}
