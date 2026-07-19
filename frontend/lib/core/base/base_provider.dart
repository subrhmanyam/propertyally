import 'package:flutter/foundation.dart';

abstract class BaseProvider extends ChangeNotifier {
  bool _isLoading = false;
  String? _errorMessage;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasError => _errorMessage != null;

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  Future<T?> runAsync<T>(Future<T> Function() action) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final result = await action();
      _isLoading = false;
      notifyListeners();
      return result;
    } catch (e, st) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      debugPrint('[$runtimeType] runAsync error: $e');
      debugPrintStack(stackTrace: st);
      return null;
    }
  }
}
