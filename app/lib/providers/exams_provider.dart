import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_exception.dart';
import '../core/exams_cache.dart';
import '../models/exam.dart';
import 'api_provider.dart';
import 'auth_provider.dart';

final examsCacheProvider = Provider<ExamsCache>((ref) => ExamsCache());

class ExamsView {
  final ExamsSchedule schedule;
  final DateTime? capturedAt;

  const ExamsView({required this.schedule, this.capturedAt});
}

final examsProvider = FutureProvider.autoDispose<ExamsView>((ref) async {
  final auth = ref.watch(authProvider);
  final cache = ref.watch(examsCacheProvider);

  if (auth.status == AuthStatus.unauthenticated) {
    throw ApiException('no_session', statusCode: 401);
  }
  if (!auth.isAuthenticated) {
    final cached = await cache.read();
    if (cached != null) return ExamsView(schedule: cached.exams, capturedAt: cached.capturedAt);
    return Completer<ExamsView>().future;
  }

  try {
    final exams = await ref.watch(apiClientProvider).getUpcomingExams();
    await cache.save(exams);
    return ExamsView(schedule: exams);
  } on ApiException catch (error) {
    if (!error.isConnectivityProblem) rethrow;

    final cached = await cache.read();
    if (cached == null) rethrow;
    return ExamsView(schedule: cached.exams, capturedAt: cached.capturedAt);
  }
});

final examsCachePeekProvider = FutureProvider.autoDispose<CachedExams?>((ref) {
  return ref.watch(examsCacheProvider).read();
});
