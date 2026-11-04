import '../../database/tables/account_table.dart';
import '../../models/account_model.dart';

class AccountController {
  double cashOpeningBalance = 0;
  double bankOpeningBalance = 0;

  Future<DateTime> saveBalances() => AccountTable.saveOpeningBalance(
    cash: cashOpeningBalance,
    bank: bankOpeningBalance,
  );

  Future<List<AccountModel>> getAllAccounts() => AccountTable.getAllAccounts();
}
