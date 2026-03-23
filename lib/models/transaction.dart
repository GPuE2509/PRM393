enum TransactionType { expense, income, loan }

class Transaction {
  final int? id;
  final TransactionType type;
  final double amount;
  final String? category;
  final String note;
  final DateTime date;
  final int userId;

  Transaction({
    this.id,
    required this.type,
    required this.amount,
    this.category,
    required this.note,
    required this.date,
    required this.userId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.name,
      'amount': amount,
      'category': category ?? '',
      'note': note,
      'date': date.toIso8601String(),
      'userId': userId,
    };
  }

  factory Transaction.fromMap(Map<String, dynamic> map) {
    return Transaction(
      id: map['id'] as int?,
      type: TransactionType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => TransactionType.expense,
      ),
      amount: (map['amount'] as num).toDouble(),
      category: (map['category'] as String?)?.isNotEmpty == true ? map['category'] as String? : null,
      note: (map['note'] as String?) ?? '',
      date: DateTime.parse(map['date'] as String),
      userId: map['userId'] as int,
    );
  }

  Transaction copyWith({
    int? id,
    TransactionType? type,
    double? amount,
    String? category,
    String? note,
    DateTime? date,
    int? userId,
  }) {
    return Transaction(
      id: id ?? this.id,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      note: note ?? this.note,
      date: date ?? this.date,
      userId: userId ?? this.userId,
    );
  }
}
