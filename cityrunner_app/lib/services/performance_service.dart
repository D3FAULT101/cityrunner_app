import 'package:firebase_performance/firebase_performance.dart';

import 'firebase_bootstrap.dart';

class PerformanceService {
  PerformanceService._();

  static final instance = PerformanceService._();

  Future<T> trace<T>(String name, Future<T> Function() action) async {
    if (!FirebaseBootstrap.isReady) return action();
    final trace = FirebasePerformance.instance.newTrace(name);
    await trace.start();
    try {
      return await action();
    } finally {
      await trace.stop();
    }
  }
}
