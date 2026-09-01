import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_exception.dart';
import '../models/news.dart';
import 'api_provider.dart';
import 'auth_provider.dart';

final newsProvider = FutureProvider.autoDispose<NewsFeed>((ref) async {
  final auth = ref.watch(authProvider);

  if (auth.status == AuthStatus.unauthenticated) {
    throw ApiException('no_session', statusCode: 401);
  }
  if (!auth.isAuthenticated) return Completer<NewsFeed>().future;

  return ref.watch(apiClientProvider).getNews();
});
