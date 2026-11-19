import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/format.dart';
import '../models/absences.dart';
import '../models/seance.dart';
import '../providers/absences_provider.dart';
import '../theme/app_theme.dart';

bool _isSameDate(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

(int, int)? _parseSlotRange(String slot) {
  final match = RegExp(r'^(\d{1,2})[:h](\d{2})\s*-\s*(\d{1,2})[:h](\d{2})').firstMatch(slot.trim());
  if (match == null) return null;
  return (int.parse(match[1]!) * 60 + int.parse(match[2]!), int.parse(match[3]!) * 60 + int.parse(match[4]!));
}

Color _tint(SeanceType type) => switch (type) {
  SeanceType.cours => AppColors.purple,
  SeanceType.td => AppColors.green,
  SeanceType.tp => AppColors.info,
  SeanceType.autre => AppColors.neutral,
};

/// The text drawn in a class cell: type, matière, teacher, room.
TextSpan _classSpan(BuildContext context, Seance seance, {required bool absent}) {
  final tint = absent ? AppColors.danger : _tint(seance.type);
  final label = [
    if (absent) 'ABSENT' else if (seance.type.label.isNotEmpty) seance.type.label,
    if (seance.rattrapage) 'Ratt.',
  ].join(' · ');
  return TextSpan(
    children: [
      if (label.isNotEmpty)
        TextSpan(
          text: '$label\n',
          style: TextStyle(color: tint, fontWeight: FontWeight.w800),
        ),
      TextSpan(
        text: seance.matiere,
        style: TextStyle(color: context.c.textPrimary, fontWeight: FontWeight.w600),
      ),
      if (seance.enseignant case final teacher?)
        TextSpan(
          text: '\n$teacher',
          style: TextStyle(color: context.c.textSecondary),
        ),
      if (seance.salle case final room?)
        TextSpan(
          text: '\n@$room',
          style: TextStyle(color: tint, fontWeight: FontWeight.w700),
        ),
    ],
  );
}

const _lineHeight = 1.15;
const _maxFont = 11.0;
const _minFont = 6.0;

/// Largest font size (≤ [cap]) at which [span] wrapped to [width] fits [height].
double _fitSize(
  TextSpan span,
  TextStyle base,
  TextScaler scaler, {
  required double width,
  required double height,
  double cap = _maxFont,
}) {
  for (var size = cap; size > _minFont; size -= 0.5) {
    final painter = TextPainter(
      text: TextSpan(
        style: base.copyWith(fontSize: size, height: _lineHeight),
        children: [span],
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      textScaler: scaler,
    )..layout(maxWidth: width);
    final fits = painter.height <= height;
    painter.dispose();
    if (fits) return size;
  }
  return _minFont;
}

/// The whole week on one screen, the way the school prints it: days across,
/// séances down, every cell sized to fit and its text shrunk until it does.
/// Nothing scrolls; tapping a class opens its full details.
class CompactScheduleGrid extends StatelessWidget {
  final List<Seance> sessions;
  final DateTime weekStart;

  /// Keys (`Absences.slotKey`) of the classes this student missed.
  final Set<String> absentKeys;

  const CompactScheduleGrid({
    super.key,
    required this.sessions,
    required this.weekStart,
    this.absentKeys = const {},
  });

  static const _slotColumnWidth = 42.0;
  static const _headerHeight = 38.0;
  static const _dayNames = ['Lun.', 'Mar.', 'Mer.', 'Jeu.', 'Ven.', 'Sam.', 'Dim.'];

  List<String> get _slots {
    final seen = <String, int>{};
    for (final seance in sessions) {
      seen.putIfAbsent(seance.slot, () => seance.startMinutes);
    }
    return seen.keys.toList()..sort((a, b) => seen[a]!.compareTo(seen[b]!));
  }

  List<int> get _weekdays {
    final latest = sessions.fold(6, (max, s) => s.weekday > max ? s.weekday : max);
    return [for (var day = 1; day <= latest; day++) day];
  }

  @override
  Widget build(BuildContext context) {
    final slots = _slots;
    final weekdays = _weekdays;
    final now = DateTime.now();
    final todayWeekday = weekdays
        .where((d) => _isSameDate(weekStart.add(Duration(days: d - 1)), now))
        .firstOrNull;
    final nowMinutes = now.hour * 60 + now.minute;
    final currentSlot = todayWeekday == null
        ? null
        : slots.where((s) {
            final range = _parseSlotRange(s);
            return range != null && nowMinutes >= range.$1 && nowMinutes < range.$2;
          }).firstOrNull;

    final border = BorderSide(color: context.c.border, width: 0.7);

    return LayoutBuilder(
      builder: (context, box) {
        // One text size for the whole week (like the printed timetable): the
        // largest that every single-class cell can hold. Cells with two
        // classes stacked shrink further on their own.
        final base = DefaultTextStyle.of(context).style;
        final scaler = MediaQuery.textScalerOf(context);
        final textWidth =
            (box.maxWidth - 2 - _slotColumnWidth) / weekdays.length - border.width - 2 * _cellPadH;
        final textHeight = (box.maxHeight - 2 - _headerHeight) / slots.length - border.width - 2 * _cellPadV;
        var shared = _maxFont;
        for (final seance in sessions) {
          if (sessions.where((o) => o.weekday == seance.weekday && o.slot == seance.slot).length > 1) {
            continue;
          }
          final date = weekStart.add(Duration(days: seance.weekday - 1));
          final absent =
              seance.seanceIndex > 0 && absentKeys.contains(Absences.slotKey(date, seance.seanceIndex));
          shared = _fitSize(
            _classSpan(context, seance, absent: absent),
            base,
            scaler,
            width: textWidth,
            height: textHeight,
            cap: shared,
          );
        }
        return _buildGrid(context, slots, weekdays, todayWeekday, currentSlot, border, shared);
      },
    );
  }

  static const _cellPadH = 2.0;
  static const _cellPadV = 3.0;

  Widget _buildGrid(
    BuildContext context,
    List<String> slots,
    List<int> weekdays,
    int? todayWeekday,
    String? currentSlot,
    BorderSide border,
    double fontSize,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: context.c.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: context.c.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          SizedBox(
            height: _headerHeight,
            child: Row(
              children: [
                _HeaderCell(
                  width: _slotColumnWidth,
                  border: border,
                  child: Text(
                    'Séance',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: context.c.textSecondary,
                    ),
                  ),
                ),
                for (final weekday in weekdays)
                  Expanded(
                    child: _DayHeader(
                      name: _dayNames[weekday - 1],
                      date: weekStart.add(Duration(days: weekday - 1)),
                      isToday: weekday == todayWeekday,
                      border: border,
                    ),
                  ),
              ],
            ),
          ),
          for (final slot in slots)
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SlotCell(slot: slot, isCurrent: slot == currentSlot, border: border),
                  for (final weekday in weekdays)
                    Expanded(
                      child: _Cell(
                        seances: [
                          for (final s in sessions)
                            if (s.weekday == weekday && s.slot == slot) s,
                        ],
                        date: weekStart.add(Duration(days: weekday - 1)),
                        isToday: weekday == todayWeekday,
                        isNow: weekday == todayWeekday && slot == currentSlot,
                        absentKeys: absentKeys,
                        border: border,
                        fontSize: fontSize,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  final double width;
  final BorderSide border;
  final Widget child;

  const _HeaderCell({required this.width, required this.border, required this.child});

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: context.c.surfaceRaised,
      border: Border(right: border, bottom: border),
    ),
    child: child,
  );
}

class _DayHeader extends StatelessWidget {
  final String name;
  final DateTime date;
  final bool isToday;
  final BorderSide border;

  const _DayHeader({required this.name, required this.date, required this.isToday, required this.border});

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall;
    final color = isToday ? AppColors.purple : context.c.textPrimary;
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isToday ? AppColors.purpleGlow : context.c.surfaceRaised,
        border: Border(right: border, bottom: border),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              name,
              style: style?.copyWith(fontSize: 11, fontWeight: FontWeight.w700, color: color),
            ),
            Text(
              '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}',
              style: style?.copyWith(
                fontSize: 9.5,
                color: isToday ? AppColors.purple : context.c.textMuted,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SlotCell extends StatelessWidget {
  final String slot;
  final bool isCurrent;
  final BorderSide border;

  const _SlotCell({required this.slot, required this.isCurrent, required this.border});

  @override
  Widget build(BuildContext context) {
    final color = isCurrent ? AppColors.purple : context.c.textSecondary;
    return Container(
      width: CompactScheduleGrid._slotColumnWidth,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isCurrent ? AppColors.purpleGlow : context.c.surfaceRaised,
        border: Border(right: border, bottom: border),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final part in slot.split('-'))
              Text(
                part.trim(),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 10,
                  height: 1.25,
                  fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                  color: color,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  final List<Seance> seances;
  final DateTime date;
  final bool isToday;
  final bool isNow;
  final Set<String> absentKeys;
  final BorderSide border;
  final double fontSize;

  const _Cell({
    required this.seances,
    required this.date,
    required this.isToday,
    required this.isNow,
    required this.absentKeys,
    required this.border,
    required this.fontSize,
  });

  bool _isAbsent(Seance s) => s.seanceIndex > 0 && absentKeys.contains(Absences.slotKey(date, s.seanceIndex));

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isToday && seances.isEmpty ? AppColors.purple.withValues(alpha: 0.04) : null,
        border: Border(right: border, bottom: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final seance in seances)
            Expanded(
              child: _ClassBlock(
                seance: seance,
                date: date,
                absent: _isAbsent(seance),
                isNow: isNow,
                fontSize: fontSize,
              ),
            ),
        ],
      ),
    );
  }
}

class _ClassBlock extends StatelessWidget {
  final Seance seance;
  final DateTime date;
  final bool absent;
  final bool isNow;
  final double fontSize;

  const _ClassBlock({
    required this.seance,
    required this.date,
    required this.absent,
    required this.isNow,
    required this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    final tint = absent ? AppColors.danger : _tint(seance.type);

    return Material(
      color: tint.withValues(alpha: absent ? 0.20 : 0.15),
      shape: isNow ? RoundedRectangleBorder(side: BorderSide(color: tint, width: 1.5)) : null,
      child: InkWell(
        onTap: () => _showDetails(context, tint),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: CompactScheduleGrid._cellPadH,
            vertical: CompactScheduleGrid._cellPadV,
          ),
          child: _FitText(
            span: _classSpan(context, seance, absent: absent),
            cap: fontSize,
          ),
        ),
      ),
    );
  }

  void _showDetails(BuildContext context, Color tint) {
    const days = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'];
    final theme = Theme.of(context);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.c.surfaceRaised,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.8),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: AppSpacing.sm,
                  children: [
                    if (seance.type.label.isNotEmpty) _Badge(seance.type.label, _tint(seance.type)),
                    if (absent) const _Badge('Absent', AppColors.danger),
                    if (seance.rattrapage) const _Badge('Rattrapage', AppColors.warning),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(seance.matiere, style: theme.textTheme.titleLarge),
                const SizedBox(height: AppSpacing.md),
                _DetailRow(
                  Icons.schedule_rounded,
                  '${days[seance.weekday - 1]} ${date.day.toString().padLeft(2, '0')}/'
                  '${date.month.toString().padLeft(2, '0')} · ${seance.slot.replaceAll('-', ' – ')}',
                ),
                if (seance.enseignant case final teacher?) _DetailRow(Icons.person_outline_rounded, teacher),
                if (seance.salle case final room?) _DetailRow(Icons.meeting_room_outlined, room),
                const SizedBox(height: AppSpacing.sm),
                const Divider(),
                const SizedBox(height: AppSpacing.sm),
                _SubjectAbsencesSection(matiere: seance.matiere),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SubjectAbsencesSection extends ConsumerWidget {
  final String matiere;

  const _SubjectAbsencesSection({required this.matiere});

  static const _days = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final async = ref.watch(absencesProvider);
    final absences = async.valueOrNull?.absences;

    Widget note(String text) =>
        Text(text, style: theme.textTheme.bodyMedium?.copyWith(color: context.c.textMuted));

    final title = Text('Absences dans cette matière', style: theme.textTheme.titleSmall);

    if (absences == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          title,
          const SizedBox(height: AppSpacing.sm),
          if (async.isLoading)
            const LinearProgressIndicator(minHeight: 2, color: AppColors.purple)
          else
            note('Les absences ne sont pas disponibles pour le moment.'),
        ],
      );
    }

    final subject = absences.forSubject(matiere);
    if (!subject.isTracked) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          title,
          const SizedBox(height: AppSpacing.sm),
          note("Cette matière n'apparaît pas dans le suivi des absences."),
        ],
      );
    }

    final stats = subject.stats;
    final taux = stats?.taux;
    final eliminated = stats?.eliminated ?? false;
    final color = eliminated || (taux ?? 0) >= subject.threshold
        ? AppColors.danger
        : subject.count == 0
        ? AppColors.green
        : (taux ?? 0) >= subject.threshold * 0.66
        ? AppColors.warning
        : AppColors.info;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        title,
        const SizedBox(height: AppSpacing.sm),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              '${subject.count}',
              style: theme.textTheme.headlineSmall?.copyWith(color: color, fontWeight: FontWeight.w700),
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              subject.count > 1 ? 'absences' : 'absence',
              style: theme.textTheme.bodyMedium?.copyWith(color: context.c.textSecondary),
            ),
            const Spacer(),
            if (taux != null)
              Text(
                '${_pct(taux)} %',
                style: theme.textTheme.bodySmall?.copyWith(color: color, fontWeight: FontWeight.w600),
              ),
          ],
        ),
        if (eliminated) ...[
          const SizedBox(height: AppSpacing.xs),
          _Badge(stats?.elimineLabel ?? 'Éliminé', AppColors.danger),
        ],
        if (stats != null && stats.parType.any((t) => t.nbre > 0)) ...[
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final t in stats.parType)
                if (t.nbre > 0) _Badge('${t.nbre} ${t.type}', context.c.textSecondary),
            ],
          ),
        ],
        if (subject.entries.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          for (final e in subject.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Row(
                children: [
                  Icon(Icons.event_busy_rounded, size: 16, color: color),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      [
                        if (e.day case final d?) '${_days[d.weekday - 1]} ${frDate(d)}' else 'Date inconnue',
                        if (e.seance != null) 'Séance ${e.seance}',
                        if (e.type != null) e.type!,
                      ].join(' · '),
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
        ] else if (subject.count == 0) ...[
          const SizedBox(height: AppSpacing.xs),
          note('Aucune absence dans cette matière.'),
        ],
      ],
    );
  }

  static String _pct(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;

  const _Badge(this.text, this.color);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(AppRadius.pill),
      border: Border.all(color: color.withValues(alpha: 0.4)),
    ),
    child: Text(
      text,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color, fontWeight: FontWeight.w700),
    ),
  );
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _DetailRow(this.icon, this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: Row(
      children: [
        Icon(icon, size: 18, color: context.c.textMuted),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyMedium)),
      ],
    ),
  );
}

/// Centered, wrapping text at the largest size up to [cap] that fits its box.
class _FitText extends StatelessWidget {
  final TextSpan span;
  final double cap;

  const _FitText({required this.span, required this.cap});

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final base = DefaultTextStyle.of(context).style;

    return LayoutBuilder(
      builder: (context, box) {
        final size = _fitSize(span, base, scaler, width: box.maxWidth, height: box.maxHeight, cap: cap);
        return ClipRect(
          child: Center(
            child: Text.rich(
              TextSpan(
                style: base.copyWith(fontSize: size, height: _lineHeight),
                children: [span],
              ),
              textAlign: TextAlign.center,
              textScaler: scaler,
            ),
          ),
        );
      },
    );
  }
}
