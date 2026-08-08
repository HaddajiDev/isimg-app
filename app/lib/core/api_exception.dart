class ApiException implements Exception {
  final int? statusCode;
  final String code;

  ApiException(this.code, {this.statusCode});

  bool get isSessionExpired => code == 'session_expired' || code == 'no_session';

  @override
  String toString() => 'ApiException($code, status: $statusCode)';
}
