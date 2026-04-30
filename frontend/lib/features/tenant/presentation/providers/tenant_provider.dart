import 'package:flutter/foundation.dart';
import '../../data/repositories/tenant_repository.dart';

class TenantProvider extends ChangeNotifier {
  TenantProvider() : _repo = TenantRepository();

  final TenantRepository _repo;

  Map<String, dynamic>? profile;
  Map<String, dynamic>? unit;
  Map<String, dynamic>? lease;
  List<Map<String, dynamic>> invoices = [];
  List<Map<String, dynamic>> maintenance = [];
  List<Map<String, dynamic>> queries = [];
  List<Map<String, dynamic>> serviceRequests = [];
  List<Map<String, dynamic>> serviceCatalog = [];

  bool isLoading = false;
  String? error;

  Future<void> loadAll() async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      final results = await Future.wait([
        _repo.getMe(),
        _repo.getMyInvoices(),
        _repo.getMyMaintenance(),
        _repo.getMyQueries(),
        _repo.getMyServiceRequests(),
      ]);
      profile = results[0] as Map<String, dynamic>;
      invoices = results[1] as List<Map<String, dynamic>>;
      maintenance = results[2] as List<Map<String, dynamic>>;
      queries = results[3] as List<Map<String, dynamic>>;
      serviceRequests = results[4] as List<Map<String, dynamic>>;

      // Load unit + catalog concurrently
      final tenant = profile!['tenant'] as Map<String, dynamic>?;
      final unitCategory = tenant?['leasing_units']?['category'] as String?;
      final unitResults = await Future.wait([
        _repo.getMyUnit().catchError((_) => <String, dynamic>{}),
        _repo.getMyLease(),
        _repo.getServiceCatalog(unitCategory),
      ]);
      unit = unitResults[0] as Map<String, dynamic>?;
      lease = unitResults[1] as Map<String, dynamic>?;
      serviceCatalog = unitResults[2] as List<Map<String, dynamic>>;
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshInvoices() async {
    invoices = await _repo.getMyInvoices();
    notifyListeners();
  }

  Future<void> refreshMaintenance() async {
    maintenance = await _repo.getMyMaintenance();
    notifyListeners();
  }

  Future<void> addMaintenance(Map<String, dynamic> data) async {
    await _repo.createMaintenance(data);
    await refreshMaintenance();
  }

  Future<void> refreshQueries() async {
    queries = await _repo.getMyQueries();
    notifyListeners();
  }

  Future<void> addQuery(Map<String, dynamic> data) async {
    await _repo.createQuery(data);
    await refreshQueries();
  }

  Future<void> replyQuery(String queryId, String body) async {
    await _repo.replyToQuery(queryId, body);
    await refreshQueries();
  }

  Future<void> addServiceRequest(Map<String, dynamic> data) async {
    await _repo.createServiceRequest(data);
    serviceRequests = await _repo.getMyServiceRequests();
    notifyListeners();
  }

  Future<Map<String, String>> startPayment(String transactionId) {
    return _repo.createCheckoutSession(
      transactionId: transactionId,
      successUrl: 'http://localhost:3000/tenant/invoices?payment=success',
      cancelUrl: 'http://localhost:3000/tenant/invoices?payment=cancelled',
    );
  }
}
