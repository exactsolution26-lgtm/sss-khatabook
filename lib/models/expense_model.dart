class ExpenseModel {
  final int? id;
  final int? accountId;
  final double amount;
  final String mode; // cash / online
  final String category;
  final String note;
  final String date;

  ExpenseModel({
    this.id,
    this.accountId,
    required this.amount,
    required this.mode,
    required this.category,
    required this.note,
    required this.date,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'account_id': accountId,
      'amount': amount,
      'mode': mode,
      'category': category,
      'note': note,
      'date': date,
    };
  }
}
