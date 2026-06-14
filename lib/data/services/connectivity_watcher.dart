import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

/// Lightweight connectivity signal for sync orchestration.
class ConnectivityWatcher {
  ConnectivityWatcher() {
    _subscription = Connectivity().onConnectivityChanged.listen(_emit);
  }

  final _controller = StreamController<List<ConnectivityResult>>.broadcast();
  Stream<List<ConnectivityResult>> get stream => _controller.stream;

  StreamSubscription<List<ConnectivityResult>>? _subscription;

  void _emit(List<ConnectivityResult> r) => _controller.add(r);

  Future<void> dispose() async {
    await _subscription?.cancel();
    await _controller.close();
  }
}
