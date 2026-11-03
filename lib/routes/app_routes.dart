import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../features/accounts/opening_balance_screen.dart';
import '../features/subscribers/subscriber_management_screen.dart';
import '../features/whatsapp/whatsapp_share_screen.dart';

class AppRoutes {
  static const String openingBalance = '/';
  static const String subscribers = '/super-admin/subscribers';
  static const String whatsappShare = '/whatsapp/share';

  static final routes = <String, WidgetBuilder>{
    openingBalance: (context) => const OpeningBalanceScreen(),
    whatsappShare: (context) => const WhatsAppShareScreen(),
    subscribers: (context) {
      const url = String.fromEnvironment('SUPABASE_URL');
      const key = String.fromEnvironment('SUPABASE_ANON_KEY');
      if (url.isEmpty || key.isEmpty) {
        return const Scaffold(body: Center(
          child: Text('Subscriber management requires backend configuration')));
      }
      return const SubscriberManagementScreen();
    },
  };
}
