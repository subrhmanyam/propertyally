class PlatformPost {
  const PlatformPost({
    required this.id,
    required this.listingId,
    required this.platformKey,
    required this.platformName,
    required this.status,
    this.externalId,
    this.externalUrl,
    this.platformTitle,
    this.platformDesc,
    this.errorMessage,
    this.postedAt,
  });

  final String id;
  final String listingId;
  final String platformKey;
  final String platformName;

  /// pending | posting | posted | failed | manual_required
  final String status;

  final String? externalId;
  final String? externalUrl;
  final String? platformTitle;
  final String? platformDesc;
  final String? errorMessage;
  final DateTime? postedAt;

  factory PlatformPost.fromJson(Map<String, dynamic> json) => PlatformPost(
        id: json['id']?.toString() ?? '',
        listingId: json['listing_id']?.toString() ?? '',
        platformKey: json['platform_key']?.toString() ?? '',
        platformName: json['platform_name']?.toString() ?? json['platform_key']?.toString() ?? '',
        status: json['status']?.toString() ?? 'pending',
        externalId: json['external_id']?.toString(),
        externalUrl: json['external_url']?.toString(),
        platformTitle: json['platform_title']?.toString(),
        platformDesc: json['platform_desc']?.toString(),
        errorMessage: json['error_message']?.toString(),
        postedAt: json['posted_at'] != null
            ? DateTime.tryParse(json['posted_at'].toString())
            : null,
      );
}

class Listing {
  const Listing({
    required this.id,
    required this.leasingUnitId,
    required this.title,
    required this.monthlyRent,
    required this.isPublished,
    this.description,
    this.availableFrom,
    this.contactEmail,
    this.contactPhone,
    this.photos = const [],
    this.videoUrls = const [],
    this.virtualTourUrl,
    this.features = const [],
    this.platformPosts = const [],
    this.createdAt,
  });

  final String id;
  final String leasingUnitId;
  final String title;
  final double monthlyRent;
  final bool isPublished;
  final String? description;
  final DateTime? availableFrom;
  final String? contactEmail;
  final String? contactPhone;
  final List<String> photos;
  final List<String> videoUrls;
  final String? virtualTourUrl;
  final List<String> features;
  final List<PlatformPost> platformPosts;
  final DateTime? createdAt;

  int get postedCount => platformPosts.where((p) => p.status == 'posted').length;
  int get manualCount => platformPosts.where((p) => p.status == 'manual_required').length;
  int get failedCount => platformPosts.where((p) => p.status == 'failed').length;
  int get pendingCount =>
      platformPosts.where((p) => p.status == 'pending' || p.status == 'posting').length;

  factory Listing.fromJson(Map<String, dynamic> json) => Listing(
        id: json['id']?.toString() ?? '',
        leasingUnitId: json['leasing_unit_id']?.toString() ?? '',
        title: json['title']?.toString() ?? '',
        monthlyRent: (json['monthly_rent'] as num?)?.toDouble() ?? 0,
        isPublished: json['is_published'] as bool? ?? false,
        description: json['description']?.toString(),
        availableFrom: json['available_from'] != null
            ? DateTime.tryParse(json['available_from'].toString())
            : null,
        contactEmail: json['contact_email']?.toString(),
        contactPhone: json['contact_phone']?.toString(),
        photos: List<String>.from(json['photos'] as List? ?? []),
        videoUrls: List<String>.from(json['video_urls'] as List? ?? []),
        virtualTourUrl: json['virtual_tour_url']?.toString(),
        features: List<String>.from(json['features'] as List? ?? []),
        createdAt: json['created_at'] != null
            ? DateTime.tryParse(json['created_at'].toString())
            : null,
      );
}
