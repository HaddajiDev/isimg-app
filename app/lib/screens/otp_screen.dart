import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';

class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _codeController = TextEditingController();

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isSubmitting = authState.status == AuthStatus.submitting;
    final theme = Theme.of(context);
    final mono = theme.extension<AppTypography>()!.monoFamily;

    // There is no Navigator route to pop back to here — AuthGate just swaps
    // widgets on auth status — so the hardware/gesture back button would
    // otherwise fall through to exiting the app instead of abandoning the
    // pending login. Route it through the same cleanup as the arrow icon.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) ref.read(authProvider.notifier).logout();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            tooltip: 'Retour',
            onPressed: () => ref.read(authProvider.notifier).logout(),
          ),
        ),
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, -0.6),
              radius: 1.1,
              colors: [Color(0xFF0E2318), AppColors.canvas],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          height: 68,
                          width: 68,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppColors.green, AppColors.greenDeep],
                            ),
                            borderRadius: BorderRadius.circular(AppRadius.lg),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.green.withValues(alpha: 0.30),
                                blurRadius: 28,
                                spreadRadius: -4,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.mark_email_read_rounded,
                            size: 32,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      Text(
                        'Vérification',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineMedium,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Saisissez le code à 6 chiffres envoyé à votre adresse email.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxl),
                      TextField(
                        controller: _codeController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        maxLength: 6,
                        autofocus: true,
                        textAlign: TextAlign.center,
                        autofillHints: const [AutofillHints.oneTimeCode],
                        style: TextStyle(
                          fontFamily: mono,
                          fontSize: 30,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 12,
                          color: AppColors.textPrimary,
                        ),
                        decoration: const InputDecoration(
                          counterText: '',
                          hintText: '······',
                          contentPadding: EdgeInsets.symmetric(
                            vertical: AppSpacing.xl,
                          ),
                        ),
                        onChanged: (value) {
                          // Auto-submit once the full code is entered.
                          if (value.length == 6 && !isSubmitting) _submit();
                        },
                        onSubmitted: (_) => _submit(),
                      ),
                      if (authState.errorMessage != null) ...[
                        const SizedBox(height: AppSpacing.md),
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: AppColors.danger.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                            border: Border.all(
                              color: AppColors.danger.withValues(alpha: 0.32),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.error_outline_rounded,
                                color: AppColors.danger,
                                size: 18,
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Text(
                                  authState.errorMessage!,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: AppColors.danger,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.xl),
                      FilledButton(
                        onPressed: isSubmitting ? null : _submit,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.green,
                        ),
                        child: isSubmitting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.textMuted,
                                ),
                              )
                            : const Text('Vérifier et continuer'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _submit() {
    final code = _codeController.text.trim();
    if (code.length < 6) return;
    ref.read(authProvider.notifier).verifyOtp(code);
  }
}
