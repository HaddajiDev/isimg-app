import 'package:flutter/material.dart';

import '../models/seance.dart';
import '../theme/app_theme.dart';

bool _isSameDate(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

(int, int)? _parseSlotRange(String slot) {
  final match =
      RegExp(r'^(\d{1,2})[:h](\d{2})\s*-\s*(\d{1,2})[:h](\d{2})').firstMatch(slot.trim());
  if (match == null) return null;
  return (
    int.parse(match[1]!) * 60 + int.parse(match[2]!),
    int.parse(match[3]!) * 60 + int.parse(match[4]!),
  );
}

class ScheduleGrid extends StatelessWidget {
  final List<Seance> sessions;

  final DateTime weekStart;

  const ScheduleGrid({super.key, required this.sessions, required this.weekStart});

  static const _slotColumnWidth = 74.0;
  static const _dayColumnWidth = 158.0;
  static const _rowHeight = 96.0;
  static const _headerHeight = 52.0;

  List<String> get _slots {
    final seen = <String, int>{};
    for (final seance in sessions) {
      seen.putIfAbsent(seance.slot, () => seance.startMinutes);
    }
    final slots = seen.keys.toList()
      ..sort((a, b) => seen[a]!.compareTo(seen[b]!));
    return slots;
  }

  List<int> get _weekdays {
    final latest = sessions.fold(6, (max, s) => s.weekday > max ? s.weekday : max);
    return [for (var day = 1; day <= latest; day++) day];
  }

  List<Seance> _at(int weekday, String slot) => [
        for (final seance in sessions)
          if (seance.weekday == weekday && seance.slot == slot) seance,
      ];

  int _stackDepth(String slot) {
    final perDay = <int, int>{};
    for (final seance in sessions) {
      if (seance.slot == slot) {
        perDay[seance.weekday] = (perDay[seance.weekday] ?? 0) + 1;
      }
    }
    return perDay.values.fold(1, (deepest, n) => n > deepest ? n : deepest);
  }

  int? _todayWeekday(List<int> weekdays) {
    final now = DateTime.now();
    for (final weekday in weekdays) {
      if (_isSameDate(weekStart.add(Duration(days: weekday - 1)), now)) return weekday;
    }
    return null;
  }

  String? _currentSlot(List<String> slots, int? todayWeekday) {
    if (todayWeekday == null) return null;
    final nowMinutes = DateTime.now().hour * 60 + DateTime.now().minute;
    for (final slot in slots) {
      final range = _parseSlotRange(slot);
      if (range != null && nowMinutes >= range.$1 && nowMinutes < range.$2) return slot;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final slots = _slots;
    final weekdays = _weekdays;
    final todayWeekday = _todayWeekday(weekdays);
    final currentSlot = _currentSlot(slots, todayWeekday);
    final heights = {
      for (final slot in slots) slot: _rowHeight * _stackDepth(slot),
    };

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.border),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _SlotHeaderCell(),
                  for (final slot in slots)
                    _SlotCell(
                      slot: slot,
                      isCurrent: slot == currentSlot,
                      height: heights[slot]!,
                    ),
                ],
              ),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _HeaderRow(
                        weekdays: weekdays,
                        weekStart: weekStart,
                        todayWeekday: todayWeekday,
                      ),
                      for (final slot in slots)
                        Row(
                          children: [
                            for (final weekday in weekdays)
                              _GridCell(
                                seances: _at(weekday, slot),
                                isToday: weekday == todayWeekday,
                                isCurrentSlot: slot == currentSlot,
                                height: heights[slot]!,
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SlotHeaderCell extends StatelessWidget {
  const _SlotHeaderCell();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: ScheduleGrid._slotColumnWidth,
      height: ScheduleGrid._headerHeight,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: AppColors.surfaceRaised,
        border: Border(right: BorderSide(color: AppColors.border)),
      ),
      child: Text(
        'Séance',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
      ),
    );
  }
}

class _HeaderRow extends StatelessWidget {
  final List<int> weekdays;
  final DateTime weekStart;
  final int? todayWeekday;

  const _HeaderRow({required this.weekdays, required this.weekStart, required this.todayWeekday});

  static const _names = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'];

  String _date(int weekday) {
    final day = weekStart.add(Duration(days: weekday - 1));
    return '${day.day.toString().padLeft(2, '0')}/${day.month.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      color: AppColors.surfaceRaised,
      child: Row(
        children: [
          for (final weekday in weekdays)
            Builder(
              builder: (context) {
                final isToday = weekday == todayWeekday;
                return Container(
                  width: ScheduleGrid._dayColumnWidth,
                  height: ScheduleGrid._headerHeight,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isToday ? AppColors.purpleGlow : null,
                    border: const Border(right: BorderSide(color: AppColors.border)),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _names[weekday - 1],
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isToday ? AppColors.purple : AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        _date(weekday),
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 11,
                          color: isToday ? AppColors.purple : AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _SlotCell extends StatelessWidget {
  final String slot;
  final bool isCurrent;
  final double height;

  const _SlotCell({required this.slot, required this.isCurrent, required this.height});

  @override
  Widget build(BuildContext context) {
    final parts = slot.split('-');

    return Container(
      width: ScheduleGrid._slotColumnWidth,
      height: height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isCurrent ? AppColors.purpleGlow : AppColors.surfaceRaised,
        border: const Border(
          right: BorderSide(color: AppColors.border),
          top: BorderSide(color: AppColors.border),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (final part in parts)
            Text(
              part.trim(),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 11,
                    fontWeight: isCurrent ? FontWeight.w700 : null,
                    color: isCurrent ? AppColors.purple : AppColors.textSecondary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
            ),
        ],
      ),
    );
  }
}

class _GridCell extends StatelessWidget {
  final List<Seance> seances;
  final bool isToday;
  final bool isCurrentSlot;
  final double height;

  const _GridCell({
    required this.seances,
    required this.isToday,
    required this.isCurrentSlot,
    required this.height,
  });

  static Color _tint(SeanceType type) => switch (type) {
        SeanceType.cours => AppColors.purple,
        SeanceType.td => AppColors.green,
        SeanceType.tp => AppColors.info,
        SeanceType.autre => AppColors.textMuted,
      };

  @override
  Widget build(BuildContext context) {
    final washAlpha = (isToday ? 0.05 : 0.0) + (isCurrentSlot ? 0.05 : 0.0);

    return Container(
      width: ScheduleGrid._dayColumnWidth,
      height: height,
      decoration: BoxDecoration(
        color: washAlpha > 0 ? AppColors.purple.withValues(alpha: washAlpha) : null,
        border: Border(
          right: BorderSide(color: AppColors.border),
          top: BorderSide(color: AppColors.border),
        ),
      ),

      child: seances.isEmpty
          ? null
          : Column(
              children: [
                for (final seance in seances)
                  Expanded(
                    child: _SeanceBlock(seance: seance, tint: _tint(seance.type)),
                  ),
              ],
            ),
    );
  }
}

class _SeanceBlock extends StatelessWidget {
  final Seance seance;
  final Color tint;

  const _SeanceBlock({required this.seance, required this.tint});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final prefix = seance.type.label;

    return Container(
      margin: const EdgeInsets.all(3),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 6),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: tint.withValues(alpha: 0.34)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (prefix.isNotEmpty || seance.rattrapage)
            Row(
              children: [
                if (prefix.isNotEmpty)
                  Text(
                    prefix,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      color: tint,
                    ),
                  ),
                if (seance.rattrapage) ...[
                  if (prefix.isNotEmpty) const SizedBox(width: 4),

                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        'RATTRAPAGE',
                        maxLines: 1,
                        overflow: TextOverflow.clip,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                          color: AppColors.warning,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          Expanded(
            child: Text(
              seance.matiere,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 11,
                height: 1.2,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          if (seance.enseignant case final teacher?)
            Text(
              teacher,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 9.5,
                color: AppColors.textSecondary,
              ),
            ),
          if (seance.salle case final room?)
            Text(
              room,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
                color: tint,
              ),
            ),
        ],
      ),
    );
  }
}
