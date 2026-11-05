import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:offline_khata_app/app.dart';
import 'package:offline_khata_app/core/security/app_lock.dart';
import 'package:offline_khata_app/core/security/backend_mode.dart';
import 'package:offline_khata_app/database/db_helper.dart';
import 'package:offline_khata_app/database/tables/account_table.dart';
import 'package:offline_khata_app/features/analysis/analysis_logic.dart';
import 'package:offline_khata_app/features/backup/backup_service.dart';
import 'package:offline_khata_app/features/imports/csv_import.dart';
import 'package:offline_khata_app/features/reports/financial_report.dart';
import 'package:offline_khata_app/features/workspace/workspace_schema.dart';
import 'package:offline_khata_app/features/workspace/workspace_store.dart';
import 'package:offline_khata_app/features/workspace/workspace_screens.dart';
import 'package:offline_khata_app/features/settings/app_settings.dart';
import 'package:offline_khata_app/features/whatsapp/whatsapp_share_screen.dart';

void main(){
  TestWidgetsFlutterBinding.ensureInitialized();sqfliteFfiInit();databaseFactory=databaseFactoryFfiNoIsolate;
  late Directory folder;late int account;
  setUp(()async{SharedPreferences.setMockInitialValues({});folder=await Directory.systemTemp.createTemp('sss-completion-');
    await databaseFactory.setDatabasesPath(folder.path);await AccountTable.saveAccount(name:'Main Account',openingBalance:1000);
    account=(await AccountTable.getAllAccounts()).single.id!;});
  tearDown(()async{await DBHelper.close();await folder.delete(recursive:true);});
  String csv(String rows)=>'${CsvImport.header.join(',')}\n$rows';
  ImportEntry entry({String id='source-1',int paise=10010,int? owner})=>ImportEntry(true,owner??account,paise,'2026-11-04','Sales','cash','Ravi','+919876543210','Sale',id);
  MyApp app()=>MyApp(automaticBackups:false,appLock:AppLock(read:()async=>null,write:(_)async{},supported:true));

  test('cloud configuration never silently selects shared offline mode',(){
    expect(BackendMode.localOnly('',''),isTrue);expect(BackendMode.localOnly('https://example.invalid','public-test-key'),isFalse);
    expect(()=>BackendMode.localOnly('https://example.invalid',''),throwsStateError);expect(()=>BackendMode.localOnly('','public-test-key'),throwsStateError);
  });
  test('profile and phone validation, edits and template uniqueness preserve finance and snapshots',()async{
    await WorkspaceStore.saveProfile(name:'Exact Solution',phone:'9876543210',email:'owner@example.test',address:'New Delhi');
    expect((await WorkspaceStore.profile())!['phone'],'+919876543210');
    await expectLater(WorkspaceStore.saveProfile(name:'',email:'bad'),throwsArgumentError);
    await WorkspaceStore.saveContact('Ravi','9876543210');final contact=(await WorkspaceStore.contacts()).single;
    await CsvImport.commit([entry()]);
    await WorkspaceStore.saveContact('Ravi New','9876543211',id:contact['id'] as int);
    final db=await DBHelper.database;expect((await db.query('income')).single['contact_name'],'Ravi');
    expect((await db.query('income')).single['contact_phone'],'+919876543210');
    await WorkspaceStore.saveTemplate('Follow-up','Please call when convenient.');
    await expectLater(WorkspaceStore.saveTemplate('follow-UP','Duplicate title'),throwsA(isA<DatabaseException>()));
    expect((await AnalysisLogic().getAnalysisData())['totalBalance'],closeTo(1100.10,0.00001));
    final audit=await db.query('app_audit',where:"entity='contact_directory'",orderBy:'rowid');
    expect(audit.map((e)=>e['operation']),['insert','update']);
    await WorkspaceStore.remove('contact_directory',contact['id'] as int);expect(await WorkspaceStore.contacts(),isEmpty);
    expect((await db.query('income')).single['contact_name'],'Ravi');
  });
  test('new workspace data and import identities survive validated encrypted-compatible restore',()async{
    await WorkspaceStore.saveProfile(name:'Business');await WorkspaceStore.saveContact('Ravi','9876543210');
    await WorkspaceStore.saveTemplate('Reminder','Please review your ledger.');await CsvImport.commit([entry()]);
    final service=BackupService();final snapshot=await service.snapshot();expect(snapshot['schema'],11);await service.validate(snapshot);
    await WorkspaceStore.saveProfile(name:'Changed');
    await DBHelper.replaceSnapshot(await DBHelper.database,service.validateShape(snapshot));
    expect((await WorkspaceStore.profile())!['name'],'Business');expect(await WorkspaceStore.contacts(),hasLength(1));
    expect(await WorkspaceStore.templates(),hasLength(1));expect((await CsvImport.commit([entry()])).skipped,1);
    expect((await AnalysisLogic().getAnalysisData())['totalBalance'],closeTo(1100.10,0.00001));
    final old=jsonDecode(jsonEncode(snapshot)) as Map<String,dynamic>;old['schema']=9;
    for(final t in WorkspaceSchema.tables){(old['tables'] as Map).remove(t);}
    await service.validate(old);expect(service.validateShape(old)['message_templates'],isEmpty);
  });
  test('invalid workspace restore values never replace live data',()async{
    await WorkspaceStore.saveProfile(name:'Original');final service=BackupService();
    final snapshot=jsonDecode(jsonEncode(await service.snapshot())) as Map<String,dynamic>;
    ((snapshot['tables'] as Map)['business_profile'] as List).single['email']='not-an-email';
    await expectLater(service.validate(snapshot),throwsA(anything));expect((await WorkspaceStore.profile())!['name'],'Original');
  });
  test('strict CSV parser supports BOM, quotes/newlines and validates every row',(){
    final rows=CsvImport.parse('\ufeff'+csv('income,$account,100.10,2026-11-04,Sales,cash,Ravi,9876543210,"Sale, with ""quotes""\nand newline",abc\r\n'));
    expect(rows.single.note,'Sale, with "quotes"\nand newline');expect(rows.single.phone,'+919876543210');expect(rows.single.paise,10010);
    for(final text in [csv('income,$account,0,2026-11-04,Sales,cash,,,,x'),csv('income,$account,1,2026-02-30,Sales,cash,,,,x'),
      csv('income,$account,1,2099-01-01,Sales,cash,,,,x'),csv('income,$account,1,2026-11-04,Sales,cash,Ravi,,,x'),csv('"unclosed')]){
      expect(()=>CsvImport.parse(text),throwsFormatException);
    }
  });
  test('import duplicate IDs skip, conflicting IDs roll back the entire batch',()async{
    final first=await CsvImport.commit([entry(),entry()]);expect(first.inserted,1);expect(first.skipped,1);
    final db=await DBHelper.database;final saved=(await db.query('income')).single['created_at'];
    await expectLater(CsvImport.commit([entry(id:'source-2'),entry(paise:20000)]),throwsStateError);
    expect(await db.query('income'),hasLength(1));expect(await db.query('import_records'),hasLength(1));
    expect((await db.query('income')).single['created_at'],saved);
    await expectLater(CsvImport.commit([entry(id:'source-2'),entry(id:'missing-account',owner:999)]),throwsStateError);
    expect(await db.query('income'),hasLength(1));
    await expectLater(CsvImport.commit([entry(paise:-1)]),throwsArgumentError);
  });
  test('no-ID imports deduplicate exact manual rows; explicit different source IDs permit intentional identical payments',()async{
    final db=await DBHelper.database;
    await db.insert('income',{'account_id':account,'amount':100.10,'date':'2026-11-04','category':'Sales','mode':'cash','description':'Sale',
      'contact_name':'Ravi','contact_phone':'+919876543210','created_at':'2026-11-04T00:00:00Z'});
    expect((await CsvImport.commit([entry(id:'')])).skipped,1);
    expect((await CsvImport.commit([entry(id:'another-payment')])).inserted,1);
    expect(await db.query('income'),hasLength(2));
  });
  test('concurrent imports do not double insert the same source payment',()async{
    final results=await Future.wait([CsvImport.commit([entry()]),CsvImport.commit([entry()])]);
    expect(results.fold(0,(int n,r)=>n+r.inserted),1);expect(await (await DBHelper.database).query('income'),hasLength(1));
  });
  test('detailed reports use paise, inclusive dates, source accounts and stable category/mode totals',()async{
    await CsvImport.commit([entry(),ImportEntry(false,account,5005,'2026-11-04','Travel','upi','','','Bus','cost-1'),
      ImportEntry(true,account,20020,'2026-11-03','Sales','bank','','','Sale 2','source-2')]);
    final all=await FinancialReport.load();expect(all.income,30030);expect(all.expense,5005);expect(all.net,25025);
    expect(all.categories['Sales']!.income,30030);expect(all.modes['upi']!.expense,5005);expect(all.months['2026-11']!.net,25025);
    final day=await FinancialReport.load(from:'2026-11-04',to:'2026-11-04',accountId:account);
    expect(day.count,2);expect(day.net,5005);expect(day.income,10010);
    await expectLater(FinancialReport.load(from:'2026-11-05',to:'2026-11-04'),throwsArgumentError);
    await expectLater(FinancialReport.load(accountId:999),throwsStateError);
  });

  test('account archive keeps financial totals/history and blocks writes until restore',()async{
    await CsvImport.commit([entry()]);final db=await DBHelper.database;
    final before=(await AnalysisLogic().getAnalysisData())['totalBalance'];
    await AccountTable.archive(account,archived:true);
    expect(await AccountTable.getAllAccounts(),isEmpty);
    expect((await AccountTable.getAllAccounts(includeArchived:true)).single.isArchived,isTrue);
    expect((await AnalysisLogic().getAnalysisData())['totalBalance'],before);
    expect(await db.query('income'),hasLength(1));
    await expectLater(CsvImport.commit([entry(id:'blocked')]),throwsA(isA<DatabaseException>()));
    await expectLater(db.update('income',{'amount':200},where:'id=1'),throwsA(isA<DatabaseException>()));
    final service=BackupService();final snapshot=await service.snapshot();await service.validate(snapshot);
    await DBHelper.replaceSnapshot(db,service.validateShape(snapshot));
    expect((await AccountTable.getAllAccounts(includeArchived:true)).single.isArchived,isTrue);
    await AccountTable.archive(account,archived:false);
    expect(await AccountTable.getAllAccounts(),hasLength(1));
    expect((await CsvImport.commit([entry(id:'after-restore')])).inserted,1);
  });
  test('schema10 workspace upgrades without changing records and adds archive guards',()async{
    await CsvImport.commit([entry()]);final db=await DBHelper.database;
    for(final table in ['income','expenses']){for(final action in ['insert','update']){await db.execute('DROP TRIGGER ${table}_${action}_guard');}}
    await db.execute('ALTER TABLE accounts DROP COLUMN archived_at');
    await db.execute('PRAGMA user_version=10');await DBHelper.close();
    final upgraded=await DBHelper.database;
    expect((await upgraded.rawQuery('PRAGMA user_version')).single.values.single,11);
    expect((await upgraded.query('income')).single['amount'],100.10);
    await AccountTable.archive(account,archived:true);
    await expectLater(CsvImport.commit([entry(id:'must-block')]),throwsA(isA<DatabaseException>()));
    expect((await upgraded.rawQuery('PRAGMA integrity_check')).single.values.single,'ok');
  });
  testWidgets('Hindi preference also localizes framework calendar and dialog controls',(tester)async{
    SharedPreferences.setMockInitialValues({'sss_language':'hindi'});
    await tester.pumpWidget(app());await tester.pumpAndSettle();
    final context=tester.element(find.text('डैशबोर्ड'));
    expect(Localizations.localeOf(context).languageCode,'hi');
    expect(MaterialLocalizations.of(context).cancelButtonLabel,isNot('Cancel'));
    expect(tester.takeException(),isNull);await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('profile form saves durable values and actual saved timestamp through app navigation',(tester)async{
    await tester.pumpWidget(app());await tester.pumpAndSettle();await tester.tap(find.byTooltip('Settings'));await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Business Profile'),200,scrollable:find.byType(Scrollable).first);
    await tester.tap(find.text('Business Profile'));await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField,'Business name'),'Exact Solution');
    await tester.enterText(find.widgetWithText(TextField,'Business phone (optional)'),'9876543210');
    FocusManager.instance.primaryFocus?.unfocus();await tester.pumpAndSettle();
    final save=find.text('Save Profile');await tester.ensureVisible(save);await tester.pumpAndSettle();await tester.tap(save.hitTestable());await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('profile-saved')),findsOneWidget);expect((await WorkspaceStore.profile())!['name'],'Exact Solution');
    expect(tester.takeException(),isNull);await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('saved template opens editable custom draft with sharing still opt-in',(tester)async{
    await WorkspaceStore.saveTemplate('Call back','Please call when convenient.');final settings=AppSettings();
    await tester.pumpWidget(SettingsScope(settings:settings,child:const MaterialApp(home:WorkspaceDirectoryScreen(contacts:false))));await tester.pumpAndSettle();
    await tester.tap(find.text('Review WhatsApp draft'));await tester.pumpAndSettle();
    expect(find.byType(WhatsAppShareScreen),findsOneWidget);expect(find.text('Please call when convenient.'),findsWidgets);
    expect(tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,isFalse);
    await tester.scrollUntilVisible(find.text('Open WhatsApp Draft'),160,scrollable:find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(find.byWidgetPredicate((w)=>w is FilledButton)).onPressed,isNull);
    expect(tester.takeException(),isNull);await tester.pumpWidget(const SizedBox.shrink());settings.dispose();
  });
  testWidgets('draft history distinguishes opening from delivery and tolerates malformed historic rows',(tester)async{
    SharedPreferences.setMockInitialValues({'whatsapp_draft_audit_v1':['broken',jsonEncode({'type':'receipt','opened_at_utc':'2026-11-04T20:01:02Z','status':'opened_not_confirmed_sent'})]});
    final settings=AppSettings();await tester.pumpWidget(SettingsScope(settings:settings,child:const MaterialApp(home:DraftHistoryScreen())));await tester.pumpAndSettle();
    expect(find.textContaining('Sending and delivery are not confirmed'),findsOneWidget);
    expect(find.text('Thursday, 5 November 2026 · 01:31:02 AM IST'),findsOneWidget);expect(find.text('receipt · Opened'),findsOneWidget);
    expect(tester.takeException(),isNull);await tester.pumpWidget(const SizedBox.shrink());settings.dispose();
  });
}
