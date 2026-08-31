import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/schedule.dart';

class CachedSchedule {
  final Schedule schedule;
  final DateTime capturedAt;

  const CachedSchedule({required this.schedule, required this.capturedAt});
}

class ScheduleCache {
  static const _prefix = 'schedule_v1:';

  String _key(String week) => '$_prefix$week';

  Future<void> save(String week, Schedule schedule) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _key(week),
        jsonEncode({
          'capturedAt': DateTime.now().toIso8601String(),
          'schedule': schedule.toJson(),
        }),
      );
    } catch (_) {
    }
  }

  Future<CachedSchedule?> read(String week) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key(week));
      if (raw == null) return null;

      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final capturedAt = DateTime.tryParse(decoded['capturedAt'] as String? ?? '');
      final schedule = decoded['schedule'];
      if (capturedAt == null || schedule is! Map<String, dynamic>) return null;

      return CachedSchedule(
        schedule: Schedule.fromJson(schedule),
        capturedAt: capturedAt,
      );
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
