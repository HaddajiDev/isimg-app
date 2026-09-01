import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_exception.dart';
import '../models/student.dart';
import '../providers/auth_provider.dart';
import '../providers/student_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_card.dart';
import '../widgets/offline_banner.dart';
import '../widgets/state_views.dart';
import '../widgets/student_avatar.dart';

class EtudiantScreen extends ConsumerWidget {
  const EtudiantScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final studentAsync = ref.watch(studentProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Étudiant')),
      body: studentAsync.when(
        loading: () => const _StudentLoadingPlaceholder(),
        error: (error, _) {
          if (error is ApiException && error.isSessionExpired) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ref.read(authProvider.notifier).handleSessionExpired();
            });
          }
          final offline = error is ApiException && error.isConnectivityProblem;
          return MessageView(
            icon: offline ? Icons.wifi_off_rounded : Icons.cloud_off_rounded,
            title: offline ? 'Pas de connexion' : 'Impossible de charger la fiche',
            subtitle: offline
                ? 'Votre fiche n\'a pas encore été enregistrée hors ligne.'
                : (error is ApiException ? error.code : 'Vérifiez votre connexion.'),
            tint: AppColors.danger,
            action: FilledButton(
              onPressed: () => ref.invalidate(studentProvider),
              child: const Text('Réessayer'),
            ),
          );
        },
        data: (view) => Column(
          children: [
            if (view.capturedAt case final capturedAt?) OfflineBanner(capturedAt: capturedAt),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => ref.refresh(studentProvider.future),
                color: AppColors.purple,
                backgroundColor: AppColors.surfaceRaised,
                child: _StudentContent(student: view.student),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StudentLoadingPlaceholder extends ConsumerWidget {
  const _StudentLoadingPlaceholder();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final peeked = ref.watch(studentCachePeekProvider);
    return peeked.when(
      data: (cached) => cached == null
          ? const _StudentSkeleton()
          : Stack(
              children: [
                _StudentContent(student: cached.student),
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
      loading: () => const _StudentSkeleton(),
      error: (_, _) => const _StudentSkeleton(),
    );
  }
}

class _StudentContent extends StatelessWidget {
  final StudentInfo student;

  const _StudentContent({required this.student});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xxl),
      children: [
        _HeaderCard(student: student),
        const SizedBox(height: AppSpacing.lg),
        _Section(
          title: 'Identité',
          rows: [
            _Row(Icons.badge_outlined, 'CIN', student.cin),
            _Row(Icons.tag_rounded, 'N° inscription', student.nce),
            _Row(Icons.cake_outlined, 'Date de naissance', _frDate(student.dateNaissance)),
            _Row(Icons.place_outlined, 'Lieu de naissance', student.lieuNaissance,
                arValue: student.lieuNaissanceAr),
            _Row(Icons.wc_rounded, 'Sexe', _sexe(student.sexe)),
            _Row(Icons.flag_outlined, 'Nationalité', _nationalite(student.nationalite)),
          ],
        ),
        _Section(
          title: 'Coordonnées',
          rows: [
            _Row(Icons.mail_outline_rounded, 'Email', student.email),
            _Row(Icons.phone_outlined, 'Mobile', student.mobile),
            _Row(Icons.location_city_rounded, 'Ville', _city(student)),
            _Row(Icons.home_outlined, 'Adresse', student.adresse),
          ],
        ),
        _Section(
          title: 'Scolarité',
          rows: [
            _Row(Icons.school_outlined, 'Diplôme', student.diplome),
            _Row(Icons.stairs_outlined, 'Niveau', student.niveau == null ? null : 'Niveau ${student.niveau}'),
            _Row(Icons.groups_outlined, 'Classe', student.classeName),
            _Row(Icons.group_work_outlined, 'Groupe', student.groupe),
          ],
        ),
        if (student.hasBac)
          _Section(
            title: 'Baccalauréat',
            rows: [
              _Row(Icons.event_outlined, 'Année', student.anneeBac),
              _Row(Icons.workspace_premium_outlined, 'Mention', _mention(student.mentionBac)),
            ],
          ),
      ],
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final StudentInfo student;

  const _HeaderCard({required this.student});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ar = student.fullNameAr;

    return AppCard(
      accent: AppColors.purple,
      child: Column(
        children: [
          StudentAvatar(seed: student.fullName, size: 84, initials: student.initials),
          const SizedBox(height: AppSpacing.md),
          Text(
            student.fullName,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge,
          ),
          if (ar.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                ar,
                textAlign: TextAlign.center,
                textDirection: TextDirection.rtl,
                style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              if (student.classeName != null) _Chip(student.classeName!, AppColors.purple),
              if (student.niveau != null) _Chip('Niveau ${student.niveau}', AppColors.info),
              if (student.nce != null) _Chip(student.nce!, AppColors.textSecondary),
            ],
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<_Row> rows;

  const _Section({required this.title, required this.rows});

  @override
  Widget build(BuildContext context) {
    final visible = rows.where((r) => r.value != null && r.value!.isNotEmpty).toList();
    if (visible.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: AppSpacing.xs, bottom: AppSpacing.sm),
            child: Text(
              title,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textMuted,
                    letterSpacing: 0.6,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
            child: Column(
              children: [
                for (var i = 0; i < visible.length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  visible[i],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final String? arValue;

  const _Row(this.icon, this.label, this.value, {this.arValue});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final display = (arValue != null && arValue!.isNotEmpty) ? '$value ($arValue)' : value;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.textMuted),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
                ),
                const SizedBox(height: 2),
                Text(
                  display ?? '',
                  style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;

  const _Chip(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.32)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _StudentSkeleton extends StatelessWidget {
  const _StudentSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xxl),
      children: const [
        SkeletonBox(height: 200, width: double.infinity),
        SizedBox(height: AppSpacing.lg),
        SkeletonBox(height: 160, width: double.infinity),
        SizedBox(height: AppSpacing.lg),
        SkeletonBox(height: 160, width: double.infinity),
      ],
    );
  }
}

String? _sexe(String? code) => code == null ? null : (code == '1' ? 'Féminin' : 'Masculin');

String? _nationalite(String? code) {
  if (code == null) return null;
  return code == '788' ? 'Tunisienne' : code;
}

String? _mention(String? code) {
  switch (code) {
    case '1':
      return 'Passable';
    case '2':
      return 'Assez bien';
    case '3':
      return 'Bien';
    case '4':
      return 'Très bien';
    default:
      return null;
  }
}

String? _city(StudentInfo s) {
  final parts = [s.codePostal, s.ville].whereType<String>().where((p) => p.isNotEmpty).toList();
  return parts.isEmpty ? null : parts.join(' ');
}

const _mois = [
  'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
  'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'
];

String? _frDate(String? iso) {
  if (iso == null) return null;
  final d = DateTime.tryParse(iso);
  if (d == null) return iso;
  return '${d.day} ${_mois[d.month - 1]} ${d.year}';
}
