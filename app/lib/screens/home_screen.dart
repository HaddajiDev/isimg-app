import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_drawer.dart';
import '../widgets/update_banner.dart';
import 'absences_screen.dart';
import 'exams_screen.dart';
import 'grades_screen.dart';
import 'profile_screen.dart';
import 'schedule_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _pageController = PageController();
  int _index = 0;

  static const _tabs = [
    (title: 'Emploi', subtitle: 'Votre semaine', screen: ScheduleScreen()),
    (title: 'Absences', subtitle: 'Assiduité et bilan', screen: AbsencesScreen()),
    (title: 'Examens', subtitle: 'Prochaines épreuves', screen: ExamsScreen()),
    (title: 'Notes', subtitle: 'Relevés et moyennes', screen: GradesScreen()),
    (title: 'Profil', subtitle: 'Identité et parcours', screen: ProfileScreen()),
  ];

  static const _destinations = [
    (icon: Icons.calendar_month_outlined, selected: Icons.calendar_month_rounded, label: 'Emploi'),
    (icon: Icons.fact_check_outlined, selected: Icons.fact_check_rounded, label: 'Absences'),
    (icon: Icons.event_note_outlined, selected: Icons.event_note_rounded, label: 'Examens'),
    (icon: Icons.bar_chart_outlined, selected: Icons.bar_chart_rounded, label: 'Notes'),
    (icon: Icons.person_outline_rounded, selected: Icons.person_rounded, label: 'Profil'),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goTo(int i) {
    _pageController.jumpToPage(i);
  }

  @override
  Widget build(BuildContext context) {
    final tab = _tabs[_index];

    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        titleSpacing: AppSpacing.lg,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(tab.title),
            Text(
              tab.subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: context.c.textMuted,
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: IconButton(
              onPressed: _confirmLogout,
              icon: const Icon(Icons.logout_rounded),
              tooltip: 'Se déconnecter',
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          const UpdateBanner(),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const ClampingScrollPhysics(),
              onPageChanged: (i) => setState(() => _index = i),
              children: [for (final t in _tabs) t.screen],
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _goTo,
        destinations: [
          for (final d in _destinations)
            NavigationDestination(
              icon: Icon(d.icon),
              selectedIcon: Icon(d.selected),
              label: d.label,
            ),
        ],
      ),
    );
  }

  Future<void> _confirmLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.c.surfaceRaised,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        title: const Text('Se déconnecter ?'),
        content: const Text(
          'Vous devrez vous reconnecter avec un nouveau code.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.danger,
              minimumSize: const Size(88, kMinTouchTarget),
            ),
            child: const Text('Déconnexion'),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      await ref.read(authProvider.notifier).logout();
    }
  }
}
