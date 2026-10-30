import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_exception.dart';
import '../core/services_api.dart';
import '../models/demande.dart';
import '../models/pfe.dart';
import 'api_provider.dart';
import 'auth_provider.dart';

/// Requests and PFE are live administrative data — never cached.
Future<ServicesApi> _services(Ref ref) {
  final auth = ref.watch(authProvider);
  if (auth.status == AuthStatus.unauthenticated) {
    throw ApiException('no_session', statusCode: 401);
  }
  // Still restoring the session: wait for auth to settle (this rebuilds).
  if (!auth.isAuthenticated) return Completer<ServicesApi>().future;

  final client = ref.watch(apiClientProvider);
  if (client is! ServicesApi) throw ApiException('unsupported');
  return Future.value(client as ServicesApi);
}

final servicesApiProvider = Provider<ServicesApi?>((ref) {
  final client = ref.watch(apiClientProvider);
  return client is ServicesApi ? client as ServicesApi : null;
});

final demandeModelsProvider = FutureProvider.autoDispose<List<DemandeModel>>((ref) async {
  return (await _services(ref)).getDemandeModels();
});

final demandesProvider = FutureProvider.autoDispose<List<Demande>>((ref) async {
  return (await _services(ref)).getDemandes();
});

final demandeMessagesProvider =
    FutureProvider.autoDispose.family<List<DemandeMessage>, String>((ref, id) async {
  return (await _services(ref)).getDemandeMessages(id);
});

final pfeProvider = FutureProvider.autoDispose<Pfe?>((ref) async {
  return (await _services(ref)).getPfe();
});
