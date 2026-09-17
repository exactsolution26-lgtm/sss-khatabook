import '../../database/tables/account_table.dart';
import '../../models/account_model.dart';

class AccountController {
  double cashOpeningBalance = 0;
  double bankOpeningBalance = 0;

  Future<void> saveBalances() async {
    await AccountTable.saveOpeningBalance(
      cash: cashOpeningBalance,
      bank: bankOpeningBalance,
    );
  }

  Future<List<AccountModel>> getAllAccounts() async {
    return await AccountTable.getAll();
  }

  Future<int> createAccount(AccountModel account) async {
    return await AccountTable.insert(account);
  }

  Future<AccountModel?> getAccountById(int id) async {
    return await AccountTable.getById(id);
  }

  Future<int> updateAccount(AccountModel account) async {
    return await AccountTable.update(account);
  }

  Future<int> deleteAccount(int id) async {
    return await AccountTable.delete(id);
  }
}
