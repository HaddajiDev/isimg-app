import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_exception.dart';
import '../core/profile_cache.dart';
import '../models/profile.dart';
import 'api_provider.dart';
import 'auth_provider.dart';

final profileCacheProvider = Provider<ProfileCache>((ref) => ProfileCache());

final profileProvider = FutureProvider.autoDispose<Profile>((ref) async {
  final auth = ref.watch(authProvider);
  final cache = ref.watch(profileCacheProvider);

  if (auth.status == AuthStatus.unauthenticated) {
    throw ApiException('no_session', statusCode: 401);
  }
  if (!auth.isAuthenticated) {
    // A remembered login is being silently replayed — there is no session to
    // fetch with yet. Show the cache if there is one; this rebuilds the
    // moment auth settles either way, so there is nothing else to do here
    // but wait rather than surface a spurious error.
    final cached = await cache.read();
    if (cached != null) return cached.profile;
    return Completer<Profile>().future;
  }

  try {
    final profile = await ref.watch(apiClientProvider).getProfile();
    await cache.save(profile);
    return profile;
  } on ApiException catch (error) {
    // Only stand in for a missing connection. A lapsed session must still
    // surface so the app can renew it rather than showing stale data forever.
    if (!error.isConnectivityProblem) rethrow;

    final cached = await cache.read();
    if (cached == null) rethrow;

    return cached.profile;
  }
});

/// Reads the cache without touching the network — used to seed the screen
/// instantly while [profileProvider] is still loading, instead of a skeleton.
final profileCachePeekProvider = FutureProvider.autoDispose<CachedProfile?>((ref) {
  return ref.watch(profileCacheProvider).read();
});
