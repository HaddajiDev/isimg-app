import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_exception.dart';
import '../models/grades.dart';
import 'api_provider.dart';
import 'auth_provider.dart';

/// Année universitaire code (the site's <select name="f_au"> value).
/// `null` means "let the server pick its current année" — which is the most
/// recent one holding real data, so it's the default on first load.
final selectedAuProvider = StateProvider<String?>((ref) => null);

/// Session code: 1 = Principale, 2 = Contrôle. `null` follows the server.
final selectedSsProvider = StateProvider<String?>((ref) => null);

final gradesProvider = FutureProvider.autoDispose<Grades>((ref) async {
  final auth = ref.watch(authProvider);
  final au = ref.watch(selectedAuProvider);
  final ss = ref.watch(selectedSsProvider);
  if (!auth.isAuthenticated) throw ApiException('no_session', statusCode: 401);
  return ref.watch(apiClientProvider).getGrades(au: au, ss: ss);
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
