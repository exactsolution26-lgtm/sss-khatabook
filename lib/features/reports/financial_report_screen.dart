import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/utils/date_utils.dart' as dates;
import '../../core/utils/money.dart';
import '../../database/tables/account_table.dart';
import '../../models/account_model.dart';
import '../workspace/workspace_screens.dart';
import 'financial_report.dart';

class FinancialReportScreen extends StatefulWidget {
  const FinancialReportScreen({super.key});
  @override State<FinancialReportScreen> createState()=>_FinancialReportState();
}
class _FinancialReportState extends State<FinancialReportScreen> {
  late Future<FinancialReport> report;late final Future<List<AccountModel>> accounts=AccountTable.getAllAccounts();
  DateTimeRange? range;int? accountId;
  @override void initState(){super.initState();reload();}
  String t(String en,String hi)=>workspaceText(context,en,hi);
  void reload(){report=FinancialReport.load(from:range==null?null:dates.DateUtils.formatDate(range!.start),to:range==null?null:dates.DateUtils.formatDate(range!.end),accountId:accountId);}
  Future<void> pickRange() async {
    final selected=await showDateRangePicker(context:context,firstDate:DateTime(2000),lastDate:dates.DateUtils.indiaToday(),initialDateRange:range);
    if(selected!=null&&mounted)setState((){range=selected;reload();});
  }
  Widget bucket(String title,Map<String,ReportBucket> buckets){
    final rows=buckets.entries.toList()..sort((a,b)=>a.key.compareTo(b.key));
    final ceiling=rows.fold<int>(1,(v,row)=>math.max(v,math.max(row.value.income,row.value.expense)));
    return Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      const SizedBox(height:24),Text(title,style:Theme.of(context).textTheme.titleLarge),
      if(rows.isEmpty)Text(t('No entries in this selection.','इस चयन में कोई एंट्री नहीं है।')),
      for(final row in rows)Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text(row.key,style:Theme.of(context).textTheme.titleMedium),const SizedBox(height:8),
        Text('${t('Income','आय')}: ${Money.format(row.value.income)}'),
        LinearProgressIndicator(value:row.value.income/ceiling,minHeight:8,semanticsLabel:t('Income','आय')),
        const SizedBox(height:8),Text('${t('Expenses','खर्च')}: ${Money.format(row.value.expense)}'),
        LinearProgressIndicator(value:row.value.expense/ceiling,minHeight:8,color:Theme.of(context).colorScheme.error,semanticsLabel:t('Expenses','खर्च')),
        const SizedBox(height:8),Text('${t('Net movement','शुद्ध बदलाव')}: ${Money.format(row.value.net)}'),
      ]))),
    ]);
  }
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:Text(t('Detailed Reports','विस्तृत रिपोर्ट')),actions:[IconButton(tooltip:t('Refresh','रीफ़्रेश'),icon:const Icon(Icons.refresh),onPressed:()=>setState(reload))]),
    body:ListView(padding:const EdgeInsets.all(20),children:[
      Text(t('Net movement = income minus expenses in the selected period. Opening balances and unpaid dues are not cash movements.','शुद्ध बदलाव = चुनी अवधि की आय घटा खर्च। शुरुआती बैलेंस और बकाया नकद लेन-देन नहीं हैं।')),
      const SizedBox(height:16),FutureBuilder<List<AccountModel>>(future:accounts,builder:(context,s){
        if(s.hasError)return Text(t('Account list unavailable; showing all accounts.','खाते की सूची नहीं खुली; सभी खाते दिख रहे हैं।'));
        if(!s.hasData)return const LinearProgressIndicator();
        return DropdownButtonFormField<int>(initialValue:accountId??0,isExpanded:true,decoration:InputDecoration(labelText:t('Account','खाता')),
          items:[DropdownMenuItem(value:0,child:Text(t('All accounts (including unassigned)','सभी खाते (असंबद्ध सहित)'))),
            for(final a in s.data!)DropdownMenuItem(value:a.id,child:Text(a.name))],
          onChanged:(v)=>setState((){accountId=v==0?null:v;reload();}));
      }),
      const SizedBox(height:12),Wrap(spacing:8,runSpacing:8,children:[
        OutlinedButton.icon(icon:const Icon(Icons.date_range),onPressed:pickRange,label:Text(range==null?t('Choose date range','तारीखें चुनें'):'${dates.DateUtils.formatDate(range!.start)} — ${dates.DateUtils.formatDate(range!.end)}')),
        TextButton(onPressed:()=>setState((){range=null;reload();}),child:Text(t('All dates','सभी तारीखें'))),
      ]),
      const SizedBox(height:20),FutureBuilder<FinancialReport>(future:report,builder:(context,s){
        if(s.connectionState!=ConnectionState.done)return const Center(child:CircularProgressIndicator());
        if(s.hasError||!s.hasData)return Column(children:[Text(t('Could not load report. Records have not been changed.','रिपोर्ट नहीं खुली। रिकॉर्ड नहीं बदले गए हैं।')),
          TextButton(onPressed:()=>setState(reload),child:Text(t('Retry','फिर कोशिश करें')))]);
        final r=s.data!;return Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
          Text('${t('Entries','एंट्री')}: ${r.count}'),
          Text('${t('Income','आय')}: ${Money.format(r.income)}',key:const ValueKey('report-income')),
          Text('${t('Expenses','खर्च')}: ${Money.format(r.expense)}',key:const ValueKey('report-expense')),
          Text('${t('Net movement','शुद्ध बदलाव')}: ${Money.format(r.net)}',key:const ValueKey('report-net')),
          if(r.unassigned>0)Text(t('Includes ${r.unassigned} unassigned historic expenses.','${r.unassigned} पुराने असंबद्ध खर्च भी शामिल हैं।')),
          bucket(t('By month','महीने के अनुसार'),r.months),bucket(t('By category','श्रेणी के अनुसार'),r.categories),bucket(t('By payment mode','भुगतान प्रकार के अनुसार'),r.modes),
        ]);
      }),
    ]));
}
