import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/calendar.dart';

class CachedCalendar {
  final UniversityCalendar calendar;
  final DateTime capturedAt;

  const CachedCalendar({required this.calendar, required this.capturedAt});
}

class CalendarCache {
  static const _key = 'calendar_v1';

  Future<void> save(UniversityCalendar calendar) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _key,
        jsonEncode({
          'capturedAt': DateTime.now().toIso8601String(),
          'calendar': calendar.toJson(),
        }),
      );
    } catch (_) {}
  }

  Future<CachedCalendar?> read() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return null;

      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final capturedAt = DateTime.tryParse(decoded['capturedAt'] as String? ?? '');
      final calendar = decoded['calendar'];
      if (capturedAt == null || calendar is! Map<String, dynamic>) return null;

      return CachedCalendar(
        calendar: UniversityCalendar.fromJson(calendar),
        capturedAt: capturedAt,
      );
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
