class ApiException implements Exception {
  final int? statusCode;
  final String code;

  ApiException(this.code, {this.statusCode});

  bool get isSessionExpired => code == 'session_expired' || code == 'no_session';

  bool get isConnectivityProblem =>
      code == 'network_error' || code == 'upstream_timeout';

  @override
  String toString() => 'ApiException($code, status: $statusCode)';
}
