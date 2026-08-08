import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';
import '../core/credential_store.dart';
import '../core/session_store.dart';
import 'api_provider.dart';

/// Injectable so tests can supply in-memory stores.
final credentialStoreProvider = Provider<CredentialStore>((ref) => CredentialStore());
final sessionStoreProvider = Provider<SessionStore>((ref) => SessionStore());

enum AuthStatus { checking, unauthenticated, submitting, otpPending, authenticated }

class AuthState {
  final AuthStatus status;

  /// Bumped whenever a new session is stored, so dependants refetch.
  final int sessionGeneration;

  /// Interim state handed out by a login that needs the emailed code.
  final String? pendingSession;
  final String? pendingToken2fa;

  final String? errorMessage;

  const AuthState({
    required this.status,
    this.sessionGeneration = 0,
    this.pendingSession,
    this.pendingToken2fa,
    this.errorMessage,
  });

  const AuthState.initial() : this(status: AuthStatus.checking);

  bool get isAuthenticated => status == AuthStatus.authenticated;

  AuthState copyWith({
    AuthStatus? status,
    int? sessionGeneration,
    String? pendingSession,
    String? pendingToken2fa,
    String? errorMessage,
  }) {
    return AuthState(
      status: status ?? this.status,
      sessionGeneration: sessionGeneration ?? this.sessionGeneration,
      pendingSession: pendingSession ?? this.pendingSession,
      pendingToken2fa: pendingToken2fa ?? this.pendingToken2fa,
      errorMessage: errorMessage,
    );
  }
}

class AuthNotifier extends Notifier<AuthState> {
  ApiClient get _api => ref.read(apiClientProvider);
  CredentialStore get _credentials => ref.read(credentialStoreProvider);
  SessionStore get _sessions => ref.read(sessionStoreProvider);

  /// Credentials from the login form, held only until we know whether the
  /// login needs a code — they are saved once it actually succeeds.
  Credentials? _pendingCredentials;

  @override
  AuthState build() {
    _restoreSession();
    return const AuthState.initial();
  }

  void _markAuthenticated() {
    state = AuthState(
      status: AuthStatus.authenticated,
      sessionGeneration: state.sessionGeneration + 1,
    );
  }

  Future<void> _restoreSession() async {
    try {
      if (await _sessions.read() != null) {
        _markAuthenticated();
        return;
      }

      // No session, but the device remembers the login: sign in silently.
      final stored = await _credentials.read();
      if (stored != null) {
        state = state.copyWith(status: AuthStatus.submitting);
        if (await _attemptSilentLogin(stored)) return;
      }
    } catch (_) {
      // Storage unavailable (e.g. a test harness) — fall through to the login
      // screen rather than getting stuck on "checking".
    }
    state = state.copyWith(status: AuthStatus.unauthenticated);
  }

  /// Signs in with saved credentials. Returns false if they no longer work, or
  /// if the site now wants a code — the caller then shows the login screen.
  Future<bool> _attemptSilentLogin(Credentials credentials) async {
    try {
      final result = await _api.login(credentials.username, credentials.password);
      if (result is LoginOk) {
        _markAuthenticated();
        return true;
      }
      // A code is required, so this cannot be completed unattended.
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Called when the backend reports the upstream session has lapsed. Tries to
  /// renew it in the background; only forces the login screen if that fails.
  Future<void> handleSessionExpired() async {
    final stored = await _credentials.read();
    if (stored != null && await _attemptSilentLogin(stored)) return;
    await logout();
  }

  Future<void> login(
    String username,
    String password, {
    bool rememberMe = false,
  }) async {
    state = state.copyWith(status: AuthStatus.submitting, errorMessage: null);
    _pendingCredentials =
        rememberMe ? Credentials(username: username, password: password) : null;

    try {
      final result = await _api.login(username, password);
      switch (result) {
        case LoginOk():
          await _persistPendingCredentials();
          _markAuthenticated();
        case LoginOtpRequired(session: final session, token2fa: final token2fa):
          state = AuthState(
            status: AuthStatus.otpPending,
            sessionGeneration: state.sessionGeneration,
            pendingSession: session,
            pendingToken2fa: token2fa,
          );
      }
    } catch (e) {
      _pendingCredentials = null;
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        errorMessage: 'Identifiants incorrects',
      );
    }
  }

  Future<void> _persistPendingCredentials() async {
    final credentials = _pendingCredentials;
    _pendingCredentials = null;
    if (credentials != null) await _credentials.save(credentials);
  }

  Future<void> verifyOtp(String code) async {
    final session = state.pendingSession;
    final token2fa = state.pendingToken2fa;
    if (session == null || token2fa == null) return;

    final pending = state;
    state = state.copyWith(status: AuthStatus.submitting, errorMessage: null);
    try {
      await _api.verifyOtp(session: session, token2fa: token2fa, code: code);
      // Only now is the login proven, so this is where it becomes worth
      // remembering the credentials that got us here.
      await _persistPendingCredentials();
      _markAuthenticated();
    } catch (e) {
      // Keep the interim state so the student can retype the code.
      state = pending.copyWith(
        status: AuthStatus.otpPending,
        errorMessage: 'Code invalide ou expiré',
      );
    }
  }

  /// Signing out is explicit, so the remembered login is discarded too —
  /// otherwise the app would immediately sign itself back in.
  Future<void> logout() async {
    _pendingCredentials = null;
    await _sessions.clear();
    await _credentials.clear();
    state = AuthState(
      status: AuthStatus.unauthenticated,
      sessionGeneration: state.sessionGeneration + 1,
    );
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
