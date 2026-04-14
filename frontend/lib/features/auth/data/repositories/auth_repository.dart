import 'package:supabase_flutter/supabase_flutter.dart';

class AuthRepository {
  SupabaseClient get _client => Supabase.instance.client;

  User? get currentUser => _client.auth.currentUser;
  bool get isSignedIn => currentUser != null;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) =>
      _client.auth.signInWithPassword(email: email, password: password);

  Future<void> signOut() => _client.auth.signOut();

  Future<AuthResponse> signUp({
    required String email,
    required String password,
  }) =>
      _client.auth.signUp(email: email, password: password);
}
