import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import '../../database/db_helper.dart';
import '../../core/utils/money.dart';
import '../../core/utils/date_utils.dart' as dates;
import '../entries/party_snapshot.dart';

class ImportEntry {
  const ImportEntry(this.income,this.accountId,this.paise,this.date,this.category,this.mode,this.name,this.phone,this.note,this.externalId);
  final bool income;final int accountId,paise;final String date,category,mode,name,phone,note,externalId;
  List<Object> get identity=>[income?'income':'expense',accountId,paise,date,category,mode,name,phone,note];
}
class ImportResult {
  const ImportResult(this.inserted,this.skipped);final int inserted,skipped;
}

class CsvImport {
  static const header=['type','account_id','amount','date','category','mode','name','phone','note','external_id'];
  static String get sample=>'${header.join(',')}\nincome,1,100.00,2026-11-04,Sales,cash,,,Example sale,example-1\n';
  /// Strict CSV including quoted commas/newlines and escaped quotes. Never evaluates cells.
  static List<List<String>> _csv(String input) {
    if(utf8.encode(input).length>1024*1024)throw const FormatException('CSV exceeds 1 MB');
    if(input.startsWith('\ufeff'))input=input.substring(1);
    final rows=<List<String>>[];var row=<String>[];var field=StringBuffer();var quoted=false,closed=false;
    void cell(){row.add(field.toString());field=StringBuffer();closed=false;}
    void line(){cell();if(row.any((c)=>c.isNotEmpty))rows.add(row);row=[];if(rows.length>1001)throw const FormatException('Maximum 1000 entries per import');}
    for(var i=0;i<input.length;i++){
      final c=input[i];
      if(quoted){if(c=='"'){if(i+1<input.length && input[i+1]=='"'){field.write('"');i++;}else{quoted=false;closed=true;}}else{field.write(c);}continue;}
      if(c==','){cell();continue;}
      if(c=='\r'||c=='\n'){if(c=='\r' && i+1<input.length && input[i+1]=='\n')i++;line();continue;}
      if(closed)throw const FormatException('Unexpected text after closing quote');
      if(c=='"'){if(field.isNotEmpty)throw const FormatException('Unexpected quote');quoted=true;continue;}
      field.write(c);
    }
    if(quoted)throw const FormatException('Unclosed CSV quote');
    if(field.isNotEmpty||row.isNotEmpty||closed)line();
    return rows;
  }
  static List<ImportEntry> parse(String input) {
    final rows=_csv(input);
    if(rows.length<2 || rows.first.length!=header.length ||
        List.generate(header.length,(i)=>rows.first[i].trim().toLowerCase()).join(',')!=header.join(',')) {
      throw const FormatException('Use the sample CSV header and at least one entry');
    }
    final result=<ImportEntry>[];
    for(var i=1;i<rows.length;i++){
      try{
        final r=rows[i];if(r.length!=header.length)throw const FormatException('Wrong column count');
        final kind=r[0].trim().toLowerCase(),account=int.tryParse(r[1].trim());
        final paise=Money.parse(r[2]),date=r[3].trim(),parsed=DateTime.tryParse(date);
        final category=r[4].trim().isEmpty?'Other':r[4].trim(),mode=r[5].trim().toLowerCase();
        final contact=PartySnapshot.optional(r[6],r[7]);final external=r[9].trim();
        if(!['income','expense'].contains(kind)||account==null||account<=0||parsed==null||
          !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date)||dates.DateUtils.formatDate(parsed)!=date||
          parsed.isAfter(dates.DateUtils.indiaToday())||parsed.year<2000||category.length>60||r[8].length>2000||
          !['cash','online','bank','upi','card'].contains(mode)||external.length>120||
          (external.isNotEmpty && !RegExp(r'^[A-Za-z0-9_.:-]+$').hasMatch(external)))throw const FormatException('Invalid entry');
        result.add(ImportEntry(kind=='income',account,paise,date,category,mode,contact?.name??'',contact?.phone??'',r[8],external));
      }catch(_){throw FormatException('Check values in CSV row ${i+1}');}
    }
    return List.unmodifiable(result);
  }

  /// Revalidates caller input, deduplicates within an atomic transaction and never
  /// overwrites existing financial entries. Same external ID + changed contents is a conflict.
  static Future<ImportResult> commit(List<ImportEntry> entries) async {
    if(entries.isEmpty||entries.length>1000)throw ArgumentError('Import 1 to 1000 entries');
    final prepared=<(ImportEntry,String,String)>[];
    for(final e in entries){
      if(e.paise<1||e.paise>Money.maximumPaise)throw ArgumentError('Amount out of range');
      // Re-parse through the exact public constraints even if a caller constructed ImportEntry directly.
      String escape(String value)=>'"${value.replaceAll('"','""')}"';
      final checked=parse('${header.join(',')}\n${[e.income?'income':'expense','${e.accountId}','${e.paise~/100}.${(e.paise%100).toString().padLeft(2,'0')}',e.date,e.category,e.mode,e.name,e.phone,e.note,e.externalId].map(escape).join(',')}').single;
      final hash=(await Sha256().hash(utf8.encode(jsonEncode(checked.identity)))).bytes.map((b)=>b.toRadixString(16).padLeft(2,'0')).join();
      prepared.add((checked,checked.externalId.isEmpty?'hash:$hash':'external:${checked.externalId}',hash));
    }
    return (await DBHelper.database).transaction((txn) async {
      var inserted=0,skipped=0;
      for(final (e,key,hash) in prepared){
        final old=await txn.query('import_records',where:'source_key=?',whereArgs:[key]);
        if(old.isNotEmpty){if(old.single['content_hash']!=hash)throw StateError('An external ID has different contents. Nothing was imported.');skipped++;continue;}
        if((await txn.query('accounts',columns:['id'],where:'id=?',whereArgs:[e.accountId])).length!=1)throw StateError('An import account no longer exists. Nothing was imported.');
        final table=e.income?'income':'expenses',noteColumn=e.income?'description':'note';
        // Without an explicit source ID, identical existing manual/imported rows are duplicates.
        if(e.externalId.isEmpty && (await txn.rawQuery('SELECT id FROM $table WHERE account_id=? AND round(amount*100)=? AND date=? AND COALESCE(category,\'Other\')=? AND COALESCE(mode,\'cash\')=? AND COALESCE(contact_name,\'\')=? AND COALESCE(contact_phone,\'\')=? AND COALESCE($noteColumn,\'\')=? LIMIT 1',
          [e.accountId,e.paise,e.date,e.category,e.mode,e.name,e.phone,e.note])).isNotEmpty){skipped++;continue;}
        final stamp=DateTime.now().toUtc().toIso8601String();
        final id=await txn.insert(table,{'account_id':e.accountId,'amount':e.paise/100,'date':e.date,'category':e.category,'mode':e.mode,
          'contact_name':e.name.isEmpty?null:e.name,'contact_phone':e.phone.isEmpty?null:e.phone,noteColumn:e.note,'created_at':stamp});
        await txn.insert('import_records',{'source_key':key,'content_hash':hash,'kind':e.income?'income':'expense','record_id':id,'created_at':stamp});
        inserted++;
      }
      return ImportResult(inserted,skipped);
    });
  }
}
