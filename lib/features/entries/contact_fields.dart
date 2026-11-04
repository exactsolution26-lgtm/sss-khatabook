import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_native_contact_picker/flutter_native_contact_picker.dart';

/// The native picker returns only the contact explicitly chosen by the user.
/// No contact-book enumeration or automatic upload is performed here.
class ContactFields extends StatefulWidget {
  const ContactFields({super.key, required this.name, required this.phone, this.onChanged});
  final TextEditingController name;
  final TextEditingController phone;
  final VoidCallback? onChanged;

  @override
  State<ContactFields> createState() => _ContactFieldsState();
}

class _ContactFieldsState extends State<ContactFields> {
  bool picking = false;

  Future<void> pick() async {
    if (picking) return;
    setState(() => picking = true);
    try {
      final selected = await FlutterNativeContactPicker().selectPhoneNumber();
      if (!mounted || selected == null) return;
      final numbers = selected.phoneNumbers ?? const <String>[];
      widget.name.text = selected.fullName ?? '';
      widget.phone.text = selected.selectedPhoneNumber ?? (numbers.isEmpty ? '' : numbers.first);
      widget.onChanged?.call();
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contact picker unavailable. Enter the details below.')),
      );
    } finally {
      if (mounted) setState(() => picking = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS))
        OutlinedButton.icon(onPressed: picking ? null : pick,
          icon: const Icon(Icons.contact_page_outlined),
          label: Text(picking ? 'Opening contacts…' : 'Choose from Contacts')),
      TextFormField(controller: widget.name, keyboardType: TextInputType.name,
        decoration: const InputDecoration(labelText: 'Contact name (optional)'),
        onChanged: (_) => widget.onChanged?.call()),
      const SizedBox(height: 12),
      TextFormField(controller: widget.phone, keyboardType: TextInputType.phone,
        decoration: const InputDecoration(labelText: 'Mobile number (optional)'),
        onChanged: (_) => widget.onChanged?.call()),
    ],
  );
}
