import 'package:flutter_test/flutter_test.dart';
import 'package:isimg_app/core/home_widget_sync.dart';
import 'package:isimg_app/models/schedule.dart';
import 'package:isimg_app/models/seance.dart';

void main() {
  final monday = DateTime(2026, 10, 26);
  Seance s(int weekday, String slot, String matiere, {String? salle}) =>
      Seance(weekday: weekday, slot: slot, type: SeanceType.tp, matiere: matiere, salle: salle);

  test('slotRange reads start and end in minutes', () {
    expect(HomeWidgetSync.slotRange('08:15-09:45'), (495, 585));
    expect(HomeWidgetSync.slotRange('8h30 - 10h00'), (510, 600));
    expect(HomeWidgetSync.slotRange(''), isNull);
  });

  test('payload dates each class within the week and sorts by day then time', () {
    final payload = HomeWidgetSync.buildPayload(
      Schedule(hasSessions: true, sessions: [
        s(3, '11:30-13:00', 'Réseaux', salle: 'B2'),
        s(1, '09:55-11:25', 'Algo'),
        s(1, '08:15-09:45', 'Maths'),
        s(2, '', 'Sans horaire'),
      ]),
      monday,
      now: DateTime(2026, 10, 26, 7),
    );
    expect(payload['from'], '2026-10-26');
    expect(payload['to'], '2026-11-01');
    final sessions = (payload['sessions'] as List).cast<Map<String, dynamic>>();
    expect(sessions.map((e) => e['matiere']), ['Maths', 'Algo', 'Réseaux']);
    expect(sessions.last['date'], '2026-10-28');
    expect(sessions.last['salle'], 'B2');
    expect(sessions.first['type'], 'TP');
  });

  test('refresh times are class starts and ends plus midnights, future only', () {
    final payload = HomeWidgetSync.buildPayload(
      Schedule(hasSessions: true, sessions: [
        s(1, '08:15-09:45', 'Maths'),
        s(1, '09:55-11:25', 'Algo'),
      ]),
      monday,
    );
    final times = HomeWidgetSync.refreshTimes(payload, DateTime(2026, 10, 26, 10));
    // 08:15, 09:45 and 09:55 already passed; 11:25 is next, then Tuesday 00:01.
    expect(times.first, DateTime(2026, 10, 26, 11, 25, 1));
    expect(times[1], DateTime(2026, 10, 27, 0, 1));
    expect(times, isNot(contains(DateTime(2026, 10, 26, 9, 55, 1))));
    expect(times.last, DateTime(2026, 11, 2, 0, 1));
  });
}
