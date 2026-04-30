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
  String _userRole = 'admin';

  AuthStatus get status => _status;
  String? get errorMessage => _errorMessage;
  User? get user => _user;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  String get userEmail => _user?.email ?? '';
  String get userRole => _userRole;
  bool get isTenant => _userRole == 'tenant';

  void _init() {
    _user = _repo.currentUser;
    if (_user != null) {
      _status = AuthStatus.authenticated;
      _userRole = _repo.userRole;
      // Fallback: fetch from backend if JWT hook not enabled
      if (_userRole == 'admin') _fetchRoleFromBackend(_user!.id);
    } else {
      _status = AuthStatus.unauthenticated;
    }

    _sub = _repo.authStateChanges.listen((state) {
      _user = state.session?.user;
      if (_user != null) {
        _status = AuthStatus.authenticated;
        _userRole = _repo.userRole;
        if (_userRole == 'admin') _fetchRoleFromBackend(_user!.id);
      } else {
        _status = AuthStatus.unauthenticated;
        _userRole = 'admin';
      }
      notifyListeners();
    });
  }

  Future<void> _fetchRoleFromBackend(String userId) async {
    final role = await _repo.fetchRole(userId);
    if (role != _userRole) {
      _userRole = role;
      notifyListeners();
    }
  }

  Future<bool> signIn({required String email, required String password}) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await _repo.signIn(email: email, password: password);
      _user = res.user;
      if (_user != null) {
        _status = AuthStatus.authenticated;
        _userRole = _repo.userRole;
        if (_userRole == 'admin') await _fetchRoleFromBackend(_user!.id);
      } else {
        _status = AuthStatus.unauthenticated;
      }
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

  Future<bool> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String role,
  }) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repo.register(
        email: email,
        password: password,
        firstName: firstName,
        lastName: lastName,
        role: role,
      );
      // Sign in immediately after registration
      return await signIn(email: email, password: password);
    } catch (e) {
      _status = AuthStatus.error;
      _errorMessage = e.toString().replaceAll('DioException', '').trim();
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut() async {
    await _repo.signOut();
    _user = null;
    _userRole = 'admin';
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
