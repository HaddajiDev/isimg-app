import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/profile.dart';

/// A profile served from the cache, with when it was captured.
class CachedProfile {
  final Profile profile;
  final DateTime capturedAt;

  const CachedProfile({required this.profile, required this.capturedAt});
}

/// Keeps the last fetched profile on the device — there is only ever one, so
/// unlike [GradesCache] or the schedule cache this needs no key.
class ProfileCache {
  static const _key = 'profile_v1';

  Future<void> save(Profile profile) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _key,
        jsonEncode({
          'capturedAt': DateTime.now().toIso8601String(),
          'profile': profile.toJson(),
        }),
      );
    } catch (_) {
      // Caching is an optimisation; a failure here must not break the fetch.
    }
  }

  Future<CachedProfile?> read() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return null;

      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final capturedAt = DateTime.tryParse(decoded['capturedAt'] as String? ?? '');
      final profile = decoded['profile'];
      if (capturedAt == null || profile is! Map<String, dynamic>) return null;

      return CachedProfile(profile: Profile.fromJson(profile), capturedAt: capturedAt);
    } catch (_) {
      // A corrupt entry behaves as a miss rather than breaking the screen.
      return null;
    }
  }

  Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (_) {
      // Nothing to do; the entry was already unreadable.
    }
  }
}
