import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_exception.dart';
import '../models/profile.dart';
import '../providers/auth_provider.dart';
import '../providers/profile_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_card.dart';
import '../widgets/state_views.dart';
import '../widgets/student_avatar.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileProvider);

    return profileAsync.when(
      loading: () => const _ProfileLoadingPlaceholder(),
      error: (error, _) {
        if (error is ApiException && error.isSessionExpired) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.read(authProvider.notifier).handleSessionExpired();
          });
        }
        return MessageView(
          icon: Icons.cloud_off_rounded,
          title: 'Impossible de charger le profil',
          subtitle: error is ApiException
              ? error.code
              : 'Vérifiez votre connexion.',
          tint: AppColors.danger,
          action: FilledButton(
            onPressed: () => ref.invalidate(profileProvider),
            child: const Text('Réessayer'),
          ),
        );
      },
      data: (profile) => RefreshIndicator(
        onRefresh: () => ref.refresh(profileProvider.future),
        color: AppColors.purple,
        backgroundColor: AppColors.surfaceRaised,
        child: _ProfileContent(profile: profile),
      ),
    );
  }
}

/// Shown while [profileProvider] is still loading: the last cached profile,
/// if there is one, instead of a bare skeleton.
class _ProfileLoadingPlaceholder extends ConsumerWidget {
  const _ProfileLoadingPlaceholder();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final peeked = ref.watch(profileCachePeekProvider);

    return peeked.when(
      data: (cached) => cached == null
          ? const _ProfileSkeleton()
          : Stack(
              children: [
                _ProfileContent(profile: cached.profile),
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
      loading: () => const _ProfileSkeleton(),
      error: (_, _) => const _ProfileSkeleton(),
    );
  }
}

/// The profile itself, shared between a fresh load and a cached seed so both
/// render identically.
class _ProfileContent extends StatelessWidget {
  final Profile profile;

  const _ProfileContent({required this.profile});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.xxl,
      ),
      children: [
        _IdentityCard(profile: profile),
        const SizedBox(height: AppSpacing.xl),
        Padding(
          padding: const EdgeInsets.only(
            bottom: AppSpacing.md,
            left: AppSpacing.xs,
          ),
          child: Text(
            'Parcours',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        if (profile.years.isEmpty)
          const AppCard(
            child: SizedBox(
              height: 140,
              child: MessageView(
                icon: Icons.timeline_rounded,
                title: 'Aucun parcours',
                subtitle: 'Rien à afficher pour le moment.',
              ),
            ),
          )
        else
          for (var i = 0; i < profile.years.length; i++)
            _YearTile(
              year: profile.years[i],
              isFirst: i == 0,
              isLast: i == profile.years.length - 1,
            ),
      ],
    );
  }
}

class _IdentityCard extends StatelessWidget {
  final Profile profile;

  const _IdentityCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mono = theme.extension<AppTypography>()!.monoFamily;

    return AppCard(
      accent: AppColors.purple,
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        children: [
          StudentAvatar(
            seed: profile.fullName,
            initials: profile.initials,
            size: 88,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            profile.fullName.isEmpty ? '—' : profile.fullName,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge,
          ),
          if (profile.filiere != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              profile.filiere!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          const Divider(),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: _InfoField(
                  label: 'CIN',
                  value: profile.cin ?? '—',
                  monoFamily: mono,
                ),
              ),
              Container(width: 1, height: 34, color: AppColors.border),
              Expanded(
                child: _InfoField(
                  label: 'N° Inscription',
                  value:
                      profile.years
                          .map((y) => y.numeroInscription)
                          .whereType<String>()
                          .firstOrNull ??
                      '—',
                  monoFamily: mono,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoField extends StatelessWidget {
  final String label;
  final String value;
  final String monoFamily;

  const _InfoField({
    required this.label,
    required this.value,
    required this.monoFamily,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontFamily: monoFamily,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
        ),
      ],
    );
  }
}

/// A year in the parcours, drawn as a timeline entry with a status dot.
class _YearTile extends StatelessWidget {
  final CursusYear year;
  final bool isFirst;
  final bool isLast;

  const _YearTile({
    required this.year,
    required this.isFirst,
    required this.isLast,
  });

  Color get _statusColor {
    if (year.isInProgress) return AppColors.purple;
    if (year.isPassed) return AppColors.green;
    if (year.isRepeated) return AppColors.danger;
    return AppColors.textSecondary;
  }

  IconData get _statusIcon {
    if (year.isInProgress) return Icons.autorenew_rounded;
    if (year.isPassed) return Icons.check_rounded;
    if (year.isRepeated) return Icons.replay_rounded;
    return Icons.remove_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mono = theme.extension<AppTypography>()!.monoFamily;
    final color = _statusColor;

    // IntrinsicHeight gives the row a definite height inside the scroll view,
    // without which the rail's Expanded connector lines cannot be laid out.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Timeline rail: dot plus connecting lines.
          SizedBox(
            width: 28,
            child: Column(
              children: [
                Expanded(
                  child: Container(
                    width: 2,
                    color: isFirst ? Colors.transparent : AppColors.border,
                  ),
                ),
                Container(
                  height: 22,
                  width: 22,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                    border: Border.all(color: color, width: 1.5),
                  ),
                  child: Icon(_statusIcon, size: 12, color: color),
                ),
                Expanded(
                  child: Container(
                    width: 2,
                    color: isLast ? Colors.transparent : AppColors.border,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: AppCard(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          year.annee ?? '—',
                          style: TextStyle(
                            fontFamily: mono,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        if (year.classe != null)
                          _Tag(
                            text: year.groupe == null
                                ? year.classe!
                                : '${year.classe!} · ${year.groupe!}',
                          ),
                        const Spacer(),
                        if (year.statut != null)
                          Text(
                            year.statut!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.textMuted,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      year.resultat ?? 'En cours',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        _Metric(
                          label: 'Niveau',
                          value: year.niveau ?? '—',
                          monoFamily: mono,
                        ),
                        const SizedBox(width: AppSpacing.lg),
                        _Metric(
                          label: 'Moyenne',
                          value: year.moyenne ?? '—',
                          monoFamily: mono,
                          // Only tint once a real average exists.
                          color: year.isInProgress
                              ? AppColors.textSecondary
                              : ((year.moyenneValue ?? 0) >= 10
                                    ? AppColors.green
                                    : AppColors.danger),
                        ),
                        const SizedBox(width: AppSpacing.lg),
                        _Metric(
                          label: 'Crédits',
                          value: year.credits ?? '—',
                          monoFamily: mono,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  final String monoFamily;
  final Color? color;

  const _Metric({
    required this.label,
    required this.value,
    required this.monoFamily,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            fontFamily: monoFamily,
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: color ?? AppColors.textPrimary,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.textMuted,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  final String text;

  const _Tag({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: AppColors.textSecondary,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _ProfileSkeleton extends StatelessWidget {
  const _ProfileSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        const SkeletonBox(height: 250),
        const SizedBox(height: AppSpacing.xl),
        for (var i = 0; i < 4; i++) ...[
          const SkeletonBox(height: 120),
          const SizedBox(height: AppSpacing.md),
        ],
      ],
    );
  }
}
