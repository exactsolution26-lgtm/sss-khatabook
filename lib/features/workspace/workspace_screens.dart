import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../database/tables/account_table.dart';
import '../../core/utils/date_utils.dart' as dates;
import '../entries/contact_fields.dart';
import '../settings/app_settings.dart';
import '../whatsapp/whatsapp_share_screen.dart';
import 'workspace_store.dart';

String workspaceText(BuildContext context,String en,String hi) =>
    SettingsScope.of(context).language.name=='hindi' ? hi : en;

class BusinessProfileScreen extends StatefulWidget {
  const BusinessProfileScreen({super.key});
  @override State<BusinessProfileScreen> createState()=>_BusinessProfileState();
}
class _BusinessProfileState extends State<BusinessProfileScreen> {
  final name=TextEditingController(),phone=TextEditingController(),email=TextEditingController(),address=TextEditingController();
  bool loading=true,busy=false;String? error,saved;
  @override void initState(){super.initState();load();}
  @override void dispose(){for(final c in [name,phone,email,address]){c.dispose();}super.dispose();}
  String t(String en,String hi)=>workspaceText(context,en,hi);
  Future<void> load() async {
    setState((){loading=true;error=null;});
    try {final p=await WorkspaceStore.profile();if(!mounted)return;
      if(p!=null){name.text=p['name'] as String;phone.text=p['phone'] as String;email.text=p['email'] as String;address.text=p['address'] as String;}
    }catch(_){if(mounted)error='Could not load profile. Retry before editing.';}
    if(mounted)setState(()=>loading=false);
  }
  Future<void> save() async {
    if(busy)return;setState((){busy=true;error=null;saved=null;});
    try {await WorkspaceStore.saveProfile(name:name.text,phone:phone.text,email:email.text,address:address.text);
      final p=await WorkspaceStore.profile();if(mounted)setState(()=>saved=dates.DateUtils.formatIstDateTime(DateTime.parse(p!['updated_at'] as String)));
    }catch(_){if(mounted)setState(()=>error=t('Could not save. Check business name, phone and email.','सेव नहीं हुआ। नाम, फोन और ईमेल जांचें।'));}
    finally{if(mounted)setState(()=>busy=false);}
  }
  @override Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:Text(t('Business Profile','व्यवसाय प्रोफ़ाइल'))),
    body:loading?const Center(child:CircularProgressIndicator()):ListView(padding:const EdgeInsets.all(20),children:[
      Text(t('Stored on this device and included in encrypted backups.','इस डिवाइस और एन्क्रिप्टेड बैकअप में सेव होगी।')),
      const SizedBox(height:16),
      TextField(controller:name,maxLength:120,keyboardType:TextInputType.name,decoration:InputDecoration(labelText:t('Business name','व्यवसाय का नाम'))),
      const SizedBox(height:12),TextField(controller:phone,keyboardType:TextInputType.phone,decoration:InputDecoration(labelText:t('Business phone (optional)','व्यवसाय फोन (वैकल्पिक)'))),
      const SizedBox(height:12),TextField(controller:email,keyboardType:TextInputType.emailAddress,maxLength:254,decoration:InputDecoration(labelText:t('Email (optional)','ईमेल (वैकल्पिक)'))),
      const SizedBox(height:12),TextField(controller:address,maxLines:3,maxLength:500,decoration:InputDecoration(labelText:t('Address (optional)','पता (वैकल्पिक)'))),
      if(error!=null)Text(error!,style:TextStyle(color:Theme.of(context).colorScheme.error)),
      if(saved!=null)Text('${t('Saved ✓','सेव हुआ ✓')}\n$saved',key:const ValueKey('profile-saved')),
      const SizedBox(height:16),FilledButton(onPressed:busy?null:save,child:Text(busy?t('Saving…','सेव हो रहा है…'):t('Save Profile','प्रोफ़ाइल सेव करें'))),
      TextButton(onPressed:busy?null:load,child:Text(t('Reload profile','प्रोफ़ाइल दोबारा खोलें'))),
    ]));
}

