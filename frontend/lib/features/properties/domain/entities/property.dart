class Unit {
  const Unit({
    required this.id,
    required this.propertyId,
    required this.unitNumber,
    required this.status,
    required this.bedrooms,
    required this.bathrooms,
    required this.rentAmount,
  });

  final String id;
  final String propertyId;
  final String unitNumber;
  final String status; // 'occupied', 'vacant', 'maintenance'
  final int bedrooms;
  final double bathrooms;
  final double rentAmount;

  factory Unit.fromJson(Map<String, dynamic> json) => Unit(
        id: json['id']?.toString() ?? '',
        propertyId: json['property_id']?.toString() ?? '',
        unitNumber: json['unit_number']?.toString() ?? '',
        status: json['status']?.toString() ?? 'vacant',
        bedrooms: (json['bedrooms'] as num?)?.toInt() ?? 0,
        bathrooms: (json['bathrooms'] as num?)?.toDouble() ?? 0.0,
        rentAmount: (json['rent_amount'] as num?)?.toDouble() ?? 0.0,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'property_id': propertyId,
        'unit_number': unitNumber,
        'status': status,
        'bedrooms': bedrooms,
        'bathrooms': bathrooms,
        'rent_amount': rentAmount,
      };

  Unit copyWith({String? status}) => Unit(
        id: id,
        propertyId: propertyId,
        unitNumber: unitNumber,
        status: status ?? this.status,
        bedrooms: bedrooms,
        bathrooms: bathrooms,
        rentAmount: rentAmount,
      );

  static Unit mock(String propertyId, int index) => Unit(
        id: 'unit_$index',
        propertyId: propertyId,
        unitNumber: '${index + 1}0${index % 3 + 1}',
        status: index % 3 == 0 ? 'vacant' : 'occupied',
        bedrooms: (index % 3) + 1,
        bathrooms: 1.0 + (index % 2) * 0.5,
        rentAmount: 1200.0 + index * 150,
      );
}

class Property {
  const Property({
    required this.id,
    required this.name,
    required this.street,
    required this.city,
    required this.state,
    required this.zipCode,
    required this.propertyType,
    required this.totalUnits,
    required this.isActive,
    required this.photos,
    required this.amenities,
    required this.units,
    this.yearBuilt,
  });

  final String id;
  final String name;
  final String street;
  final String city;
  final String state;
  final String zipCode;
  final String propertyType;
  final int totalUnits;
  final bool isActive;
  final List<String> photos;
  final List<String> amenities;
  final List<Unit> units;
  final int? yearBuilt;

  String get address => '$street, $city, $state $zipCode';

  int get occupiedUnits => units.where((u) => u.status == 'occupied').length;

  double get occupancyRate =>
      totalUnits > 0 ? (occupiedUnits / totalUnits) * 100 : 0;

  factory Property.fromJson(Map<String, dynamic> json) => Property(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        street: json['street']?.toString() ?? '',
        city: json['city']?.toString() ?? '',
        state: json['state']?.toString() ?? '',
        zipCode: json['zip_code']?.toString() ?? '',
        propertyType: json['property_type']?.toString() ?? 'Residential',
        totalUnits: (json['total_units'] as num?)?.toInt() ?? 0,
        isActive: json['is_active'] as bool? ?? true,
        photos: List<String>.from(json['photos'] as List? ?? []),
        amenities: List<String>.from(json['amenities'] as List? ?? []),
        units: (json['units'] as List? ?? [])
            .map((u) => Unit.fromJson(u as Map<String, dynamic>))
            .toList(),
        yearBuilt: (json['year_built'] as num?)?.toInt(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'street': street,
        'city': city,
        'state': state,
        'zip_code': zipCode,
        'property_type': propertyType,
        'total_units': totalUnits,
        'is_active': isActive,
        'photos': photos,
        'amenities': amenities,
        'units': units.map((u) => u.toJson()).toList(),
        if (yearBuilt != null) 'year_built': yearBuilt,
      };

  static final List<Property> mockList = List.generate(6, (i) {
    final id = 'prop_$i';
    return Property(
      id: id,
      name: [
        'Greenwood Apartments',
        'Riverside Villas',
        'Oak Park Residences',
        'Sunset Court',
        'Maple Grove',
        'Lakeview Towers',
      ][i],
      street: '${100 + i * 10} Main St',
      city: ['Austin', 'Dallas', 'Houston', 'San Antonio', 'Plano', 'Irving'][i],
      state: 'TX',
      zipCode: '7870${i + 1}',
      propertyType: i % 2 == 0 ? 'Apartment' : 'Single Family',
      totalUnits: 8 + i * 2,
      isActive: i != 4,
      photos: [],
      amenities: ['Pool', 'Gym', 'Parking', 'Pet Friendly'].sublist(0, (i % 4) + 1),
      units: List.generate(4 + i, (j) => Unit.mock(id, j)),
      yearBuilt: 2000 + i * 3,
    );
  });
}
