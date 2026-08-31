import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/absences.dart';

class CachedAbsences {
  final Absences absences;
  final DateTime capturedAt;

  const CachedAbsences({required this.absences, required this.capturedAt});
}

class AbsencesCache {
  static const _key = 'absences_v1';

  Future<void> save(Absences absences) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _key,
        jsonEncode({
          'capturedAt': DateTime.now().toIso8601String(),
          'absences': absences.toJson(),
        }),
      );
    } catch (_) {
    }
  }

  Future<CachedAbsences?> read() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return null;

      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final capturedAt = DateTime.tryParse(decoded['capturedAt'] as String? ?? '');
      final absences = decoded['absences'];
      if (capturedAt == null || absences is! Map<String, dynamic>) return null;

      return CachedAbsences(absences: Absences.fromJson(absences), capturedAt: capturedAt);
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
