import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';
import '../core/demo_api_client.dart';
import '../isimg/svc5_client.dart';

final apiClientProvider = Provider<ApiClient>((ref) => DemoAwareApiClient(Svc5Client()));
