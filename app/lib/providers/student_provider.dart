import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_exception.dart';
import '../core/student_cache.dart';
import '../models/student.dart';
import 'api_provider.dart';
import 'auth_provider.dart';

final studentCacheProvider = Provider<StudentCache>((ref) => StudentCache());

class StudentView {
  final StudentInfo student;
  final DateTime? capturedAt;

  const StudentView({required this.student, this.capturedAt});
}

final studentProvider = FutureProvider.autoDispose<StudentView>((ref) async {
  final auth = ref.watch(authProvider);
  final cache = ref.watch(studentCacheProvider);

  if (auth.status == AuthStatus.unauthenticated) {
    throw ApiException('no_session', statusCode: 401);
  }
  if (!auth.isAuthenticated) {
    final cached = await cache.read();
    if (cached != null) return StudentView(student: cached.student, capturedAt: cached.capturedAt);
    return Completer<StudentView>().future;
  }

  try {
    final student = await ref.watch(apiClientProvider).getStudentDetails();
    await cache.save(student);
    return StudentView(student: student);
  } on ApiException catch (error) {
    if (!error.isConnectivityProblem) rethrow;

    final cached = await cache.read();
    if (cached == null) rethrow;
    return StudentView(student: cached.student, capturedAt: cached.capturedAt);
  }
});

final studentCachePeekProvider = FutureProvider.autoDispose<CachedStudent?>((ref) {
  return ref.watch(studentCacheProvider).read();
});
