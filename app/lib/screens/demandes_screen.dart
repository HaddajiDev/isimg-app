import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_exception.dart';
import '../core/format.dart';
import '../models/demande.dart';
import '../providers/services_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_card.dart';
import '../widgets/info_widgets.dart';
import '../widgets/state_views.dart';

Color _statutColor(DemandeStatut s) => switch (s) {
      DemandeStatut.prete => AppColors.green,
      DemandeStatut.refusee => AppColors.danger,
      DemandeStatut.enCours => AppColors.warning,
    };

IconData _statutIcon(DemandeStatut s) => switch (s) {
      DemandeStatut.prete => Icons.task_alt_rounded,
      DemandeStatut.refusee => Icons.cancel_rounded,
      DemandeStatut.enCours => Icons.hourglass_bottom_rounded,
    };

String _errorText(Object e) => e is ApiException && e.isConnectivityProblem
    ? 'Pas de connexion. Réessayez.'
    : 'L\'administration n\'a pas accepté l\'opération. Réessayez plus tard.';

/// Administrative requests (attestations, relevés…) and their follow-up.
class DemandesScreen extends ConsumerWidget {
  const DemandesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(demandesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Demandes')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const NewDemandeScreen()),
        ),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nouvelle demande'),
      ),
      body: SafeArea(
        top: false,
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => LoadErrorView(
            error: e,
            what: 'les demandes',
            onRetry: () => ref.invalidate(demandesProvider),
          ),
          data: (demandes) => RefreshIndicator(
            onRefresh: () => ref.refresh(demandesProvider.future),
            color: AppColors.purple,
            backgroundColor: context.c.surfaceRaised,
            child: demandes.isEmpty
                ? const ScrollableFill(
                    child: MessageView(
                      icon: Icons.description_outlined,
                      title: 'Aucune demande',
                      subtitle: 'Demandez une attestation ou un document à l\'administration avec « Nouvelle demande ».',
                    ),
                  )
                : ListView.separated(
                    // Bottom room so the last card clears the floating button.
                    padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 96),
                    itemCount: demandes.length,
                    separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
                    itemBuilder: (context, i) => _DemandeCard(demande: demandes[i]),
                  ),
          ),
        ),
      ),
    );
  }
}

class _DemandeCard extends StatelessWidget {
  final Demande demande;

  const _DemandeCard({required this.demande});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _statutColor(demande.statut);

