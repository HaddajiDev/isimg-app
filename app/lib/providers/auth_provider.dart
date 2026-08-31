import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';
import '../core/api_exception.dart';
import '../core/credential_store.dart';
import '../core/session_store.dart';
import 'api_provider.dart';

typedef _SilentLogin = ({bool signedIn, String? message});

const _wrongCredentials = 'Identifiants incorrects';

const _passwordExpired = 'Votre mot de passe ISIMG a expiré. Changez-le sur '
    'isimg.rnu.tn, puis reconnectez-vous.';

String _typedLoginMessage(Object error) =>
    error is ApiException && error.code == 'password_expired'
        ? _passwordExpired
        : _wrongCredentials;

String? _replayedLoginMessage(Object error) {
  if (error is! ApiException) return null;
  return switch (error.code) {
    'password_expired' => _passwordExpired,
    'invalid_credentials' => _wrongCredentials,
    _ => null,
  };
}

final credentialStoreProvider = Provider<CredentialStore>((ref) => CredentialStore());
final sessionStoreProvider = Provider<SessionStore>((ref) => SessionStore());

enum AuthStatus {
  checking,
  unauthenticated,
  submitting,
  otpPending,
  authenticated,

  reauthenticating,
}

class AuthState {
  final AuthStatus status;

  final int sessionGeneration;

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

  bool get showsAppShell =>
      status == AuthStatus.authenticated || status == AuthStatus.reauthenticating;

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

      final stored = await _credentials.read();
      if (stored != null) {
        state = state.copyWith(status: AuthStatus.reauthenticating);
        final attempt = await _attemptSilentLogin(stored);
        if (attempt.signedIn) return;
        if (attempt.message != null) {
          await logout(errorMessage: attempt.message);
          return;
        }
      }
    } catch (_) {
    }
    state = state.copyWith(status: AuthStatus.unauthenticated);
  }

  Future<_SilentLogin> _attemptSilentLogin(Credentials credentials) async {
    try {
      final result = await _api.login(credentials.username, credentials.password);
      if (result is LoginOk) {
        _markAuthenticated();
        return (signedIn: true, message: null);
      }

      return (signedIn: false, message: null);
    } catch (e) {
      return (signedIn: false, message: _replayedLoginMessage(e));
    }
  }

  Future<void> handleSessionExpired() async {
    final stored = await _credentials.read();
    if (stored != null) {
      final attempt = await _attemptSilentLogin(stored);
      if (attempt.signedIn) return;
      if (attempt.message != null) {
        await logout(errorMessage: attempt.message);
        return;
      }
    }
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
        errorMessage: _typedLoginMessage(e),
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

      await _persistPendingCredentials();
      _markAuthenticated();
    } catch (e) {
      state = pending.copyWith(
        status: AuthStatus.otpPending,
        errorMessage: 'Code invalide ou expiré',
      );
    }
  }

  Future<void> logout({String? errorMessage}) async {
    _pendingCredentials = null;
    await _sessions.clear();
    await _credentials.clear();
    state = AuthState(
      status: AuthStatus.unauthenticated,
      sessionGeneration: state.sessionGeneration + 1,
      errorMessage: errorMessage,
    );
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
