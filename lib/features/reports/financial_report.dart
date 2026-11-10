import '../../database/db_helper.dart';
import '../../core/utils/date_utils.dart' as dates;

class ReportBucket {
  int income=0,expense=0;
  int get net=>income-expense;
  void add(bool incoming,int paise){if(incoming){income+=paise;}else{expense+=paise;}}
}
class FinancialReport {
  FinancialReport(this.income,this.expense,this.count,this.unassigned,this.years,this.months,this.categories,this.modes);
  final int income,expense,count,unassigned;
  final Map<String,ReportBucket> years,months,categories,modes;
  int get net=>income-expense;
  static void validateDate(String? text){
    if(text!=null && (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(text)||DateTime.tryParse(text)==null||
      dates.DateUtils.formatDate(DateTime.parse(text))!=text))throw ArgumentError('Invalid report date');
  }
  static Future<FinancialReport> load({String? from,String? to,int? accountId}) async {
    validateDate(from);validateDate(to);
    if((from!=null && to!=null && from.compareTo(to)>0)||(accountId!=null&&accountId<=0))throw ArgumentError('Invalid report range or account');
    return (await DBHelper.database).transaction((txn)async{
      if(accountId!=null && (await txn.query('accounts',columns:['id'],where:'id=?',whereArgs:[accountId])).length!=1)throw StateError('Account not found');
      final clauses=<String>[],args=<Object?>[];
      if(from!=null){clauses.add('date>=?');args.add(from);}if(to!=null){clauses.add('date<=?');args.add(to);}
      if(accountId!=null){clauses.add('account_id=?');args.add(accountId);}
      final where=clauses.isEmpty?'':'WHERE ${clauses.join(' AND ')}';
      final rows=await txn.rawQuery('''SELECT * FROM (
        SELECT account_id,amount,date,category,mode,1 AS incoming FROM income
        UNION ALL SELECT account_id,amount,date,category,mode,0 AS incoming FROM expenses) $where ORDER BY date''',args);
      final years=<String,ReportBucket>{},months=<String,ReportBucket>{},categories=<String,ReportBucket>{},modes=<String,ReportBucket>{};
      var income=0,expense=0,unassigned=0;
      for(final row in rows){final incoming=row['incoming']==1,paise=((row['amount'] as num)*100).round();
        if(incoming){income+=paise;}else{expense+=paise;}if(row['account_id']==null)unassigned++;
        final date=row['date'] as String,category=(row['category'] as String?)?.trim()??'',mode=(row['mode'] as String?)?.trim()??'';
        (years.putIfAbsent(date.length>=7?date.substring(0,4):'Unknown date',ReportBucket.new)).add(incoming,paise);
        (months.putIfAbsent(date.length>=7?date.substring(0,7):'Unknown date',ReportBucket.new)).add(incoming,paise);
        (categories.putIfAbsent(category.isEmpty?'Other':category,ReportBucket.new)).add(incoming,paise);
        (modes.putIfAbsent(mode.isEmpty?'Unknown':mode,ReportBucket.new)).add(incoming,paise);
      }
      return FinancialReport(income,expense,rows.length,unassigned,years,months,categories,modes);
    });
  }
}
