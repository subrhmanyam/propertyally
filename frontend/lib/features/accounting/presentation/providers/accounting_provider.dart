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
  bool _generating = false;

  List<Transaction> get transactions => _transactions;
  AccountingFilter get filter => _filter;
  bool get isGenerating => _generating;

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
          (t.referenceNo?.toLowerCase().contains(q) ?? false) ||
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

  /// Generates monthly rent invoices for all active leases. Returns a summary map.
  Future<Map<String, dynamic>> generateInvoices() async {
    _generating = true;
    notifyListeners();
    try {
      final result = await _repo.generateInvoices();
      // Reload so new invoices appear immediately
      _transactions = await _repo.getTransactions();
      return result;
    } finally {
      _generating = false;
      notifyListeners();
    }
  }

  Future<void> markPaid(String transactionId) async {
    final updated = await _repo.markPaid(transactionId);
    final idx = _transactions.indexWhere((t) => t.id == transactionId);
    if (idx != -1) {
      _transactions = List.of(_transactions)..[idx] = updated;
      notifyListeners();
    }
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
