import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/exam.dart';

class CachedExams {
  final ExamsSchedule exams;
  final DateTime capturedAt;

  const CachedExams({required this.exams, required this.capturedAt});
}

class ExamsCache {
  static const _key = 'exams_v1';

  Future<void> save(ExamsSchedule exams) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _key,
        jsonEncode({
          'capturedAt': DateTime.now().toIso8601String(),
          'exams': exams.toJson(),
        }),
      );
    } catch (_) {
    }
  }

  Future<CachedExams?> read() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return null;

      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final capturedAt = DateTime.tryParse(decoded['capturedAt'] as String? ?? '');
      final exams = decoded['exams'];
      if (capturedAt == null || exams is! Map<String, dynamic>) return null;

      return CachedExams(exams: ExamsSchedule.fromJson(exams), capturedAt: capturedAt);
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
