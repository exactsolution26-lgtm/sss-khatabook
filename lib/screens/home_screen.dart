import 'package:flutter/material.dart';
import '../routes/app_routes.dart';
import '../core/constants/app_strings.dart';
import '../core/constants/app_sizes.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.appName),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSizes.paddingL),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              AppStrings.appName,
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: AppSizes.paddingXL),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              mainAxisSpacing: AppSizes.paddingL,
              crossAxisSpacing: AppSizes.paddingL,
              children: [
                _buildMenuCard(
                  context,
                  icon: Icons.account_balance,
                  title: 'Opening Balance',
                  route: AppRoutes.openingBalance,
                ),
                _buildMenuCard(
                  context,
                  icon: Icons.trending_down,
                  title: AppStrings.addExpense,
                  route: AppRoutes.expenses,
                ),
                _buildMenuCard(
                  context,
                  icon: Icons.trending_up,
                  title: AppStrings.addIncome,
                  route: AppRoutes.income,
                ),
                _buildMenuCard(
                  context,
                  icon: Icons.timer,
                  title: AppStrings.workToday,
                  route: AppRoutes.workToday,
                ),
                _buildMenuCard(
                  context,
                  icon: Icons.analytics,
                  title: AppStrings.analysis,
                  route: AppRoutes.analysis,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String route,
  }) {
    return Card(
      elevation: 4,
      child: InkWell(
        onTap: () => Navigator.pushNamed(context, route),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 48,
              color: Theme.of(context).primaryColor,
            ),
            const SizedBox(height: AppSizes.paddingM),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
