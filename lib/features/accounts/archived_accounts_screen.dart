import '../../core/localization/app_text.dart';
import 'package:flutter/material.dart';
import '../../database/tables/account_table.dart';
import '../../models/account_model.dart';
import '../workspace/workspace_screens.dart';
import 'accounts_screen.dart';

class ArchivedAccountsScreen extends StatefulWidget {
  const ArchivedAccountsScreen({super.key});
  @override State<ArchivedAccountsScreen> createState()=>_ArchivedState();
}
class _ArchivedState extends State<ArchivedAccountsScreen> {
  late Future<List<AccountModel>> accounts;
  @override void initState(){super.initState();reload();}
  void reload(){accounts=AccountTable.getAllAccounts(includeArchived:true);}
  Future<void> restore(AccountModel a)async{
    try{await AccountTable.archive(a.id!,archived:false);if(mounted)setState(reload);}
    catch(_){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:AppText('Could not restore account. Retry.')));}
  }
  @override Widget build(BuildContext context){String t(String en,String hi)=>workspaceText(context,en,hi);
    return Scaffold(appBar:AppBar(title:Text(t('Archived accounts','संग्रहित खाते'))),body:FutureBuilder<List<AccountModel>>(future:accounts,builder:(context,s){
      if(s.hasError)return Center(child:TextButton(onPressed:()=>setState(reload),child:Text(t('Retry','फिर कोशिश करें'))));
      if(!s.hasData)return const Center(child:CircularProgressIndicator());
      final archived=s.data!.where((a)=>a.isArchived).toList();
      return ListView(padding:const EdgeInsets.all(20),children:[
        Text(t('Archived accounts keep every record and remain included in overall reports and history. Restore before adding or editing entries.','संग्रहित खातों के सभी रिकॉर्ड रिपोर्ट और इतिहास में रहते हैं। एंट्री जोड़ने या बदलने से पहले खाता वापस लाएं।')),
        if(archived.isEmpty)Padding(padding:const EdgeInsets.only(top:24),child:Text(t('No archived accounts.','कोई संग्रहित खाता नहीं है।'))),
        for(final a in archived)Card(child:Column(children:[ListTile(title:Text(a.name),subtitle:Text(t('Archived','संग्रहित')),
          onTap:()=>Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>AccountLedgerScreen(account:a)))),
          TextButton.icon(icon:const Icon(Icons.unarchive_outlined),onPressed:()=>restore(a),label:Text(t('Restore account','खाता वापस लाएं')))])),
      ]);
    }));
  }
}
