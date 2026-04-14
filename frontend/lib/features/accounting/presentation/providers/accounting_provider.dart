import '../../../../core/base/base_provider.dart';
import '../../data/repositories/accounting_repository.dart';
import '../../domain/entities/transaction.dart';

enum AccountingFilter { all, income, expenses, rentRoll }

class AccountingProvider extends BaseProvider {
  AccountingProvider() : _repo = AccountingRepository();

  final AccountingRepository _repo;

  List<Transaction> _transactions = [];
  AccountingFilter _filter = AccountingFilter.all;
  String _searchQuery = '';

  List<Transaction> get transactions => _transactions;
  AccountingFilter get filter => _filter;

  List<Transaction> get filtered {
    var list = _transactions;
    if (_filter == AccountingFilter.income) {
      list = list.where((t) => t.type == TransactionType.income).toList();
    } else if (_filter == AccountingFilter.expenses) {
      list = list.where((t) => t.type == TransactionType.expense).toList();
    } else if (_filter == AccountingFilter.rentRoll) {
      list = list.where((t) => t.category == 'Rent').toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((t) =>
          t.description.toLowerCase().contains(q) ||
          (t.tenantName?.toLowerCase().contains(q) ?? false) ||
          (t.propertyName?.toLowerCase().contains(q) ?? false) ||
          t.category.toLowerCase().contains(q)).toList();
    }
    return list;
  }

  double get totalIncome => _transactions
      .where((t) => t.type == TransactionType.income && t.status == TransactionStatus.paid)
      .fold(0, (sum, t) => sum + t.amount);

  double get totalExpenses => _transactions
      .where((t) => t.type == TransactionType.expense)
      .fold(0, (sum, t) => sum + t.amount);

  double get netIncome => totalIncome - totalExpenses;

  double get outstandingRent => _transactions
      .where((t) =>
          t.type == TransactionType.income &&
          t.category == 'Rent' &&
          (t.status == TransactionStatus.pending || t.status == TransactionStatus.overdue))
      .fold(0, (sum, t) => sum + t.amount);

  Future<void> loadTransactions() async {
    await runAsync(() async {
      _transactions = await _repo.getTransactions();
      return _transactions;
    });
  }

  void setFilter(AccountingFilter f) {
    _filter = f;
    notifyListeners();
  }

  void setSearchQuery(String q) {
    _searchQuery = q;
    notifyListeners();
  }
}
