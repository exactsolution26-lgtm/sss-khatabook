import '../../database/tables/account_table.dart';

class AccountController {
  double cashOpeningBalance = 0;
  double bankOpeningBalance = 0;

  Future<void> saveBalances() async {
    await AccountTable.saveOpeningBalance(
      cash: cashOpeningBalance,
      bank: bankOpeningBalance,
    );
  }
}
