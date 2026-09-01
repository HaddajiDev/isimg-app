import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_exception.dart';
import '../models/calendar.dart';
import '../providers/academic_year_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/calendar_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_card.dart';
import '../widgets/offline_banner.dart';
import '../widgets/state_views.dart';

class CalendarScreen extends ConsumerWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final calendarAsync = ref.watch(calendarProvider);
    final year = ref.watch(academicYearProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Calendrier universitaire'),
            if (year != null)
              Text(
                year,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textMuted,
                      fontSize: 12,
                    ),
              ),
          ],
        ),
      ),
      body: calendarAsync.when(
        loading: () => const _CalendarLoadingPlaceholder(),
        error: (error, _) {
          if (error is ApiException && error.isSessionExpired) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ref.read(authProvider.notifier).handleSessionExpired();
            });
          }
          final offline = error is ApiException && error.isConnectivityProblem;
          return MessageView(
            icon: offline ? Icons.wifi_off_rounded : Icons.cloud_off_rounded,
            title: offline ? 'Pas de connexion' : 'Impossible de charger le calendrier',
            subtitle: offline
                ? 'Le calendrier n\'a pas encore été enregistré hors ligne.'
                : (error is ApiException ? error.code : 'Vérifiez votre connexion.'),
            tint: AppColors.danger,
            action: FilledButton(
              onPressed: () => ref.invalidate(calendarProvider),
              child: const Text('Réessayer'),
            ),
          );
        },
        data: (view) => Column(
          children: [
            if (view.capturedAt case final capturedAt?) OfflineBanner(capturedAt: capturedAt),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => ref.refresh(calendarProvider.future),
                color: AppColors.purple,
                backgroundColor: AppColors.surfaceRaised,
                child: _CalendarContent(calendar: view.calendar),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CalendarLoadingPlaceholder extends ConsumerWidget {
  const _CalendarLoadingPlaceholder();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final peeked = ref.watch(calendarCachePeekProvider);
    return peeked.when(
      data: (cached) => cached == null
          ? const _CalendarSkeleton()
          : Stack(
              children: [
                _CalendarContent(calendar: cached.calendar),
                const Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: LinearProgressIndicator(
                    minHeight: 2,
                    color: AppColors.purple,
                    backgroundColor: Colors.transparent,
                  ),
                ),
              ],
            ),
      loading: () => const _CalendarSkeleton(),
      error: (_, _) => const _CalendarSkeleton(),
    );
  }
}

class _CalendarContent extends StatelessWidget {
  final UniversityCalendar calendar;

  const _CalendarContent({required this.calendar});

  @override
  Widget build(BuildContext context) {
    if (!calendar.hasEvents) {
      return LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: const MessageView(
              icon: Icons.event_outlined,
              title: 'Aucun événement',
              subtitle: 'Le calendrier de l\'année n\'est pas encore publié.',
            ),
          ),
        ),
      );
    }

    final now = DateTime.now();
    final next = _firstUpcoming(calendar.events, now);
    final semestres = calendar.events.map((e) => e.semestre).toSet().toList()..sort();

    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xxl),
      children: [
        if (next != null) ...[
          Padding(
            padding: const EdgeInsets.only(left: AppSpacing.xs, bottom: AppSpacing.sm),
            child: Text('Prochain événement', style: Theme.of(context).textTheme.titleMedium),
          ),
          _NextEventCard(event: next, now: now),
          const SizedBox(height: AppSpacing.xl),
        ],
        for (final sem in semestres) ...[
          _SemesterHeader(semestre: sem),
          const SizedBox(height: AppSpacing.sm),
          _Timeline(events: calendar.forSemestre(sem), now: now, nextId: next?.id),
          const SizedBox(height: AppSpacing.lg),
        ],
      ],
    );
  }

  static CalendarEvent? _firstUpcoming(List<CalendarEvent> events, DateTime now) {
    for (final e in events) {
      if (!e.isPast(now)) return e;
    }
    return null;
  }
}

class _SemesterHeader extends StatelessWidget {
  final int semestre;

  const _SemesterHeader({required this.semestre});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: AppColors.purple,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          semestre == 0 ? 'Année' : 'Semestre $semestre',
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ],
    );
  }
}

class _NextEventCard extends StatelessWidget {
  final CalendarEvent event;
  final DateTime now;

  const _NextEventCard({required this.event, required this.now});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ongoing = event.isOngoing(now);
    final color = ongoing ? AppColors.green : AppColors.purple;

    return AppCard(
      accent: color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _StatusChip(label: ongoing ? 'En cours' : _countdown(event.start, now), color: color),
              const Spacer(),
              Text(
                'S${event.semestre}',
                style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            event.name,
            textAlign: TextAlign.right,
            textDirection: TextDirection.rtl,
            style: theme.textTheme.titleLarge?.copyWith(height: 1.3, fontSize: 20),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Icon(Icons.calendar_today_rounded, size: 16, color: color),
              const SizedBox(width: AppSpacing.sm),
              Text(_fullRange(event), style: theme.textTheme.bodyMedium),
            ],
          ),
          if (event.concerned != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              event.concerned!,
              textAlign: TextAlign.right,
              textDirection: TextDirection.rtl,
              style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
            ),
          ],
        ],
      ),
    );
  }
}