    return AppCard(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => DemandeDetailScreen(demande: demande)),
      ),
      child: Row(
        children: [
          Container(
            height: 42,
            width: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(_statutIcon(demande.statut), color: color, size: 22),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(demande.name, style: theme.textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(
                  frDate(demande.created) ?? '',
                  style: theme.textTheme.bodySmall?.copyWith(color: context.c.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              StatusBadge(label: demande.statut.label, color: color),
              if (demande.hasUnreadReply) ...[
                const SizedBox(height: AppSpacing.xs),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(color: AppColors.purple, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Nouvelle réponse',
                      style: theme.textTheme.bodySmall?.copyWith(color: AppColors.purple),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ─── New request ────────────────────────────────────────────────────────────

class NewDemandeScreen extends ConsumerStatefulWidget {
  const NewDemandeScreen({super.key});

  @override
  ConsumerState<NewDemandeScreen> createState() => _NewDemandeScreenState();
}

class _NewDemandeScreenState extends ConsumerState<NewDemandeScreen> {
  DemandeModel? _model;
  final _values = <String, String>{};
  final _controllers = <String, TextEditingController>{};
  bool _sending = false;

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _pick(DemandeModel? m) {
    setState(() {
      _model = m;
      _values.clear();
      for (final c in _controllers.values) {
        c.dispose();
      }
      _controllers.clear();
    });
  }

  TextEditingController _controller(DemandeField f) => _controllers.putIfAbsent(f.id, () {
        final c = TextEditingController(text: _values[f.id]);
        c.addListener(() => _values[f.id] = c.text);
        return c;
      });

  bool get _canSend {
    final m = _model;
    if (m == null || m.needsFile || _sending) return false;
    // Text, choice and date fields are required, as in the official form.
    return m.fields
        .where((f) => f.type == DemandeFieldType.texte ||
            f.type == DemandeFieldType.select ||
            f.type == DemandeFieldType.radio ||
            f.type == DemandeFieldType.date)
        .every((f) => (_values[f.id] ?? '').trim().isNotEmpty);
  }

  Future<void> _send() async {
    final m = _model!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.c.surfaceRaised,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        title: const Text('Envoyer la demande ?'),
        content: Text('« ${m.name} » sera transmise à l\'administration.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Envoyer')),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _sending = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(servicesApiProvider)!.addDemande(m, {
        for (final e in _values.entries) e.key: e.value.trim(),
      });
      ref.invalidate(demandesProvider);
      if (!mounted) return;
      Navigator.of(context).pop();
      messenger.showSnackBar(const SnackBar(content: Text('Demande envoyée')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      messenger.showSnackBar(SnackBar(content: Text(_errorText(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(demandeModelsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Nouvelle demande')),
      body: SafeArea(
        top: false,
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => LoadErrorView(
            error: e,
            what: 'les types de demande',
            onRetry: () => ref.invalidate(demandeModelsProvider),
          ),
          data: (models) => models.isEmpty
              ? const MessageView(
                  icon: Icons.description_outlined,
                  title: 'Aucun type de demande',
                  subtitle: 'L\'établissement n\'a publié aucun modèle de demande.',
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xxl),
                  children: [
                    DropdownButtonFormField<DemandeModel>(
                      initialValue: _model,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Type de demande'),
                      items: [
                        for (final m in models)
                          DropdownMenuItem(value: m, child: Text(m.name, overflow: TextOverflow.ellipsis)),
                      ],
                      onChanged: _sending ? null : _pick,
                    ),
                    if (_model case final m?) ...[
                      if (m.titre != null && m.titre != m.name) ...[
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          m.titre!,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: context.c.textSecondary),
                        ),
                      ],
                      for (final f in m.fields) ...[
                        const SizedBox(height: AppSpacing.lg),
                        _field(f),
                      ],
                      if (m.needsFile) ...[
                        const SizedBox(height: AppSpacing.lg),
                        const _Notice(
                          'Cette demande exige une pièce jointe, ce que l\'application ne gère pas encore. '
                          'Utilisez l\'application officielle pour celle-ci.',
                        ),
                      ],
                      const SizedBox(height: AppSpacing.xl),
                      FilledButton.icon(
                        onPressed: _canSend ? _send : null,
                        icon: _sending
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.send_rounded),
                        label: const Text('Envoyer la demande'),
                        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(kMinTouchTarget)),
                      ),
                    ],
                  ],
                ),
        ),
      ),
    );
  }

  Widget _field(DemandeField f) {
    final theme = Theme.of(context);
    switch (f.type) {
      case DemandeFieldType.label:
        return Text(f.label, style: theme.textTheme.bodyMedium?.copyWith(color: context.c.textSecondary));
      case DemandeFieldType.file:
        return InfoRow(Icons.attach_file_rounded, f.label, 'Pièce jointe — non prise en charge');
      case DemandeFieldType.select:
      case DemandeFieldType.radio:
        final v = _values[f.id];
        return DropdownButtonFormField<String>(
          initialValue: f.choices.contains(v) ? v : null,
          isExpanded: true,
          decoration: InputDecoration(labelText: f.label),
          items: [for (final c in f.choices) DropdownMenuItem(value: c, child: Text(c))],
          onChanged: _sending ? null : (c) => setState(() => _values[f.id] = c ?? ''),
        );
      case DemandeFieldType.checkbox:
        return CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: _values[f.id] == 'Oui',
          title: Text(f.label),
          controlAffinity: ListTileControlAffinity.leading,
          onChanged: _sending ? null : (c) => setState(() => _values[f.id] = c == true ? 'Oui' : ''),
        );
      case DemandeFieldType.date:
        final v = _values[f.id];
        return InkWell(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          onTap: _sending
              ? null
              : () async {
                  final now = DateTime.now();
                  final d = await showDatePicker(
                    context: context,
                    initialDate: DateTime.tryParse(v ?? '') ?? now,
                    firstDate: DateTime(now.year - 10),
                    lastDate: DateTime(now.year + 5),
                  );
                  if (d != null) {
                    setState(() => _values[f.id] =
                        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}');
                  }
                },
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: f.label,
              suffixIcon: const Icon(Icons.calendar_today_rounded, size: 18),
            ),
            child: Text(frDate(DateTime.tryParse(v ?? '')) ?? 'Choisir une date'),
          ),
        );
      case DemandeFieldType.texte:
        return TextField(
          controller: _controller(f),
          enabled: !_sending,
          minLines: 1,
          maxLines: 4,
          decoration: InputDecoration(labelText: f.label),
          onChanged: (_) => setState(() {}),
        );
    }
  }
}

class _Notice extends StatelessWidget {
  final String text;

  const _Notice(this.text);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: AppColors.warning.withValues(alpha: 0.30)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline_rounded, size: 18, color: AppColors.warning),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: Text(text, style: Theme.of(context).textTheme.bodySmall)),
          ],
        ),
      );
}

// ─── Request detail & conversation ──────────────────────────────────────────

class DemandeDetailScreen extends ConsumerStatefulWidget {
  final Demande demande;

  const DemandeDetailScreen({super.key, required this.demande});

