import 'dart:convert';
import 'dart:typed_data';
import 'package:file_selector/file_selector.dart' as files;
import 'package:flutter/material.dart';
import '../../core/utils/file_actions.dart';
import '../../core/utils/money.dart';
import '../workspace/workspace_screens.dart';
import 'csv_import.dart';

class CsvImportScreen extends StatefulWidget {
  const CsvImportScreen({super.key});
  @override State<CsvImportScreen> createState()=>_CsvImportState();
}
class _CsvImportState extends State<CsvImportScreen> {
  List<ImportEntry>? preview;bool busy=false;String? message;
  String t(String en,String hi)=>workspaceText(context,en,hi);
  Future<void> pick() async {
    if(busy)return;setState((){busy=true;message=null;preview=null;});
    try{final file=await files.openFile(acceptedTypeGroups:[const files.XTypeGroup(label:'CSV',extensions:['csv'])]);
      if(file==null)return;if(await file.length()>1024*1024)throw const FormatException('File too large');
      final rows=CsvImport.parse(utf8.decode(await file.readAsBytes()));if(mounted)setState(()=>preview=rows);
    }catch(_){if(mounted)setState(()=>message=t('Could not read CSV. Use the sample format, up to 1000 rows and 1 MB.','CSV नहीं खुला। सैंपल फॉर्मेट, अधिकतम 1000 एंट्री और 1 MB रखें।'));}
    finally{if(mounted)setState(()=>busy=false);}
  }
  Future<void> apply() async {
    if(busy||preview==null)return;
    final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:Text(t('Import reviewed entries?','जांची हुई एंट्री आयात करें?')),
      content:Text(t('Existing entries will not be overwritten. Repeated source IDs are skipped; conflicting IDs cancel the entire import. Save times record this import time.','पुरानी एंट्री नहीं बदलेगी। दोहराई ID छोड़ेंगे; अलग विवरण वाली समान ID पर पूरा आयात रद्द होगा। सेव समय अभी के आयात का होगा।')),
      actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:Text(t('Cancel','रद्द करें'))),FilledButton(onPressed:()=>Navigator.pop(c,true),child:Text(t('Import','आयात करें')))]));
    if(ok!=true||!mounted)return;setState(()=>busy=true);
    try{final result=await CsvImport.commit(preview!);if(mounted)setState((){preview=null;message=t('Imported ${result.inserted}; skipped ${result.skipped} duplicates.','${result.inserted} आयात हुईं; ${result.skipped} दोहराई एंट्री छोड़ीं।');});}
    catch(_){if(mounted)setState(()=>message=t('Import cancelled. Check account IDs and conflicting external IDs. No entries from this import were saved.','आयात रद्द। खाता ID और बाहरी ID जांचें। इस आयात से कोई एंट्री सेव नहीं हुई।'));}
    finally{if(mounted)setState(()=>busy=false);}
  }
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:Text(t('Import CSV','CSV आयात करें'))),
    body:ListView(padding:const EdgeInsets.all(20),children:[
      Text(t('Review before importing. Keep an encrypted backup first. Account IDs must match existing accounts on this device.','आयात से पहले जांचें और एन्क्रिप्टेड बैकअप रखें। खाता ID इस डिवाइस के मौजूदा खातों की होनी चाहिए।')),
      const SizedBox(height:12),Text(t('Maximum 1000 entries / 1 MB. Blank external IDs use exact-content duplicate checks; provide distinct IDs for intentional identical payments.','अधिकतम 1000 एंट्री / 1 MB। खाली बाहरी ID पर समान विवरण डुप्लिकेट माना जाएगा; जानबूझकर समान भुगतान के लिए अलग ID दें।')),
      OutlinedButton(onPressed:busy?null:()async{await shareFile(context,Uint8List.fromList(utf8.encode(CsvImport.sample)),'sss-import-sample.csv','text/csv');},child:Text(t('Download / Share sample CSV','सैंपल CSV डाउनलोड / शेयर करें'))),
      FilledButton(onPressed:busy?null:pick,child:Text(t('Choose CSV and preview','CSV चुनें और प्रीव्यू देखें'))),
      if(busy)const LinearProgressIndicator(),if(message!=null)Padding(padding:const EdgeInsets.symmetric(vertical:16),child:Text(message!)),
      if(preview!=null)...[
        Text(t('Preview: ${preview!.length} entries','प्रीव्यू: ${preview!.length} एंट्री'),style:Theme.of(context).textTheme.titleLarge),
        for(final e in preview!.take(20))ListTile(title:Text('${e.income?'Income':'Expense'} · ${Money.format(e.paise)}'),subtitle:Text('Account ${e.accountId} · ${e.date}\n${e.category} · ${e.name}')),
        if(preview!.length>20)Text(t('First 20 shown; all ${preview!.length} will be checked.','पहली 20 दिख रही हैं; सभी ${preview!.length} जांचेंगे।')),
        FilledButton(onPressed:busy?null:apply,child:Text(t('Confirm import','आयात की पुष्टि करें'))),
        TextButton(onPressed:busy?null:()=>setState(()=>preview=null),child:Text(t('Discard preview','प्रीव्यू रद्द करें'))),
      ],
    ]));
}
