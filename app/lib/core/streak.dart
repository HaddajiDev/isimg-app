import 'dart:math' as math;

/// Attendance streak derived from a student's recorded absences.
///
/// A streak counts *school days* — every weekday except Sunday, which the
/// institute never schedules. Sundays are skipped: they neither add to a streak
/// nor break it.
class StreakStats {
  /// School days without an absence since the most recent miss, through today.
  final int current;

  /// Longest run of school days without an absence across the whole year
  /// (both semesters) — the student's record.
  final int best;

  /// Whether any dated absence was found. When false the student is either
  /// spotless or the server returned no per-class list to build a streak from.
  final bool hasAbsences;

  /// The most recent absence date considered, if any.
  final DateTime? lastAbsence;

  const StreakStats({
    required this.current,
    required this.best,
    required this.hasAbsences,
    this.lastAbsence,
  });

  static const empty =
      StreakStats(current: 0, best: 0, hasAbsences: false, lastAbsence: null);
}

bool _isSchoolDay(DateTime d) => d.weekday != DateTime.sunday;

/// School days in the half-open range `(after, through]` — strictly after
/// [after], up to and including [through], excluding Sundays.
int _schoolDaysBetween(DateTime after, DateTime through) {
  final end = DateTime(through.year, through.month, through.day);
  var d = DateTime(after.year, after.month, after.day).add(const Duration(days: 1));
  var n = 0;
  while (!d.isAfter(end)) {
    if (_isSchoolDay(d)) n++;
    d = d.add(const Duration(days: 1));
  }
  return n;
}

/// Builds [StreakStats] from a student's absence dates.
///
/// [absenceDates] may contain duplicates and times; only the day part matters.
/// Future-dated entries (relative to [today]) are ignored.
StreakStats computeAttendanceStreak(
  Iterable<DateTime> absenceDates, {
  DateTime? today,
}) {
  final ref = today ?? DateTime.now();
  final refDay = DateTime(ref.year, ref.month, ref.day);

  final days = <DateTime>{
    for (final d in absenceDates)
      if (!DateTime(d.year, d.month, d.day).isAfter(refDay))
        DateTime(d.year, d.month, d.day),
  }.toList()
    ..sort();

  if (days.isEmpty) return StreakStats.empty;

  final last = days.last;
  final current = _schoolDaysBetween(last, refDay);

  var best = current;
  for (var i = 1; i < days.length; i++) {
    // School days the student attended between two consecutive misses:
    // days strictly between them (the later date is itself an absence).
    final gap = _schoolDaysBetween(days[i - 1], days[i]) - 1;
    best = math.max(best, gap < 0 ? 0 : gap);
  }

  return StreakStats(
    current: current,
    best: best,
    hasAbsences: true,
    lastAbsence: last,
  );
}