class WorkspaceDirectoryScreen extends StatefulWidget {
  const WorkspaceDirectoryScreen({super.key,required this.contacts});
  final bool contacts;
  @override State<WorkspaceDirectoryScreen> createState()=>_DirectoryState();
}
class _DirectoryState extends State<WorkspaceDirectoryScreen> {
  late Future<List<Map<String,Object?>>> records;String query='';
  String t(String en,String hi)=>workspaceText(context,en,hi);
  @override void initState(){super.initState();reload();}
  void reload(){records=widget.contacts?WorkspaceStore.contacts():WorkspaceStore.templates();}
  Future<void> edit([Map<String,Object?>? row]) async {
    final saved=await showDialog<bool>(context:context,builder:(_)=>_DirectoryEditor(contacts:widget.contacts,row:row));
    if(saved==true && mounted)setState(reload);
  }
  Future<void> remove(Map<String,Object?> row) async {
    final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:Text(t('Delete saved item?','सेव किया आइटम हटाएं?')),
      content:Text(t('Existing transaction contact snapshots will remain unchanged.','पुरानी एंट्री में सेव संपर्क विवरण नहीं बदलेंगे।')),
      actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:Text(t('Cancel','रद्द करें'))),
        FilledButton(onPressed:()=>Navigator.pop(c,true),child:Text(t('Delete','हटाएं')))]));
    if(ok!=true)return;
    try{await WorkspaceStore.remove(widget.contacts?'contact_directory':'message_templates',row['id'] as int);if(mounted)setState(reload);}
    catch(_){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(t('Could not delete. Retry.','हटाया नहीं गया। फिर कोशिश करें।'))));}
  }
  @override Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:Text(widget.contacts?t('Contact Directory','संपर्क सूची'):t('Message Templates','संदेश टेम्पलेट'))),
    floatingActionButton:FloatingActionButton.extended(onPressed:edit,icon:const Icon(Icons.add),
      label:Text(widget.contacts?t('New contact','नया संपर्क'):t('New template','नया टेम्पलेट'))),
    body:Column(children:[Padding(padding:const EdgeInsets.all(16),child:TextField(onChanged:(v)=>setState(()=>query=v.toLowerCase()),
      decoration:InputDecoration(labelText:t('Search','खोजें'),prefixIcon:const Icon(Icons.search)))),
      Expanded(child:FutureBuilder<List<Map<String,Object?>>>(future:records,builder:(context,s){
        if(s.hasError)return Center(child:TextButton(onPressed:()=>setState(reload),child:Text(t('Could not load — Retry','खुला नहीं — फिर कोशिश करें'))));
        if(!s.hasData)return const Center(child:CircularProgressIndicator());
        final rows=s.data!.where((r)=>'${r[widget.contacts?'name':'title']} ${r[widget.contacts?'phone':'body']}'.toLowerCase().contains(query)).toList();
        if(rows.isEmpty)return Center(child:Text(t('No saved items. Use the + button.','अभी कोई आइटम नहीं। + बटन इस्तेमाल करें।')));
        return ListView(padding:const EdgeInsets.fromLTRB(16,0,16,100),children:[for(final r in rows)Card(child:Column(children:[
          ListTile(title:Text(r[widget.contacts?'name':'title'] as String),subtitle:Text(r[widget.contacts?'phone':'body'] as String,maxLines:3,overflow:TextOverflow.ellipsis),
            onTap:()=>edit(r),trailing:IconButton(tooltip:t('Delete','हटाएं'),icon:const Icon(Icons.delete_outline),onPressed:()=>remove(r))),
          if(!widget.contacts)TextButton.icon(icon:const Icon(Icons.chat_outlined),label:Text(t('Review WhatsApp draft','WhatsApp ड्राफ्ट देखें')),
            onPressed:()=>Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>WhatsAppShareScreen(initialMessage:r['body'] as String)))),
        ]))]);
      })),
    ]));
}
class _DirectoryEditor extends StatefulWidget {
  const _DirectoryEditor({required this.contacts,this.row});final bool contacts;final Map<String,Object?>? row;
  @override State<_DirectoryEditor> createState()=>_DirectoryEditorState();
}
class _DirectoryEditorState extends State<_DirectoryEditor> {
  late final first=TextEditingController(text:widget.row?[widget.contacts?'name':'title'] as String? ?? '');
  late final second=TextEditingController(text:widget.row?[widget.contacts?'phone':'body'] as String? ?? '');
  bool busy=false;String? error;
  @override void dispose(){first.dispose();second.dispose();super.dispose();}
  String t(String en,String hi)=>workspaceText(context,en,hi);
  Future<void> save() async {
    if(busy)return;setState((){busy=true;error=null;});
    try{
      if(widget.contacts){await WorkspaceStore.saveContact(first.text,second.text,id:widget.row?['id'] as int?);}
      else{await WorkspaceStore.saveTemplate(first.text,second.text,id:widget.row?['id'] as int?);}
      if(mounted)Navigator.pop(context,true);
    }catch(_){if(mounted)setState(()=>error=t('Check values. The phone or template title may already exist.','विवरण जांचें। यह फोन या टेम्पलेट नाम पहले से हो सकता है।'));}
    finally{if(mounted)setState(()=>busy=false);}
  }
  @override Widget build(BuildContext context)=>AlertDialog(
    title:Text(widget.contacts?t('Save contact','संपर्क सेव करें'):t('Save template','टेम्पलेट सेव करें')),
    content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
      if(widget.contacts)ContactFields(name:first,phone:second) else ...[
        TextField(controller:first,maxLength:80,decoration:InputDecoration(labelText:t('Template title','टेम्पलेट नाम'))),
        TextField(controller:second,maxLength:4000,maxLines:5,decoration:InputDecoration(labelText:t('Message','संदेश'))),
        Text(t('Custom message only. Review before sharing; it is not a verified receipt.','कस्टम संदेश। भेजने से पहले जांचें; यह सत्यापित रसीद नहीं है।')),
      ],
      if(error!=null)Text(error!,style:TextStyle(color:Theme.of(context).colorScheme.error)),
    ])),actions:[TextButton(onPressed:busy?null:()=>Navigator.pop(context),child:Text(t('Cancel','रद्द करें'))),
      FilledButton(onPressed:busy?null:save,child:Text(t('Save','सेव करें')))]);
}