  @override
  ConsumerState<DemandeDetailScreen> createState() => _DemandeDetailScreenState();
}

class _DemandeDetailScreenState extends ConsumerState<DemandeDetailScreen> {
  final _message = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // Clears the "Nouvelle réponse" marker, like the official app does on open.
    if (widget.demande.hasUnreadReply) {
      ref.read(servicesApiProvider)?.markDemandeSeen(widget.demande.id).then(
            (_) => ref.invalidate(demandesProvider),
            onError: (_) {},
          );
    }
  }

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _message.text.trim();
    if (text.isEmpty) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(servicesApiProvider)!.addDemandeMessage(widget.demande.id, text);
      _message.clear();
      ref.invalidate(demandeMessagesProvider(widget.demande.id));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(_errorText(e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.c.surfaceRaised,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        title: const Text('Annuler la demande ?'),
        content: Text('« ${widget.demande.name} » sera supprimée.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Garder')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(servicesApiProvider)!.deleteDemande(widget.demande.id);
      ref.invalidate(demandesProvider);
      if (!mounted) return;
      Navigator.of(context).pop();
      messenger.showSnackBar(const SnackBar(content: Text('Demande supprimée')));
    } catch (e) {
      if (mounted) setState(() => _busy = false);
      messenger.showSnackBar(SnackBar(content: Text(_errorText(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.demande;
    final theme = Theme.of(context);
    final color = _statutColor(d.statut);
    final messages = ref.watch(demandeMessagesProvider(d.id));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Demande'),
        actions: [
          if (d.canDelete)
            IconButton(
              onPressed: _busy ? null : _delete,
              icon: const Icon(Icons.delete_outline_rounded),
              tooltip: 'Supprimer',
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => ref.refresh(demandeMessagesProvider(d.id).future),
                color: AppColors.purple,
                backgroundColor: context.c.surfaceRaised,
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  children: [
                    AppCard(
                      accent: color,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(d.name, style: theme.textTheme.titleLarge),
                          const SizedBox(height: AppSpacing.sm),
                          StatusBadge(label: d.statut.label, color: color, icon: _statutIcon(d.statut)),
                          InfoRows([
                            InfoRow(Icons.send_outlined, 'Envoyée le', frDateTime(d.created)),
                            InfoRow(Icons.update_rounded, 'Mise à jour', frDateTime(d.updated)),
                            for (final v in d.values) InfoRow(Icons.short_text_rounded, v.label, v.value),
                            if (d.rawContent != null) InfoRow(Icons.notes_rounded, 'Contenu', d.rawContent),
                          ]),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Text(
                      'ÉCHANGES',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: context.c.textSecondary,
                        letterSpacing: 0.8,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    messages.when(
                      loading: () => const Padding(
                        padding: EdgeInsets.all(AppSpacing.lg),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      error: (e, _) => Text(
                        'Impossible de charger les échanges.',
                        style: theme.textTheme.bodySmall?.copyWith(color: AppColors.danger),
                      ),
                      data: (list) => list.isEmpty
                          ? Text(
                              'Aucun message pour l\'instant.',
                              style: theme.textTheme.bodySmall?.copyWith(color: context.c.textMuted),
                            )
                          : Column(children: [for (final m in list) _Bubble(message: m)]),
                    ),
                  ],
                ),
              ),
            ),
            _Composer(controller: _message, busy: _busy, onSend: _sendMessage),
          ],
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final DemandeMessage message;

  const _Bubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mine = message.fromMe;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.78),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: mine ? AppColors.purple.withValues(alpha: 0.18) : context.c.surfaceRaised,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: mine ? AppColors.purple.withValues(alpha: 0.35) : context.c.border),
        ),
        child: Column(
          crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!mine)
              Text(
                'Administration',
                style: theme.textTheme.bodySmall?.copyWith(color: AppColors.purple, fontWeight: FontWeight.w600),
              ),
            Text(message.message, style: theme.textTheme.bodyMedium),
            if (message.when != null)
              Text(
                frDateTime(message.when)!,
                style: theme.textTheme.bodySmall?.copyWith(color: context.c.textMuted, fontSize: 11),
              ),
          ],
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final bool busy;
  final VoidCallback onSend;

  const _Composer({required this.controller, required this.busy, required this.onSend});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.sm, AppSpacing.sm),
      decoration: BoxDecoration(
        color: context.c.surface,
        border: Border(top: BorderSide(color: context.c.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              enabled: !busy,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.newline,
              decoration: const InputDecoration(hintText: 'Écrire à l\'administration…'),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          IconButton.filled(
            onPressed: busy ? null : onSend,
            icon: busy
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.send_rounded),
            tooltip: 'Envoyer',
          ),
        ],
      ),
    );
  }
}
