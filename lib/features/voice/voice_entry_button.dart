import 'dart:async';
import 'package:flutter/material.dart';
import 'voice_capture.dart';
import 'voice_draft.dart';

class VoiceEntryButton extends StatelessWidget {
  const VoiceEntryButton({super.key,required this.onConfirmed,required this.income,this.capture});
  final ValueChanged<VoiceDraft> onConfirmed;final bool income;
  final VoiceCapture? capture;
  @override Widget build(BuildContext context)=>OutlinedButton.icon(icon:const Icon(Icons.mic_none),label:const Text('Voice entry — review first'),
    onPressed:() async {
      final draft=await showDialog<VoiceDraft>(context:context,builder:(_)=>_VoiceDialog(income:income,capture:capture ?? VoiceCapture.instance));
      if(draft!=null && context.mounted) onConfirmed(draft);
    });
}
class _VoiceDialog extends StatefulWidget {
  const _VoiceDialog({required this.income,required this.capture});final bool income;final VoiceCapture capture;
  @override State<_VoiceDialog> createState()=>_VoiceDialogState();
}
class _VoiceDialogState extends State<_VoiceDialog> with WidgetsBindingObserver {
  final transcript=TextEditingController();String lastWords='';String? reviewError;
  VoiceCapture get capture=>widget.capture;
  @override void initState(){super.initState();WidgetsBinding.instance.addObserver(this);capture.open();capture.addListener(changed);}
  @override void didChangeDependencies(){
    super.didChangeDependencies();
    // AppLockGate disables the financial subtree while locked. A permission
    // result must never start recording behind the PIN screen.
    if(!TickerMode.valuesOf(context).enabled) unawaited(capture.background(notify:false));
  }
  void changed(){
    if(!mounted) return;
    if(capture.words!=lastWords){lastWords=capture.words;if(lastWords.isNotEmpty) transcript.value=TextEditingValue(text:lastWords,selection:TextSelection.collapsed(offset:lastWords.length));}
    setState((){});
  }
  @override void didChangeAppLifecycleState(AppLifecycleState state){
    if(state==AppLifecycleState.hidden || state==AppLifecycleState.paused || state==AppLifecycleState.detached) unawaited(capture.background());
  }
  @override void dispose(){WidgetsBinding.instance.removeObserver(this);capture.removeListener(changed);unawaited(capture.close());transcript.dispose();super.dispose();}
  Future<void> provider() async {
    final accepted=await showDialog<bool>(context:context,builder:(context)=>AlertDialog(title:const Text('Use device speech service?'),
      content:const Text('Your phone’s speech provider may process audio online. Audio is not sent to Supabase by this app. Continue only if you agree.'),
      actions:[TextButton(onPressed:()=>Navigator.pop(context,false),child:const Text('Cancel')),
        FilledButton(onPressed:()=>Navigator.pop(context,true),child:const Text('Continue'))]));
    if(accepted==true && mounted){capture.setOffline(false);await capture.start();}
  }
  Future<void> review() async {
    await capture.stop();if(!mounted) return;
    try {
      final draft=VoiceDraft.parse(transcript.text);
      if(draft.income!=null && draft.income!=widget.income){setState(()=>reviewError='This phrase describes ${draft.income! ? 'income':'an expense'}. Open the matching entry form.');return;}
      final approved=await showDialog<bool>(context:context,builder:(context)=>AlertDialog(title:const Text('Confirm recognized details'),
        content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text(widget.income ? 'Income':'Expense'),Text('Amount: ${draft.amount ?? 'Enter manually'}'),const SizedBox(height:12),
          Text(draft.transcript),const SizedBox(height:12),const Text('Use these details to fill the form. Check customer, category and amount before pressing Save.'),
        ])),actions:[TextButton(onPressed:()=>Navigator.pop(context,false),child:const Text('Go back')),
          FilledButton(onPressed:()=>Navigator.pop(context,true),child:const Text('Use in form'))]));
      if(approved==true && mounted) Navigator.pop(context,draft);
    }catch(_){if(mounted) setState(()=>reviewError='Say or type a short phrase first.');}
  }
  @override Widget build(BuildContext context)=>AlertDialog(title:const Text('Voice entry'),content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
    const Text('Speech is optional. Nothing is saved until you review the form and press Save.'),
    DropdownButtonFormField<VoiceLanguage>(key:ValueKey(capture.language),initialValue:capture.language,isExpanded:true,
      decoration:const InputDecoration(labelText:'Voice language'),items:const [
        DropdownMenuItem(value:VoiceLanguage.english,child:Text('English')),
        DropdownMenuItem(value:VoiceLanguage.hindi,child:Text('Hindi / हिंदी')),
        DropdownMenuItem(value:VoiceLanguage.hinglish,child:Text('Hinglish / Hindi + English',overflow:TextOverflow.ellipsis)),
      ],onChanged:capture.busy ? null:(value){if(value!=null) capture.setLanguage(value);}),
    if(capture.language==VoiceLanguage.hinglish) const Padding(padding:EdgeInsets.only(top:8),child:Text('Hinglish uses Hindi (India) speech recognition. Mixed words and the output script depend on your phone’s provider; review and edit the text.')),
    CheckboxListTile(contentPadding:EdgeInsets.zero,title:const Text('Offline only'),subtitle:const Text('Requires a downloaded speech language.'),
      value:capture.offlineOnly,onChanged:capture.busy ? null:(value) async {
        if(value==true){capture.setOffline(true);}else{await provider();}
      }),
    if(!capture.offlineOnly) const Text('Device speech service enabled with your consent; it may use the internet.'),
    OutlinedButton.icon(onPressed:capture.preparing || capture.starting ? null:capture.listening ? capture.stop:capture.start,
      icon:Icon(capture.listening ? Icons.stop:Icons.mic),label:Text(capture.listening ? 'Stop':capture.preparing ? 'Preparing…':capture.starting ? 'Starting microphone…':capture.issue!=null ? 'Retry':'Start speaking')),
    if(capture.listening) Semantics(liveRegion:true,child:Column(children:[const Text('Listening… Speak now'),
      LinearProgressIndicator(value:((capture.soundLevel+2)/12).clamp(0,1).toDouble())])),
    TextField(controller:transcript,readOnly:capture.listening || capture.starting,maxLines:3,maxLength:2000,
      decoration:const InputDecoration(labelText:'Recognized text — editable',hintText:'Received 500 rupees / ५०० रुपये मिले')),
    if(capture.issue!=null) Semantics(liveRegion:true,child:Text(capture.message,style:TextStyle(color:Theme.of(context).colorScheme.error))),
    if(capture.canTryProvider) TextButton(onPressed:capture.busy ? null:provider,child:const Text('Try device speech service')),
    if(capture.issue=='permission_denied' || capture.issue=='error_permission') const Text('After allowing Microphone, return here and tap Retry.'),
    if(reviewError!=null) Text(reviewError!,style:TextStyle(color:Theme.of(context).colorScheme.error)),
  ])),actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('Cancel')),
    FilledButton(onPressed:capture.preparing || capture.starting ? null:review,child:const Text('Review details'))]);
}
