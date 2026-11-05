import '../../database/db_helper.dart';
import '../entries/party_snapshot.dart';

class WorkspaceStore {
  static Map<String,Object?> profileValues({required String name, String phone='', String email='', String address=''}) {
    name=name.trim();phone=phone.trim();email=email.trim();address=address.trim();
    if(name.isEmpty || name.length>120 || address.length>500 || email.length>254 ||
      (email.isNotEmpty && !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email))) {
      throw ArgumentError('Check business name, email and address');
    }
    if(phone.isNotEmpty) phone=PartySnapshot.optional(name,phone)!.phone;
    return {'id':1,'name':name,'phone':phone,'email':email,'address':address};
  }
  static void validateTemplate(String title,String body) {
    if(title.trim().isEmpty || title.trim().length>80 || body.trim().isEmpty || body.length>4000) {
      throw ArgumentError('Use a title up to 80 and message up to 4000 characters');
    }
  }
  static Future<Map<String,Object?>?> profile() async {
    final rows=await (await DBHelper.database).query('business_profile',where:'id=1');
    return rows.isEmpty ? null : rows.single;
  }
  static Future<void> saveProfile({required String name,String phone='',String email='',String address=''}) async {
    final values=profileValues(name:name,phone:phone,email:email,address:address);
    await (await DBHelper.database).transaction((txn) async {
      final old=await txn.query('business_profile',where:'id=1');
      values['updated_at']=DateTime.now().toUtc().toIso8601String();
      if(old.isEmpty) {await txn.insert('business_profile',values);}
      else {await txn.update('business_profile',values,where:'id=1');}
      await txn.insert('app_audit',{'entity':'business_profile','record_id':1,'operation':old.isEmpty?'insert':'update',
        'old_label':old.isEmpty?null:old.single['name'],'new_label':values['name']});
    });
  }
  static Future<List<Map<String,Object?>>> contacts() async =>
    (await DBHelper.database).query('contact_directory',orderBy:'name COLLATE NOCASE,id');
  static Future<void> saveContact(String name,String phone,{int? id}) async {
    final contact=PartySnapshot.optional(name,phone);
    if(contact==null) throw ArgumentError('Name and phone are required');
    await (await DBHelper.database).transaction((txn) async {
      final old=id==null ? <Map<String,Object?>>[] : await txn.query('contact_directory',where:'id=?',whereArgs:[id]);
      if(id!=null && old.length!=1) throw StateError('Contact no longer exists');
      final values=<String,Object?>{'name':contact.name,'phone':contact.phone,'updated_at':DateTime.now().toUtc().toIso8601String()};
      final saved=id ?? await txn.insert('contact_directory',values);
      if(id!=null) await txn.update('contact_directory',values,where:'id=?',whereArgs:[id]);
      await txn.insert('app_audit',{'entity':'contact_directory','record_id':saved,'operation':id==null?'insert':'update',
        'old_contact_name':old.isEmpty?null:old.single['name'],'old_contact_phone':old.isEmpty?null:old.single['phone'],
        'new_contact_name':contact.name,'new_contact_phone':contact.phone});
    });
  }
  static Future<List<Map<String,Object?>>> templates() async =>
    (await DBHelper.database).query('message_templates',orderBy:'title COLLATE NOCASE,id');
  static Future<void> saveTemplate(String title,String body,{int? id}) async {
    validateTemplate(title,body);
    await (await DBHelper.database).transaction((txn) async {
      if(id==null && ((await txn.rawQuery('SELECT COUNT(*) AS n FROM message_templates')).single['n'] as int) >= 50) {
        throw StateError('Maximum 50 saved templates');
      }
      final values={'title':title.trim(),'body':body.trim(),'updated_at':DateTime.now().toUtc().toIso8601String()};
      final saved=id ?? await txn.insert('message_templates',values);
      if(id!=null && await txn.update('message_templates',values,where:'id=?',whereArgs:[id])!=1) throw StateError('Template no longer exists');
      await txn.insert('app_audit',{'entity':'message_templates','record_id':saved,'operation':id==null?'insert':'update','new_label':title.trim()});
    });
  }
  static Future<void> remove(String table,int id) async {
    if(!['contact_directory','message_templates'].contains(table)) throw ArgumentError('Unsupported record type');
    await (await DBHelper.database).transaction((txn) async {
      if(await txn.delete(table,where:'id=?',whereArgs:[id])!=1) throw StateError('Record no longer exists');
      await txn.insert('app_audit',{'entity':table,'record_id':id,'operation':'delete'});
    });
  }
}
