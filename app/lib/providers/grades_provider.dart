import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_exception.dart';
import '../core/grades_cache.dart';
import '../models/grades.dart';
import 'api_provider.dart';
import 'auth_provider.dart';

/// Année universitaire code (the site's <select name="f_au"> value).
/// `null` means "let the server pick its current année" — which is the most
/// recent one holding real data, so it's the default on first load.
final selectedAuProvider = StateProvider<String?>((ref) => null);

/// Session code: 1 = Principale, 2 = Contrôle. `null` follows the server.
final selectedSsProvider = StateProvider<String?>((ref) => null);

final gradesCacheProvider = Provider<GradesCache>((ref) => GradesCache());

/// Cache key mirrors exactly what is requested, `null` included, so a default
/// load always lands on the same slot regardless of what the server resolves
/// it to — the response's resolved codes are not known until after the fetch.
String _cacheKey(String? code) => code ?? '_default';

final gradesProvider = FutureProvider.autoDispose<Grades>((ref) async {
  final auth = ref.watch(authProvider);
  final au = ref.watch(selectedAuProvider);
  final ss = ref.watch(selectedSsProvider);

  final cache = ref.watch(gradesCacheProvider);
  final cacheAu = _cacheKey(au);
  final cacheSs = _cacheKey(ss);

  if (auth.status == AuthStatus.unauthenticated) {
    throw ApiException('no_session', statusCode: 401);
  }
  if (!auth.isAuthenticated) {
    // A remembered login is being silently replayed — there is no session to
    // fetch with yet. Show the cache if there is one; this rebuilds the
    // moment auth settles either way, so there is nothing else to do here
    // but wait rather than surface a spurious error.
    final cached = await cache.read(cacheAu, cacheSs);
    if (cached != null) return cached.grades;
    return Completer<Grades>().future;
  }

  try {
    final grades = await ref.watch(apiClientProvider).getGrades(au: au, ss: ss);
    await cache.save(cacheAu, cacheSs, grades);
    return grades;
  } on ApiException catch (error) {
    // Only stand in for a missing connection. A lapsed session must still
    // surface so the app can renew it rather than showing stale data forever.
    if (!error.isConnectivityProblem) rethrow;

    final cached = await cache.read(cacheAu, cacheSs);
    if (cached == null) rethrow;

    return cached.grades;
  }
});

/// Reads the cache without touching the network — used to seed the screen
/// instantly while [gradesProvider] is still loading, instead of a skeleton.
final gradesCachePeekProvider = FutureProvider.autoDispose<CachedGrades?>((ref) {
  final cache = ref.watch(gradesCacheProvider);
  return cache.read(_cacheKey(ref.watch(selectedAuProvider)), _cacheKey(ref.watch(selectedSsProvider)));
});

/// The code a dropdown should display: the user's explicit pick if any,
/// else the code the backend says the data belongs to. Never guessed from the
/// upstream markup, which leaves nothing marked on a default load.
String? effectiveCode(String? userPick, String? currentFromServer, List<SelectOption> options) {
  final code = userPick ?? currentFromServer;
  // Only show a value the dropdown actually offers, or it will assert.
  if (code != null && options.any((o) => o.code == code)) return code;
  return options.isNotEmpty ? options.first.code : null;
}
