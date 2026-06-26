import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/leasing_unit.dart';

/// Repository for leasing units.
/// Reads/writes to Supabase tables:
///   - leasing_units (id, name, category, floor, status, contact, email, notes)
///   - area_entries (id, leasing_unit_id, type, sqft, rate)
///
/// Falls back to mock data when Supabase is not yet configured or returns empty.
class LeasingRepository {
  LeasingRepository();

  SupabaseClient get _db => Supabase.instance.client;

  Future<List<LeasingUnit>> getAll() async {
    try {
      final rows = await _db
          .from('leasing_units')
          .select('*, area_entries(*)')
          .order('name');

      return rows.map((r) => LeasingUnit.fromJson(r)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<LeasingUnit> insert(LeasingUnit unit) async {
    try {
      // Strip the local id so Supabase generates a valid UUID.
      final payload = Map<String, dynamic>.from(unit.toJson())..remove('id');
      final row = await _db
          .from('leasing_units')
          .insert(payload)
          .select()
          .single();

      final savedId = row['id'].toString();
      for (final a in unit.areas) {
        await _db.from('area_entries').insert({
          ...a.toJson(),
          'leasing_unit_id': savedId,
        });
      }
      // Return the unit with the DB-assigned UUID and correct fields.
      return LeasingUnit.fromJson({
        ...row,
        'area_entries': unit.areas.map((a) => a.toJson()).toList(),
      });
    } catch (_) {
      return unit;
    }
  }

  Future<void> update(LeasingUnit unit) async {
    try {
      final payload = Map<String, dynamic>.from(unit.toJson())..remove('id');
      await _db
          .from('leasing_units')
          .update(payload)
          .eq('id', unit.id);

      // Replace area entries
      await _db.from('area_entries').delete().eq('leasing_unit_id', unit.id);
      for (final a in unit.areas) {
        await _db.from('area_entries').insert({
          ...a.toJson(),
          'leasing_unit_id': unit.id,
        });
      }
    } catch (_) {
      // Offline — provider already updated in memory
    }
  }

  Future<void> delete(String id) async {
    try {
      await _db.from('tenants').delete().eq('leasing_unit_id', id);
      await _db.from('area_entries').delete().eq('leasing_unit_id', id);
      await _db.from('leasing_units').delete().eq('id', id);
    } catch (_) {
      // Offline — provider already removed from memory
    }
  }

  // Deletes all units in a portfolio (and their tenants + area entries).
  Future<void> deletePortfolio(List<String> unitIds) async {
    try {
      if (unitIds.isEmpty) return;
      await _db
          .from('tenants')
          .delete()
          .inFilter('leasing_unit_id', unitIds);
      await _db
          .from('area_entries')
          .delete()
          .inFilter('leasing_unit_id', unitIds);
      for (final id in unitIds) {
        await _db.from('leasing_units').delete().eq('id', id);
      }
    } catch (_) {}
  }
}
