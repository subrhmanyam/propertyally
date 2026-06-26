import '../../../../core/base/base_provider.dart';
import '../../data/repositories/tenant_repository.dart';
import '../../domain/entities/tenant.dart';

class TenantsProvider extends BaseProvider {
  TenantsProvider({TenantRepository? repository})
      : _repository = repository ?? TenantRepository();

  final TenantRepository _repository;

  List<Tenant> _tenants = [];
  Tenant? _selectedTenant;
  Lease? _selectedLease;
  String _statusFilter = 'All';
  String _searchQuery = '';

  List<Tenant> get tenants => _filteredTenants();
  Tenant? get selectedTenant => _selectedTenant;
  Lease? get selectedLease => _selectedLease;
  String get statusFilter => _statusFilter;
  String get searchQuery => _searchQuery;

  List<Tenant> _filteredTenants() {
    var list = _tenants;
    if (_statusFilter != 'All') {
      list = list
          .where((t) => t.status.toLowerCase() == _statusFilter.toLowerCase())
          .toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list
          .where((t) =>
              t.fullName.toLowerCase().contains(q) ||
              t.email.toLowerCase().contains(q) ||
              t.phone.contains(q))
          .toList();
    }
    return list;
  }

  void setStatusFilter(String filter) {
    _statusFilter = filter;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  Future<void> loadTenants({String? propertyId}) async {
    await runAsync(() async {
      _tenants = await _repository.listTenants(propertyId: propertyId);
    });
  }

  Future<void> loadTenant(String id) async {
    await runAsync(() async {
      _selectedTenant = await _repository.getTenant(id);
      _selectedLease = await _repository.getTenantLease(id);
    });
    if (_selectedTenant == null) {
      _selectedTenant = _tenants.where((t) => t.id == id).firstOrNull;
      notifyListeners();
    }
  }

  Future<Tenant?> createTenant(Map<String, dynamic> data) async {
    return runAsync(() async {
      final tenant = await _repository.createTenant(data);
      _tenants = [tenant, ..._tenants];
      return tenant;
    });
  }

  Future<void> deleteTenant(String id) async {
    await runAsync(() async {
      await _repository.deleteTenant(id);
      _tenants = _tenants.where((t) => t.id != id).toList();
    });
  }
}
