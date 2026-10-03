import 'package:flutter_test/flutter_test.dart';
import 'package:isimg_app/core/streak.dart';

// Reference weekdays used below (October 2026):
//   Oct 1 Thu · 2 Fri · 3 Sat · 4 Sun · 5 Mon · 6 Tue · 7 Wed
//   Oct 8 Thu · 9 Fri · 10 Sat · 11 Sun · 12 Mon
void main() {
  group('computeAttendanceStreak', () {
    test('no absences yields the empty (spotless) stats', () {
      final s = computeAttendanceStreak(const [], today: DateTime(2026, 10, 5));
      expect(s.hasAbsences, isFalse);
      expect(s.current, 0);
      expect(s.best, 0);
    });

    test('counts school days since the last absence, through today', () {
      final s = computeAttendanceStreak(
        [DateTime(2026, 10, 1)],
        today: DateTime(2026, 10, 9),
      );
      // Oct 2,3,5,6,7,8,9 (Oct 4 Sunday excluded) = 7
      expect(s.current, 7);
      expect(s.best, 7);
      expect(s.hasAbsences, isTrue);
      expect(s.lastAbsence, DateTime(2026, 10, 1));
    });

    test('Sundays never count toward a streak', () {
      final s = computeAttendanceStreak(
        [DateTime(2026, 10, 2)],
        today: DateTime(2026, 10, 5),
      );
      // Oct 3 (Sat), Oct 5 (Mon); Oct 4 Sunday skipped = 2
      expect(s.current, 2);
    });

    test('best streak mines historical gaps, not just the current run', () {
      final s = computeAttendanceStreak(
        [DateTime(2026, 10, 1), DateTime(2026, 10, 9)],
        today: DateTime(2026, 10, 12),
      );
      // current: after Oct 9 through Oct 12 -> Oct 10, Oct 12 = 2
      expect(s.current, 2);
      // gap between Oct 1 and Oct 9 -> Oct 2,3,5,6,7,8 = 6
      expect(s.best, 6);
    });

    test('an absence today gives a zero current streak', () {
      final s = computeAttendanceStreak(
        [DateTime(2026, 10, 5)],
        today: DateTime(2026, 10, 5),
      );
      expect(s.current, 0);
      expect(s.hasAbsences, isTrue);
    });

    test('duplicate same-day entries do not inflate the streak', () {
      final s = computeAttendanceStreak(
        [DateTime(2026, 10, 1), DateTime(2026, 10, 1)],
        today: DateTime(2026, 10, 2),
      );
      expect(s.current, 1);
    });

    test('future-dated absences are ignored', () {
      final s = computeAttendanceStreak(
        [DateTime(2026, 10, 20)],
        today: DateTime(2026, 10, 5),
      );
      expect(s.hasAbsences, isFalse);
      expect(s.current, 0);
    });
  });
}
