import 'package:flutter/material.dart';

import '../models/seance.dart';
import '../theme/app_theme.dart';

/// Timetable laid out the way the school prints it: one column per day, one row
/// per time slot, each class a coloured block.
///
/// The grid is wider than a phone, so it scrolls sideways with the slot column
/// pinned — a phone-shaped rewrite would lose the week-at-a-glance reading that
/// makes this layout worth keeping.
class ScheduleGrid extends StatelessWidget {
  final List<Seance> sessions;

  /// Monday of the displayed week, used for the dates in the header.
  final DateTime weekStart;

  const ScheduleGrid({super.key, required this.sessions, required this.weekStart});

  static const _slotColumnWidth = 74.0;
  static const _dayColumnWidth = 158.0;
  static const _rowHeight = 96.0;
  static const _headerHeight = 52.0;

  /// Slots in the order they occur, taken from the data rather than a fixed
  /// list so an unusual timetable still renders every class it contains.
  List<String> get _slots {
    final seen = <String, int>{};
    for (final seance in sessions) {
      seen.putIfAbsent(seance.slot, () => seance.startMinutes);
    }
    final slots = seen.keys.toList()
      ..sort((a, b) => seen[a]!.compareTo(seen[b]!));
    return slots;
  }

  /// Monday through Saturday, extended if the timetable somehow runs later.
  List<int> get _weekdays {
    final latest = sessions.fold(6, (max, s) => s.weekday > max ? s.weekday : max);
    return [for (var day = 1; day <= latest; day++) day];
  }

  Seance? _at(int weekday, String slot) {
    for (final seance in sessions) {
      if (seance.weekday == weekday && seance.slot == slot) return seance;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final slots = _slots;
    final weekdays = _weekdays;

    // The slot column sits outside the horizontal scroll view so the times stay
    // readable however far right the week is scrolled; only the day columns move.
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
                  for (final slot in slots) _SlotCell(slot: slot),
                ],
              ),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _HeaderRow(weekdays: weekdays, weekStart: weekStart),
                      for (final slot in slots)
                        Row(
                          children: [
                            for (final weekday in weekdays)
                              _GridCell(seance: _at(weekday, slot)),
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

/// The "Séance" label above the pinned slot column.
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

  const _HeaderRow({required this.weekdays, required this.weekStart});

  static const _names = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'];

  String _date(int weekday) {
    final day = weekStart.add(Duration(days: weekday - 1));
    return '${day.day.toString().padLeft(2, '0')}/${day.month.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final theme = Theme.of(context);

    return Container(
      color: AppColors.surfaceRaised,
      child: Row(
        children: [
          for (final weekday in weekdays)
            Builder(
              builder: (context) {
                final day = weekStart.add(Duration(days: weekday - 1));
                final isToday = day.year == today.year &&
                    day.month == today.month &&
                    day.day == today.day;
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

  const _SlotCell({required this.slot});

  @override
  Widget build(BuildContext context) {
    // Split so the two times stack instead of overflowing the narrow column.
    final parts = slot.split('-');

    return Container(
      width: ScheduleGrid._slotColumnWidth,
      height: ScheduleGrid._rowHeight,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: AppColors.surfaceRaised,
        border: Border(
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
                    color: AppColors.textSecondary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
            ),
        ],
      ),
    );
  }
}

class _GridCell extends StatelessWidget {
  final Seance? seance;

  const _GridCell({this.seance});

  /// Colour per kind of class, so a week can be read at a glance. The school's
  /// own palette is not reused: it is light-theme pastel and unreadable here.
  static Color _tint(SeanceType type) => switch (type) {
        SeanceType.cours => AppColors.purple,
        SeanceType.td => AppColors.green,
        SeanceType.tp => AppColors.info,
        SeanceType.autre => AppColors.textMuted,
      };

  @override
  Widget build(BuildContext context) {
    final current = seance;

    return Container(
      width: ScheduleGrid._dayColumnWidth,
      height: ScheduleGrid._rowHeight,
      decoration: const BoxDecoration(
        border: Border(
          right: BorderSide(color: AppColors.border),
          top: BorderSide(color: AppColors.border),
        ),
      ),
      child: current == null ? null : _SeanceBlock(seance: current, tint: _tint(current.type)),
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
