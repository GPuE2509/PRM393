import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../models/budget.dart' as budget_model;
import '../models/expense.dart';
import '../models/transaction.dart' as model;
import '../models/user.dart';

class DatabaseHelper {
  DatabaseHelper._internal();

  static final DatabaseHelper instance = DatabaseHelper._internal();

  static const _databaseName = 'prm393_expense_managers.db';
  static const _databaseVersion = 7;

  static const userTable = 'users';
  static const expenseTable = 'expenses';
  static const transactionTable = 'transactions';
  static const budgetTable = 'budgets';

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

    await db.execute('''
      CREATE TABLE $transactionTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        amount REAL NOT NULL,
        category TEXT,
        note TEXT,
        date TEXT NOT NULL,
        userId INTEGER NOT NULL,
        FOREIGN KEY (userId) REFERENCES $userTable (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE $budgetTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        userId INTEGER NOT NULL,
        category TEXT,
        amount REAL NOT NULL,
        startDate TEXT NOT NULL,
        endDate TEXT NOT NULL,
        repeatMonthly INTEGER NOT NULL DEFAULT 0,
        createdAt TEXT NOT NULL,
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

    // Create transactions table if it doesn't exist
    if (oldVersion < 6) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS $transactionTable (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          type TEXT NOT NULL,
          amount REAL NOT NULL,
          category TEXT,
          note TEXT,
          date TEXT NOT NULL,
          userId INTEGER NOT NULL,
          FOREIGN KEY (userId) REFERENCES $userTable (id) ON DELETE CASCADE
        )
      ''');
    }

    // Migrate existing transactions table to make category nullable
    if (oldVersion == 6) {
      // Check if the table exists and has the old schema
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='$transactionTable'",
      );

      if (tables.isNotEmpty) {
        // Get table info to check if category is NOT NULL
        final tableInfo = await db.rawQuery(
          "PRAGMA table_info($transactionTable)",
        );
        final categoryColumn = tableInfo.firstWhere(
          (col) => col['name'] == 'category',
          orElse: () => {},
        );

        // If category column is NOT NULL, migrate it
        if (categoryColumn['notnull'] == 1) {
          await db.execute('''
            CREATE TABLE ${transactionTable}_new (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              type TEXT NOT NULL,
              amount REAL NOT NULL,
              category TEXT,
              note TEXT,
              date TEXT NOT NULL,
              userId INTEGER NOT NULL,
              FOREIGN KEY (userId) REFERENCES $userTable (id) ON DELETE CASCADE
            )
          ''');

          await db.execute('''
            INSERT INTO ${transactionTable}_new 
            SELECT id, type, amount, category, note, date, userId 
            FROM $transactionTable
          ''');

          await db.execute('DROP TABLE $transactionTable');
          await db.execute(
            'ALTER TABLE ${transactionTable}_new RENAME TO $transactionTable',
          );
        }
      }
    }

    if (oldVersion < 4) {
      await db.execute('DROP TABLE IF EXISTS artworks');
      await db.execute('DROP TABLE IF EXISTS favorites');
    }

    if (oldVersion < 7) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS $budgetTable (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          userId INTEGER NOT NULL,
          category TEXT,
          amount REAL NOT NULL,
          startDate TEXT NOT NULL,
          endDate TEXT NOT NULL,
          repeatMonthly INTEGER NOT NULL DEFAULT 0,
          createdAt TEXT NOT NULL,
          FOREIGN KEY (userId) REFERENCES $userTable (id) ON DELETE CASCADE
        )
      ''');
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

  // Transaction CRUD operations
  Future<int> insertTransaction(model.Transaction transaction) async {
    final db = await database;
    return db.insert(transactionTable, transaction.toMap());
  }

  Future<List<model.Transaction>> getTransactionsByUser(int userId) async {
    final db = await database;
    final result = await db.query(
      transactionTable,
      where: 'userId = ?',
      whereArgs: [userId],
      orderBy: 'date DESC, id DESC',
    );
    return result.map(model.Transaction.fromMap).toList();
  }

  Future<List<model.Transaction>> getTransactionsByUserAndType(
    int userId,
    model.TransactionType type,
  ) async {
    final db = await database;
    final result = await db.query(
      transactionTable,
      where: 'userId = ? AND type = ?',
      whereArgs: [userId, type.name],
      orderBy: 'date DESC, id DESC',
    );
    return result.map(model.Transaction.fromMap).toList();
  }

  Future<List<model.Transaction>> searchTransactions(
    int userId,
    String query,
  ) async {
    final db = await database;
    final result = await db.query(
      transactionTable,
      where: 'userId = ? AND (category LIKE ? OR note LIKE ?)',
      whereArgs: [userId, '%$query%', '%$query%'],
      orderBy: 'date DESC, id DESC',
    );
    return result.map(model.Transaction.fromMap).toList();
  }

  Future<List<model.Transaction>> searchTransactionsByCategory(
    int userId,
    String query,
  ) async {
    final db = await database;
    final trimmedQuery = query.trim();
    final likeQuery = '%$trimmedQuery%';

    final result = await db.query(
      transactionTable,
      where: trimmedQuery.isEmpty
          ? 'userId = ?'
          : "userId = ? AND (COALESCE(NULLIF(TRIM(category), ''), '') LIKE ? OR COALESCE(note, '') LIKE ?)",
      whereArgs: trimmedQuery.isEmpty
          ? [userId]
          : [userId, likeQuery, likeQuery],
      orderBy: 'date DESC, id DESC',
    );

    return result.map(model.Transaction.fromMap).toList();
  }

  Future<List<model.Transaction>> getTransactionsByDateRange(
    int userId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final db = await database;
    final result = await db.query(
      transactionTable,
      where: 'userId = ? AND date BETWEEN ? AND ?',
      whereArgs: [
        userId,
        startDate.toIso8601String(),
        endDate.toIso8601String(),
      ],
      orderBy: 'date DESC, id DESC',
    );
    return result.map(model.Transaction.fromMap).toList();
  }

  Future<double> getTotalByUserAndType(
    int userId,
    model.TransactionType type,
  ) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT SUM(amount) AS total FROM $transactionTable WHERE userId = ? AND type = ?',
      [userId, type.name],
    );

    final total = result.first['total'];
    if (total == null) return 0;
    return (total as num).toDouble();
  }

  Future<double> getTotalByUserAndTypeInRange(
    int userId,
    model.TransactionType type,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final db = await database;
    final result = await db.rawQuery(
      '''
      SELECT SUM(amount) AS total
      FROM $transactionTable
      WHERE userId = ? AND type = ? AND date >= ? AND date <= ?
      ''',
      [
        userId,
        type.name,
        startDate.toIso8601String(),
        endDate.toIso8601String(),
      ],
    );

    final total = result.first['total'];
    if (total == null) return 0;
    return (total as num).toDouble();
  }

  Future<Map<String, double>> getCategoryTotalsByUserAndTypeInRange(
    int userId,
    model.TransactionType type,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final db = await database;
    const categoryExpr = "COALESCE(NULLIF(TRIM(category), ''), 'Khác')";

    final rows = await db.rawQuery(
      '''
      SELECT $categoryExpr AS category, SUM(amount) AS total
      FROM $transactionTable
      WHERE userId = ? AND type = ? AND date >= ? AND date <= ?
      GROUP BY $categoryExpr
      ORDER BY total DESC
      ''',
      [
        userId,
        type.name,
        startDate.toIso8601String(),
        endDate.toIso8601String(),
      ],
    );

    final result = <String, double>{};
    for (final row in rows) {
      final category = row['category'] as String? ?? 'Khác';
      final total = (row['total'] as num?)?.toDouble() ?? 0;
      result[category] = total;
    }
    return result;
  }

  Future<Map<String, double>> getMonthlyTotalsByUserAndType(
    int userId,
    model.TransactionType type,
    DateTime startMonth,
    DateTime endMonth,
  ) async {
    final db = await database;
    final start = DateTime(startMonth.year, startMonth.month, 1);
    final end = _lastMomentOfMonth(DateTime(endMonth.year, endMonth.month, 1));

    final rows = await db.rawQuery(
      '''
      SELECT substr(date, 1, 7) AS monthKey, SUM(amount) AS total
      FROM $transactionTable
      WHERE userId = ? AND type = ? AND date >= ? AND date <= ?
      GROUP BY monthKey
      ''',
      [userId, type.name, start.toIso8601String(), end.toIso8601String()],
    );

    final totalsByMonth = <String, double>{};
    for (final row in rows) {
      final key = row['monthKey'] as String?;
      if (key == null) continue;
      totalsByMonth[key] = (row['total'] as num?)?.toDouble() ?? 0;
    }

    final filled = <String, double>{};
    var cursor = DateTime(start.year, start.month, 1);
    final last = DateTime(endMonth.year, endMonth.month, 1);
    while (!cursor.isAfter(last)) {
      final key = _monthKey(cursor);
      filled[key] = totalsByMonth[key] ?? 0;
      cursor = DateTime(cursor.year, cursor.month + 1, 1);
    }

    return filled;
  }

  Future<int> updateTransaction(model.Transaction transaction) async {
    final db = await database;
    return db.update(
      transactionTable,
      transaction.toMap(),
      where: 'id = ?',
      whereArgs: [transaction.id],
    );
  }

  Future<int> deleteTransaction(int transactionId) async {
    final db = await database;
    return db.delete(
      transactionTable,
      where: 'id = ?',
      whereArgs: [transactionId],
    );
  }

  Future<model.Transaction?> getTransactionById(int transactionId) async {
    final db = await database;
    final result = await db.query(
      transactionTable,
      where: 'id = ?',
      whereArgs: [transactionId],
      limit: 1,
    );

    if (result.isEmpty) return null;
    return model.Transaction.fromMap(result.first);
  }

  Future<int> insertBudget(budget_model.Budget budget) async {
    final db = await database;
    return db.insert(budgetTable, budget.toMap());
  }

  Future<int> updateBudget(budget_model.Budget budget) async {
    final db = await database;
    return db.update(
      budgetTable,
      budget.toMap(),
      where: 'id = ?',
      whereArgs: [budget.id],
    );
  }

  Future<int> deleteBudget(int budgetId) async {
    final db = await database;
    return db.delete(budgetTable, where: 'id = ?', whereArgs: [budgetId]);
  }

  Future<List<budget_model.Budget>> getBudgetsByUser(int userId) async {
    final db = await database;
    final rows = await db.query(
      budgetTable,
      where: 'userId = ?',
      whereArgs: [userId],
      orderBy: 'startDate DESC, id DESC',
    );
    return rows.map(budget_model.Budget.fromMap).toList();
  }

  Future<budget_model.Budget?> getRelevantBudgetByUser(
    int userId,
    DateTime at,
  ) async {
    final db = await database;
    final atIso = at.toIso8601String();

    final activeRows = await db.query(
      budgetTable,
      where: 'userId = ? AND startDate <= ? AND endDate >= ?',
      whereArgs: [userId, atIso, atIso],
      orderBy: 'startDate DESC, id DESC',
      limit: 1,
    );

    if (activeRows.isNotEmpty) {
      return budget_model.Budget.fromMap(activeRows.first);
    }

    final latestRows = await db.query(
      budgetTable,
      where: 'userId = ?',
      whereArgs: [userId],
      orderBy: 'endDate DESC, id DESC',
      limit: 1,
    );

    if (latestRows.isEmpty) return null;
    return budget_model.Budget.fromMap(latestRows.first);
  }

  Future<double> getExpenseTotalInRangeForBudget({
    required int userId,
    required DateTime startDate,
    required DateTime endDate,
    String? category,
  }) async {
    final db = await database;
    final normalizedCategory = category?.trim();
    final hasCategoryFilter =
        normalizedCategory != null && normalizedCategory.isNotEmpty;

    final rows = await db.rawQuery(
      '''
      SELECT SUM(amount) AS total
      FROM $transactionTable
      WHERE userId = ?
        AND type = ?
        AND date >= ?
        AND date <= ?
        ${hasCategoryFilter ? "AND COALESCE(NULLIF(TRIM(category), ''), '') = ?" : ''}
      ''',
      [
        userId,
        model.TransactionType.expense.name,
        startDate.toIso8601String(),
        endDate.toIso8601String(),
        if (hasCategoryFilter) normalizedCategory,
      ],
    );

    final total = rows.first['total'];
    if (total == null) return 0;
    return (total as num).toDouble();
  }

  String _monthKey(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    return '${date.year}-$month';
  }

  DateTime _lastMomentOfMonth(DateTime month) {
    return DateTime(
      month.year,
      month.month + 1,
      1,
    ).subtract(const Duration(microseconds: 1));
  }
}
