import '../../../../core/base/base_provider.dart';
import '../../data/repositories/leasing_repository.dart';
import '../../domain/entities/leasing_unit.dart';

/// Summary statistics for a single parent company.
class CompanySummary {
  const CompanySummary({
    required this.name,
    required this.units,
  });

  final String name;
  final List<LeasingUnit> units;

  int get totalUnits => units.length;
  int get occupiedCount => units.where((u) => u.status == 'occupied').length;
  int get vacantCount => units.where((u) => u.status == 'vacant').length;
  int get inHouseCount => units.where((u) => u.status == 'in_house').length;
  int get ownerOccupiedCount =>
      units.where((u) => u.status == 'owner_occupied').length;
  double get totalMonthlyRent => units.fold(0, (s, u) => s + u.totalRent);
  double get totalSqft => units.fold(0, (s, u) => s + u.totalSqft);
  double get occupancyRate =>
      totalUnits == 0 ? 0 : occupiedCount / totalUnits * 100;
}

class LeasingProvider extends BaseProvider {
  LeasingProvider() : _repo = LeasingRepository();

  final LeasingRepository _repo;

  List<LeasingUnit> _units = [];
  String? _selectedCompany;
  String _statusFilter = 'all';
  String _searchQuery = '';

  List<LeasingUnit> get units => _units;
  String? get selectedCompany => _selectedCompany;
  String get statusFilter => _statusFilter;

  // ── Company grouping ───────────────────────────────────────────────

  List<CompanySummary> get companies {
    final map = <String, List<LeasingUnit>>{};
    for (final u in _units) {
      map.putIfAbsent(u.companyName, () => []).add(u);
    }
    return map.entries
        .map((e) => CompanySummary(name: e.key, units: e.value))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  CompanySummary? get selectedCompanySummary {
    if (_selectedCompany == null) return null;
    final match = companies.where((c) => c.name == _selectedCompany);
    return match.isEmpty ? null : match.first;
  }

  void selectCompany(String? name) {
    _selectedCompany = name;
    _statusFilter = 'all';
    _searchQuery = '';
    notifyListeners();
  }

  // ── Filtered unit list (for the selected company view) ────────────

  List<LeasingUnit> get filtered {
    var list = _selectedCompany != null
        ? _units.where((u) => u.companyName == _selectedCompany).toList()
        : _units;

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

  // ── KPI getters (whole portfolio) ─────────────────────────────────

  int get totalUnits => _units.length;
  int get occupiedCount => _units.where((u) => u.status == 'occupied').length;
  int get vacantCount => _units.where((u) => u.status == 'vacant').length;
  double get totalMonthlyRent => _units.fold(0, (s, u) => s + u.totalRent);
  double get totalSqft => _units.fold(0, (s, u) => s + u.totalSqft);

  // ── CRUD ──────────────────────────────────────────────────────────

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
    final matches = _units.where((u) => u.id == id);
    final deletedUnit = matches.isNotEmpty ? matches.first : null;
    await _repo.delete(id);
    _units = _units.where((u) => u.id != id).toList();
    // If we just removed the last unit in the selected company, go back to Level 1
    if (deletedUnit != null && _selectedCompany == deletedUnit.companyName) {
      final stillHas = _units.any((u) => u.companyName == deletedUnit.companyName);
      if (!stillHas) _selectedCompany = null;
    }
    notifyListeners();
  }

  Future<void> deletePortfolio(CompanySummary summary) async {
    final ids = summary.units.map((u) => u.id).toList();
    await _repo.deletePortfolio(ids);
    _units = _units.where((u) => u.companyName != summary.name).toList();
    if (_selectedCompany == summary.name) _selectedCompany = null;
    notifyListeners();
  }

  /// Bulk-import units, tagging them with [companyName], and persist each
  /// one so it survives a reload.
  Future<void> addImported(
    List<LeasingUnit> imported, {
    required String companyName,
  }) async {
    final tagged = imported.map((u) => u.copyWith(companyName: companyName));
    final saved = await Future.wait(tagged.map(_repo.insert));
    _units = [...saved, ..._units];
    notifyListeners();
  }
}
