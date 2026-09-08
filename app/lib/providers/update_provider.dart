import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

import '../core/app_config.dart';
import '../models/app_update.dart';

/// Resolves to an [AppUpdate] when the backend advertises a build newer than the
/// one running, otherwise null. Fails silently (returns null) on any error so a
/// version-check hiccup never disrupts the app.
final updateProvider = FutureProvider.autoDispose<AppUpdate?>((ref) async {
  if (kVersionApiUrl.isEmpty) return null;

  try {
    final info = await PackageInfo.fromPlatform();
    final current = int.tryParse(info.buildNumber) ?? 0;

    final res = await http
        .get(Uri.parse(kVersionApiUrl))
        .timeout(const Duration(seconds: 6));
    if (res.statusCode != 200) return null;

    final decoded = jsonDecode(res.body);
    if (decoded is! Map<String, dynamic>) return null;

    final latest = AppUpdate.fromJson(decoded);
    return latest.build > current ? latest : null;
  } catch (_) {
    return null;
  }
});

/// Lets the user dismiss the update banner for the current session.
final updateBannerDismissedProvider = StateProvider<bool>((ref) => false);
