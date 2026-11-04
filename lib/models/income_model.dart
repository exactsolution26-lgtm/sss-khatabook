import '../core/utils/date_utils.dart';

class IncomeModel {
  final int? id;
  final int accountId;
  final double amount;
  final String? description;
  final DateTime date;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? contactName, contactPhone, category, mode;

  IncomeModel({
    this.id,
    required this.accountId,
    required this.amount,
    this.description,
    required this.date,
    required this.createdAt,
    this.updatedAt, this.contactName, this.contactPhone, this.category, this.mode,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'account_id': accountId,
      'amount': amount,
      'description': description,
      'date': DateUtils.formatDate(date),
      'created_at': DateUtils.formatDateTime(createdAt),
      'updated_at': updatedAt?.toUtc().toIso8601String(),
      'contact_name': contactName, 'contact_phone': contactPhone,
      'category': category, 'mode': mode,
    };
  }

  factory IncomeModel.fromMap(Map<String, dynamic> map) {
    return IncomeModel(
      id: map['id'] as int?,
      accountId: map['account_id'] as int,
      amount: (map['amount'] as num).toDouble(),
      description: map['description'] as String?,
      date: DateUtils.parseDate(map['date'] as String),
      createdAt: DateUtils.parseDateTime(map['created_at'] as String),
      updatedAt: map['updated_at'] == null ? null : DateTime.parse(map['updated_at'] as String),
      contactName: map['contact_name'] as String?, contactPhone: map['contact_phone'] as String?,
      category: map['category'] as String?, mode: map['mode'] as String?,
    );
  }

  IncomeModel copyWith({
    int? id,
    int? accountId,
    double? amount,
    String? description,
    DateTime? date,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? contactName, contactPhone, category, mode,
  }) {
    return IncomeModel(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      amount: amount ?? this.amount,
      description: description ?? this.description,
      date: date ?? this.date,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      contactName: contactName ?? this.contactName, contactPhone: contactPhone ?? this.contactPhone,
      category: category ?? this.category, mode: mode ?? this.mode,
    );
  }
}
