import 'package:dio/dio.dart';

import '../../../../core/network/api_client.dart';
import '../../domain/entities/transaction.dart';

class AccountingRepository {
  final Dio _dio = ApiClient.accounting;

  Future<List<Transaction>> getTransactions({
    String? type,
    String? status,
    String? leasingUnitId,
    String? fromDate,
    String? toDate,
  }) async {
    final params = <String, String>{};
    if (type != null) params['type'] = type;
    if (status != null) params['status'] = status;
    if (leasingUnitId != null) params['leasing_unit_id'] = leasingUnitId;
    if (fromDate != null) params['from_date'] = fromDate;
    if (toDate != null) params['to_date'] = toDate;

    final resp = await _dio.get(
      '/api/v1/accounting/transactions',
      queryParameters: params.isEmpty ? null : params,
    );
    final list = (resp.data as List?) ?? [];
    return list.map((e) => Transaction.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Map<String, dynamic>> getSummary() async {
    final resp = await _dio.get('/api/v1/accounting/summary');
    return Map<String, dynamic>.from(resp.data as Map);
  }

  Future<Map<String, dynamic>> generateInvoices() async {
    final resp = await _dio.post('/api/v1/accounting/invoices/generate');
    return Map<String, dynamic>.from(resp.data as Map);
  }

  Future<Transaction> markPaid(String transactionId) async {
    final resp = await _dio.patch(
      '/api/v1/accounting/transactions/$transactionId/status',
      data: {'status': 'paid'},
    );
    return Transaction.fromJson(resp.data as Map<String, dynamic>);
  }
}
