import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import '../models/schedule.dart';

/// Feeds the Android "Aujourd'hui" home-screen widget.
///
/// The whole displayed week is stored, not just today: the native widget picks
/// today's classes itself at render time, so it stays right across midnight
/// without the app being opened.
class HomeWidgetSync {
  const HomeWidgetSync._();

  static const androidName = 'TodayWidgetProvider';
  static const dataKey = 'week_json';

  static String _d(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static String _hm(int minutes) =>
      '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';

  /// `08:15-09:45` → (495, 585). Null when the slot can't be read.
  static (int, int)? slotRange(String slot) {
    final m = RegExp(r'(\d{1,2})[:h](\d{2})\s*-\s*(\d{1,2})[:h](\d{2})').firstMatch(slot);
    if (m == null) return null;
    int v(int i) => int.parse(m[i]!);
    return (v(1) * 60 + v(2), v(3) * 60 + v(4));
  }

  /// The JSON the native widget reads. Sessions are sorted by date then time.
  static Map<String, dynamic> buildPayload(Schedule schedule, DateTime monday, {DateTime? now}) {
    final start = DateTime(monday.year, monday.month, monday.day);
    final sessions = <Map<String, dynamic>>[];
    for (final s in schedule.sessions) {
      final range = slotRange(s.slot);
      if (range == null || s.weekday < 1 || s.weekday > 7) continue;
      sessions.add({
        'date': _d(start.add(Duration(days: s.weekday - 1))),
        'start': _hm(range.$1),
        'end': _hm(range.$2),
        'matiere': s.matiere,
        'salle': s.salle ?? '',
        'type': s.type.label,
        'ratt': s.rattrapage,
      });
    }
    sessions.sort((a, b) {
      final byDate = (a['date'] as String).compareTo(b['date'] as String);
      return byDate != 0 ? byDate : (a['start'] as String).compareTo(b['start'] as String);
    });
    return {
      'from': _d(start),
      'to': _d(start.add(const Duration(days: 6))),
      'updated': (now ?? DateTime.now()).toIso8601String(),
      'sessions': sessions,
    };
  }

  /// When the widget should redraw: each class's start and end (the hero card
  /// flips between "prochain" and "en cours") and each midnight of the week (to
  /// switch days).
  static List<DateTime> refreshTimes(Map<String, dynamic> payload, DateTime now) {
    final times = <DateTime>{};
    for (final s in (payload['sessions'] as List).cast<Map<String, dynamic>>()) {
      final day = DateTime.parse(s['date'] as String);
      for (final key in const ['start', 'end']) {
        final hm = (s[key] as String).split(':').map(int.parse).toList();
        times.add(DateTime(day.year, day.month, day.day, hm[0], hm[1], 1));
      }
    }
    final from = DateTime.parse(payload['from'] as String);
    for (var i = 0; i <= 7; i++) {
      times.add(DateTime(from.year, from.month, from.day + i, 0, 1));
    }
    return times.where((t) => t.isAfter(now)).toList()..sort();
  }

  /// Pushes [schedule] (the week starting [monday]) to the widget. Never throws:
  /// a missing widget or platform must not break the timetable.
  static Future<void> publish(Schedule schedule, DateTime monday) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      final now = DateTime.now();
      final payload = buildPayload(schedule, monday, now: now);
      await HomeWidget.saveWidgetData<String>(dataKey, jsonEncode(payload));
      await HomeWidget.updateWidget(androidName: androidName);
      await HomeWidget.scheduleWidgetUpdates(refreshTimes(payload, now), androidName: androidName);
    } catch (_) {
      // No widget placed, plugin unavailable (tests), or OEM restrictions.
    }
  }
}
