import '../../../../core/base/base_provider.dart';
import '../../data/repositories/maintenance_repository.dart';
import '../../domain/entities/maintenance_request.dart';

enum MaintFilter { all, open, inProgress, completed }

class MaintenanceProvider extends BaseProvider {
  MaintenanceProvider() : _repo = MaintenanceRepository();

  final MaintenanceRepository _repo;

  List<MaintenanceRequest> _requests = [];
  MaintFilter _filter = MaintFilter.all;
  String _searchQuery = '';

  List<MaintenanceRequest> get requests => _requests;
  MaintFilter get filter => _filter;

  List<MaintenanceRequest> get filtered {
    var list = _requests;
    if (_filter == MaintFilter.open) {
      list = list.where((r) => r.status == MaintStatus.open).toList();
    } else if (_filter == MaintFilter.inProgress) {
      list = list.where((r) => r.status == MaintStatus.inProgress).toList();
    } else if (_filter == MaintFilter.completed) {
      list = list.where((r) => r.status == MaintStatus.completed).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((r) =>
          r.title.toLowerCase().contains(q) ||
          (r.category?.toLowerCase().contains(q) ?? false) ||
          (r.assignedTo?.toLowerCase().contains(q) ?? false) ||
          (r.description?.toLowerCase().contains(q) ?? false)).toList();
    }
    return list;
  }

  int get openCount => _requests.where((r) => r.status == MaintStatus.open).length;
  int get inProgressCount => _requests.where((r) => r.status == MaintStatus.inProgress).length;
  int get urgentCount => _requests.where((r) => r.priority == MaintPriority.urgent).length;

  Future<void> load() async {
    await runAsync(() async {
      _requests = await _repo.getAll();
      return _requests;
    });
  }

  Future<void> createRequest(Map<String, dynamic> data) async {
    final created = await _repo.create(data);
    _requests = [created, ..._requests];
    notifyListeners();
  }

  Future<void> updateStatus(MaintenanceRequest req, String newStatus) async {
    final updated = await _repo.updateStatus(req, newStatus);
    final idx = _requests.indexWhere((r) => r.id == req.id);
    if (idx != -1) {
      _requests = List.of(_requests)..[idx] = updated;
      notifyListeners();
    }
  }

  void setFilter(MaintFilter f) {
    _filter = f;
    notifyListeners();
  }

  void setSearchQuery(String q) {
    _searchQuery = q;
    notifyListeners();
  }
}
