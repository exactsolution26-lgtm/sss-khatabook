class ExpenseModel {
  final int? id;
  final int? accountId;
  final double amount;
  final String mode; // cash / online
  final String category;
  final String note;
  final String date;
  final String? contactName, contactPhone;
  final DateTime? createdAt, updatedAt;

  ExpenseModel({
    this.id,
    this.accountId,
    required this.amount,
    required this.mode,
    required this.category,
    required this.note,
    required this.date,
    this.contactName, this.contactPhone, this.createdAt, this.updatedAt,
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
      'contact_name': contactName, 'contact_phone': contactPhone,
      'created_at': createdAt?.toUtc().toIso8601String(),
      'updated_at': updatedAt?.toUtc().toIso8601String(),
    };
  }
  factory ExpenseModel.fromMap(Map<String, dynamic> row) => ExpenseModel(
    id: row['id'] as int?, accountId: row['account_id'] as int?,
    amount: (row['amount'] as num).toDouble(), mode: row['mode'] as String? ?? 'unknown',
    category: row['category'] as String? ?? '', note: row['note'] as String? ?? '',
    date: row['date'] as String,
    contactName: row['contact_name'] as String?, contactPhone: row['contact_phone'] as String?,
    createdAt: row['created_at'] == null ? null : DateTime.parse(row['created_at'] as String),
    updatedAt: row['updated_at'] == null ? null : DateTime.parse(row['updated_at'] as String),
  );
}
