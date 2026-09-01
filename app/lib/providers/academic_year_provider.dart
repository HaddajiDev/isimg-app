import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/demo_api_client.dart';
import '../core/demo_data.dart';
import '../isimg/svc5_session.dart';
import 'api_provider.dart';
import 'auth_provider.dart';

final academicYearProvider = FutureProvider.autoDispose<String?>((ref) async {
  ref.watch(authProvider);

  final client = ref.watch(apiClientProvider);
  if (client is DemoAwareApiClient && client.isDemoSession) {
    return demoAcademicYear;
  }

  final session = Svc5Session.tryDecode(await ref.watch(sessionStoreProvider).read());
  if (session == null || session.au <= 0) return null;
  return session.labelFor(session.au);
});

final drawerIdentityProvider =
    FutureProvider.autoDispose<({String name, String subtitle})?>((ref) async {
  ref.watch(authProvider);

  final client = ref.watch(apiClientProvider);
  if (client is DemoAwareApiClient && client.isDemoSession) {
    return (name: 'Étudiant Démo', subtitle: 'Espace étudiant');
  }

  final session = Svc5Session.tryDecode(await ref.watch(sessionStoreProvider).read());
  if (session == null) return null;
  final name = [session.prenom, session.nom].whereType<String>().join(' ').trim();
  final subtitle = session.filiere ??
      (session.niveau != null ? 'Niveau ${session.niveau}' : 'Espace étudiant');
  return (name: name.isEmpty ? 'Étudiant' : name, subtitle: subtitle);
});
