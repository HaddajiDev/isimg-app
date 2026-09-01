import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_exception.dart';
import '../core/calendar_cache.dart';
import '../models/calendar.dart';
import 'api_provider.dart';
import 'auth_provider.dart';

final calendarCacheProvider = Provider<CalendarCache>((ref) => CalendarCache());

class CalendarView {
  final UniversityCalendar calendar;
  final DateTime? capturedAt;

  const CalendarView({required this.calendar, this.capturedAt});
}

final calendarProvider = FutureProvider.autoDispose<CalendarView>((ref) async {
  final auth = ref.watch(authProvider);
  final cache = ref.watch(calendarCacheProvider);

  if (auth.status == AuthStatus.unauthenticated) {
    throw ApiException('no_session', statusCode: 401);
  }
  if (!auth.isAuthenticated) {
    final cached = await cache.read();
    if (cached != null) {
      return CalendarView(calendar: cached.calendar, capturedAt: cached.capturedAt);
    }
    return Completer<CalendarView>().future;
  }

  try {
    final calendar = await ref.watch(apiClientProvider).getUniversityCalendar();
    await cache.save(calendar);
    return CalendarView(calendar: calendar);
  } on ApiException catch (error) {
    if (!error.isConnectivityProblem) rethrow;

    final cached = await cache.read();
    if (cached == null) rethrow;
    return CalendarView(calendar: cached.calendar, capturedAt: cached.capturedAt);
  }
});

final calendarCachePeekProvider = FutureProvider.autoDispose<CachedCalendar?>((ref) {
  return ref.watch(calendarCacheProvider).read();
});