class GettingStartedScreen extends StatefulWidget {
  const GettingStartedScreen({super.key});
  @override State<GettingStartedScreen> createState()=>_GettingStartedState();
}
class _GettingStartedState extends State<GettingStartedScreen> {
  late Future<(bool,bool)> state;
  @override void initState(){super.initState();reload();}
  void reload(){state=load();}
  Future<(bool,bool)> load() async => ((await WorkspaceStore.profile())!=null,(await AccountTable.getAllAccounts()).isNotEmpty);
  Future<void> open(String route) async {await Navigator.pushNamed(context,route);if(mounted)setState(reload);}
  @override Widget build(BuildContext context){
    String t(String en,String hi)=>workspaceText(context,en,hi);
    return Scaffold(appBar:AppBar(title:Text(t('Getting Started','शुरुआत करें'))),body:FutureBuilder<(bool,bool)>(future:state,builder:(context,s){
      if(s.hasError)return Center(child:TextButton(onPressed:()=>setState(reload),child:Text(t('Retry','फिर कोशिश करें'))));
      if(!s.hasData)return const Center(child:CircularProgressIndicator());
      return ListView(padding:const EdgeInsets.all(20),children:[
        Text(t('Start your offline workspace','अपना ऑफ़लाइन खाता शुरू करें'),style:Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height:12),Text(t('Records stay on this device. Keep an encrypted backup before changing phones.','रिकॉर्ड इस डिवाइस में रहते हैं। फोन बदलने से पहले एन्क्रिप्टेड बैकअप रखें।')),
        ListTile(leading:Icon(s.data!.$1?Icons.check_circle:Icons.business_outlined),title:Text(t('Business profile','व्यवसाय प्रोफ़ाइल')),onTap:()=>open('/profile')),
        ListTile(leading:Icon(s.data!.$2?Icons.check_circle:Icons.person_add_outlined),title:Text(t('Create your first account','पहला खाता बनाएं')),onTap:()=>open('/accounts')),
        ListTile(leading:const Icon(Icons.lock_outline),title:Text(t('Set PIN and biometric preferences','पिन और बायोमेट्रिक सेट करें')),onTap:()=>open('/security')),
        ListTile(leading:const Icon(Icons.backup_outlined),title:Text(t('Create an encrypted backup','एन्क्रिप्टेड बैकअप बनाएं')),onTap:()=>open('/backup')),
        FilledButton(onPressed:()=>Navigator.pop(context),child:Text(t('Continue to Dashboard','डैशबोर्ड पर जाएं'))),
      ]);
    }));
  }
}

