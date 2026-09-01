import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/academic_year_provider.dart';
import '../providers/notifications_provider.dart';
import '../screens/calendar_screen.dart';
import '../screens/etudiant_screen.dart';
import '../screens/news_screen.dart';
import '../screens/notifications_screen.dart';
import '../screens/stage_screen.dart';
import '../theme/app_theme.dart';
import 'student_avatar.dart';

class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final identity = ref.watch(drawerIdentityProvider).valueOrNull;
    final year = ref.watch(academicYearProvider);
    final name = identity?.name ?? 'Étudiant';

    return Drawer(
      backgroundColor: AppColors.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.xl,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              child: Row(
                children: [
                  StudentAvatar(seed: name, size: 52, initials: _initials(name)),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium,
                        ),
                        if (identity != null)
                          Text(
                            identity.subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(),
            const SizedBox(height: AppSpacing.xs),
            _DrawerButton(
              icon: Icons.campaign_outlined,
              label: 'Actualités',
              value: 'Annonces de l\'établissement',
              onTap: () => _go(context, const NewsScreen()),
            ),
            _DrawerButton(
              icon: Icons.notifications_none_rounded,
              label: 'Notifications',
              value: _notifSubtitle(ref),
              badge: ref.watch(notificationsProvider).valueOrNull?.total,
              onTap: () => _go(context, const NotificationsScreen()),
            ),
            _DrawerButton(
              icon: Icons.person_outline_rounded,
              label: 'Étudiant',
              value: 'Fiche personnelle',
              onTap: () => _go(context, const EtudiantScreen()),
            ),
            _DrawerButton(
              icon: Icons.work_outline_rounded,
              label: 'Stages',
              value: 'Ouvrier · technicien · ingénieur',
              onTap: () => _go(context, const StageScreen()),
            ),
            _DrawerButton(
              icon: Icons.event_note_rounded,
              label: 'Année universitaire',
              value: year.when(
                data: (y) => y ?? 'Calendrier',
                loading: () => '…',
                error: (_, _) => 'Calendrier',
              ),
              onTap: () => _go(context, const CalendarScreen()),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Text(
                'Application non officielle',
                style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _go(BuildContext context, Widget page) {
    Navigator.pop(context);
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  String _notifSubtitle(WidgetRef ref) {
    final total = ref.watch(notificationsProvider).valueOrNull?.total;
    if (total == null || total == 0) return 'Vous êtes à jour';
    return total > 1 ? '$total nouveautés' : '1 nouveauté';
  }

  static String _initials(String name) {
    final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    return words.map((w) => w[0].toUpperCase()).take(2).join();
  }
}

class _DrawerButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;
  final int? badge;

  const _DrawerButton({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
            child: Row(
              children: [
                Container(
                  height: 40,
                  width: 40,
                  decoration: BoxDecoration(
                    color: AppColors.purpleGlow,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Icon(icon, color: AppColors.purple, size: 20),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: theme.textTheme.titleMedium),
                      const SizedBox(height: 2),
                      Text(
                        value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                if (badge != null && badge! > 0) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    constraints: const BoxConstraints(minWidth: 22),
                    decoration: BoxDecoration(
                      color: AppColors.purple,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(
                      '${badge! > 99 ? '99+' : badge}',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                ],
                const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
