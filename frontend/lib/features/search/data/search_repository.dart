import '../../../core/network/api_client.dart';

class SearchResult {
  const SearchResult({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.route,
  });

  final String id;
  final String type;
  final String title;
  final String subtitle;
  final String status;
  final String route;

  factory SearchResult.fromJson(Map<String, dynamic> j) => SearchResult(
        id: j['id'] as String,
        type: j['type'] as String,
        title: j['title'] as String,
        subtitle: j['subtitle'] as String? ?? '',
        status: j['status'] as String? ?? '',
        route: j['route'] as String,
      );
}

class SearchRepository {
  Future<List<SearchResult>> search(String query) async {
    if (query.trim().isEmpty) return [];
    final res = await ApiClient.instance.get(
      '/api/v1/search/',
      queryParameters: {'q': query.trim()},
    );
    final data = res.data as Map<String, dynamic>;
    final results = <SearchResult>[];
    for (final key in ['properties', 'tenants', 'maintenance']) {
      final list = data[key] as List? ?? [];
      results.addAll(list.map((e) => SearchResult.fromJson(e as Map<String, dynamic>)));
    }
    return results;
  }
}
