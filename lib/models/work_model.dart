import '../core/utils/date_utils.dart';

class WorkModel {
  final int? id;
  final DateTime date;
  final DateTime? startTime;
  final DateTime? endTime;
  final int duration; // in seconds
  final String? description;
  final DateTime createdAt;

  WorkModel({
    this.id,
    required this.date,
    this.startTime,
    this.endTime,
    required this.duration,
    this.description,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': AppDateUtils.formatDate(date),
      'start_time': startTime != null ? AppDateUtils.formatDateTime(startTime!) : null,
      'end_time': endTime != null ? AppDateUtils.formatDateTime(endTime!) : null,
      'duration': duration,
      'description': description,
      'created_at': AppDateUtils.formatDateTime(createdAt),
    };
  }

  factory WorkModel.fromMap(Map<String, dynamic> map) {
    return WorkModel(
      id: map['id'] as int?,
      date: AppDateUtils.parseDate(map['date'] as String),
      startTime: map['start_time'] != null
          ? AppDateUtils.parseDateTime(map['start_time'] as String)
          : null,
      endTime: map['end_time'] != null
          ? AppDateUtils.parseDateTime(map['end_time'] as String)
          : null,
      duration: map['duration'] as int,
      description: map['description'] as String?,
      createdAt: AppDateUtils.parseDateTime(map['created_at'] as String),
    );
  }

  String get formattedDuration => AppDateUtils.formatDuration(duration);

  WorkModel copyWith({
    int? id,
    DateTime? date,
    DateTime? startTime,
    DateTime? endTime,
    int? duration,
    String? description,
    DateTime? createdAt,
  }) {
    return WorkModel(
      id: id ?? this.id,
      date: date ?? this.date,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      duration: duration ?? this.duration,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
