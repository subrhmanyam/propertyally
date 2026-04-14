/// Area breakdown within a single leasing unit (covered / open / common).
class AreaEntry {
  const AreaEntry({
    required this.type,
    required this.sqft,
    required this.rate,
  });

  /// 'covered' | 'open' | 'common'
  final String type;
  final double sqft;

  /// Rent rate per sq.ft (₹)
  final double rate;

  double get rent => sqft * rate;

  String get typeLabel => switch (type) {
        'covered' => 'Covered Area',
        'open' => 'Open Area',
        'common' => 'Common Area',
        _ => type,
      };

  AreaEntry copyWith({String? type, double? sqft, double? rate}) => AreaEntry(
        type: type ?? this.type,
        sqft: sqft ?? this.sqft,
        rate: rate ?? this.rate,
      );

  factory AreaEntry.fromJson(Map<String, dynamic> json) => AreaEntry(
        type: json['type']?.toString() ?? 'covered',
        sqft: (json['sqft'] as num?)?.toDouble() ?? 0,
        rate: (json['rate'] as num?)?.toDouble() ?? 0,
      );

  Map<String, dynamic> toJson() => {'type': type, 'sqft': sqft, 'rate': rate};
}

/// A single leasing unit in the Bogineni complex.
class LeasingUnit {
  const LeasingUnit({
    required this.id,
    required this.name,
    required this.category,
    required this.floor,
    required this.status,
    required this.areas,
    this.contact,
    this.email,
    this.notes,
  });

  final String id;
  final String name;

  /// Restaurant | Brewery | Cafe & Restaurant | Office | Residence |
  /// Shop | Event/Party | Studio Room | Co-working | Parking
  final String category;

  /// Ground Floor | First Floor | Second Floor | Outdoor
  final String floor;

  /// occupied | vacant | in_house | owner_occupied
  final String status;

  final List<AreaEntry> areas;
  final String? contact;
  final String? email;
  final String? notes;

  double get totalRent => areas.fold(0.0, (s, a) => s + a.rent);
  double get totalSqft => areas.fold(0.0, (s, a) => s + a.sqft);

  String get statusLabel => switch (status) {
        'occupied' => 'Occupied',
        'vacant' => 'Vacant',
        'in_house' => 'In-house',
        'owner_occupied' => 'Owner-occupied',
        _ => status,
      };

  LeasingUnit copyWith({
    String? name,
    String? category,
    String? floor,
    String? status,
    List<AreaEntry>? areas,
    String? contact,
    String? email,
    String? notes,
  }) =>
      LeasingUnit(
        id: id,
        name: name ?? this.name,
        category: category ?? this.category,
        floor: floor ?? this.floor,
        status: status ?? this.status,
        areas: areas ?? this.areas,
        contact: contact ?? this.contact,
        email: email ?? this.email,
        notes: notes ?? this.notes,
      );

