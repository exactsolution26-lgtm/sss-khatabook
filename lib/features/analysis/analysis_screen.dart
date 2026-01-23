import 'package:flutter/material.dart';
import '../../widgets/header_text.dart';
import '../../core/constants/app_strings.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/calculation_utils.dart';
import 'analysis_logic.dart';

class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({super.key});

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  final _analysisLogic = AnalysisLogic();
  bool _isLoading = true;
  Map<String, dynamic> _analysisData = {};
  List<Map<String, dynamic>> _accountDetails = [];

  @override
  void initState() {
    super.initState();
    _loadAnalysis();
  }

  Future<void> _loadAnalysis() async {
    setState(() => _isLoading = true);
    try {
      final data = await _analysisLogic.getAnalysisData();
      final details = await _analysisLogic.getAccountDetails();
      setState(() {
        _analysisData = data;
        _accountDetails = details;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.analysis),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAnalysis,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAnalysis,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const HeaderText(text: AppStrings.financialAnalysis),
                    const SizedBox(height: 24),
                    _buildSummaryCard(
                      AppStrings.totalIncome,
                      CalculationUtils.formatCurrency(
                        (_analysisData['totalIncome'] as num?)?.toDouble() ?? 0.0,
                      ),
                      AppColors.income,
                    ),
                    const SizedBox(height: 16),
                    _buildSummaryCard(
                      AppStrings.totalExpense,
                      CalculationUtils.formatCurrency(
                        (_analysisData['totalExpense'] as num?)?.toDouble() ?? 0.0,
                      ),
                      AppColors.expense,
                    ),
                    const SizedBox(height: 16),
                    _buildSummaryCard(
                      AppStrings.totalBalance,
                      CalculationUtils.formatCurrency(
                        (_analysisData['totalBalance'] as num?)?.toDouble() ?? 0.0,
                      ),
                      AppColors.balance,
                    ),
                    const SizedBox(height: 32),
                    const HeaderText(text: AppStrings.accountDetails),
                    const SizedBox(height: 16),
                    ..._accountDetails.map((detail) => _buildAccountCard(detail)),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSummaryCard(String title, String amount, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(
              amount,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountCard(Map<String, dynamic> detail) {
    final account = detail['account'];
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              account.name,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            _buildDetailRow(AppStrings.openingBalanceLabel2, detail['openingBalance']),
            _buildDetailRow(AppStrings.income, detail['income']),
            _buildDetailRow(AppStrings.expense, detail['expense']),
            const Divider(),
            _buildDetailRow(
              AppStrings.balance,
              detail['balance'],
              isBold: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, double value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            CalculationUtils.formatCurrency(value),
            style: isBold
                ? Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    )
                : null,
          ),
        ],
      ),
    );
  }
}
