class PartySnapshot {
  const PartySnapshot(this.name, this.phone);
  final String name;
  final String phone;

  static PartySnapshot? optional(String? name, String? phone) {
    final cleanName = (name ?? '').trim();
    var raw = (phone ?? '').trim();
    if (cleanName.isEmpty && raw.isEmpty) return null;
    if (cleanName.isEmpty || cleanName.length > 120 || raw.isEmpty ||
        !RegExp(r'^\+?[0-9\s().-]+$').hasMatch(raw)) {
      throw ArgumentError('Enter a contact name and valid phone number');
    }
    if (raw.startsWith('00')) raw = '+${raw.substring(2)}';
    var digits = raw.replaceAll(RegExp(r'\D'), '');
    if (!raw.startsWith('+') && digits.length == 10) digits = '91$digits';
    else if (!raw.startsWith('+')) {
      throw ArgumentError('Include the country code for this phone number');
    }
    if (digits.length < 7 || digits.length > 15 || digits.startsWith('0')) {
      throw ArgumentError('Enter a valid international phone number');
    }
    return PartySnapshot(cleanName, '+$digits');
  }

  Map<String, Object?> toMap() => {'contact_name': name, 'contact_phone': phone};
}