  factory LeasingUnit.fromJson(Map<String, dynamic> json) => LeasingUnit(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        category: json['category']?.toString() ?? '',
        floor: json['floor']?.toString() ?? 'Ground Floor',
        status: json['status']?.toString() ?? 'vacant',
        contact: json['contact']?.toString(),
        email: json['email']?.toString(),
        notes: json['notes']?.toString(),
        areas: (json['area_entries'] as List<dynamic>? ?? [])
            .map((e) => AreaEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category,
        'floor': floor,
        'status': status,
        if (contact != null) 'contact': contact,
        if (email != null) 'email': email,
        if (notes != null) 'notes': notes,
      };

  // ── Actual Bogineni leasing data (from BOGINENI LEASING AREA STATEMENT) ──

  static const List<String> categories = [
    'Restaurant',
    'Brewery',
    'Cafe & Restaurant',
    'Office',
    'Residence',
    'Shop',
    'Event/Party',
    'Studio Room',
    'Co-working',
    'Parking',
    'Other',
  ];

  static const List<String> floors = [
    'Ground Floor',
    'First Floor',
    'Second Floor',
    'Outdoor',
  ];

  static const List<String> statuses = [
    'occupied',
    'vacant',
    'in_house',
    'owner_occupied',
  ];

  static final List<LeasingUnit> mockList = [
    LeasingUnit(
      id: 'lu_1',
      name: 'Nandhini Restaurant',
      category: 'Restaurant',
      floor: 'Ground Floor & First Floor',
      status: 'occupied',
      areas: const [
        AreaEntry(type: 'covered', sqft: 2624, rate: 150), // GF covered → ₹393,600
        AreaEntry(type: 'open', sqft: 750, rate: 0),       // GF open (rate TBD)
        AreaEntry(type: 'covered', sqft: 3284, rate: 100), // FF covered → ₹328,400
        AreaEntry(type: 'open', sqft: 400, rate: 50),      // FF open → ₹20,000
      ],
    ),
    LeasingUnit(
      id: 'lu_2',
      name: 'Pump House',
      category: 'Brewery',
      floor: 'Ground Floor & First Floor',
      status: 'occupied',
      areas: const [
        AreaEntry(type: 'covered', sqft: 4172, rate: 75),   // GF covered → ₹312,900
        AreaEntry(type: 'covered', sqft: 3473, rate: 100),  // FF covered → ₹347,300
        AreaEntry(type: 'open', sqft: 11963, rate: 50),     // Outdoor → ₹598,150
        AreaEntry(type: 'common', sqft: 2096, rate: 0),     // Common area
      ],
    ),
    LeasingUnit(
      id: 'lu_3',
      name: 'Bogineni Coffee',
      category: 'Cafe & Restaurant',
      floor: 'Ground Floor',
      status: 'in_house',
      areas: const [
        AreaEntry(type: 'covered', sqft: 931, rate: 150), // ₹139,650
        AreaEntry(type: 'open', sqft: 255, rate: 50),     // ₹12,750
      ],
    ),
    LeasingUnit(
      id: 'lu_4',
      name: 'Bogineni Office',
      category: 'Office',
      floor: 'First Floor',
      status: 'in_house',
      areas: const [
        AreaEntry(type: 'covered', sqft: 931, rate: 100), // ₹93,100
        AreaEntry(type: 'open', sqft: 141, rate: 50),     // ₹7,050
      ],
    ),
    LeasingUnit(
      id: 'lu_5',
      name: 'Bogineni Home',
      category: 'Residence',
      floor: 'Second Floor',
      status: 'owner_occupied',
      areas: const [
        AreaEntry(type: 'covered', sqft: 931, rate: 75), // ₹69,825
        AreaEntry(type: 'open', sqft: 141, rate: 50),    // ₹7,050
      ],
    ),
    LeasingUnit(
      id: 'lu_6',
      name: 'Fashion Showroom',
      category: 'Shop',
      floor: 'Ground Floor',
      status: 'vacant',
      notes: 'Indoor: 20×31 ft, Outdoor: 10×20 ft',
      areas: const [
        AreaEntry(type: 'covered', sqft: 559.5, rate: 150), // ₹83,925
        AreaEntry(type: 'open', sqft: 126, rate: 50),       // ₹6,300
      ],
    ),
    LeasingUnit(
      id: 'lu_7',
      name: 'Bogineni Lifestyle Store',
      category: 'Shop',
      floor: 'Ground Floor',
      status: 'vacant',
      areas: const [
        AreaEntry(type: 'covered', sqft: 924, rate: 150), // ₹138,600
      ],
    ),
    LeasingUnit(
      id: 'lu_8',
      name: 'B Private',
      category: 'Event/Party',
      floor: 'Outdoor',
      status: 'vacant',
      areas: const [
        AreaEntry(type: 'open', sqft: 4074, rate: 50), // ₹203,700
      ],
    ),
    LeasingUnit(
      id: 'lu_9',
      name: 'Penthouse',
      category: 'Studio Room',
      floor: 'Second Floor',
      status: 'occupied',
      areas: const [
        AreaEntry(type: 'covered', sqft: 1075, rate: 75), // ₹80,625
      ],
    ),
    LeasingUnit(
      id: 'lu_10',
      name: 'Co-Work',
      category: 'Co-working',
      floor: 'First Floor',
      status: 'owner_occupied',
      areas: const [
        AreaEntry(type: 'covered', sqft: 253, rate: 150), // ₹37,950
      ],
    ),
    LeasingUnit(
      id: 'lu_11',
      name: 'Car Parking Area',
      category: 'Parking',
      floor: 'Ground Floor',
      status: 'occupied',
      notes: '70 parking spaces',
      areas: const [
        AreaEntry(type: 'open', sqft: 70, rate: 50), // ₹3,500 (70 spaces × ₹50)
      ],
    ),
  ];
}

// Draft classes (LeasingUnitDraft, AreaEntryDraft) live in
// presentation/widgets/leasing_form_dialog.dart to keep Flutter
// dependencies out of the domain layer.
