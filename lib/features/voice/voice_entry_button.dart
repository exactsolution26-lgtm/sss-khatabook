import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'voice_draft.dart';

class VoiceEntryButton extends StatelessWidget {
  const VoiceEntryButton({super.key,required this.onConfirmed,required this.income});
  final ValueChanged<VoiceDraft> onConfirmed;final bool income;
  @override Widget build(BuildContext context) => OutlinedButton.icon(icon: const Icon(Icons.mic_none),label: const Text('Voice entry — review first'),
    onPressed: () async {
      final draft=await showDialog<VoiceDraft>(context: context,builder: (_) => _VoiceDialog(income: income));
      if(draft!=null && context.mounted) onConfirmed(draft);
    });
}
class _VoiceDialog extends StatefulWidget {
  const _VoiceDialog({required this.income}); final bool income;
  @override State<_VoiceDialog> createState() => _VoiceDialogState();
}
class _VoiceDialogState extends State<_VoiceDialog> with WidgetsBindingObserver {
  final speech=stt.SpeechToText();final transcript=TextEditingController();
  bool hindi=false,onDevice=true,busy=false,listening=false;String? error;
  @override void initState() {super.initState();WidgetsBinding.instance.addObserver(this);}
  @override void didChangeAppLifecycleState(AppLifecycleState state) {if(state!=AppLifecycleState.resumed) {speech.cancel();if(mounted) setState(() => listening=false);}}
  @override void dispose() {WidgetsBinding.instance.removeObserver(this);speech.cancel();transcript.dispose();super.dispose();}
  Future<void> start() async {
    if(busy || listening) return;
    setState(() {busy=true;error=null;});
    try {
      final ready=await speech.initialize(onStatus: (status) {if(mounted) setState(() => listening=status=='listening');},
        onError: (_) {if(mounted) setState(() {listening=false;error='Speech unavailable. You can type the phrase or use the entry form.';});});
      if(!ready) throw StateError('Speech permission or service unavailable');
      final locales=await speech.locales();
      final matching=locales.where((l) => l.localeId.toLowerCase().replaceAll('_','-').startsWith(hindi ? 'hi-' : 'en-')).toList();
      if(matching.isEmpty) throw StateError('Language unavailable');
      final indian=matching.where((l) => l.localeId.toLowerCase().endsWith('in')).toList();
      if(!mounted) return;
      await speech.listen(onResult: (result) {if(mounted) setState(() => transcript.text=result.recognizedWords);},
        listenOptions: stt.SpeechListenOptions(localeId: (indian.isNotEmpty ? indian.first : matching.first).localeId,
          onDevice: onDevice,cancelOnError: true,partialResults: true,listenFor: const Duration(seconds: 25)));
    } catch (_) {if(mounted) setState(() => error='Microphone or selected speech language is unavailable. Type below instead.');}
    finally {if(mounted) setState(() => busy=false);}
  }
  Future<void> review() async {
    await speech.stop();if(!mounted) return;
    try {
      final draft=VoiceDraft.parse(transcript.text);
      if(draft.income!=null && draft.income!=widget.income) {setState(() => error='This phrase describes ${draft.income! ? 'income' : 'an expense'}. Open the matching entry form.');return;}
      final approved=await showDialog<bool>(context: context,builder: (context) => AlertDialog(title: const Text('Confirm recognized details'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min,crossAxisAlignment: CrossAxisAlignment.start,children: [
          Text(widget.income ? 'Income' : 'Expense'),Text('Amount: ${draft.amount ?? 'Enter manually'}'),
          const SizedBox(height: 12),Text(draft.transcript),const SizedBox(height: 12),
          const Text('Use these details to fill the form. Check customer, category and amount before pressing Save.'),
        ])),actions: [TextButton(onPressed: () => Navigator.pop(context,false),child: const Text('Go back')),
          FilledButton(onPressed: () => Navigator.pop(context,true),child: const Text('Use in form'))]));
      if(approved==true && mounted) Navigator.pop(context,draft);
    } catch (_) {if(mounted) setState(() => error='Say or type a short phrase first.');}
  }
  @override Widget build(BuildContext context) => AlertDialog(title: const Text('Voice entry'),content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min,children: [
    const Text('Speech is optional. Nothing is saved until you review the form and press Save.'),
    SwitchListTile(contentPadding: EdgeInsets.zero,title: const Text('Hindi / हिंदी'),value: hindi,onChanged: busy || listening ? null : (v) => setState(() => hindi=v)),
    CheckboxListTile(contentPadding: EdgeInsets.zero,title: const Text('Use on-device recognition'),value: onDevice,onChanged: busy || listening ? null : (v) => setState(() => onDevice=v ?? true)),
    if(!onDevice) const Text('Your device speech provider may process audio online. Continue only if you agree.'),
    OutlinedButton.icon(onPressed: busy ? null : listening ? () async {await speech.stop();} : start,icon: Icon(listening ? Icons.stop : Icons.mic),label: Text(listening ? 'Stop' : busy ? 'Preparing…' : 'Start speaking')),
    TextField(controller: transcript,maxLines: 3,maxLength: 2000,decoration: const InputDecoration(labelText: 'Recognized text — editable',hintText: 'Received 500 rupees / ५०० रुपये मिले')),
    if(error!=null) Text(error!,style: TextStyle(color: Theme.of(context).colorScheme.error)),
  ])),actions: [TextButton(onPressed: () => Navigator.pop(context),child: const Text('Cancel')),FilledButton(onPressed: busy ? null : review,child: const Text('Review details'))]);
}
