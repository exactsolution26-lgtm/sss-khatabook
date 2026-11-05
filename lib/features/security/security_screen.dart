import '../../core/localization/app_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/security/app_lock.dart';

class AppLockGate extends StatefulWidget {
  const AppLockGate({super.key, required this.child, this.controller});
  final Widget child;
  final AppLock? controller;
  @override
  State<AppLockGate> createState() => _AppLockGateState();
}
class _AppLockGateState extends State<AppLockGate> {
  late final AppLock lock;
  final pin = TextEditingController();
  bool opened = false, busy = false;
  @override
  void initState() {super.initState(); lock = widget.controller ?? AppLock.instance; WidgetsBinding.instance.addObserver(lock); lock.load();}
  @override
  void dispose() {WidgetsBinding.instance.removeObserver(lock); pin.dispose(); super.dispose();}
  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: lock, builder: (context, child) {
    if (lock.loaded && !lock.locked && lock.storageError == null) opened = true;
    final hidden = !lock.loaded || lock.locked || lock.storageError != null;
    return Stack(fit: StackFit.expand, children: [
      if (opened) ExcludeSemantics(excluding: hidden, child: Offstage(offstage: hidden, child: TickerMode(enabled: !hidden, child: widget.child))),
      if (hidden) Scaffold(body: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400), child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.lock_outline, size: 40), const SizedBox(height: 16), const AppText('Unlock SSS Khatabook'),
          if (lock.storageError != null) ...[
            Text(lock.storageError!), TextButton(onPressed: lock.load, child: const AppText('Retry')),
          ] else if (!lock.loaded) const CircularProgressIndicator() else ...[
            const SizedBox(height: 20),
            TextField(controller: pin, obscureText: true, keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
              enableSuggestions: false, autocorrect: false, decoration: const InputDecoration(labelText: 'Six digit PIN')),
            const SizedBox(height: 16), FilledButton(onPressed: busy ? null : () async {
              setState(() => busy = true);
              await lock.unlock(pin.text); pin.clear();
              if (mounted) setState(() => busy = false);
            }, child: Text(busy ? 'Checking…' : 'Unlock')),
            if (lock.biometricEnabled) TextButton.icon(onPressed: busy ? null : () => lock.unlockBiometric(),
              icon: const Icon(Icons.fingerprint), label: const AppText('Use biometrics')),
            if (lock.message != null) Text(lock.message!),
          ],
        ]),
      )))),
    ]);
  });
}

class SecurityScreen extends StatefulWidget {
  const SecurityScreen({super.key});
  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}
class _SecurityScreenState extends State<SecurityScreen> {
  final current = TextEditingController(), next = TextEditingController(), confirm = TextEditingController();
  final lock = AppLock.instance;
  bool busy = false; String? message;
  @override
  void dispose() {current.dispose(); next.dispose(); confirm.dispose(); super.dispose();}
  Widget field(TextEditingController controller, String label) => Padding(padding: const EdgeInsets.only(bottom: 16),
    child: TextField(controller: controller, obscureText: true, keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
      enableSuggestions: false, autocorrect: false, decoration: InputDecoration(labelText: label)));
  Future<void> run(Future<void> Function() action) async {
    setState(() {busy = true; message = null;});
    try {await action(); current.clear(); next.clear(); confirm.clear(); if (mounted) setState(() => message = 'Security settings saved.');}
    catch (_) {if (mounted) setState(() => message = 'Check your current PIN and matching new PINs, then retry. Biometrics require device support.');}
    finally {if (mounted) setState(() => busy = false);}
  }
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const AppText('PIN & Biometrics')),
    body: ListenableBuilder(listenable: lock, builder: (context, child) => AbsorbPointer(absorbing: busy,
      child: ListView(padding: const EdgeInsets.all(24), children: [
        const AppText('Lock this app on your device. Keep your PIN and portable backup passphrase safe.'),
        const SizedBox(height: 20),
        if (!lock.supported) const AppText('App PIN and biometrics are available on Android and iOS. Browser account security requires the online authentication setup.') else ...[
          if (lock.enabled) field(current, 'Current PIN'),
          field(next, 'New six digit PIN'), field(confirm, 'Confirm new PIN'),
          FilledButton(onPressed: () => run(() async {
            if (next.text != confirm.text) throw ArgumentError('PINs do not match');
            await lock.setPin(next.text, currentPin: current.text);
          }), child: Text(lock.enabled ? 'Change PIN' : 'Enable PIN')),
          if (lock.enabled) ...[
            OutlinedButton(onPressed: () => run(() => lock.setBiometric(!lock.biometricEnabled, current.text)),
              child: Text(lock.biometricEnabled ? 'Disable biometrics' : 'Enable biometrics')),
            TextButton(onPressed: () => run(() => lock.disable(current.text)), child: const AppText('Disable PIN')),
            TextButton(onPressed: lock.lock, child: const AppText('Lock now')),
          ],
        ],
        if (busy) const LinearProgressIndicator(),
        if (message != null) Text(message!),
      ]))),
  );
}
