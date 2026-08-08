import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_exception.dart';
import '../models/schedule.dart';
import 'api_provider.dart';
import 'auth_provider.dart';

DateTime _mondayOf(DateTime date) {
  final daysSinceMonday = date.weekday - DateTime.monday;
  return DateTime(date.year, date.month, date.day).subtract(Duration(days: daysSinceMonday));
}

String _formatDate(DateTime date) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

final selectedWeekProvider = StateProvider<DateTime>((ref) => _mondayOf(DateTime.now()));

final scheduleProvider = FutureProvider.autoDispose<Schedule>((ref) async {
  final auth = ref.watch(authProvider);
  final weekStart = ref.watch(selectedWeekProvider);
  if (!auth.isAuthenticated) throw ApiException('no_session', statusCode: 401);
  return ref.watch(apiClientProvider).getSchedule(week: _formatDate(weekStart));
});

void goToPreviousWeek(WidgetRef ref) {
  ref.read(selectedWeekProvider.notifier).update((week) => week.subtract(const Duration(days: 7)));
}

void goToNextWeek(WidgetRef ref) {
  ref.read(selectedWeekProvider.notifier).update((week) => week.add(const Duration(days: 7)));
}

void goToCurrentWeek(WidgetRef ref) {
  ref.read(selectedWeekProvider.notifier).state = _mondayOf(DateTime.now());
}
