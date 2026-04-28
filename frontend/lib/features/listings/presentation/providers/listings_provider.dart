import '../../../../core/base/base_provider.dart';
import '../../data/repositories/listings_repository.dart';
import '../../domain/entities/listing.dart';

class ListingsProvider extends BaseProvider {
  ListingsProvider() : _repo = ListingsRepository();

  final ListingsRepository _repo;

  List<Listing> _listings = [];
  Map<String, List<PlatformPost>> _platformPosts = {};

  List<Listing> get listings => _listings;

  List<PlatformPost> postsFor(String listingId) =>
      _platformPosts[listingId] ?? [];

  Future<void> load() async {
    await runAsync(() async {
      _listings = await _repo.getAll();
      return _listings;
    });
  }

  Future<void> loadPlatformPosts(String listingId) async {
    await runAsync(() async {
      final posts = await _repo.getPlatformPosts(listingId);
      _platformPosts = {..._platformPosts, listingId: posts};
      return posts;
    });
  }

  Future<List<Map<String, dynamic>>> getPlatformsForUnit(String unitId) async {
    return await _repo.getPlatformsForUnit(unitId);
  }

  Future<void> triggerAgent(String unitId, List<String> platformKeys) async {
    await runAsync(() => _repo.triggerAgent(unitId, platformKeys));
    await load();
  }

  Future<void> retryPost(String postId, String listingId) async {
    await runAsync(() => _repo.retryPost(postId));
    await loadPlatformPosts(listingId);
  }
}
