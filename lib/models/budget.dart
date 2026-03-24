class Budget {
  final int? id;
  final int userId;
  final String? category;
  final double amount;
  final DateTime startDate;
  final DateTime endDate;
  final bool repeatMonthly;
  final DateTime createdAt;

  Budget({
    this.id,
    required this.userId,
    this.category,
    required this.amount,
    required this.startDate,
    required this.endDate,
    this.repeatMonthly = false,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'category': category ?? '',
      'amount': amount,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'repeatMonthly': repeatMonthly ? 1 : 0,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Budget.fromMap(Map<String, dynamic> map) {
    final rawCategory = (map['category'] as String?)?.trim();
    return Budget(
      id: map['id'] as int?,
      userId: map['userId'] as int,
      category: rawCategory == null || rawCategory.isEmpty ? null : rawCategory,
      amount: (map['amount'] as num).toDouble(),
      startDate: DateTime.parse(map['startDate'] as String),
      endDate: DateTime.parse(map['endDate'] as String),
      repeatMonthly: (map['repeatMonthly'] as int? ?? 0) == 1,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }

  Budget copyWith({
    int? id,
    int? userId,
    String? category,
    double? amount,
    DateTime? startDate,
    DateTime? endDate,
    bool? repeatMonthly,
    DateTime? createdAt,
  }) {
    return Budget(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      category: category ?? this.category,
      amount: amount ?? this.amount,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      repeatMonthly: repeatMonthly ?? this.repeatMonthly,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
