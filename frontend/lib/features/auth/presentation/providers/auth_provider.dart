import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/repositories/auth_repository.dart';

enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

class AuthProvider extends ChangeNotifier {
  AuthProvider() : _repo = AuthRepository() {
    _init();
  }

  final AuthRepository _repo;
  StreamSubscription<AuthState>? _sub;

  AuthStatus _status = AuthStatus.initial;
  String? _errorMessage;
  User? _user;

  AuthStatus get status => _status;
  String? get errorMessage => _errorMessage;
  User? get user => _user;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  String get userEmail => _user?.email ?? '';

  void _init() {
    _user = _repo.currentUser;
    _status = _user != null
        ? AuthStatus.authenticated
        : AuthStatus.unauthenticated;

    _sub = _repo.authStateChanges.listen((state) {
      _user = state.session?.user;
      _status = _user != null
          ? AuthStatus.authenticated
          : AuthStatus.unauthenticated;
      notifyListeners();
    });
  }

  Future<bool> signIn({required String email, required String password}) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await _repo.signIn(email: email, password: password);
      _user = res.user;
      _status = _user != null
          ? AuthStatus.authenticated
          : AuthStatus.unauthenticated;
      notifyListeners();
      return _user != null;
    } on AuthException catch (e) {
      _status = AuthStatus.error;
      _errorMessage = e.message;
      notifyListeners();
      return false;
    } catch (e) {
      _status = AuthStatus.error;
      _errorMessage = 'Unexpected error. Please try again.';
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut() async {
    await _repo.signOut();
    _user = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
