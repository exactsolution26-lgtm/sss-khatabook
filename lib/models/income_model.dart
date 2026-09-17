import '../core/utils/date_utils.dart';

class IncomeModel {
  final int? id;
  final int accountId;
  final double amount;
  final String? description;
  final DateTime date;
  final DateTime createdAt;

  IncomeModel({
    this.id,
    required this.accountId,
    required this.amount,
    this.description,
    required this.date,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'account_id': accountId,
      'amount': amount,
      'description': description,
      'date': AppDateUtils.formatDate(date),
      'created_at': AppDateUtils.formatDateTime(createdAt),
    };
  }

  factory IncomeModel.fromMap(Map<String, dynamic> map) {
    return IncomeModel(
      id: map['id'] as int?,
      accountId: map['account_id'] as int,
      amount: (map['amount'] as num).toDouble(),
      description: map['description'] as String?,
      date: AppDateUtils.parseDate(map['date'] as String),
      createdAt: AppDateUtils.parseDateTime(map['created_at'] as String),
    );
  }

  IncomeModel copyWith({
    int? id,
    int? accountId,
    double? amount,
    String? description,
    DateTime? date,
    DateTime? createdAt,
  }) {
    return IncomeModel(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      amount: amount ?? this.amount,
      description: description ?? this.description,
      date: date ?? this.date,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
