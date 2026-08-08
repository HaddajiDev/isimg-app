import 'seance.dart';

class Schedule {
  final String? weekLabel;
  final bool hasSessions;
  final String? rawContentHtml;

  /// Parsed classes, when they could be extracted. Empty means "not parsed" —
  /// which is still the case for real data, so the screen falls back to a
  /// summary rather than claiming the week is free.
  final List<Seance> sessions;

  Schedule({
    this.weekLabel,
    required this.hasSessions,
    this.rawContentHtml,
    this.sessions = const [],
  });

  factory Schedule.fromJson(Map<String, dynamic> json) {
    return Schedule(
      weekLabel: json['weekLabel'] as String?,
      hasSessions: json['hasSessions'] as bool? ?? false,
      rawContentHtml: json['rawContentHtml'] as String?,
      sessions: (json['sessions'] as List<dynamic>? ?? [])
          .map((s) => Seance.fromJson(s as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Round-trips through the offline cache.
  Map<String, dynamic> toJson() => {
        'weekLabel': weekLabel,
        'hasSessions': hasSessions,
        'rawContentHtml': rawContentHtml,
        'sessions': sessions.map((s) => s.toJson()).toList(),
      };
}
