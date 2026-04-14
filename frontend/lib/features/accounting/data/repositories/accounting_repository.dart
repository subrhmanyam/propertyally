import '../../domain/entities/transaction.dart';

class AccountingRepository {
  AccountingRepository();

  Future<List<Transaction>> getTransactions() async {
    await Future.delayed(const Duration(milliseconds: 400));
    return Transaction.mockList;
  }
}
