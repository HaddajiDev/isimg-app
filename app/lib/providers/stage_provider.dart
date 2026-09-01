import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_exception.dart';
import '../core/stage_cache.dart';
import '../models/stage.dart';
import 'api_provider.dart';
import 'auth_provider.dart';

final stageCacheProvider = Provider<StageCache>((ref) => StageCache());

class StageView {
  final Stages stages;
  final DateTime? capturedAt;

  const StageView({required this.stages, this.capturedAt});
}

final stageProvider = FutureProvider.autoDispose<StageView>((ref) async {
  final auth = ref.watch(authProvider);
  final cache = ref.watch(stageCacheProvider);

  if (auth.status == AuthStatus.unauthenticated) {
    throw ApiException('no_session', statusCode: 401);
  }
  if (!auth.isAuthenticated) {
    final cached = await cache.read();
    if (cached != null) return StageView(stages: cached.stages, capturedAt: cached.capturedAt);
    return Completer<StageView>().future;
  }

  try {
    final stages = await ref.watch(apiClientProvider).getStages();
    await cache.save(stages);
    return StageView(stages: stages);
  } on ApiException catch (error) {
    if (!error.isConnectivityProblem) rethrow;

    final cached = await cache.read();
    if (cached == null) rethrow;
    return StageView(stages: cached.stages, capturedAt: cached.capturedAt);
  }
});

final stageCachePeekProvider = FutureProvider.autoDispose<CachedStages?>((ref) {
  return ref.watch(stageCacheProvider).read();
});
