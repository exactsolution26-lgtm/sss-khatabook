class SubscriberAccount {
  const SubscriberAccount({
    required this.id,
    required this.ownerUserId,
    required this.displayName,
    required this.status,
  });

  final String id;
  final String ownerUserId;
  final String displayName;
  final String status;

  bool get isActive => status == 'active';

  factory SubscriberAccount.fromJson(Map<String, dynamic> json) {
    return SubscriberAccount(
      id: json['id'] as String,
      ownerUserId: json['owner_user_id'] as String,
      displayName: json['display_name'] as String,
      status: json['status'] as String,
    );
  }
}
