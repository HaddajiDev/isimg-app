import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_updater.dart';

final appUpdaterProvider = Provider<AppUpdater>((ref) => AppUpdater());

class UpdateNotifier extends Notifier<UpdateState> {
  AppUpdater get _updater => ref.read(appUpdaterProvider);

  @override
  UpdateState build() {
    // Checked once on launch. A failure here is silent: a student who cannot
    // reach the bucket should still get on with using the app.
    check();
    return const UpdateState();
  }

  Future<void> check() async {
    state = const UpdateState(stage: UpdateStage.checking);
    try {
      final release = await _updater.check();
      state = release == null
          ? const UpdateState()
          : UpdateState(stage: UpdateStage.available, release: release);
    } catch (_) {
      state = const UpdateState();
    }
  }

  Future<void> downloadAndInstall() async {
    final release = state.release;
    if (release == null) return;

    state = UpdateState(stage: UpdateStage.downloading, release: release);
    try {
      final apk = await _updater.download(
        release,
        onProgress: (progress) {
          state = UpdateState(
            stage: UpdateStage.downloading,
            release: release,
            progress: progress,
          );
        },
      );

      state = UpdateState(stage: UpdateStage.readyToInstall, release: release);
      await _updater.install(apk);
    } catch (error) {
      state = UpdateState(
        stage: UpdateStage.failed,
        release: release,
        error: error.toString(),
      );
    }
  }

  void dismiss() => state = const UpdateState();
}

final updateProvider =
    NotifierProvider<UpdateNotifier, UpdateState>(UpdateNotifier.new);
