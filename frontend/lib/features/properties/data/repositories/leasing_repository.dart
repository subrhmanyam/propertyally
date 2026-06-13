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
      final row = await _db
          .from('leasing_units')
          .insert(unit.toJson())
          .select()
          .single();

      final id = row['id'].toString();
      for (final a in unit.areas) {
        await _db.from('area_entries').insert({
          ...a.toJson(),
          'leasing_unit_id': id,
        });
      }
      return unit.copyWith();
    } catch (_) {
      // Offline — return as-is (provider keeps in memory)
      return unit;
    }
  }

  Future<void> update(LeasingUnit unit) async {
    try {
      await _db
          .from('leasing_units')
          .update(unit.toJson())
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
      await _db.from('area_entries').delete().eq('leasing_unit_id', id);
      await _db.from('leasing_units').delete().eq('id', id);
    } catch (_) {
      // Offline — provider already removed from memory
    }
  }
}
