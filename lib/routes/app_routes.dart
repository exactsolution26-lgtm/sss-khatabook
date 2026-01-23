import 'package:flutter/material.dart';
import '../features/accounts/opening_balance_screen.dart';

class AppRoutes {
  static const String openingBalance = '/';

  static final routes = {
    openingBalance: (context) => const OpeningBalanceScreen(),
  };
}
