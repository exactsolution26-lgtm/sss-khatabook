import 'package:flutter/material.dart';
import '../features/accounts/opening_balance_screen.dart';
import '../features/dashboard/dashboard_selection_screen.dart';
import '../features/expenses/expense_screen.dart';
import '../features/income/income_screen.dart';

class AppRoutes {
  static const String openingBalance = '/';
  static const String dashboardSelection = '/dashboard-selection';
  static const String addExpense = '/add-expense';
  static const String addIncome = '/add-income';

  static final routes = {
    openingBalance: (context) => const OpeningBalanceScreen(),
    dashboardSelection: (context) => const DashboardSelectionScreen(),
    addExpense: (context) => const ExpenseScreen(),
    addIncome: (context) => const IncomeScreen(),
  };
}
