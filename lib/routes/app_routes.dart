import 'package:flutter/material.dart';
import '../features/accounts/opening_balance_screen.dart';
import '../features/dashboard/dashboard_selection_screen.dart';

class AppRoutes {
  static const String openingBalance = '/';
  static const String dashboardSelection = '/dashboard-selection';

  static final routes = {
    openingBalance: (context) => const OpeningBalanceScreen(),
    dashboardSelection: (context) => const DashboardSelectionScreen(),
  };
}