class DraftHistoryScreen extends StatefulWidget {
  const DraftHistoryScreen({super.key});
  @override State<DraftHistoryScreen> createState()=>_DraftHistoryState();
}
class _DraftHistoryState extends State<DraftHistoryScreen> {
  late final Future<List<Map<String,dynamic>>> records=load();
  Future<List<Map<String,dynamic>>> load() async {
    final values=(await SharedPreferences.getInstance()).getStringList('whatsapp_draft_audit_v1')??[];
    final rows=<Map<String,dynamic>>[];
    for(final value in values.reversed){try{final r=jsonDecode(value);if(r is Map<String,dynamic> && r['opened_at_utc'] is String && DateTime.tryParse(r['opened_at_utc'])!=null)rows.add(r);}catch(_){/* Ignore a malformed historical audit row. */}}
    return rows;
  }
  @override Widget build(BuildContext context){String t(String en,String hi)=>workspaceText(context,en,hi);
    return Scaffold(appBar:AppBar(title:Text(t('WhatsApp Draft History','WhatsApp ड्राफ्ट इतिहास'))),body:FutureBuilder<List<Map<String,dynamic>>>(future:records,builder:(context,s){
      if(s.hasError)return Center(child:Text(t('Could not load draft history.','ड्राफ्ट इतिहास नहीं खुला।')));
      if(!s.hasData)return const Center(child:CircularProgressIndicator());
      return ListView(padding:const EdgeInsets.all(20),children:[
        Text(t('Opened drafts only. Sending and delivery are not confirmed. History keeps up to 500 opens on this device; it is not included in ledger backups.','केवल खुले ड्राफ्ट। भेजने या पहुंचने की पुष्टि नहीं है। इस डिवाइस पर अंतिम 500 रिकॉर्ड रखे जाते हैं; लेजर बैकअप में शामिल नहीं हैं।')),
        if(s.data!.isEmpty)Padding(padding:const EdgeInsets.only(top:24),child:Text(t('No draft opens recorded.','अभी कोई ड्राफ्ट खुलना रिकॉर्ड नहीं है।'))),
        for(final r in s.data!)ListTile(leading:const Icon(Icons.open_in_new),title:Text('${r['type'] ?? 'draft'} · ${t('Opened','खुला')}'),
          subtitle:Text(dates.DateUtils.formatIstDateTime(DateTime.parse(r['opened_at_utc'] as String)))),
      ]);
    }));
  }
}

class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});
  static const diagnostic='SSS Khatabook 1.0.2+102\nMode: offline workspace\nDatabase schema: 11\nSupport codes: SSS-UI, SSS-CLOUD-SETUP, SSS-STARTUP\nDescribe the screen, action and problem. Remove financial/contact information from screenshots before sharing.';
  @override Widget build(BuildContext context){String t(String en,String hi)=>workspaceText(context,en,hi);
    return Scaffold(appBar:AppBar(title:Text(t('Help & Support','सहायता'))),body:ListView(padding:const EdgeInsets.all(20),children:[
      Text(t('Keep your records safe','अपने रिकॉर्ड सुरक्षित रखें'),style:Theme.of(context).textTheme.titleLarge),
      const SizedBox(height:12),Text(t('Before replacing or uninstalling the app, create an encrypted backup and keep its passphrase separately. Restore first on a test copy when possible.','ऐप हटाने या बदलने से पहले एन्क्रिप्टेड बैकअप बनाएं और पासफ़्रेज़ अलग रखें। संभव हो तो पहले टेस्ट कॉपी में रिस्टोर जांचें।')),
      const SizedBox(height:20),Text(t('Voice entry','वॉइस एंट्री'),style:Theme.of(context).textTheme.titleLarge),
      Text(t('Allow microphone access. Select Hindi, English or Hinglish and check your phone speech-language packs. Review recognized details before saving.','माइक्रोफोन अनुमति दें। हिंदी, English या Hinglish चुनें और फोन के भाषा पैक जांचें। सेव करने से पहले विवरण जांचें।')),
      const SizedBox(height:20),Text(t('Report a problem','समस्या बताएं'),style:Theme.of(context).textTheme.titleLarge),
      Text(t('Copy safe app information and share it with your support contact. No report is uploaded automatically.','सुरक्षित ऐप जानकारी कॉपी करके अपने सहायता संपर्क को भेजें। कोई रिपोर्ट अपने आप अपलोड नहीं होती।')),
      const SizedBox(height:12),FilledButton.icon(icon:const Icon(Icons.copy_outlined),label:Text(t('Copy app information','ऐप जानकारी कॉपी करें')),
        onPressed:() async {await Clipboard.setData(const ClipboardData(text:diagnostic));if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(t('App information copied','ऐप जानकारी कॉपी हुई'))));}),
    ]));
  }
}
