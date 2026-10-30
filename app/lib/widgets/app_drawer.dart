import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/academic_year_provider.dart';
import '../providers/theme_provider.dart';
import '../screens/calendar_screen.dart';
import '../screens/demandes_screen.dart';
import '../screens/etudiant_screen.dart';
import '../screens/pfe_screen.dart';
import '../screens/plan_etudes_screen.dart';
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
      backgroundColor: context.c.surface,
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
                            style: theme.textTheme.bodySmall?.copyWith(color: context.c.textMuted),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                children: [
                  const _DrawerSection('Scolarité'),
                  _DrawerButton(
                    icon: Icons.person_outline_rounded,
                    label: 'Étudiant',
                    value: 'Fiche personnelle',
                    onTap: () => _go(context, const EtudiantScreen()),
                  ),
                  _DrawerButton(
                    icon: Icons.menu_book_outlined,
                    label: "Plan d'études",
                    value: 'Modules, coefficients, crédits',
                    onTap: () => _go(context, const PlanEtudesScreen()),
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
                  const _DrawerSection('Projets & démarches'),
                  _DrawerButton(
                    icon: Icons.work_outline_rounded,
                    label: 'Stages',
                    value: 'Ouvrier · technicien · ingénieur',
                    onTap: () => _go(context, const StageScreen()),
                  ),
                  _DrawerButton(
                    icon: Icons.school_outlined,
                    label: 'PFE',
                    value: "Projet de fin d'études",
                    onTap: () => _go(context, const PfeScreen()),
                  ),
                  _DrawerButton(
                    icon: Icons.description_outlined,
                    label: 'Demandes administratives',
                    value: 'Attestations et documents',
                    onTap: () => _go(context, const DemandesScreen()),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            const _ThemeToggle(),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.xs, AppSpacing.lg, AppSpacing.lg),
              child: Text(
                'Application non officielle',
                style: theme.textTheme.bodySmall?.copyWith(color: context.c.textMuted),
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

  static String _initials(String name) {
    final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    return words.map((w) => w[0].toUpperCase()).take(2).join();
  }
}

class _ThemeToggle extends ConsumerWidget {
  const _ThemeToggle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: AppSpacing.sm),
            child: Text(
              'APPARENCE',
              style: theme.textTheme.bodySmall?.copyWith(
                color: context.c.textMuted,
                letterSpacing: 0.8,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(
                  value: ThemeMode.system,
                  icon: Icon(Icons.brightness_auto_rounded, size: 18),
                  tooltip: 'Système',
                ),
                ButtonSegment(
                  value: ThemeMode.light,
                  icon: Icon(Icons.light_mode_rounded, size: 18),
                  tooltip: 'Clair',
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  icon: Icon(Icons.dark_mode_rounded, size: 18),
                  tooltip: 'Sombre',
                ),
              ],
              selected: {mode},
              showSelectedIcon: false,
              onSelectionChanged: (s) =>
                  ref.read(themeModeProvider.notifier).set(s.first),
              style: ButtonStyle(
                visualDensity: VisualDensity.compact,
                foregroundColor: WidgetStateProperty.resolveWith(
                  (states) => states.contains(WidgetState.selected)
                      ? AppColors.purple
                      : context.c.textSecondary,
                ),
                backgroundColor: WidgetStateProperty.resolveWith(
                  (states) => states.contains(WidgetState.selected)
                      ? AppColors.purpleGlow
                      : Colors.transparent,
                ),
                side: WidgetStatePropertyAll(BorderSide(color: context.c.border)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DrawerButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  const _DrawerButton({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
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
                        style: theme.textTheme.bodySmall?.copyWith(color: context.c.textSecondary),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: context.c.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DrawerSection extends StatelessWidget {
  final String label;

  const _DrawerSection(this.label);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xs),
        child: Text(
          label.toUpperCase(),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: context.c.textMuted,
                letterSpacing: 0.8,
                fontWeight: FontWeight.w600,
              ),
        ),
      );
}
