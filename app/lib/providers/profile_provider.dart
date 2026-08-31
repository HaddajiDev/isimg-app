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
    final cached = await cache.read();
    if (cached != null) return cached.profile;
    return Completer<Profile>().future;
  }

  try {
    final profile = await ref.watch(apiClientProvider).getProfile();
    await cache.save(profile);
    return profile;
  } on ApiException catch (error) {
    if (!error.isConnectivityProblem) rethrow;

    final cached = await cache.read();
    if (cached == null) rethrow;

    return cached.profile;
  }
});

final profileCachePeekProvider = FutureProvider.autoDispose<CachedProfile?>((ref) {
  return ref.watch(profileCacheProvider).read();
});
