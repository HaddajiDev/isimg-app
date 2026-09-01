import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/student.dart';

class CachedStudent {
  final StudentInfo student;
  final DateTime capturedAt;

  const CachedStudent({required this.student, required this.capturedAt});
}

class StudentCache {
  static const _key = 'student_v1';

  Future<void> save(StudentInfo student) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _key,
        jsonEncode({
          'capturedAt': DateTime.now().toIso8601String(),
          'student': student.toJson(),
        }),
      );
    } catch (_) {}
  }

  Future<CachedStudent?> read() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return null;

      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final capturedAt = DateTime.tryParse(decoded['capturedAt'] as String? ?? '');
      final student = decoded['student'];
      if (capturedAt == null || student is! Map<String, dynamic>) return null;

      return CachedStudent(student: StudentInfo.fromJson(student), capturedAt: capturedAt);
    } catch (_) {
      return null;
    }
  }

  Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (_) {}
  }
}
