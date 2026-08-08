class ApiException implements Exception {
  final int? statusCode;
  final String code;

  ApiException(this.code, {this.statusCode});

  bool get isSessionExpired => code == 'session_expired' || code == 'no_session';

  /// The request never reached the site. Distinct from a rejected one, because
  /// only this case may be answered from the offline cache.
  bool get isConnectivityProblem =>
      code == 'network_error' || code == 'upstream_timeout';

  @override
  String toString() => 'ApiException($code, status: $statusCode)';
}
