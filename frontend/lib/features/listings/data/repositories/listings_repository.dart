import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/network/api_client.dart';
import '../../domain/entities/listing.dart';

class ListingsRepository {
  final Dio _dio = ApiClient.instance;
  SupabaseClient get _db => Supabase.instance.client;

  Future<List<Listing>> getAll() async {
    try {
      final rows = await _db
          .from('listings')
          .select('*')
          .order('created_at', ascending: false);
      return rows.map((r) => Listing.fromJson(r)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<PlatformPost>> getPlatformPosts(String listingId) async {
    try {
      final rows = await _db
          .from('listing_platform_posts')
          .select('*')
          .eq('listing_id', listingId)
          .order('created_at');
      return rows.map((r) {
        r['platform_name'] = _platformName(r['platform_key']?.toString() ?? '');
        return PlatformPost.fromJson(r);
      }).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getPlatforms() async {
    final resp = await _dio.get('/api/v1/listing-agent/platforms');
    return List<Map<String, dynamic>>.from(resp.data as List);
  }

  Future<List<Map<String, dynamic>>> getPlatformsForUnit(String unitId) async {
    final resp = await _dio.get('/api/v1/listing-agent/platforms/$unitId');
    return List<Map<String, dynamic>>.from(resp.data as List);
  }

  Future<void> triggerAgent(String unitId, List<String> platformKeys) async {
    await _dio.post(
      '/api/v1/listing-agent/trigger/$unitId',
      data: {'platform_keys': platformKeys},
    );
  }

  Future<void> retryPost(String postId) async {
    await _dio.post('/api/v1/listing-agent/retry/$postId');
  }

  String _platformName(String key) => switch (key) {
        'housing_com' => 'Housing.com',
        '99acres' => '99acres.com',
        'magicbricks' => 'MagicBricks',
        'nobroker' => 'NoBroker',
        _ => key,
      };
}
