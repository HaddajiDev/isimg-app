import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

/// Outcome of the manual-note sheet.
sealed class ManualNoteResult {}

class ManualNoteSaved extends ManualNoteResult {
  final double note;
  ManualNoteSaved(this.note);
}

class ManualNoteDeleted extends ManualNoteResult {}

/// Prompts for a hypothetical note on an épreuve the school has not graded.
Future<ManualNoteResult?> showManualNoteSheet(
  BuildContext context, {
  required String matiere,
  required String epreuve,
  double? existing,
}) {
  return showModalBottomSheet<ManualNoteResult>(
    context: context,
    backgroundColor: AppColors.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
    ),
    builder: (context) => _ManualNoteSheet(
      matiere: matiere,
      epreuve: epreuve,
      existing: existing,
    ),
  );
}

class _ManualNoteSheet extends StatefulWidget {
  final String matiere;
  final String epreuve;
  final double? existing;

  const _ManualNoteSheet({
    required this.matiere,
    required this.epreuve,
    this.existing,
  });

  @override
  State<_ManualNoteSheet> createState() => _ManualNoteSheetState();
}

class _ManualNoteSheetState extends State<_ManualNoteSheet> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.existing == null ? '' : _trim(widget.existing!),
  );
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double? get _parsed {
    final raw = _controller.text.trim().replaceAll(',', '.');
    if (raw.isEmpty) return null;
    return double.tryParse(raw);
  }

  void _save() {
    final note = _parsed;
    if (note == null) {
      setState(() => _error = 'Entrez un nombre, par exemple 12.5');
      return;
    }
    if (note < 0 || note > 20) {
      setState(() => _error = 'La note doit être entre 0 et 20');
      return;
    }
    Navigator.pop(context, ManualNoteSaved(note));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mono = theme.extension<AppTypography>()!.monoFamily;

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.xl,
        right: AppSpacing.xl,
        top: AppSpacing.xl,
        // Clear the keyboard.
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              height: 4,
              width: 40,
              decoration: BoxDecoration(
                color: AppColors.borderStrong,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text('Note provisoire', style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${widget.matiere} · ${widget.epreuve}',
            style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: mono,
              fontSize: 30,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: '00.00',
              errorText: _error,
              suffixText: '/ 20',
              suffixStyle: const TextStyle(color: AppColors.textMuted),
            ),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Sert uniquement à simuler votre moyenne sur cet appareil. '
            'Cette note n\'est pas envoyée à l\'ISIMG et sera remplacée '
            'dès que la vraie note sera publiée.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textMuted,
              fontSize: 11.5,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          FilledButton(
            onPressed: _save,
            child: Text(widget.existing == null ? 'Enregistrer' : 'Mettre à jour'),
          ),
          if (widget.existing != null) ...[
            const SizedBox(height: AppSpacing.sm),
            TextButton.icon(
              onPressed: () => Navigator.pop(context, ManualNoteDeleted()),
              icon: const Icon(Icons.delete_outline_rounded, size: 18),
              label: const Text('Supprimer cette note'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.danger,
                minimumSize: const Size.fromHeight(kMinTouchTarget),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

String _trim(double value) =>
    value == value.roundToDouble() ? value.toStringAsFixed(0) : value.toString();
