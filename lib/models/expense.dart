class Expense {
  final int? id;
  final String title;
  final double amount;
  final String category;
  final String note;
  final String date;
  final int userId;

  Expense({
    this.id,
    required this.title,
    required this.amount,
    required this.category,
    required this.note,
    required this.date,
    required this.userId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'category': category,
      'note': note,
      'date': date,
      'userId': userId,
    };
  }

  factory Expense.fromMap(Map<String, dynamic> map) {
    return Expense(
      id: map['id'] as int?,
      title: map['title'] as String,
      amount: (map['amount'] as num).toDouble(),
      category: map['category'] as String,
      note: (map['note'] as String?) ?? '',
      date: map['date'] as String,
      userId: map['userId'] as int,
    );
  }
}
