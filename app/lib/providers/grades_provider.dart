import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_exception.dart';
import '../core/grades_cache.dart';
import '../models/grades.dart';
import 'api_provider.dart';
import 'auth_provider.dart';

final selectedAuProvider = StateProvider<String?>((ref) => null);

final selectedSsProvider = StateProvider<String?>((ref) => null);

final gradesCacheProvider = Provider<GradesCache>((ref) => GradesCache());

String _cacheKey(String? code) => code ?? '_default';

final gradesProvider = FutureProvider.autoDispose<Grades>((ref) {
  return _loadGrades(ref, ref.watch(selectedAuProvider), ref.watch(selectedSsProvider));
});

/// The current year's principal-session relevé, independent of the Notes
/// screen's year/session picks. The Plan d'études reads its modules from it.
final currentYearGradesProvider = FutureProvider.autoDispose<Grades>((ref) {
  return _loadGrades(ref, null, null);
});

Future<Grades> _loadGrades(Ref ref, String? au, String? ss) async {
  final auth = ref.watch(authProvider);
  final cache = ref.watch(gradesCacheProvider);
  final cacheAu = _cacheKey(au);
  final cacheSs = _cacheKey(ss);

  if (auth.status == AuthStatus.unauthenticated) {
    throw ApiException('no_session', statusCode: 401);
  }
  if (!auth.isAuthenticated) {
    final cached = await cache.read(cacheAu, cacheSs);
    if (cached != null) return cached.grades;
    return Completer<Grades>().future;
  }

  try {
    final grades = await ref.watch(apiClientProvider).getGrades(au: au, ss: ss);
    await cache.save(cacheAu, cacheSs, grades);
    return grades;
  } on ApiException catch (error) {
    if (!error.isConnectivityProblem) rethrow;

    final cached = await cache.read(cacheAu, cacheSs);
    if (cached == null) rethrow;

    return cached.grades;
  }
}

final gradesCachePeekProvider = FutureProvider.autoDispose<CachedGrades?>((ref) {
  final cache = ref.watch(gradesCacheProvider);
  return cache.read(_cacheKey(ref.watch(selectedAuProvider)), _cacheKey(ref.watch(selectedSsProvider)));
});

String? effectiveCode(String? userPick, String? currentFromServer, List<SelectOption> options) {
  final code = userPick ?? currentFromServer;

  if (code != null && options.any((o) => o.code == code)) return code;
  return options.isNotEmpty ? options.first.code : null;
}
