class ExpenseModel {
  final int? id;
  final int? accountId;
  final double amount;
  final String? mode; // cash / online
  final String? category;
  final String? note;
  final String date;

  ExpenseModel({
    this.id,
    this.accountId,
    required this.amount,
    this.mode,
    this.category,
    this.note,
    required this.date,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'account_id': accountId,
      'amount': amount,
      'mode': mode,
      'category': category,
      'note': note,
      'date': date,
    };
  }

  factory ExpenseModel.fromMap(Map<String, dynamic> map) {
    return ExpenseModel(
      id: map['id'] as int?,
      accountId: map['account_id'] as int?,
      amount: (map['amount'] as num).toDouble(),
      mode: map['mode'] as String?,
      category: map['category'] as String?,
      note: map['note'] as String?,
      date: map['date'] as String,
    );
  }
}
