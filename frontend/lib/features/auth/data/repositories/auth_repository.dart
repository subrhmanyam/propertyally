import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthRepository {
  static const _base = 'http://localhost:8000';

  SupabaseClient get _client => Supabase.instance.client;
  Dio get _dio => Dio(BaseOptions(baseUrl: _base));

  User? get currentUser => _client.auth.currentUser;
  bool get isSignedIn => currentUser != null;
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) =>
      _client.auth.signInWithPassword(email: email, password: password);

  Future<void> signOut() => _client.auth.signOut();

  /// Register a new user via the backend (which uses service-role key to set role correctly).
  Future<void> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String role,
  }) async {
    await _dio.post('/api/v1/auth/register', data: {
      'email': email,
      'password': password,
      'first_name': firstName,
      'last_name': lastName,
      'role': role,
    });
  }

  /// Parse the role from the current session JWT app_metadata.
  String get userRole {
    final session = _client.auth.currentSession;
    if (session == null) return 'admin';
    try {
      final parts = session.accessToken.split('.');
      if (parts.length < 2) return 'admin';
      final payload = base64Url.normalize(parts[1]);
      final data = json.decode(utf8.decode(base64Url.decode(payload))) as Map<String, dynamic>;
      return (data['app_metadata'] as Map?)?['role'] as String? ?? 'admin';
    } catch (_) {
      return 'admin';
    }
  }

  /// Fallback: fetch role from backend profile endpoint (when JWT hook not yet enabled).
  Future<String> fetchRole(String userId) async {
    try {
      final res = await _dio.get('/api/v1/auth/profile', queryParameters: {'user_id': userId});
      return (res.data as Map?)?['role'] as String? ?? 'admin';
    } catch (_) {
      return 'admin';
    }
  }
}
