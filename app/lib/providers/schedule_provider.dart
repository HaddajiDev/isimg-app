import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_exception.dart';
import '../core/schedule_cache.dart';
import '../models/schedule.dart';
import 'api_provider.dart';
import 'auth_provider.dart';

DateTime mondayOf(DateTime date) {
  final daysSinceMonday = date.weekday - DateTime.monday;
  return DateTime(date.year, date.month, date.day).subtract(Duration(days: daysSinceMonday));
}

String formatWeek(DateTime date) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

final selectedWeekProvider = StateProvider<DateTime>((ref) => mondayOf(DateTime.now()));

final scheduleCacheProvider = Provider<ScheduleCache>((ref) => ScheduleCache());

/// A week plus where it came from.
class ScheduleView {
  final Schedule schedule;

  /// When the cached copy was captured, or null if this is live.
  final DateTime? capturedAt;

  const ScheduleView({required this.schedule, this.capturedAt});

  bool get isFromCache => capturedAt != null;
}

final scheduleProvider = FutureProvider.autoDispose<ScheduleView>((ref) async {
  final auth = ref.watch(authProvider);
  final weekStart = ref.watch(selectedWeekProvider);
  final week = formatWeek(weekStart);
  final cache = ref.watch(scheduleCacheProvider);

  if (auth.status == AuthStatus.unauthenticated) {
    throw ApiException('no_session', statusCode: 401);
  }
  if (!auth.isAuthenticated) {
    // A remembered login is being silently replayed — there is no session to
    // fetch with yet. Show the cache if there is one; this rebuilds the
    // moment auth settles either way, so there is nothing else to do here
    // but wait rather than surface a spurious error.
    final cached = await cache.read(week);
    if (cached != null) {
      return ScheduleView(schedule: cached.schedule, capturedAt: cached.capturedAt);
    }
    return Completer<ScheduleView>().future;
  }

  try {
    final schedule = await ref.watch(apiClientProvider).getSchedule(week: week);
    await cache.save(week, schedule);
    return ScheduleView(schedule: schedule);
  } on ApiException catch (error) {
    // Only stand in for a missing connection. A lapsed session must still
    // surface so the app can renew it rather than showing stale data forever.
    if (!error.isConnectivityProblem) rethrow;

    final cached = await cache.read(week);
    if (cached == null) rethrow;

    return ScheduleView(schedule: cached.schedule, capturedAt: cached.capturedAt);
  }
});

/// Reads the cache without touching the network — used to seed the screen
/// instantly while [scheduleProvider] is still loading, instead of a
/// skeleton.
final scheduleCachePeekProvider = FutureProvider.autoDispose<CachedSchedule?>((ref) {
  final cache = ref.watch(scheduleCacheProvider);
  return cache.read(formatWeek(ref.watch(selectedWeekProvider)));
});

void goToPreviousWeek(WidgetRef ref) {
  ref.read(selectedWeekProvider.notifier).update((week) => week.subtract(const Duration(days: 7)));
}

void goToNextWeek(WidgetRef ref) {
  ref.read(selectedWeekProvider.notifier).update((week) => week.add(const Duration(days: 7)));
}

void goToCurrentWeek(WidgetRef ref) {
  ref.read(selectedWeekProvider.notifier).state = mondayOf(DateTime.now());
}

/// Jumps to whichever week contains [date].
void goToWeekOf(WidgetRef ref, DateTime date) {
  ref.read(selectedWeekProvider.notifier).state = mondayOf(date);
}
