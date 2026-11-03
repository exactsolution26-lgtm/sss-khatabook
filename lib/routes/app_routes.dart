import '../features/dashboard/dashboard_screen.dart';
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
    '/settings': (_) => const SettingsScreen(),
    '/accounts': (_) => const AccountsScreen(),
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
