import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/grades.dart';

class CachedGrades {
  final Grades grades;
  final DateTime capturedAt;

  const CachedGrades({required this.grades, required this.capturedAt});
}

class GradesCache {
  static const _prefix = 'grades_v1:';

  String _key(String au, String ss) => '$_prefix$au|$ss';

  Future<void> save(String au, String ss, Grades grades) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _key(au, ss),
        jsonEncode({
          'capturedAt': DateTime.now().toIso8601String(),
          'grades': grades.toJson(),
        }),
      );
    } catch (_) {
    }
  }

  Future<CachedGrades?> read(String au, String ss) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key(au, ss));
      if (raw == null) return null;

      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final capturedAt = DateTime.tryParse(decoded['capturedAt'] as String? ?? '');
      final grades = decoded['grades'];
      if (capturedAt == null || grades is! Map<String, dynamic>) return null;

      return CachedGrades(grades: Grades.fromJson(grades), capturedAt: capturedAt);
    } catch (_) {
      return null;
    }
  }

  Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final key in prefs.getKeys().where((k) => k.startsWith(_prefix)).toList()) {
        await prefs.remove(key);
      }
    } catch (_) {
    }
  }
}
