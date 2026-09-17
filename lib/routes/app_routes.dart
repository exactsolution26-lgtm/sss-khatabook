import 'package:flutter/material.dart';
import '../features/accounts/opening_balance_screen.dart';
import '../features/expenses/expense_screen.dart';
import '../features/income/income_screen.dart';
import '../features/work_today/work_today_screen.dart';
import '../features/analysis/analysis_screen.dart';
import '../screens/home_screen.dart';

class AppRoutes {
  static const String openingBalance = '/opening-balance';
  static const String home = '/';
  static const String expenses = '/expenses';
  static const String income = '/income';
  static const String workToday = '/work-today';
  static const String analysis = '/analysis';

  static final routes = {
    home: (context) => const HomeScreen(),
    openingBalance: (context) => const OpeningBalanceScreen(),
    expenses: (context) => const ExpenseScreen(),
    income: (context) => const IncomeScreen(),
    workToday: (context) => const WorkTodayScreen(),
    analysis: (context) => const AnalysisScreen(),
  };
}
