import '../core/utils/date_utils.dart';

class AccountModel {
  final int? id;
  final String name;
  final double openingBalance;
  final DateTime createdAt;
  final DateTime? archivedAt;
  bool get isArchived=>archivedAt!=null;

  AccountModel({
    this.id,
    required this.name,
    required this.openingBalance,
    required this.createdAt,
    this.archivedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'opening_balance': openingBalance,
      'created_at': DateUtils.formatDateTime(createdAt),
      'archived_at': archivedAt?.toUtc().toIso8601String(),
    };
  }

  factory AccountModel.fromMap(Map<String, dynamic> map) {
    return AccountModel(
      id: map['id'] as int?,
      name: map['name'] as String,
      openingBalance: (map['opening_balance'] as num).toDouble(),
      createdAt: DateUtils.parseDateTime(map['created_at'] as String),
      archivedAt: map['archived_at']==null?null:DateTime.parse(map['archived_at'] as String),
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
      archivedAt: archivedAt,
    );
  }
}
