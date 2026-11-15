import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

class ConnectionWatch extends ChangeNotifier {
  ConnectionWatch() {
    _init();
  }

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _disposed = false;

  bool _online = false;
  bool get online => _online;

  Future<void> _init() async {
    try {
      final results = await _connectivity.checkConnectivity();
      _apply(results);
    } catch (_) {
      if (!_disposed) {
        _online = true;
      }
    }
    _subscription = _connectivity.onConnectivityChanged.listen(_apply);
  }

  void _apply(List<ConnectivityResult> results) {
    if (_disposed) return;
    final online =
        results.isNotEmpty && !results.every((r) => r == ConnectivityResult.none);
    if (online == _online) return;
    _online = online;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _subscription?.cancel();
    super.dispose();
  }
}