import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';
import '../core/demo_api_client.dart';
import '../isimg/svc5_client.dart';
import 'auth_provider.dart';

/// The client shares the auth layer's [SessionStore], so there is a single
/// in-memory copy of the session.
final apiClientProvider = Provider<ApiClient>(
  (ref) => DemoAwareApiClient(Svc5Client(sessions: ref.watch(sessionStoreProvider))),
);
