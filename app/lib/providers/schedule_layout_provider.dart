import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// How the Emploi tab draws the week.
enum ScheduleLayout {
  /// The whole week on one screen, no scrolling — like the printed timetable.
  compact,

  /// Wide day columns that scroll sideways, with roomier class cards.
  detailed,
}

class ScheduleLayoutNotifier extends Notifier<ScheduleLayout> {
  static const _key = 'schedule_layout_v1';

  @override
  ScheduleLayout build() {
    _load();
    return ScheduleLayout.compact;
  }

  Future<void> _load() async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(_key);
      final layout = ScheduleLayout.values.where((l) => l.name == raw).firstOrNull;
      if (layout != null) state = layout;
    } catch (_) {
    }
  }

  Future<void> set(ScheduleLayout layout) async {
    state = layout;
    try {
      await (await SharedPreferences.getInstance()).setString(_key, layout.name);
    } catch (_) {
    }
  }

  Future<void> toggle() => set(
        state == ScheduleLayout.compact ? ScheduleLayout.detailed : ScheduleLayout.compact,
      );
}

final scheduleLayoutProvider =
    NotifierProvider<ScheduleLayoutNotifier, ScheduleLayout>(ScheduleLayoutNotifier.new);
