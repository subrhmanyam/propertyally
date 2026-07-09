class UnitAgreement {
  const UnitAgreement({
    required this.id,
    required this.unitId,
    this.documentName,
    this.documentType,
    this.fileUrl,
    this.tenantName,
    this.tenantAddress,
    this.totalAreaSqft,
    this.coveredAreaSqft,
    this.openAreaSqft,
    this.monthlyRent,
    this.monthlyMaintenance,
    this.securityDeposit,
    this.profitSharing,
    this.maintenancePaidBy,
    this.furnishingStatus,
    this.carParkingCount,
    this.amenities = const [],
    this.leaseStartDate,
    this.leaseEndDate,
    this.noticePeriodDays,
    this.paymentDueDay,
    this.tenantGstin,
    this.ownerName,
    this.ownerAddress,
    this.ownerGstin,
    this.documentDate,
    this.isGstApplicable = false,
    this.cgstRate,
    this.sgstRate,
    this.specialClauses = const [],
    this.createdAt,
  });

  final String id;
  final String unitId;
  final String? documentName;
  final String? documentType;
  final String? fileUrl;
  final String? tenantName;
  final String? tenantAddress;
  final double? totalAreaSqft;
  final double? coveredAreaSqft;
  final double? openAreaSqft;
  final double? monthlyRent;
  final double? monthlyMaintenance;
  final double? securityDeposit;
  final String? profitSharing;
  final String? maintenancePaidBy;
  final String? furnishingStatus;
  final int? carParkingCount;
  final List<String> amenities;
  final DateTime? leaseStartDate;
  final DateTime? leaseEndDate;
  final int? noticePeriodDays;
  final int? paymentDueDay;
  final String? tenantGstin;
  final String? ownerName;
  final String? ownerAddress;
  final String? ownerGstin;
  final DateTime? documentDate;
  final bool isGstApplicable;
  final double? cgstRate;
  final double? sgstRate;
  final List<String> specialClauses;
  final DateTime? createdAt;

  String get furnishingLabel => switch (furnishingStatus) {
        'fully_furnished' => 'Fully Furnished',
        'semi_furnished' => 'Semi Furnished',
        'unfurnished' => 'Unfurnished',
        _ => '',
      };

  String get maintenancePaidByLabel => switch (maintenancePaidBy) {
        'owner' => 'Owner',
        'tenant' => 'Tenant',
        'shared' => 'Shared',
        _ => '',
      };

  factory UnitAgreement.fromJson(Map<String, dynamic> j) => UnitAgreement(
        id: j['id'] as String,
        unitId: j['unit_id'] as String,
        documentName: j['document_name'] as String?,
        documentType: j['document_type'] as String?,
        fileUrl: j['file_url'] as String?,
        tenantName: j['tenant_name'] as String?,
        tenantAddress: j['tenant_address'] as String?,
        totalAreaSqft: (j['total_area_sqft'] as num?)?.toDouble(),
        coveredAreaSqft: (j['covered_area_sqft'] as num?)?.toDouble(),
        openAreaSqft: (j['open_area_sqft'] as num?)?.toDouble(),
        monthlyRent: (j['monthly_rent'] as num?)?.toDouble(),
        monthlyMaintenance: (j['monthly_maintenance'] as num?)?.toDouble(),
        securityDeposit: (j['security_deposit'] as num?)?.toDouble(),
        profitSharing: j['profit_sharing'] as String?,
        maintenancePaidBy: j['maintenance_paid_by'] as String?,
        furnishingStatus: j['furnishing_status'] as String?,
        carParkingCount: j['car_parking_count'] as int?,
        amenities: (j['amenities'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        leaseStartDate: j['lease_start_date'] != null
            ? DateTime.tryParse(j['lease_start_date'] as String)
            : null,
        leaseEndDate: j['lease_end_date'] != null
            ? DateTime.tryParse(j['lease_end_date'] as String)
            : null,
        noticePeriodDays: j['notice_period_days'] as int?,
        paymentDueDay: j['payment_due_day'] as int?,
        tenantGstin: j['tenant_gstin'] as String?,
        ownerName: j['owner_name'] as String?,
        ownerAddress: j['owner_address'] as String?,
        ownerGstin: j['owner_gstin'] as String?,
        documentDate: j['document_date'] != null
            ? DateTime.tryParse(j['document_date'] as String)
            : null,
        isGstApplicable: j['is_gst_applicable'] as bool? ?? false,
        cgstRate: (j['cgst_rate'] as num?)?.toDouble(),
        sgstRate: (j['sgst_rate'] as num?)?.toDouble(),
        specialClauses: (j['special_clauses'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        createdAt: j['created_at'] != null
            ? DateTime.tryParse(j['created_at'] as String)
            : null,
      );
}
