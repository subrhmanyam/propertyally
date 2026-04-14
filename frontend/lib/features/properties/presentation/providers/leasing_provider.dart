import '../../../../core/base/base_provider.dart';
import '../../data/repositories/leasing_repository.dart';
import '../../domain/entities/leasing_unit.dart';

class LeasingProvider extends BaseProvider {
  LeasingProvider() : _repo = LeasingRepository();

  final LeasingRepository _repo;

  List<LeasingUnit> _units = [];
  String _statusFilter = 'all';
  String _searchQuery = '';

  List<LeasingUnit> get units => _units;
  String get statusFilter => _statusFilter;

  List<LeasingUnit> get filtered {
    var list = _units;
    if (_statusFilter != 'all') {
      list = list.where((u) => u.status == _statusFilter).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list
          .where((u) =>
              u.name.toLowerCase().contains(q) ||
              u.category.toLowerCase().contains(q) ||
              u.floor.toLowerCase().contains(q) ||
              (u.contact?.toLowerCase().contains(q) ?? false))
          .toList();
    }
    return list;
  }

  int get totalUnits => _units.length;
  int get occupiedCount => _units.where((u) => u.status == 'occupied').length;
  int get vacantCount => _units.where((u) => u.status == 'vacant').length;
  double get totalMonthlyRent =>
      _units.fold(0, (s, u) => s + u.totalRent);
  double get totalSqft =>
      _units.fold(0, (s, u) => s + u.totalSqft);

  Future<void> load() async {
    await runAsync(() async {
      _units = await _repo.getAll();
      return _units;
    });
  }

  void setStatusFilter(String f) {
    _statusFilter = f;
    notifyListeners();
  }

  void setSearchQuery(String q) {
    _searchQuery = q;
    notifyListeners();
  }

  Future<void> add(LeasingUnit unit) async {
    final saved = await _repo.insert(unit);
    _units = [saved, ..._units];
    notifyListeners();
  }

  Future<void> update(LeasingUnit unit) async {
    await _repo.update(unit);
    _units = _units.map((u) => u.id == unit.id ? unit : u).toList();
    notifyListeners();
  }

  Future<void> delete(String id) async {
    await _repo.delete(id);
    _units = _units.where((u) => u.id != id).toList();
    notifyListeners();
  }

  void addImported(List<LeasingUnit> imported) {
    _units = [...imported, ..._units];
    notifyListeners();
  }
}
