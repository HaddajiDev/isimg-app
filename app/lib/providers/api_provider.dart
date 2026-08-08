import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';

/// Single seam for the backend client, so tests can substitute a fake.
final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());
