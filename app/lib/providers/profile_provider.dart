import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_exception.dart';
import '../models/profile.dart';
import 'api_provider.dart';
import 'auth_provider.dart';

final profileProvider = FutureProvider.autoDispose<Profile>((ref) async {
  final auth = ref.watch(authProvider);
  if (!auth.isAuthenticated) throw ApiException('no_session', statusCode: 401);
  return ref.watch(apiClientProvider).getProfile();
});
