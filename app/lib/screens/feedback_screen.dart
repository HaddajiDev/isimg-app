import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/feedback_client.dart';
import '../theme/app_theme.dart';
import '../widgets/app_card.dart';

class FeedbackScreen extends StatefulWidget {
  final FeedbackClient? client;

  const FeedbackScreen({super.key, this.client});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  static const _maxLength = 2000;

  late final FeedbackClient _client = widget.client ?? FeedbackClient();
  final _message = TextEditingController();
  final _contact = TextEditingController();

  FeedbackType _type = FeedbackType.idea;
  int? _rating;
  final List<Uint8List> _images = [];
  bool _picking = false;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _message.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _message.dispose();
    _contact.dispose();
    super.dispose();
  }

  bool get _canSend => !_sending && !_picking && _message.text.trim().length >= 3;

  int get _remaining => FeedbackClient.maxImages - _images.length;

  Future<void> _pickImages() async {
    setState(() {
      _picking = true;
      _error = null;
    });
    try {
      final picker = ImagePicker();
      final picked = _remaining == 1
          ? [?await picker.pickImage(source: ImageSource.gallery)]
          : await picker.pickMultiImage(limit: _remaining);
      for (final file in picked.take(_remaining)) {
        final compressed = await FeedbackClient.compressImage(await file.readAsBytes());
        if (!mounted) return;
        setState(() => _images.add(compressed));
      }
    } on FeedbackException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = "Impossible d'ouvrir la galerie.");
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _send() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await _client.send(
        message: _message.text,
        type: _type,
        rating: _rating,
        contact: _contact.text,
        images: _images,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Merci ! Votre avis a bien été envoyé.')),
      );
      Navigator.of(context).pop();
    } on FeedbackException catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Feedback')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Text(
              'Un bug, une idée, une remarque ? Votre message est envoyé directement au développeur.',
              style: theme.textTheme.bodyMedium?.copyWith(color: context.c.textSecondary),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Type', style: theme.textTheme.titleSmall),
                  const SizedBox(height: AppSpacing.sm),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<FeedbackType>(
                      segments: const [
                        ButtonSegment(
                          value: FeedbackType.bug,
                          label: Text('Bug'),
                          icon: Icon(Icons.bug_report_outlined),
                        ),
                        ButtonSegment(
                          value: FeedbackType.idea,
                          label: Text('Idée'),
                          icon: Icon(Icons.lightbulb_outline_rounded),
                        ),
                        ButtonSegment(
                          value: FeedbackType.other,
                          label: Text('Autre'),
                          icon: Icon(Icons.chat_bubble_outline_rounded),
                        ),
                      ],
                      selected: {_type},
                      showSelectedIcon: false,
                      onSelectionChanged: _sending ? null : (s) => setState(() => _type = s.first),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text('Message', style: theme.textTheme.titleSmall),
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    controller: _message,
                    enabled: !_sending,
                    minLines: 5,
                    maxLines: 10,
                    maxLength: _maxLength,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: switch (_type) {
                        FeedbackType.bug => 'Que s\'est-il passé ? Sur quel écran ?',
                        FeedbackType.idea => 'Quelle fonctionnalité aimeriez-vous ?',
                        FeedbackType.other => 'Votre message',
                      },
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Text('Note de l\'application', style: theme.textTheme.titleSmall),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        '(facultatif)',
                        style: theme.textTheme.bodySmall?.copyWith(color: context.c.textMuted),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: [
                      for (var i = 1; i <= 5; i++)
                        IconButton(
                          onPressed: _sending
                              ? null
                              : () => setState(() => _rating = _rating == i ? null : i),
                          icon: Icon(
                            (_rating ?? 0) >= i ? Icons.star_rounded : Icons.star_outline_rounded,
                            color: (_rating ?? 0) >= i ? AppColors.warning : context.c.textMuted,
                            size: 30,
                          ),
                          tooltip: '$i sur 5',
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Text('Contact', style: theme.textTheme.titleSmall),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        '(facultatif)',
                        style: theme.textTheme.bodySmall?.copyWith(color: context.c.textMuted),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    controller: _contact,
                    enabled: !_sending,
                    maxLength: 100,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      hintText: 'E-mail ou @telegram, si vous voulez une réponse',
                      counterText: '',
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Text('Captures', style: theme.textTheme.titleSmall),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        '(facultatif, ${FeedbackClient.maxImages} max)',
                        style: theme.textTheme.bodySmall?.copyWith(color: context.c.textMuted),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      for (var i = 0; i < _images.length; i++)
                        _Thumbnail(
                          bytes: _images[i],
                          onRemove: _sending ? null : () => setState(() => _images.removeAt(i)),
                        ),
                      if (_remaining > 0)
                        _AddImageTile(
                          busy: _picking,
                          onTap: _sending || _picking ? null : _pickImages,
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    "Vérifiez qu'elles ne contiennent rien de personnel.",
                    style: theme.textTheme.bodySmall?.copyWith(color: context.c.textMuted),
                  ),
                ],
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  const Icon(Icons.error_outline_rounded, size: 18, color: AppColors.danger),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      _error!,
                      style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.danger),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: _canSend ? _send : null,
              icon: _sending
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.send_rounded),
              label: Text(_sending ? 'Envoi…' : 'Envoyer'),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'La version de l\'application et du système sont jointes pour aider à corriger les bugs. '
              'Aucune donnée scolaire n\'est envoyée.',
              style: theme.textTheme.bodySmall?.copyWith(color: context.c.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  final Uint8List bytes;
  final VoidCallback? onRemove;

  const _Thumbnail({required this.bytes, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 84,
      height: 84,
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true),
            ),
          ),
          Positioned(
            top: 2,
            right: 2,
            child: Material(
              color: Colors.black54,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onRemove,
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.close_rounded, size: 16, color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddImageTile extends StatelessWidget {
  final bool busy;
  final VoidCallback? onTap;

  const _AddImageTile({required this.busy, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 84,
      height: 84,
      child: Material(
        color: context.c.surfaceRaised,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          side: BorderSide(color: context.c.border),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          onTap: onTap,
          child: Center(
            child: busy
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.purple),
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_photo_alternate_outlined, color: context.c.textSecondary),
                      const SizedBox(height: 4),
                      Text(
                        'Ajouter',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: context.c.textSecondary),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
