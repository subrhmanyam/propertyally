import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/tenant.dart';

class TenantRepository {
  TenantRepository();

  SupabaseClient get _db => Supabase.instance.client;

  Future<List<Tenant>> listTenants({String? propertyId}) async {
    try {
      var q = _db.from('tenants').select('*');
      if (propertyId != null) {
        q = q.eq('leasing_unit_id', propertyId);
      }
      final rows = await q.order('created_at', ascending: false);
      return rows.map((e) => Tenant.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<Tenant> getTenant(String id) async {
    final row = await _db.from('tenants').select('*').eq('id', id).single();
    return Tenant.fromJson(row);
  }

  Future<Tenant> createTenant(Map<String, dynamic> data) async {
    // Remove empty strings so optional columns stay null
    final payload = Map<String, dynamic>.fromEntries(
      data.entries.where((e) => e.value != null && e.value != ''),
    );
    final row =
        await _db.from('tenants').insert(payload).select().single();
    return Tenant.fromJson(row);
  }

  Future<void> updateTenant(String id, Map<String, dynamic> data) async {
    final payload = Map<String, dynamic>.fromEntries(
      data.entries.where((e) => e.value != null && e.value != ''),
    );
    await _db.from('tenants').update(payload).eq('id', id);
  }

  Future<void> deleteTenant(String id) async {
    await _db.from('tenants').delete().eq('id', id);
  }

  Future<Lease?> getTenantLease(String tenantId) async {
    try {
      final rows = await _db
          .from('leases')
          .select('*')
          .eq('tenant_id', tenantId)
          .order('created_at', ascending: false)
          .limit(1);
      if (rows.isEmpty) return null;
      return Lease.fromJson(rows.first);
    } catch (_) {
      return null;
    }
  }
}