class _Timeline extends StatelessWidget {
  final List<CalendarEvent> events;
  final DateTime now;
  final int? nextId;

  const _Timeline({required this.events, required this.now, required this.nextId});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < events.length; i++)
          _TimelineTile(
            event: events[i],
            now: now,
            isNext: events[i].id != null && events[i].id == nextId,
            isFirst: i == 0,
            isLast: i == events.length - 1,
          ),
      ],
    );
  }
}

class _TimelineTile extends StatelessWidget {
  final CalendarEvent event;
  final DateTime now;
  final bool isNext;
  final bool isFirst;
  final bool isLast;

  const _TimelineTile({
    required this.event,
    required this.now,
    required this.isNext,
    required this.isFirst,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mono = theme.extension<AppTypography>()!.monoFamily;
    final ongoing = event.isOngoing(now);
    final past = event.isPast(now);
    final color = ongoing
        ? AppColors.green
        : isNext
            ? AppColors.purple
            : past
                ? AppColors.textMuted
                : AppColors.info;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 24,
            child: Column(
              children: [
                Container(width: 2, height: 6, color: isFirst ? Colors.transparent : AppColors.border),
                Container(
                  height: 14,
                  width: 14,
                  decoration: BoxDecoration(
                    color: past && !ongoing ? AppColors.surface : color,
                    shape: BoxShape.circle,
                    border: Border.all(color: color, width: 2),
                  ),
                ),
                Expanded(
                  child: Container(width: 2, color: isLast ? Colors.transparent : AppColors.border),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Opacity(
                opacity: past && !ongoing ? 0.55 : 1,
                child: AppCard(
                  accent: (isNext || ongoing) ? color : null,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _DateBadge(event: event, color: color, mono: mono),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (ongoing || isNext)
                              Padding(
                                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                                child: _StatusChip(label: ongoing ? 'En cours' : 'À venir', color: color),
                              ),
                            Text(
                              event.name,
                              textAlign: TextAlign.right,
                              textDirection: TextDirection.rtl,
                              style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            if (event.concerned != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                event.concerned!,
                                textAlign: TextAlign.right,
                                textDirection: TextDirection.rtl,
                                style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DateBadge extends StatelessWidget {
  final CalendarEvent event;
  final Color color;
  final String mono;

  const _DateBadge({required this.event, required this.color, required this.mono});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final start = event.start;

    return Container(
      width: 52,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: color.withValues(alpha: 0.26)),
      ),
      child: Column(
        children: [
          Text(
            start == null ? '--' : start.day.toString().padLeft(2, '0'),
            style: theme.textTheme.titleLarge?.copyWith(fontFamily: mono, color: color, height: 1),
          ),
          const SizedBox(height: 2),
          Text(
            start == null ? '' : _mois[start.month - 1],
            style: theme.textTheme.bodySmall?.copyWith(color: color, fontSize: 11),
          ),
          if (event.isRange && event.end != null) ...[
            const SizedBox(height: 2),
            Text(
              '→ ${event.end!.day.toString().padLeft(2, '0')} ${_mois[event.end!.month - 1]}',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted, fontSize: 9),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.34)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
      ),
    );
  }
}

class _CalendarSkeleton extends StatelessWidget {
  const _CalendarSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xxl),
      children: const [
        SkeletonBox(height: 130, width: double.infinity),
        SizedBox(height: AppSpacing.xl),
        SkeletonBox(height: 20, width: 120),
        SizedBox(height: AppSpacing.md),
        SkeletonBox(height: 72, width: double.infinity),
        SizedBox(height: AppSpacing.sm),
        SkeletonBox(height: 72, width: double.infinity),
      ],
    );
  }
}

String _countdown(DateTime? start, DateTime now) {
  if (start == null) return 'À venir';
  final diff = DateTime(start.year, start.month, start.day)
      .difference(DateTime(now.year, now.month, now.day))
      .inDays;
  if (diff <= 0) return "Aujourd'hui";
  if (diff == 1) return 'Demain';
  if (diff < 7) return 'Dans $diff jours';
  if (diff < 30) return 'Dans ${(diff / 7).floor()} sem.';
  return 'Dans ${(diff / 30).floor()} mois';
}

String _fullRange(CalendarEvent e) {
  final s = e.start;
  if (s == null) return 'Date à confirmer';
  final start = '${s.day} ${_mois[s.month - 1]} ${s.year}';
  if (!e.isRange || e.end == null) return start;
  final end = e.end!;
  return 'Du ${s.day} ${_mois[s.month - 1]} au ${end.day} ${_mois[end.month - 1]} ${end.year}';
}

const _mois = [
  'janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin',
  'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'
];
