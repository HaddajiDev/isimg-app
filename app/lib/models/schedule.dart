class Schedule {
  final String? weekLabel;
  final bool hasSessions;
  final String? rawContentHtml;

  Schedule({this.weekLabel, required this.hasSessions, this.rawContentHtml});

  factory Schedule.fromJson(Map<String, dynamic> json) {
    return Schedule(
      weekLabel: json['weekLabel'] as String?,
      hasSessions: json['hasSessions'] as bool? ?? false,
      rawContentHtml: json['rawContentHtml'] as String?,
    );
  }

  /// Round-trips through the offline cache.
  Map<String, dynamic> toJson() => {
        'weekLabel': weekLabel,
        'hasSessions': hasSessions,
        'rawContentHtml': rawContentHtml,
      };
}
