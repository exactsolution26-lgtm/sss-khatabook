import 'package:flutter/foundation.dart';
import '../../database/db_helper.dart';
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

  Future<void> saved() async {
    final selected = await showModalBottomSheet<(String,String)>(context: context,isScrollControlled: true,
      builder: (_) => const _SavedContactPicker());
    if(selected == null || !mounted) return;
    widget.name.text=selected.$1; widget.phone.text=selected.$2; widget.onChanged?.call();
  }

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
      OutlinedButton.icon(onPressed: saved,icon: const Icon(Icons.people_outline),label: const Text('Choose saved contact')),
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

class _SavedContactPicker extends StatefulWidget {
  const _SavedContactPicker();
  @override State<_SavedContactPicker> createState() => _SavedContactPickerState();
}
class _SavedContactPickerState extends State<_SavedContactPicker> {
  late final Future<List<Map<String,Object?>>> contacts=load(); String query='';
  Future<List<Map<String,Object?>>> load() async => (await DBHelper.database).rawQuery('''SELECT contact_name,contact_phone FROM income
    WHERE contact_name IS NOT NULL AND contact_phone IS NOT NULL
    UNION SELECT contact_name,contact_phone FROM expenses WHERE contact_name IS NOT NULL AND contact_phone IS NOT NULL
    UNION SELECT name AS contact_name,phone AS contact_phone FROM contact_directory
    UNION SELECT contact_name,contact_phone FROM obligations WHERE contact_name IS NOT NULL AND contact_phone IS NOT NULL
    ORDER BY contact_name COLLATE NOCASE''');
  @override Widget build(BuildContext context) => SafeArea(child: SizedBox(height: MediaQuery.sizeOf(context).height*0.75,
    child: Column(children: [
      const Padding(padding: EdgeInsets.all(16),child: Text('Saved contacts',style: TextStyle(fontSize: 20,fontWeight: FontWeight.bold))),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 16),child: TextField(decoration: const InputDecoration(labelText: 'Search name or number',prefixIcon: Icon(Icons.search)),onChanged: (v) => setState(() => query=v.toLowerCase()))),
      Expanded(child: FutureBuilder<List<Map<String,Object?>>>(future: contacts,builder: (context,snapshot) {
        if(snapshot.hasError) return const Center(child: Text('Could not load contacts. Enter details manually.'));
        if(!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final rows=snapshot.data!.where((r) => '${r['contact_name']} ${r['contact_phone']}'.toLowerCase().contains(query)).toList();
        if(rows.isEmpty) return const Center(child: Text('No saved contacts. Choose a phone contact or enter details below.'));
        return ListView(children: rows.map((r) => ListTile(leading: const Icon(Icons.person_outline),title: Text(r['contact_name'] as String),subtitle: Text(r['contact_phone'] as String),
          onTap: () => Navigator.pop(context,(r['contact_name'] as String,r['contact_phone'] as String)))).toList());
      })),
    ])));
}
