import '../../../../core/base/base_provider.dart';
import '../../data/repositories/property_repository.dart';
import '../../domain/entities/property.dart';

class PropertiesProvider extends BaseProvider {
  PropertiesProvider({PropertyRepository? repository})
      : _repository = repository ?? PropertyRepository();

  final PropertyRepository _repository;

  List<Property> _properties = [];
  Property? _selectedProperty;
  String _statusFilter = 'All';
  String _searchQuery = '';

  List<Property> get properties => _filteredProperties();
  List<Property> get allProperties => _properties;
  Property? get selectedProperty => _selectedProperty;
  String get statusFilter => _statusFilter;
  String get searchQuery => _searchQuery;

  List<Property> _filteredProperties() {
    var list = _properties;
    if (_statusFilter == 'Vacant') {
      list =
          list.where((p) => p.units.any((u) => u.status == 'vacant')).toList();
    } else if (_statusFilter == 'Occupied') {
      list = list.where((p) => p.occupancyRate == 100).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list
          .where((p) =>
              p.name.toLowerCase().contains(q) ||
              p.city.toLowerCase().contains(q) ||
              p.address.toLowerCase().contains(q))
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

  Future<void> loadProperties() async {
    await runAsync(() async {
      _properties = await _repository.listProperties();
    });
  }

  Future<void> loadProperty(String id) async {
    await runAsync(() async {
      _selectedProperty = await _repository.getProperty(id);
    });
    if (_selectedProperty == null) {
      _selectedProperty = _properties.where((p) => p.id == id).firstOrNull;
      notifyListeners();
    }
  }

  Future<Property?> createProperty(Map<String, dynamic> data) async {
    return runAsync(() async {
      final property = await _repository.createProperty(data);
      _properties = [property, ..._properties];
      return property;
    });
  }

  Future<void> updateUnitStatus(
    String propertyId,
    String unitId,
    String status,
  ) async {
    await runAsync(() async {
      await _repository.updateUnitStatus(propertyId, unitId, status);
      await loadProperty(propertyId);
    });
  }
}
