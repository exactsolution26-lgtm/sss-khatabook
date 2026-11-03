import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum DashboardType {
  simple('Simple Dashboard', 'Cash, bank, income and expenses', Icons.wallet_outlined),
  business('Business Dashboard', 'Accounts, parties and ledger', Icons.business_outlined),
  analytics('Analytics Dashboard', 'Trends, charts and comparisons', Icons.bar_chart_outlined),
  accounting('Accounting Dashboard', 'Profit, loss and cash flow', Icons.calculate_outlined),
  collection('Collection Dashboard', 'Pending payments and follow-ups', Icons.payments_outlined),
  advanced('Advanced Dashboard', 'Detailed financial reporting', Icons.insights_outlined);

  const DashboardType(this.title, this.subtitle, this.icon);
  final String title;
  final String subtitle;
  final IconData icon;
}

class DashboardSelectionScreen extends StatefulWidget {
  const DashboardSelectionScreen({super.key});

  @override
  State<DashboardSelectionScreen> createState() => _DashboardSelectionScreenState();
}

class _DashboardSelectionScreenState extends State<DashboardSelectionScreen> {
  static const _selectionKey = 'active_dashboard_v1';
  DashboardType _selected = DashboardType.simple;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadSelection();
  }

  Future<void> _loadSelection() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_selectionKey);
      if (!mounted) return;
      setState(() {
        _selected = DashboardType.values.firstWhere(
          (item) => item.name == saved,
          orElse: () => DashboardType.simple,
        );
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not load dashboard preference.')),
      );
    }
  }

  Future<void> _saveSelection() async {
    setState(() => _saving = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = await prefs.setString(_selectionKey, _selected.name);
      if (!saved) throw StateError('Preference save failed');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_selected.title} selected')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save dashboard selection.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Choose Dashboard')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text('Choose one of six dashboards. You can change it later.'),
                const SizedBox(height: 12),
                ...DashboardType.values.map(
                  (item) => Card(
                    child: RadioListTile<DashboardType>(
                      value: item,
                      groupValue: _selected,
                      onChanged: _saving ? null : (value) {
                        if (value != null) setState(() => _selected = value);
                      },
                      secondary: Icon(item.icon),
                      title: Text(item.title),
                      subtitle: Text(item.subtitle),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _saving ? null : _saveSelection,
                  child: Text(_saving ? 'Saving...' : 'Save Dashboard Choice'),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Dashboard screens and cloud sync are under development. '
                  'This saves only your choice on this device.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
    );
  }
}
