import 'package:flutter/foundation.dart';
import '../../data/repositories/services_repository.dart';

class ServicesProvider extends ChangeNotifier {
  ServicesProvider() : _repo = ServicesRepository();

  final ServicesRepository _repo;

  List<Map<String, dynamic>> requests = [];
  List<Map<String, dynamic>> catalog = [];
  List<Map<String, dynamic>> units = [];

  bool isLoading = false;
  String? error;
  String _statusFilter = 'all';

  String get statusFilter => _statusFilter;

  List<Map<String, dynamic>> get filtered => _statusFilter == 'all'
      ? requests
      : requests.where((r) => r['status'] == _statusFilter).toList();

  void setFilter(String f) {
    _statusFilter = f;
    notifyListeners();
  }

  Future<void> load() async {
    isLoading = true;
    error = null;
    notifyListeners();
    await Future.wait([
      _repo.listRequests().then((v) => requests = v).catchError((_) => requests = []),
      _repo.getUnits().then((v) => units = v).catchError((_) => units = []),
    ]);
    isLoading = false;
    notifyListeners();
  }

  Future<void> loadUnits() async {
    units = await _repo.getUnits();
    notifyListeners();
  }

  Future<List<Map<String, dynamic>>> getCatalog({String? category}) async {
    return _repo.getCatalog(category: category);
  }

  Future<List<Map<String, dynamic>>> catalogForUnit(String unitId) async {
    final unit = units.firstWhere((u) => u['id'] == unitId, orElse: () => {});
    final category = unit['category'] as String?;
    return _repo.getCatalog(category: category);
  }

  Future<void> createRequest({
    required String leasingUnitId,
    String? serviceId,
    String? serviceName,
    String? description,
    String priority = 'normal',
  }) async {
    final r = await _repo.createAdminRequest(
      leasingUnitId: leasingUnitId,
      serviceId: serviceId,
      serviceName: serviceName,
      description: description,
      priority: priority,
    );
    requests = [r, ...requests];
    notifyListeners();
  }

  Future<void> updateStatus(String id, String status) async {
    await _repo.updateRequest(id, {'status': status});
    final idx = requests.indexWhere((r) => r['id'] == id);
    if (idx != -1) {
      requests[idx] = {...requests[idx], 'status': status};
      notifyListeners();
    }
  }
}
