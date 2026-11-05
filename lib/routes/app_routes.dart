import '../features/dashboard/dashboard_screen.dart';
import '../features/workspace/workspace_screens.dart';
import '../features/imports/csv_import_screen.dart';
import '../features/reports/financial_report_screen.dart';
import '../features/backup/backup_screen.dart';
import '../features/history/audit_screen.dart';
import '../features/history/transaction_history_screen.dart';
import '../features/security/security_screen.dart';
import '../features/dues/dues_screen.dart';
import '../features/followups/followup_screen.dart';
import '../features/dashboard/dashboard_templates.dart';
import '../features/settings/settings_screen.dart';
import '../features/income/income_screen.dart';
import '../features/expenses/expense_screen.dart';
import '../features/analysis/analysis_screen.dart';
import '../features/work_today/work_today_screen.dart';
import '../features/accounts/accounts_screen.dart';

import 'package:flutter/material.dart';

import '../features/accounts/opening_balance_screen.dart';
import '../features/subscribers/subscriber_management_screen.dart';
import '../features/whatsapp/whatsapp_share_screen.dart';

class AppRoutes {
  static const String dashboard = '/';
  static const String openingBalance = '/opening-balance';
  static const String subscribers = '/super-admin/subscribers';
  static const String whatsappShare = '/whatsapp/share';

  static final routes = <String, WidgetBuilder>{
    dashboard: (_) => const DashboardScreen(),
    '/reports/detailed': (_) => const FinancialReportScreen(),
    '/import': (_) => const CsvImportScreen(),
    '/profile': (_) => const BusinessProfileScreen(),
    '/getting-started': (_) => const GettingStartedScreen(),
    '/contacts': (_) => const WorkspaceDirectoryScreen(contacts:true),
    '/message-templates': (_) => const WorkspaceDirectoryScreen(contacts:false),
    '/draft-history': (_) => const DraftHistoryScreen(),
    '/support': (_) => const SupportScreen(),
    '/dashboard-previews': (_) => const DashboardPreviewsScreen(),
    '/settings': (_) => const SettingsScreen(),
    '/backup': (_) => const BackupScreen(),
    '/audit': (_) => const AuditScreen(),
    '/security': (_) => const SecurityScreen(),
    '/dues': (_) => const DuesScreen(),
    '/followups': (_) => const FollowupScreen(),
    '/accounts': (_) => const AccountsScreen(),
    '/income-history': (_) => const TransactionHistoryScreen(income: true),
    '/expense-history': (_) => const TransactionHistoryScreen(income: false),
    '/income': (_) => const IncomeScreen(),
    '/expenses': (_) => const ExpenseScreen(),
    '/reports': (_) => const AnalysisScreen(),
    '/work': (_) => const WorkTodayScreen(),
    openingBalance: (context) => const OpeningBalanceScreen(),
    whatsappShare: (context) => const WhatsAppShareScreen(),
    subscribers: (context) {
      const url = String.fromEnvironment('SUPABASE_URL');
      const key = String.fromEnvironment('SUPABASE_ANON_KEY');
      if (url.isEmpty || key.isEmpty) {
        return const Scaffold(
          body: Center(
            child: Text('Subscriber management requires backend configuration'),
          ),
        );
      }
      return const SubscriberManagementScreen();
    },
  };
}
