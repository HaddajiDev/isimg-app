/// URL of the backend's `/version` endpoint used for update checks.
///
/// Set it to your deployed backend, e.g. `https://your-host.example/version`.
/// Leave empty to disable the check entirely (the banner never shows).
/// Can be overridden at build time without editing this file:
///   flutter build appbundle --release --dart-define=VERSION_API=https://host/version
const String kVersionApiUrl = String.fromEnvironment(
  'VERSION_API',
  defaultValue: 'https://isimg-app-backend.vercel.app/version',
);

/// Play Store listing opened by the "Mettre à jour" button on the update banner.
const String kPlayStoreUrl =
    'https://play.google.com/store/apps/details?id=io.github.haddajidev.isimg';

