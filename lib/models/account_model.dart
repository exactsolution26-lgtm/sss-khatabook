import '../core/utils/date_utils.dart';

class AccountModel {
  final int? id;
  final String name;
  final double openingBalance;
  final DateTime createdAt;

  AccountModel({
    this.id,
    required this.name,
    required this.openingBalance,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'opening_balance': openingBalance,
      'created_at': AppDateUtils.formatDateTime(createdAt),
    };
  }

  factory AccountModel.fromMap(Map<String, dynamic> map) {
    return AccountModel(
      id: map['id'] as int?,
      name: map['name'] as String,
      openingBalance: (map['opening_balance'] as num).toDouble(),
      createdAt: AppDateUtils.parseDateTime(map['created_at'] as String),
    );
  }

  AccountModel copyWith({
    int? id,
    String? name,
    double? openingBalance,
    DateTime? createdAt,
  }) {
    return AccountModel(
      id: id ?? this.id,
      name: name ?? this.name,
      openingBalance: openingBalance ?? this.openingBalance,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
