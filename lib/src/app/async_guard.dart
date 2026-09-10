import 'package:flutter/foundation.dart';

/// Owns "is something in flight" state plus the last error string. One
/// instance is shared by every controller so the busy/error plumbing is
/// defined exactly once (was `AppController._runBusy`).
class AsyncGuard extends ChangeNotifier {
  int _depth = 0;
  bool _isBusy = false;
  String? _errorMessage;

  bool get isBusy => _isBusy;
  String? get errorMessage => _errorMessage;

  /// Reentrant busy scope. First entrant flips [isBusy] true and clears the
  /// error; the last to leave flips it back. A throw is captured into
  /// [errorMessage] and swallowed (matches the pre-split `_runBusy`).
  Future<void> run(Future<void> Function() action) async {
    final wasIdle = _depth == 0;
    _depth++;
    if (wasIdle) {
      _isBusy = true;
      _errorMessage = null;
      notifyListeners();
    }
    try {
      await action();
    } catch (error) {
      _errorMessage = error.toString();
    } finally {
      _depth--;
      if (_depth < 0) _depth = 0;
      if (_depth == 0) {
        _isBusy = false;
        notifyListeners();
      }
    }
  }

  void reportError(Object error) {
    _errorMessage = error.toString();
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
