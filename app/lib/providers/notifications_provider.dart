import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_exception.dart';
import '../models/notifications.dart';
import 'api_provider.dart';
import 'auth_provider.dart';

final notificationsProvider = FutureProvider.autoDispose<NotifData>((ref) async {
  final auth = ref.watch(authProvider);

  if (auth.status == AuthStatus.unauthenticated) {
    throw ApiException('no_session', statusCode: 401);
  }
  if (!auth.isAuthenticated) return Completer<NotifData>().future;

  return ref.watch(apiClientProvider).getNotifications();
});
