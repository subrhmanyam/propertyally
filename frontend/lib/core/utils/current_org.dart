import 'package:supabase_flutter/supabase_flutter.dart';

/// Resolves the org the signed-in user belongs to, via `organization_members`.
///
/// Returns null if the user has no membership row, or if the schema itself
/// isn't there yet (e.g. the 004_organizations.sql migration hasn't been run) —
/// callers should treat a null org as "skip, don't block the caller's flow".
Future<String?> getCurrentOrgId() async {
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) return null;
  try {
    final row = await Supabase.instance.client
        .from('organization_members')
        .select('org_id')
        .eq('user_id', userId)
        .limit(1)
        .maybeSingle();
    return row?['org_id']?.toString();
  } catch (_) {
    return null;
  }
}
