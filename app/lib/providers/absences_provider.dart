import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/absences_cache.dart';
import '../core/api_exception.dart';
import '../models/absences.dart';
import 'api_provider.dart';
import 'auth_provider.dart';

final absencesCacheProvider = Provider<AbsencesCache>((ref) => AbsencesCache());

class AbsencesView {
  final Absences absences;
  final DateTime? capturedAt;

  const AbsencesView({required this.absences, this.capturedAt});
}

final absencesProvider = FutureProvider.autoDispose<AbsencesView>((ref) async {
  final auth = ref.watch(authProvider);
  final cache = ref.watch(absencesCacheProvider);

  if (auth.status == AuthStatus.unauthenticated) {
    throw ApiException('no_session', statusCode: 401);
  }
  if (!auth.isAuthenticated) {
    final cached = await cache.read();
    if (cached != null) {
      return AbsencesView(absences: cached.absences, capturedAt: cached.capturedAt);
    }
    return Completer<AbsencesView>().future;
  }

  try {
    final absences = await ref.watch(apiClientProvider).getAbsences();
    await cache.save(absences);
    return AbsencesView(absences: absences);
  } on ApiException catch (error) {
    if (!error.isConnectivityProblem) rethrow;

    final cached = await cache.read();
    if (cached == null) rethrow;
    return AbsencesView(absences: cached.absences, capturedAt: cached.capturedAt);
  }
});

final absencesCachePeekProvider = FutureProvider.autoDispose<CachedAbsences?>((ref) {
  return ref.watch(absencesCacheProvider).read();
});
