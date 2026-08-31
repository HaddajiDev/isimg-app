import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/profile.dart';

class CachedProfile {
  final Profile profile;
  final DateTime capturedAt;

  const CachedProfile({required this.profile, required this.capturedAt});
}

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
      return null;
    }
  }

  Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (_) {
    }
  }
}
